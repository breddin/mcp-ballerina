// Parallel Processor for Ballerina MCP Server
// Implements concurrent task execution with worker pools and futures

import ballerina/lang.runtime as runtime;
import ballerina/log;
import ballerina/time;
import ballerina/task;

// Task status
public enum TaskStatus {
    PENDING,
    RUNNING,
    COMPLETED,
    FAILED,
    CANCELLED
}

// Parallel task
public type ParallelTask record {|
    string id;
    function() returns any|error executor;
    TaskStatus status = PENDING;
    any? result?;
    error? errorResult?;
    time:Utc? startTime?;
    time:Utc? endTime?;
    int priority = 0;
    string[] dependencies = [];
|};

// Worker pool configuration
public type WorkerPoolConfig record {|
    int corePoolSize = 4;
    int maxPoolSize = 10;
    int queueCapacity = 100;
    int keepAliveTime = 60; // seconds
    boolean allowCoreThreadTimeout = false;
|};

// Execution strategy
public enum ExecutionStrategy {
    PARALLEL,
    SEQUENTIAL,
    BATCH,
    PIPELINE,
    MAP_REDUCE
}

// Task result
public type TaskResult record {|
    string taskId;
    TaskStatus status;
    any? value;
    error? err;
    decimal executionTime;
|};

// Batch result
public type BatchResult record {|
    TaskResult[] results;
    int successCount;
    int failureCount;
    decimal totalTime;
|};

// Parallel Processor
public class ParallelProcessor {
    private WorkerPoolConfig config;
    private map<ParallelTask> tasks = {};
    private map<future<any|error>> futures = {};
    private int activeWorkers = 0;
    private int completedTasks = 0;
    private boolean shutdown = false;
    
    public function init(WorkerPoolConfig? config = ()) {
        self.config = config ?: {};
    }
    
    // Execute single task asynchronously
    public function executeAsync(function() returns any|error fn, string? taskId = ()) 
        returns future<any|error> {
        
        string id = taskId ?: self.generateTaskId();
        
        // Create task
        ParallelTask task = {
            id: id,
            executor: fn,
            status: RUNNING,
            startTime: time:utcNow()
        };
        
        self.tasks[id] = task;
        
        // Execute in worker
        future<any|error> f = @strand {thread: "any"} start self.runTask(task);
        self.futures[id] = f;
        
        return f;
    }
    
    // Execute multiple tasks in parallel
    public function executeParallel(function()[] fns) returns TaskResult[]|error {
        ParallelTask[] tasks = [];
        
        foreach int i in 0 ..< fns.length() {
            tasks.push({
                id: "task_" + i.toString(),
                executor: fns[i]
            });
        }
        
        return self.executeTasks(tasks, PARALLEL);
    }
    
    // Execute tasks with strategy
    public function executeTasks(ParallelTask[] tasks, ExecutionStrategy strategy) 
        returns TaskResult[]|error {
        
        match strategy {
            PARALLEL => {
                return self.executeInParallel(tasks);
            }
            SEQUENTIAL => {
                return self.executeSequentially(tasks);
            }
            BATCH => {
                return self.executeInBatches(tasks, self.config.corePoolSize);
            }
            PIPELINE => {
                return self.executePipeline(tasks);
            }
            MAP_REDUCE => {
                return self.executeMapReduce(tasks);
            }
        }
    }
    
    // Execute tasks in parallel
    private function executeInParallel(ParallelTask[] tasks) returns TaskResult[]|error {
        future<any|error>[] futures = [];
        
        foreach ParallelTask task in tasks {
            self.tasks[task.id] = task;
            task.status = RUNNING;
            task.startTime = time:utcNow();
            
            future<any|error> f = @strand {thread: "any"} start self.runTask(task);
            futures.push(f);
            self.futures[task.id] = f;
        }
        
        // Wait for all to complete
        TaskResult[] results = [];
        foreach int i in 0 ..< futures.length() {
            any|error result = wait futures[i];
            ParallelTask task = tasks[i];
            
            results.push(self.createTaskResult(task, result));
        }
        
        return results;
    }
    
    // Execute tasks sequentially
    private function executeSequentially(ParallelTask[] tasks) returns TaskResult[]|error {
        TaskResult[] results = [];
        
        foreach ParallelTask task in tasks {
            task.status = RUNNING;
            task.startTime = time:utcNow();
            
            any|error result = task.executor();
            results.push(self.createTaskResult(task, result));
        }
        
        return results;
    }
    
