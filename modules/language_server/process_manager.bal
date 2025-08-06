// Ballerina Language Server Process Manager
// Handles spawning, lifecycle management, and health checking of the Ballerina Language Server

import ballerina/io;
import ballerina/log;
import ballerina/os;
import ballerina/time;
import ballerina/lang.runtime;
import ballerina/regex;

// Process configuration
public type ProcessConfig record {|
    string ballerinaCommand = "bal";//default command
    string[] additionalArgs = [];//additional arguments
    int healthCheckInterval = 30000;//health check interval in ms
    int maxRestartAttempts = 3;//maximum restart attempts
    int processTimeout = 60000;//process timeout in ms
    boolean enableLogging = true;//enable process logging
    string workingDirectory?;//working directory for the process
|};

// Process status enumeration
public enum ProcessStatus {
    STOPPED,
    STARTING,
    RUNNING,
    STOPPING,
    ERROR,
    RESTART_PENDING
}

// Process health information
public type HealthInfo record {|
    ProcessStatus status;
    time:Utc lastHealthCheck;
    boolean responsive;
    string? errorMessage;
    int restartCount;
|};

// Process event types
public type ProcessEvent record {|
    string eventType;//"started", "stopped", "error", "health_check"
    time:Utc timestamp;
    string message;
    json? data;
|};

// Language Server Process Manager
public class ProcessManager {
    private ProcessConfig config;
    private ProcessStatus status = STOPPED;
    private os:Process? process = ();
    private int restartCount = 0;
    private time:Utc? lastHealthCheck = ();
    private boolean healthCheckEnabled = false;
    private string? lastError = ();
    
    // Event listeners
    private function(ProcessEvent)[] eventListeners = [];

    public function init(ProcessConfig? config = ()) {
        self.config = config ?: {};
        if self.config.enableLogging {
            log:printInfo("Initializing Ballerina Language Server Process Manager");
        }
    }

    // Start the language server process
    public function start() returns error? {
        if self.status == RUNNING {
            return error("Language server is already running");
        }

        self.setStatus(STARTING);
        
        try {
            // Prepare command arguments
            string[] args = ["start-language-server"];
            args.push(...self.config.additionalArgs);

            // Set working directory if specified
            map<string> env = {};
            if self.config.workingDirectory is string {
                env["PWD"] = <string>self.config.workingDirectory;
            }

            // Start the process
            os:Process ballerinaProcess = check os:exec({
                value: self.config.ballerinaCommand,
                arguments: args,
                env: env
            });

            self.process = ballerinaProcess;
            self.setStatus(RUNNING);
            self.restartCount = 0;
            
            // Start health checking
            self.startHealthCheck();
            
            // Start stream monitoring
            _ = start self.monitorStreams();
            
            self.emitEvent("started", "Language server process started successfully", ());
            
            if self.config.enableLogging {
                log:printInfo("Ballerina Language Server started successfully");
            }

        } catch (error e) {
            self.setStatus(ERROR);
            self.lastError = e.message();
            self.emitEvent("error", "Failed to start language server", {"error": e.message()});
            return error("Failed to start language server: " + e.message());
        }
    }

    // Stop the language server process
    public function stop() returns error? {
        if self.status == STOPPED {
            return;
        }

        self.setStatus(STOPPING);
        self.healthCheckEnabled = false;

        if self.process is os:Process {
            os:Process currentProcess = <os:Process>self.process;
            
            try {
                // Attempt graceful shutdown
                check currentProcess.destroy();
                
                // Wait for process to terminate
                os:ProcessExitResult exitResult = check currentProcess.waitForExit();
                
                if self.config.enableLogging {
                    log:printInfo(string `Language server stopped with exit code: ${exitResult.exitCode}`);
                }
                
            } catch (error e) {
                if self.config.enableLogging {
                    log:printWarn("Error during process shutdown: " + e.message());
                }
                
                // Force kill if graceful shutdown fails
                try {
                    check currentProcess.forceDestroy();
                } catch (error forceError) {
                    log:printError("Failed to force destroy process: " + forceError.message());
                }
            }
        }

        self.process = ();
        self.setStatus(STOPPED);
        self.emitEvent("stopped", "Language server process stopped", ());
        
        if self.config.enableLogging {
            log:printInfo("Language server process stopped");
        }
    }

