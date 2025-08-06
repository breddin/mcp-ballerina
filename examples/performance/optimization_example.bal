import ballerina/io;
import ballerina/time;
import ballerina/random;
import modules.performance.cache_manager;
import modules.performance.parallel_processor;
import modules.performance.memory_optimizer;

public function main() returns error? {
    // Example 1: Multi-level Caching
    io:println("=== Multi-level Caching Example ===");
    
    cache_manager:CacheConfig cacheConfig = {
        maxSizeBytes: 10485760,  // 10MB
        maxEntries: 1000,
        evictionPolicy: cache_manager:LRU,
        ttlSeconds: 300,
        enableStats: true
    };
    
    cache_manager:CacheManager cache = new(cacheConfig);
    
    // Simulate database queries with caching
    foreach int i in 0 ..< 10 {
        string key = string `user_${i % 3}`;  // Reuse some keys
        
        // Try to get from cache first
        any? cachedValue = cache.get(key);
        
        if cachedValue is () {
            io:println(string `Cache MISS for ${key} - fetching from database`);
            
            // Simulate expensive database query
            time:Utc startTime = time:utcNow();
            check simulateSlowDatabaseQuery();
            time:Utc endTime = time:utcNow();
            
            decimal queryTime = <decimal>(endTime[0] - startTime[0]) + 
                               <decimal>(endTime[1] - startTime[1]) / 1000000000.0;
            
            // Store in cache
            json userData = {
                "id": i % 3,
                "name": string `User${i % 3}`,
                "email": string `user${i % 3}@example.com`,
                "queryTime": queryTime
            };
            
            check cache.put(key, userData, 60);  // Cache for 60 seconds
            io:println(string `  Stored in cache (query took ${queryTime}s)`);
        } else {
            io:println(string `Cache HIT for ${key} - returned from cache`);
        }
    }
    
    // Display cache statistics
    cache_manager:CacheStats stats = cache.getStats();
    io:println("\nCache Statistics:");
    io:println(string `  Hits: ${stats.hits} (${stats.hitRate}%)`);
    io:println(string `  Misses: ${stats.misses}`);
    io:println(string `  Evictions: ${stats.evictions}`);
    io:println(string `  Size: ${stats.currentSize} bytes`);
    io:println(string `  Entries: ${stats.entryCount}`);
    
    // Example 2: Parallel Processing
    io:println("\n\n=== Parallel Processing Example ===");
    
    parallel_processor:WorkerPoolConfig poolConfig = {
        corePoolSize: 4,
        maxPoolSize: 8,
        queueCapacity: 100,
        keepAliveTime: 60
    };
    
    parallel_processor:ParallelProcessor processor = new(poolConfig);
    
    // Process data in parallel
    int[] data = [];
    foreach int i in 0 ..< 20 {
        data.push(i);
    }
    
    io:println(string `Processing ${data.length()} items...`);
    
    time:Utc parallelStart = time:utcNow();
    
    // Map operation - square each number in parallel
    any[] squared = check processor.map(data, function(any item) returns any {
        int num = <int>item;
        // Simulate some computation
        check simulateComputation();
        return num * num;
    });
    
    time:Utc parallelEnd = time:utcNow();
    decimal parallelTime = <decimal>(parallelEnd[0] - parallelStart[0]) + 
                          <decimal>(parallelEnd[1] - parallelStart[1]) / 1000000000.0;
    
    io:println(string `Parallel processing completed in ${parallelTime}s`);
    io:println("Results: ", squared);
    
    // Compare with sequential processing
    time:Utc sequentialStart = time:utcNow();
    
    int[] sequentialResult = [];
    foreach int num in data {
        check simulateComputation();
        sequentialResult.push(num * num);
    }
    
    time:Utc sequentialEnd = time:utcNow();
    decimal sequentialTime = <decimal>(sequentialEnd[0] - sequentialStart[0]) + 
                            <decimal>(sequentialEnd[1] - sequentialStart[1]) / 1000000000.0;
    
    io:println(string `Sequential processing completed in ${sequentialTime}s`);
    io:println(string `Speedup: ${sequentialTime / parallelTime}x`);
    
    // Example 3: Batch Processing
    io:println("\n\n=== Batch Processing Example ===");
    
    // Process large dataset in batches
    int[] largeDataset = [];
    foreach int i in 0 ..< 100 {
        largeDataset.push(i);
    }
    
    parallel_processor:BatchConfig batchConfig = {
        batchSize: 10,
        parallelBatches: true
    };
    
    parallel_processor:BatchResult batchResult = check processor.processBatch(
        largeDataset,
        function(any[] batch) returns any[]|error {
            // Process each batch
            any[] results = [];
            foreach any item in batch {
                int num = <int>item;
                results.push(num * 2);
            }
            return results;
        },
        batchConfig
    );
    
    io:println(string `Processed ${batchResult.totalProcessed} items in ${batchResult.batchesProcessed} batches`);
    io:println(string `Success rate: ${batchResult.successRate}%`);
    
    // Example 4: Memory Optimization
    io:println("\n\n=== Memory Optimization Example ===");
    
    memory_optimizer:MemoryPoolConfig memConfig = {
        initialSize: 50,
        maxSize: 200,
        gcThreshold: 80,
        enableMonitoring: true
    };
    
    memory_optimizer:MemoryOptimizer optimizer = new(memConfig);
    
    // Pre-allocate objects
    optimizer.preallocate(string, 100);
    io:println("Pre-allocated 100 string objects");
    
    // Use object pooling
    io:println("\nObject pooling demonstration:");
    
    // Without pooling - creates new objects
    time:Utc noPoolStart = time:utcNow();
    foreach int i in 0 ..< 1000 {
        json obj = {"id": i, "data": "test"};
        // Object goes out of scope and needs GC
    }
    time:Utc noPoolEnd = time:utcNow();
    decimal noPoolTime = <decimal>(noPoolEnd[0] - noPoolStart[0]) + 
                        <decimal>(noPoolEnd[1] - noPoolStart[1]) / 1000000000.0;
    
    // With pooling - reuses objects
    time:Utc poolStart = time:utcNow();
    foreach int i in 0 ..< 1000 {
        any obj = optimizer.acquire(json);
        // Use the object
        json data = <json>obj;
        data = {"id": i, "data": "test"};
        // Return to pool for reuse
        optimizer.release(obj);
    }
    time:Utc poolEnd = time:utcNow();
    decimal poolTime = <decimal>(poolEnd[0] - poolStart[0]) + 
                      <decimal>(poolEnd[1] - poolStart[1]) / 1000000000.0;
    
    io:println(string `Without pooling: ${noPoolTime}s`);
    io:println(string `With pooling: ${poolTime}s`);
    io:println(string `Performance improvement: ${(noPoolTime - poolTime) / noPoolTime * 100}%`);
    
    // Get memory statistics
    memory_optimizer:MemoryStats memStats = optimizer.getStats();
    io:println("\nMemory Pool Statistics:");
    io:println(string `  Total allocated: ${memStats.totalAllocated}`);
    io:println(string `  Currently in use: ${memStats.inUse}`);
    io:println(string `  Available: ${memStats.available}`);
    io:println(string `  Pool efficiency: ${memStats.efficiency}%`);
    io:println(string `  GC triggers avoided: ${memStats.gcAvoided}`);
    
    // Example 5: Pipeline Processing
    io:println("\n\n=== Pipeline Processing Example ===");
    
    // Create a processing pipeline
    function[] pipeline = [
        function(any input) returns any {
            // Stage 1: Parse
            int num = <int>input;
            return num.toString();
        },
        function(any input) returns any {
            // Stage 2: Transform
            string str = <string>input;
            return "processed_" + str;
        },
        function(any input) returns any {
            // Stage 3: Format
            string str = <string>input;
            return str.toUpperAscii();
        }
    ];
    
    int[] pipelineData = [1, 2, 3, 4, 5];
    
    parallel_processor:PipelineResult pipelineResult = check processor.executePipeline(
        pipelineData, pipeline
    );
    
    io:println("Pipeline Results:");
    foreach any result in pipelineResult.results {
        io:println("  ", result);
    }
    io:println(string `Pipeline execution time: ${pipelineResult.executionTime}ms`);
    
    // Example 6: Map-Reduce Pattern
    io:println("\n\n=== Map-Reduce Example ===");
    
    // Calculate word frequencies
    string[] documents = [
        "The quick brown fox",
        "The fox jumps over",
        "Brown fox quick jumps"
    ];
    
    // Map phase - tokenize documents
    any[] mapped = check processor.map(documents, function(any doc) returns any {
        string document = <string>doc;
        string[] words = re`\s+`.split(document.toLowerAscii());
        map<int> wordCount = {};
        
        foreach string word in words {
            wordCount[word] = (wordCount[word] ?: 0) + 1;
        }
        
        return wordCount;
    });
    
    // Reduce phase - combine word counts
    any reduced = check processor.reduce(mapped, function(any acc, any item) returns any {
        map<int> accumulator = <map<int>>acc;
        map<int> current = <map<int>>item;
        
        foreach [string, int] [word, count] in current.entries() {
            accumulator[word] = (accumulator[word] ?: 0) + count;
        }
        
        return accumulator;
    }, {});
    
    io:println("Word Frequencies:");
    map<int> frequencies = <map<int>>reduced;
    foreach [string, int] [word, count] in frequencies.entries() {
        io:println(string `  ${word}: ${count}`);
    }
    
    // Example 7: Cache Eviction Policies
    io:println("\n\n=== Cache Eviction Policies ===");
    
    // Test different eviction policies
    string[] policies = ["LRU", "LFU", "FIFO"];
    
    foreach string policy in policies {
        io:println(string `\nTesting ${policy} eviction:`);
        
        cache_manager:EvictionPolicy evictionPolicy = 
            policy == "LRU" ? cache_manager:LRU :
            policy == "LFU" ? cache_manager:LFU :
            cache_manager:FIFO;
        
        cache_manager:CacheConfig testConfig = {
            maxEntries: 3,  // Small cache for demonstration
            evictionPolicy: evictionPolicy
        };
        
        cache_manager:CacheManager testCache = new(testConfig);
        
        // Add items
        check testCache.put("A", "Value A");
        check testCache.put("B", "Value B");
        check testCache.put("C", "Value C");
        
        // Access pattern for LRU/LFU testing
        _ = testCache.get("A");
        _ = testCache.get("A");
        _ = testCache.get("B");
        
        // Add new item (triggers eviction)
        check testCache.put("D", "Value D");
        
        io:println("  Cache contents after eviction:");
        string[] keys = ["A", "B", "C", "D"];
        foreach string key in keys {
            any? value = testCache.get(key);
            if value is () {
                io:println(string `    ${key}: EVICTED`);
            } else {
                io:println(string `    ${key}: ${value.toString()}`);
            }
        }
    }
    
    io:println("\n✅ Performance optimization examples completed!");
}

// Helper function to simulate slow database query
function simulateSlowDatabaseQuery() returns error? {
    // Simulate network latency
    runtime:sleep(0.1);
}

// Helper function to simulate computation
function simulateComputation() returns error? {
    // Simulate CPU-intensive work
    int sum = 0;
    foreach int i in 0 ..< 1000 {
        sum += i;
    }
    runtime:sleep(0.01);
}