    // Execute tasks in batches
    private function executeInBatches(ParallelTask[] tasks, int batchSize) 
        returns TaskResult[]|error {
        
        TaskResult[] allResults = [];
        
        int totalBatches = (tasks.length() + batchSize - 1) / batchSize;
        
        foreach int batchNum in 0 ..< totalBatches {
            int startIdx = batchNum * batchSize;
            int endIdx = int:min(startIdx + batchSize, tasks.length());
            
            ParallelTask[] batch = tasks.slice(startIdx, endIdx);
            TaskResult[] batchResults = check self.executeInParallel(batch);
            allResults.push(...batchResults);
        }
        
        return allResults;
    }
    
    // Execute pipeline (sequential with data passing)
    private function executePipeline(ParallelTask[] tasks) returns TaskResult[]|error {
        TaskResult[] results = [];
        any? previousResult = ();
        
        foreach ParallelTask task in tasks {
            task.status = RUNNING;
            task.startTime = time:utcNow();
            
            // Pass previous result to next task if available
            any|error result;
            if previousResult is any {
                // Modify executor to accept previous result
                result = task.executor();
            } else {
                result = task.executor();
            }
            
            TaskResult taskResult = self.createTaskResult(task, result);
            results.push(taskResult);
            
            if result is any {
                previousResult = result;
            }
        }
        
        return results;
    }
    
    // Execute map-reduce pattern
    private function executeMapReduce(ParallelTask[] tasks) returns TaskResult[]|error {
        // Map phase - execute all tasks in parallel
        TaskResult[] mapResults = check self.executeInParallel(tasks);
        
        // Reduce phase - combine results
        any[] values = [];
        foreach TaskResult result in mapResults {
            if result.value is any {
                values.push(result.value);
            }
        }
        
        // Return map results (reduce would be application-specific)
        return mapResults;
    }
    
    // Run single task
    private function runTask(ParallelTask task) returns any|error {
        self.activeWorkers += 1;
        
        any|error result = trap task.executor();
        
        task.endTime = time:utcNow();
        self.activeWorkers -= 1;
        self.completedTasks += 1;
        
        if result is error {
            task.status = FAILED;
            task.errorResult = result;
        } else {
            task.status = COMPLETED;
            task.result = result;
        }
        
        return result;
    }
    
    // Create task result
    private function createTaskResult(ParallelTask task, any|error result) returns TaskResult {
        time:Utc endTime = task.endTime ?: time:utcNow();
        time:Utc startTime = task.startTime ?: time:utcNow();
        decimal executionTime = <decimal>time:utcDiffSeconds(endTime, startTime);
        
        if result is error {
            return {
                taskId: task.id,
                status: FAILED,
                value: (),
                err: result,
                executionTime: executionTime
            };
        } else {
            return {
                taskId: task.id,
                status: COMPLETED,
                value: result,
                err: (),
                executionTime: executionTime
            };
        }
    }
    
    // Map operation (parallel map over array)
    public function map(any[] items, function(any) returns any|error mapper) 
        returns any[]|error {
        
        function()[] mappers = [];
        foreach any item in items {
            function() returns any|error fn = function() returns any|error {
                return mapper(item);
            };
            mappers.push(fn);
        }
        
        TaskResult[] results = check self.executeParallel(mappers);
        
        any[] mappedValues = [];
        foreach TaskResult result in results {
            if result.err is error {
                return result.err;
            }
            mappedValues.push(result.value);
        }
        
        return mappedValues;
    }
    
    // Filter operation (parallel filter)
    public function filter(any[] items, function(any) returns boolean predicate) 
        returns any[]|error {
        
        function()[] filters = [];
        foreach int i in 0 ..< items.length() {
            any item = items[i];
            function() returns any|error fn = function() returns any|error {
                if predicate(item) {
                    return item;
                }
                return ();
            };
            filters.push(fn);
        }
        
        TaskResult[] results = check self.executeParallel(filters);
        
        any[] filtered = [];
        foreach TaskResult result in results {
            if result.value is any && result.value != () {
                filtered.push(result.value);
            }
        }
        
        return filtered;
    }
    
