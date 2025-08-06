// Memory Optimizer for Ballerina MCP Server
// Implements memory pooling, object reuse, and garbage collection optimization

import ballerina/log;
import ballerina/time;
import ballerina/jballerina.java;

// Memory pool configuration
public type MemoryPoolConfig record {|
    int initialSize = 100;
    int maxSize = 1000;
    int growthFactor = 2;
    boolean enableMetrics = true;
    int gcThreshold = 80; // Trigger GC at 80% memory usage
|};

// Memory statistics
public type MemoryStats record {|
    int totalAllocated;
    int totalFreed;
    int currentUsage;
    int peakUsage;
    int poolHits;
    int poolMisses;
    decimal hitRate;
    int gcRuns;
    time:Utc lastGC;
|};

// Object pool entry
public type PoolEntry record {|
    any object;
    boolean inUse;
    time:Utc lastAccessed;
    int reuseCount;
|};

// Memory Optimizer
public class MemoryOptimizer {
    private MemoryPoolConfig config;
    private map<PoolEntry[]> objectPools = {};
    private MemoryStats stats;
    private int currentMemoryUsage = 0;
    
    public function init(MemoryPoolConfig? config = ()) {
        self.config = config ?: {};
        self.stats = {
            totalAllocated: 0,
            totalFreed: 0,
            currentUsage: 0,
            peakUsage: 0,
            poolHits: 0,
            poolMisses: 0,
            hitRate: 0.0,
            gcRuns: 0,
            lastGC: time:utcNow()
        };
        
        // Start memory monitoring
        _ = @strand {thread: "any"} start self.monitorMemory();
    }
    
    // Get object from pool
    public function acquire(typedesc<any> t) returns any {
        string typeName = t.toString();
        
        // Check if pool exists for this type
        if !self.objectPools.hasKey(typeName) {
            self.createPool(typeName);
        }
        
        PoolEntry[]? pool = self.objectPools[typeName];
        if pool is PoolEntry[] {
            // Find available object in pool
            foreach PoolEntry entry in pool {
                if !entry.inUse {
                    entry.inUse = true;
                    entry.lastAccessed = time:utcNow();
                    entry.reuseCount += 1;
                    self.stats.poolHits += 1;
                    self.updateHitRate();
                    return entry.object;
                }
            }
        }
        
        // No available object, create new one
        self.stats.poolMisses += 1;
        self.updateHitRate();
        any newObject = self.createObject(t);
        self.addToPool(typeName, newObject);
        return newObject;
    }
    
    // Release object back to pool
    public function release(any obj) {
        string typeName = typeof obj;
        PoolEntry[]? pool = self.objectPools[typeName];
        
        if pool is PoolEntry[] {
            foreach PoolEntry entry in pool {
                if entry.object === obj {
                    entry.inUse = false;
                    entry.lastAccessed = time:utcNow();
                    self.resetObject(obj);
                    self.stats.currentUsage -= self.estimateObjectSize(obj);
                    return;
                }
            }
        }
    }
    
    // Create object pool for type
    private function createPool(string typeName) {
        PoolEntry[] pool = [];
        self.objectPools[typeName] = pool;
    }
    
    // Add object to pool
    private function addToPool(string typeName, any obj) {
        PoolEntry[]? pool = self.objectPools[typeName];
        if pool is PoolEntry[] {
            if pool.length() < self.config.maxSize {
                pool.push({
                    object: obj,
                    inUse: true,
                    lastAccessed: time:utcNow(),
                    reuseCount: 0
                });
                self.stats.totalAllocated += 1;
                int objSize = self.estimateObjectSize(obj);
                self.stats.currentUsage += objSize;
                if self.stats.currentUsage > self.stats.peakUsage {
                    self.stats.peakUsage = self.stats.currentUsage;
                }
            }
        }
    }
    
    // Create new object instance
    private function createObject(typedesc<any> t) returns any {
        // Would use reflection or factory pattern
        return new;
    }
    
    // Reset object state for reuse
    private function resetObject(any obj) {
        // Clear object state for reuse
        // Implementation depends on object type
    }
    
    // Estimate object size in bytes
    private function estimateObjectSize(any obj) returns int {
        if obj is string {
            return (<string>obj).length() * 2; // 2 bytes per char
        } else if obj is byte[] {
            return (<byte[]>obj).length();
        } else if obj is int|float|boolean {
            return 8;
        } else if obj is map<any> {
            return (<map<any>>obj).keys().length() * 32; // Rough estimate
        } else if obj is any[] {
            return (<any[]>obj).length() * 8;
        }
        return 32; // Default object overhead
    }
    
    // Update hit rate
    private function updateHitRate() {
        int total = self.stats.poolHits + self.stats.poolMisses;
        if total > 0 {
            self.stats.hitRate = <decimal>self.stats.poolHits / <decimal>total * 100;
        }
    }
    
    // Garbage collection optimization
    public function optimizeGC() {
        // Force garbage collection if memory usage is high
        decimal memoryUsagePercent = self.getMemoryUsagePercent();
        
        if memoryUsagePercent > <decimal>self.config.gcThreshold {
            self.triggerGC();
        }
        
        // Compact object pools
        self.compactPools();
    }
    
    // Trigger garbage collection
    private function triggerGC() {
        log:printInfo("Triggering garbage collection");
        
        // Clean up unused objects in pools
        foreach [string, PoolEntry[]] [typeName, pool] in self.objectPools.entries() {
            self.cleanPool(pool);
        }
        
        // Request system GC
        self.requestSystemGC();
        
        self.stats.gcRuns += 1;
        self.stats.lastGC = time:utcNow();
    }
    