    // Restart the language server process
    public function restart() returns error? {
        if self.restartCount >= self.config.maxRestartAttempts {
            return error(string `Maximum restart attempts (${self.config.maxRestartAttempts}) reached`);
        }

        if self.config.enableLogging {
            log:printInfo(string `Restarting language server (attempt ${self.restartCount + 1})`);
        }

        self.setStatus(RESTART_PENDING);
        
        // Stop current process
        check self.stop();
        
        // Wait a moment before restarting
        runtime:sleep(2);
        
        // Increment restart count
        self.restartCount += 1;
        
        // Start again
        return self.start();
    }

    // Check if the language server is healthy
    public function isHealthy() returns boolean|error {
        if self.status != RUNNING || self.process is () {
            return false;
        }

        os:Process currentProcess = <os:Process>self.process;
        
        try {
            // Check if process is still alive
            boolean alive = check currentProcess.isAlive();
            
            if !alive {
                self.setStatus(ERROR);
                self.lastError = "Process is not alive";
                return false;
            }

            // Update last health check time
            self.lastHealthCheck = time:utcNow();
            
            return true;
            
        } catch (error e) {
            self.lastError = e.message();
            return error("Health check failed: " + e.message());
        }
    }

    // Get current health information
    public function getHealthInfo() returns HealthInfo {
        boolean responsive = false;
        
        // Try to get current health status
        boolean|error healthResult = self.isHealthy();
        if healthResult is boolean {
            responsive = healthResult;
        }

        return {
            status: self.status,
            lastHealthCheck: self.lastHealthCheck ?: time:utcNow(),
            responsive: responsive,
            errorMessage: self.lastError,
            restartCount: self.restartCount
        };
    }

    // Get current process status
    public function getStatus() returns ProcessStatus {
        return self.status;
    }

    // Add event listener
    public function addEventListener(function(ProcessEvent) listener) {
        self.eventListeners.push(listener);
    }

    // Remove event listener
    public function removeEventListener(function(ProcessEvent) listener) {
        int? index = self.eventListeners.indexOf(listener);
        if index is int {
            _ = self.eventListeners.remove(index);
        }
    }

    // Send input to the language server process
    public function sendInput(string input) returns error? {
        if self.process is () || self.status != RUNNING {
            return error("Language server is not running");
        }

        os:Process currentProcess = <os:Process>self.process;
        
        try {
            // Write to process stdin
            check currentProcess.stdin().writeString(input);
            check currentProcess.stdin().writeString("\n");
            check currentProcess.stdin().flush();
            
        } catch (error e) {
            return error("Failed to send input to language server: " + e.message());
        }
    }

    // Get process output (non-blocking)
    public function getOutput() returns string|error {
        if self.process is () || self.status != RUNNING {
            return error("Language server is not running");
        }

        os:Process currentProcess = <os:Process>self.process;
        
        try {
            // Read available output
            string output = check currentProcess.stdout().readString();
            return output;
            
        } catch (error e) {
            return error("Failed to read output from language server: " + e.message());
        }
    }

    // Get process error output
    public function getErrorOutput() returns string|error {
        if self.process is () || self.status != RUNNING {
            return error("Language server is not running");
        }

        os:Process currentProcess = <os:Process>self.process;
        
        try {
            // Read available error output
            string errorOutput = check currentProcess.stderr().readString();
            return errorOutput;
            
        } catch (error e) {
            return error("Failed to read error output from language server: " + e.message());
        }
    }

    // Update configuration
    public function updateConfig(ProcessConfig newConfig) {
        self.config = newConfig;
        
        if self.config.enableLogging {
            log:printInfo("Process configuration updated");
        }
    }

    // Private method to set status and log changes
    private function setStatus(ProcessStatus newStatus) {
        ProcessStatus oldStatus = self.status;
        self.status = newStatus;
        
        if self.config.enableLogging && oldStatus != newStatus {
            log:printInfo(string `Process status changed: ${oldStatus} -> ${newStatus}`);
        }
    }

