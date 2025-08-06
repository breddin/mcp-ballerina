// Cache Manager for Ballerina MCP Server
// Implements multi-level caching with LRU eviction and TTL support

import ballerina/time;
import ballerina/log;
import ballerina/crypto;

// Cache entry
public type CacheEntry record {|
    string key;
    any value;
    time:Utc createdAt;
    time:Utc? lastAccessed;
    int accessCount = 0;
    int? ttlSeconds?;
    int sizeBytes = 0;
    map<string> metadata = {};
|};

// Cache statistics
public type CacheStats record {|
    int totalEntries;
    int totalSizeBytes;
    int hits;
    int misses;
    decimal hitRate;
    int evictions;
    time:Utc startTime;
    time:Utc lastReset;
|};

// Cache configuration
public type CacheConfig record {|
    int maxSizeBytes = 104857600; // 100MB default
    int maxEntries = 10000;
    int defaultTTL = 3600; // 1 hour
    boolean enableStatistics = true;
    EvictionPolicy evictionPolicy = LRU;
    boolean enableCompression = false;
    int compressionThreshold = 1024; // Compress if > 1KB
|};

// Eviction policies
public enum EvictionPolicy {
    LRU,  // Least Recently Used
    LFU,  // Least Frequently Used
    FIFO, // First In First Out
    TTL   // Time To Live based
}

// Cache levels
public enum CacheLevel {
    L1_MEMORY,
    L2_DISK,
    L3_DISTRIBUTED
}

// Cache Manager
public class CacheManager {
    private map<CacheEntry> l1Cache = {};
    private map<CacheEntry> l2Cache = {};
    private CacheConfig config;
    private CacheStats stats;
    private map<time:Utc> accessHistory = {};
    private string[] lruQueue = [];
    
    public function init(CacheConfig? config = ()) {
        self.config = config ?: {};
        self.stats = {
            totalEntries: 0,
            totalSizeBytes: 0,
            hits: 0,
            misses: 0,
            hitRate: 0.0,
            evictions: 0,
            startTime: time:utcNow(),
            lastReset: time:utcNow()
        };
        
        // Start background tasks
        _ = @strand {thread: "any"} start self.ttlCleanup();
    }
    
    // Get value from cache
    public function get(string key) returns any? {
        // Check L1 cache
        CacheEntry? entry = self.l1Cache[key];
        if entry is CacheEntry {
            if self.isValid(entry) {
                self.updateAccessInfo(entry);
                self.recordHit();
                return entry.value;
            } else {
                // Entry expired
                _ = self.l1Cache.remove(key);
            }
        }
        
        // Check L2 cache
        entry = self.l2Cache[key];
        if entry is CacheEntry {
            if self.isValid(entry) {
                // Promote to L1
                self.promoteToL1(entry);
                self.updateAccessInfo(entry);
                self.recordHit();
                return entry.value;
            } else {
                _ = self.l2Cache.remove(key);
            }
        }
        
        self.recordMiss();
        return ();
    }
    
    // Put value in cache
    public function put(string key, any value, int? ttl = ()) returns error? {
        int sizeBytes = self.estimateSize(value);
        
        // Check size limits
        if sizeBytes > self.config.maxSizeBytes {
            return error("Value too large for cache: " + sizeBytes.toString() + " bytes");
        }
        
        // Evict if necessary
        if self.needsEviction(sizeBytes) {
            self.evict(sizeBytes);
        }
        
        // Compress if needed
        any storedValue = value;
        if self.config.enableCompression && sizeBytes > self.config.compressionThreshold {
            storedValue = self.compress(value);
        }
        
        // Create cache entry
        CacheEntry entry = {
            key: key,
            value: storedValue,
            createdAt: time:utcNow(),
            lastAccessed: time:utcNow(),
            ttlSeconds: ttl ?: self.config.defaultTTL,
            sizeBytes: sizeBytes
        };
        
        // Add to L1 cache
        self.l1Cache[key] = entry;
        self.updateLRUQueue(key);
        self.stats.totalEntries += 1;
        self.stats.totalSizeBytes += sizeBytes;
        
        return;
    }
    
    // Remove from cache
    public function remove(string key) returns boolean {
        boolean removed = false;
        
        CacheEntry? entry = self.l1Cache[key];
        if entry is CacheEntry {
            _ = self.l1Cache.remove(key);
            self.stats.totalSizeBytes -= entry.sizeBytes;
            self.stats.totalEntries -= 1;
            removed = true;
        }
        
        entry = self.l2Cache[key];
        if entry is CacheEntry {
            _ = self.l2Cache.remove(key);
            self.stats.totalSizeBytes -= entry.sizeBytes;
            self.stats.totalEntries -= 1;
            removed = true;
        }
        
        return removed;
    }
    
    // Clear entire cache
    public function clear() {
        self.l1Cache = {};
        self.l2Cache = {};
        self.lruQueue = [];
        self.stats.totalEntries = 0;
        self.stats.totalSizeBytes = 0;
        self.stats.evictions = 0;
        log:printInfo("Cache cleared");
    }
    