    // Clean unused objects from pool
    private function cleanPool(PoolEntry[] pool) {
        time:Utc now = time:utcNow();
        int cleanupThreshold = 300; // 5 minutes
        
        PoolEntry[] activeEntries = [];
        foreach PoolEntry entry in pool {
            time:Seconds elapsed = time:utcDiffSeconds(now, entry.lastAccessed);
            if entry.inUse || elapsed < <time:Seconds>cleanupThreshold {
                activeEntries.push(entry);
            } else {
                self.stats.totalFreed += 1;
                self.stats.currentUsage -= self.estimateObjectSize(entry.object);
            }
        }
        
        // Replace pool with active entries only
        pool = activeEntries;
    }
    
    // Compact object pools
    private function compactPools() {
        foreach [string, PoolEntry[]] [typeName, pool] in self.objectPools.entries() {
            // Remove empty pools
            if pool.length() == 0 {
                _ = self.objectPools.remove(typeName);
            }
        }
    }
    
    // Request system garbage collection
    private function requestSystemGC() {
        // Would call Java System.gc() through interop
        java:Method gcMethod = check java:resolveMethod(
            java:fromString("java.lang.System"),
            "gc",
            []
        );
        _ = gcMethod.invoke();
    }
    
    // Monitor memory usage
    private function monitorMemory() {
        while true {
            runtime:sleep(30); // Check every 30 seconds
            
            decimal usage = self.getMemoryUsagePercent();
            if usage > <decimal>self.config.gcThreshold {
                self.optimizeGC();
            }
            
            // Log if usage is critical
            if usage > 90.0 {
                log:printWarn("Critical memory usage: " + usage.toString() + "%");
            }
        }
    }
    
    // Get memory usage percentage
    private function getMemoryUsagePercent() returns decimal {
        int maxMemory = self.getMaxMemory();
        if maxMemory > 0 {
            return <decimal>self.stats.currentUsage / <decimal>maxMemory * 100;
        }
        return 0.0;
    }
    
    // Get maximum available memory
    private function getMaxMemory() returns int {
        // Would get from JVM runtime
        return 1073741824; // 1GB default
    }
    
    // Get memory statistics
    public function getStats() returns MemoryStats {
        return self.stats;
    }
    
    // Clear all pools
    public function clearPools() {
        foreach [string, PoolEntry[]] [_, pool] in self.objectPools.entries() {
            pool = [];
        }
        self.objectPools = {};
        self.stats.totalFreed = self.stats.totalAllocated;
        self.stats.currentUsage = 0;
        log:printInfo("All memory pools cleared");
    }
    
    // Pre-allocate objects
    public function preallocate(typedesc<any> t, int count) {
        string typeName = t.toString();
        
        if !self.objectPools.hasKey(typeName) {
            self.createPool(typeName);
        }
        
        foreach int i in 0 ..< count {
            any obj = self.createObject(t);
            self.addToPool(typeName, obj);
            self.release(obj); // Mark as available
        }
        
        log:printInfo("Pre-allocated " + count.toString() + " objects of type " + typeName);
    }
}

// String Builder for efficient string concatenation
public class StringBuilder {
    private string[] segments = [];
    private int totalLength = 0;
    
    public function append(string s) {
        self.segments.push(s);
        self.totalLength += s.length();
    }
    
    public function toString() returns string {
        return string:'join("", ...self.segments);
    }
    
    public function clear() {
        self.segments = [];
        self.totalLength = 0;
    }
    
    public function length() returns int {
        return self.totalLength;
    }
}

// Lazy Loader for deferred initialization
public class LazyLoader {
    private map<any> cache = {};
    private map<function() returns any> loaders = {};
    
    public function register(string key, function() returns any loader) {
        self.loaders[key] = loader;
    }
    
    public function get(string key) returns any? {
        // Check cache first
        if self.cache.hasKey(key) {
            return self.cache[key];
        }
        
        // Load if loader exists
        function() returns any? loader = self.loaders[key];
        if loader is function() returns any {
            any value = loader();
            self.cache[key] = value;
            return value;
        }
        
        return ();
    }
    
    public function isLoaded(string key) returns boolean {
        return self.cache.hasKey(key);
    }
    
    public function invalidate(string key) {
        _ = self.cache.remove(key);
    }
    
    public function clear() {
        self.cache = {};
    }
}

// Memory-efficient buffer for streaming data
public class StreamBuffer {
    private byte[] buffer;
    private int position = 0;
    private int capacity;
    
    public function init(int capacity = 8192) {
        self.capacity = capacity;
        self.buffer = [];
        foreach int i in 0 ..< capacity {
            self.buffer.push(0);
        }
    }
    
    public function write(byte[] data) returns error? {
        if self.position + data.length() > self.capacity {
            return error("Buffer overflow");
        }
        
        foreach int i in 0 ..< data.length() {
            self.buffer[self.position + i] = data[i];
        }
        self.position += data.length();
        
        return;
    }
    
    public function read(int length) returns byte[] {
        int readLength = int:min(length, self.position);
        byte[] data = self.buffer.slice(0, readLength);
        
        // Shift remaining data
        foreach int i in 0 ..< (self.position - readLength) {
            self.buffer[i] = self.buffer[i + readLength];
        }
        self.position -= readLength;
        
        return data;
    }
    
    public function available() returns int {
        return self.position;
    }
    
    public function remaining() returns int {
        return self.capacity - self.position;
    }
    
    public function clear() {
        self.position = 0;
    }
}