    // Private method to emit events
    private function emitEvent(string eventType, string message, json? data) {
        ProcessEvent event = {
            eventType: eventType,
            timestamp: time:utcNow(),
            message: message,
            data: data
        };

        // Notify all listeners
        foreach function(ProcessEvent) listener in self.eventListeners {
            try {
                listener(event);
            } catch (error e) {
                if self.config.enableLogging {
                    log:printWarn("Error in event listener: " + e.message());
                }
            }
        }
    }

    // Private method to start health checking
    private function startHealthCheck() {
        self.healthCheckEnabled = true;
        _ = start self.healthCheckLoop();
    }

    // Private method for health check loop
    private function healthCheckLoop() {
        while self.healthCheckEnabled {
            runtime:sleep(self.config.healthCheckInterval / 1000.0);
            
            if !self.healthCheckEnabled {
                break;
            }

            boolean|error healthResult = self.isHealthy();
            
            if healthResult is error {
                if self.config.enableLogging {
                    log:printError("Health check error: " + healthResult.message());
                }
                
                self.emitEvent("health_check", "Health check failed", {"error": healthResult.message()});
                
                // Attempt restart if configured
                if self.restartCount < self.config.maxRestartAttempts {
                    _ = start self.attemptRestart();
                }
                
            } else if !healthResult {
                if self.config.enableLogging {
                    log:printWarn("Language server is not healthy");
                }
                
                self.emitEvent("health_check", "Process unhealthy", ());
                
                // Attempt restart if configured
                if self.restartCount < self.config.maxRestartAttempts {
                    _ = start self.attemptRestart();
                }
            } else {
                self.emitEvent("health_check", "Process healthy", ());
            }
        }
    }

    // Private method to attempt restart
    private function attemptRestart() {
        try {
            error? restartResult = self.restart();
            if restartResult is error {
                self.emitEvent("error", "Restart failed", {"error": restartResult.message()});
            }
        } catch (error e) {
            self.emitEvent("error", "Restart attempt failed", {"error": e.message()});
        }
    }

    // Private method to monitor process streams
    private function monitorStreams() {
        if self.process is () {
            return;
        }

        os:Process currentProcess = <os:Process>self.process;
        
        // Monitor stdout in a separate worker
        _ = start self.monitorStdout(currentProcess);
        
        // Monitor stderr in a separate worker
        _ = start self.monitorStderr(currentProcess);
    }

    // Private method to monitor stdout
    private function monitorStdout(os:Process process) {
        while self.status == RUNNING {
            try {
                string? line = check process.stdout().readLine();
                if line is string && line.trim().length() > 0 {
                    if self.config.enableLogging {
                        log:printDebug("STDOUT: " + line);
                    }
                    self.emitEvent("stdout", "Process output", {"output": line});
                }
            } catch (error e) {
                if self.status == RUNNING {
                    if self.config.enableLogging {
                        log:printError("Error reading stdout: " + e.message());
                    }
                }
                break;
            }
        }
    }

    // Private method to monitor stderr
    private function monitorStderr(os:Process process) {
        while self.status == RUNNING {
            try {
                string? line = check process.stderr().readLine();
                if line is string && line.trim().length() > 0 {
                    if self.config.enableLogging {
                        log:printWarn("STDERR: " + line);
                    }
                    self.emitEvent("stderr", "Process error output", {"error": line});
                }
            } catch (error e) {
                if self.status == RUNNING {
                    if self.config.enableLogging {
                        log:printError("Error reading stderr: " + e.message());
                    }
                }
                break;
            }
        }
    }

    // Cleanup resources
    public function cleanup() returns error? {
        self.healthCheckEnabled = false;
        
        if self.status != STOPPED {
            check self.stop();
        }
        
        // Clear event listeners
        self.eventListeners = [];
        
        if self.config.enableLogging {
            log:printInfo("Process manager cleanup completed");
        }
    }
}

// Utility function to create a default process manager
public function createDefaultProcessManager() returns ProcessManager {
    ProcessConfig defaultConfig = {
        ballerinaCommand: "bal",
        additionalArgs: [],
        healthCheckInterval: 30000,
        maxRestartAttempts: 3,
        processTimeout: 60000,
        enableLogging: true
    };
    
    return new ProcessManager(defaultConfig);
}

// Utility function to create a process manager with custom configuration
public function createProcessManager(ProcessConfig config) returns ProcessManager {
    return new ProcessManager(config);
}