    // Get cache statistics
    public function getStats() returns CacheStats {
        decimal total = <decimal>(self.stats.hits + self.stats.misses);
        if total > 0 {
            self.stats.hitRate = <decimal>self.stats.hits / total * 100;
        }
        return self.stats;
    }
    
    // Batch get operation
    public function batchGet(string[] keys) returns map<any> {
        map<any> results = {};
        foreach string key in keys {
            any? value = self.get(key);
            if value is any {
                results[key] = value;
            }
        }
        return results;
    }
    
    // Batch put operation
    public function batchPut(map<any> entries, int? ttl = ()) returns error? {
        foreach [string, any] [key, value] in entries.entries() {
            check self.put(key, value, ttl);
        }
        return;
    }
    
    // Warm up cache with preloaded data
    public function warmUp(map<any> data) returns error? {
        log:printInfo("Warming up cache with " + data.keys().length().toString() + " entries");
        return self.batchPut(data);
    }
    
    // Check if cache needs eviction
    private function needsEviction(int additionalBytes) returns boolean {
        return self.stats.totalSizeBytes + additionalBytes > self.config.maxSizeBytes ||
               self.stats.totalEntries >= self.config.maxEntries;
    }
    
    // Evict entries based on policy
    private function evict(int bytesNeeded) {
        match self.config.evictionPolicy {
            LRU => {
                self.evictLRU(bytesNeeded);
            }
            LFU => {
                self.evictLFU(bytesNeeded);
            }
            FIFO => {
                self.evictFIFO(bytesNeeded);
            }
            TTL => {
                self.evictExpired();
            }
        }
    }
    
    // LRU eviction
    private function evictLRU(int bytesNeeded) {
        int evicted = 0;
        
        while evicted < bytesNeeded && self.lruQueue.length() > 0 {
            string? key = self.lruQueue.shift();
            if key is string {
                CacheEntry? entry = self.l1Cache[key];
                if entry is CacheEntry {
                    evicted += entry.sizeBytes;
                    // Move to L2 instead of removing
                    self.demoteToL2(entry);
                    self.stats.evictions += 1;
                }
            }
        }
    }
    
    // LFU eviction
    private function evictLFU(int bytesNeeded) {
        // Sort by access count and evict least frequently used
        CacheEntry[] entries = self.l1Cache.toArray();
        entries = entries.sort(function(CacheEntry a, CacheEntry b) returns int {
            return a.accessCount - b.accessCount;
        });
        
        int evicted = 0;
        foreach CacheEntry entry in entries {
            if evicted >= bytesNeeded {
                break;
            }
            evicted += entry.sizeBytes;
            self.demoteToL2(entry);
            self.stats.evictions += 1;
        }
    }
    
    // FIFO eviction
    private function evictFIFO(int bytesNeeded) {
        // Sort by creation time and evict oldest
        CacheEntry[] entries = self.l1Cache.toArray();
        entries = entries.sort(function(CacheEntry a, CacheEntry b) returns int {
            return <int>time:utcDiffSeconds(a.createdAt, b.createdAt);
        });
        
        int evicted = 0;
        foreach CacheEntry entry in entries {
            if evicted >= bytesNeeded {
                break;
            }
            evicted += entry.sizeBytes;
            _ = self.l1Cache.remove(entry.key);
            self.stats.evictions += 1;
        }
    }
    
    // Evict expired entries
    private function evictExpired() {
        time:Utc now = time:utcNow();
        string[] toRemove = [];
        
        foreach [string, CacheEntry] [key, entry] in self.l1Cache.entries() {
            if !self.isValid(entry) {
                toRemove.push(key);
            }
        }
        
        foreach string key in toRemove {
            _ = self.l1Cache.remove(key);
            self.stats.evictions += 1;
        }
    }
    
    // Check if entry is valid (not expired)
    private function isValid(CacheEntry entry) returns boolean {
        if entry.ttlSeconds is int {
            time:Utc expiryTime = time:utcAddSeconds(entry.createdAt, <time:Seconds>entry.ttlSeconds);
            return time:utcDiffSeconds(time:utcNow(), expiryTime) < 0;
        }
        return true;
    }
    
    // Update access information
    private function updateAccessInfo(CacheEntry entry) {
        entry.lastAccessed = time:utcNow();
        entry.accessCount += 1;
        self.updateLRUQueue(entry.key);
    }
    
    // Update LRU queue
    private function updateLRUQueue(string key) {
        // Remove from current position
        int? index = self.lruQueue.indexOf(key);
        if index is int {
            _ = self.lruQueue.remove(index);
        }
        // Add to end (most recently used)
        self.lruQueue.push(key);
    }
    
    // Promote entry to L1 cache
    private function promoteToL1(CacheEntry entry) {
        _ = self.l2Cache.remove(entry.key);
        self.l1Cache[entry.key] = entry;
        self.updateLRUQueue(entry.key);
    }
    