    // Reduce operation (parallel reduce with combiner)
    public function reduce(any[] items, any initial, 
                          function(any, any) returns any reducer,
                          function(any, any) returns any combiner) 
        returns any|error {
        
        // Split into chunks for parallel reduction
        int chunkSize = (items.length() + self.config.corePoolSize - 1) / self.config.corePoolSize;
        
        function()[] reducers = [];
        foreach int i in 0 ..< self.config.corePoolSize {
            int startIdx = i * chunkSize;
            int endIdx = int:min(startIdx + chunkSize, items.length());
            
            if startIdx < items.length() {
                any[] chunk = items.slice(startIdx, endIdx);
                function() returns any|error fn = function() returns any {
                    any result = initial;
                    foreach any item in chunk {
                        result = reducer(result, item);
                    }
                    return result;
                };
                reducers.push(fn);
            }
        }
        
        // Execute parallel reductions
        TaskResult[] results = check self.executeParallel(reducers);
        
        // Combine results
        any finalResult = initial;
        foreach TaskResult result in results {
            if result.value is any {
                finalResult = combiner(finalResult, result.value);
            }
        }
        
        return finalResult;
    }
    
    // Execute with timeout
    public function executeWithTimeout(function() returns any|error fn, decimal timeoutSeconds) 
        returns any|error {
        
        future<any|error> f = self.executeAsync(fn);
        
        // Create timeout future
        future<()> timeoutFuture = @strand {thread: "any"} start self.timeout(timeoutSeconds);
        
        // Wait for either completion or timeout
        worker w1 returns any|error {
            return wait f;
        }
        
        worker w2 returns error {
            wait timeoutFuture;
            return error("Task timeout after " + timeoutSeconds.toString() + " seconds");
        }
        
        any|error result = wait w1 | w2;
        
        if result is error && result.message().includes("timeout") {
            // Cancel the task
            self.cancelTask(f);
        }
        
        return result;
    }
    
    // Timeout helper
    private function timeout(decimal seconds) {
        runtime:sleep(seconds);
    }
    
    // Cancel task
    private function cancelTask(future<any|error> f) {
        // Ballerina doesn't support future cancellation directly
        // Would need to implement cancellation token pattern
    }
    
    // Get active worker count
    public function getActiveWorkers() returns int {
        return self.activeWorkers;
    }
    
    // Get completed task count
    public function getCompletedTasks() returns int {
        return self.completedTasks;
    }
    
    // Shutdown processor
    public function shutdown() {
        self.shutdown = true;
        log:printInfo("Parallel processor shutting down");
    }
    
    // Generate task ID
    private function generateTaskId() returns string {
        return "task_" + time:utcNow().toString();
    }
    
    // Wait for all tasks to complete
    public function awaitTermination(decimal timeoutSeconds) returns error? {
        decimal elapsed = 0;
        decimal checkInterval = 0.1;
        
        while self.activeWorkers > 0 && elapsed < timeoutSeconds {
            runtime:sleep(checkInterval);
            elapsed += checkInterval;
        }
        
        if self.activeWorkers > 0 {
            return error("Timeout waiting for tasks to complete");
        }
        
        return;
    }
}

// Parallel Stream Processor
public class ParallelStreamProcessor {
    private ParallelProcessor processor;
    private int bufferSize;
    private any[] buffer = [];
    
    public function init(WorkerPoolConfig? config = (), int bufferSize = 100) {
        self.processor = new(config);
        self.bufferSize = bufferSize;
    }
    
    // Process stream in parallel
    public function processStream(stream<any, error?> input, 
                                 function(any) returns any|error processor) 
        returns stream<any, error?> {
        
        return stream from any item in input
               let any|error processed = self.processItem(item, processor)
               where processed is any
               select processed;
    }
    
    // Process single item
    private function processItem(any item, function(any) returns any|error proc) 
        returns any|error {
        
        return proc(item);
    }
    
    // Batch process stream
    public function batchProcessStream(stream<any, error?> input, int batchSize,
                                      function(any[]) returns any[]|error processor) 
        returns stream<any, error?> {
        
        return stream from any item in input
               let any|error processed = self.processBatch(item, batchSize, processor)
               where processed is any
               select processed;
    }
    
    // Process batch
    private function processBatch(any item, int batchSize, 
                                 function(any[]) returns any[]|error processor) 
        returns any|error {
        
        self.buffer.push(item);
        
        if self.buffer.length() >= batchSize {
            any[] batch = self.buffer.clone();
            self.buffer = [];
            return processor(batch);
        }
        
        return ();
    }
}