    // Demote entry to L2 cache
    private function demoteToL2(CacheEntry entry) {
        _ = self.l1Cache.remove(entry.key);
        self.l2Cache[entry.key] = entry;
        
        // Remove from LRU queue
        int? index = self.lruQueue.indexOf(entry.key);
        if index is int {
            _ = self.lruQueue.remove(index);
        }
    }
    
    // Record cache hit
    private function recordHit() {
        if self.config.enableStatistics {
            self.stats.hits += 1;
        }
    }
    
    // Record cache miss
    private function recordMiss() {
        if self.config.enableStatistics {
            self.stats.misses += 1;
        }
    }
    
    // Estimate size of value in bytes
    private function estimateSize(any value) returns int {
        // Simplified size estimation
        if value is string {
            return value.length();
        } else if value is byte[] {
            return value.length();
        } else if value is int|float|decimal|boolean {
            return 8;
        } else {
            // For complex types, use JSON serialization
            string jsonStr = value.toString();
            return jsonStr.length();
        }
    }
    
    // Compress value
    private function compress(any value) returns any {
        // Simplified compression (would use actual compression library)
        if value is string {
            // Could use gzip compression here
            return value;
        }
        return value;
    }
    
    // Background TTL cleanup
    private function ttlCleanup() {
        while true {
            runtime:sleep(60); // Check every minute
            self.evictExpired();
        }
    }
    
    // Get cache size
    public function getSize() returns int {
        return self.stats.totalSizeBytes;
    }
    
    // Get entry count
    public function getEntryCount() returns int {
        return self.stats.totalEntries;
    }
    
    // Check if key exists
    public function contains(string key) returns boolean {
        return self.l1Cache.hasKey(key) || self.l2Cache.hasKey(key);
    }
    
    // Get all keys
    public function getKeys() returns string[] {
        string[] keys = self.l1Cache.keys();
        keys.push(...self.l2Cache.keys());
        return keys;
    }
    
    // Reset statistics
    public function resetStats() {
        self.stats = {
            totalEntries: self.stats.totalEntries,
            totalSizeBytes: self.stats.totalSizeBytes,
            hits: 0,
            misses: 0,
            hitRate: 0.0,
            evictions: 0,
            startTime: self.stats.startTime,
            lastReset: time:utcNow()
        };
    }
}

// Distributed Cache Manager (for multi-instance)
public class DistributedCacheManager {
    private CacheManager localCache;
    private map<string> peerNodes = {};
    private string nodeId;
    
    public function init(CacheConfig? config = (), string? nodeId = ()) {
        self.localCache = new(config);
        self.nodeId = nodeId ?: crypto:hashMd5(time:utcNow().toString()).toBase16();
    }
    
    // Get with distributed lookup
    public function get(string key) returns any? {
        // Check local cache first
        any? value = self.localCache.get(key);
        if value is any {
            return value;
        }
        
        // Check peer nodes
        string targetNode = self.getTargetNode(key);
        if targetNode != self.nodeId {
            return self.getFromPeer(targetNode, key);
        }
        
        return ();
    }
    
    // Put with replication
    public function put(string key, any value, int? ttl = ()) returns error? {
        // Store locally
        check self.localCache.put(key, value, ttl);
        
        // Replicate to peers
        string[] replicas = self.getReplicaNodes(key);
        foreach string replica in replicas {
            error? result = self.replicateToPeer(replica, key, value, ttl);
            if result is error {
                log:printError("Failed to replicate to " + replica, 'error = result);
            }
        }
        
        return;
    }
    
    // Get target node for key (consistent hashing)
    private function getTargetNode(string key) returns string {
        // Simplified consistent hashing
        string hash = crypto:hashMd5(key).toBase16();
        string[] nodes = self.peerNodes.keys();
        if nodes.length() == 0 {
            return self.nodeId;
        }
        
        // Find closest node
        int minDistance = int:MAX_VALUE;
        string targetNode = self.nodeId;
        
        foreach string node in nodes {
            int distance = self.hashDistance(hash, node);
            if distance < minDistance {
                minDistance = distance;
                targetNode = node;
            }
        }
        
        return targetNode;
    }
    
    // Get replica nodes for key
    private function getReplicaNodes(string key) returns string[] {
        // Return N replica nodes for redundancy
        return [];
    }
    
    // Get from peer node
    private function getFromPeer(string nodeId, string key) returns any? {
        // Would implement network call to peer
        return ();
    }
    
    // Replicate to peer node
    private function replicateToPeer(string nodeId, string key, any value, int? ttl) 
        returns error? {
        // Would implement network call to peer
        return;
    }
    
    // Calculate hash distance
    private function hashDistance(string hash1, string hash2) returns int {
        // Simplified distance calculation
        return 0;
    }
    
    // Add peer node
    public function addPeer(string nodeId, string address) {
        self.peerNodes[nodeId] = address;
    }
    
    // Remove peer node
    public function removePeer(string nodeId) {
        _ = self.peerNodes.remove(nodeId);
    }
}