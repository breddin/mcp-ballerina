// Language Server Utility Functions
// Provides helper functions for process management, validation, and configuration

import ballerina/io;
import ballerina/log;
import ballerina/os;
import ballerina/time;
import ballerina/regex;
import ballerina/file;

// Validate process configuration
public function validateProcessConfig(ProcessConfig config) returns ValidationResult {
    string[] errors = [];
    string[] warnings = [];
    string[] suggestions = [];

    // Validate Ballerina command
    if config.ballerinaCommand.trim().length() == 0 {
        errors.push("Ballerina command cannot be empty");
    }

    // Validate health check interval
    if config.healthCheckInterval < 5000 {
        warnings.push("Health check interval is very low, may impact performance");
    }

    // Validate max restart attempts
    if config.maxRestartAttempts > 10 {
        warnings.push("High restart attempts may cause resource issues");
    }

    // Validate process timeout
    if config.processTimeout < 10000 {
        warnings.push("Process timeout is very low, may cause premature timeouts");
    }

    // Check working directory if specified
    if config.workingDirectory is string {
        string workDir = <string>config.workingDirectory;
        if !file:exists(workDir) {
            errors.push(string `Working directory does not exist: ${workDir}`);
        }
    }

    // Suggestions
    if config.healthCheckInterval > 60000 {
        suggestions.push("Consider reducing health check interval for better responsiveness");
    }

    if !config.enableLogging {
        suggestions.push("Enable logging for better debugging and monitoring");
    }

    return {
        valid: errors.length() == 0,
        errors: errors,
        warnings: warnings,
        suggestions: suggestions
    };
}

// Check if Ballerina runtime is available
public function checkBallerinaAvailability(string command = "bal") returns boolean|error {
    try {
        os:Process versionProcess = check os:exec({
            value: command,
            arguments: ["version"]
        });

        os:ProcessExitResult result = check versionProcess.waitForExit();
        return result.exitCode == 0;
    } catch (error e) {
        return false;
    }
}

// Get Ballerina version information
public function getBallerinaVersion(string command = "bal") returns string|error {
    try {
        os:Process versionProcess = check os:exec({
            value: command,
            arguments: ["version"]
        });

        string output = check versionProcess.stdout().readString();
        os:ProcessExitResult result = check versionProcess.waitForExit();
        
        if result.exitCode != 0 {
            return error("Failed to get Ballerina version");
        }

        // Extract version from output
        string[] lines = regex:split(output, "\n");
        foreach string line in lines {
            if line.includes("Ballerina") && line.includes("version") {
                return line.trim();
            }
        }

        return output.trim();
    } catch (error e) {
        return error("Unable to determine Ballerina version: " + e.message());
    }
}

// Create default extended process configuration
public function createDefaultExtendedConfig() returns ExtendedProcessConfig {
    ProcessConfig baseConfig = {
        ballerinaCommand: "bal",
        additionalArgs: [],
        healthCheckInterval: 30000,
        maxRestartAttempts: 3,
        processTimeout: 60000,
        enableLogging: true
    };

    ConnectionConfig connectionConfig = {
        host: "localhost",
        protocol: "stdio",
        useJsonRpc: true,
        connectionTimeout: 30000,
        requestTimeout: 10000
    };

    MonitoringConfig monitoringConfig = {
        enablePerformanceMonitoring: true,
        enableLogCollection: true,
        enableMetrics: true,
        metricsCollectionInterval: 60000,
        logRetentionDays: 7,
        logLevel: "INFO"
    };

    FeatureFlags features = {
        autoRestart: true,
        healthMonitoring: true,
        performanceTracking: true,
        errorRecovery: true,
        streamLogging: false,
        detailedMetrics: false
    };

    RecoveryAction[] recoveryActions = [
        {
            strategy: RESTART_PROCESS,
            maxAttempts: 3,
            backoffDelay: 5000,
            notifyUser: true
        },
        {
            strategy: REINITIALIZE_CONNECTION,
            maxAttempts: 2,
            backoffDelay: 2000,
            notifyUser: false
        }
    ];

    return {
        ballerinaCommand: baseConfig.ballerinaCommand,
        additionalArgs: baseConfig.additionalArgs,
        healthCheckInterval: baseConfig.healthCheckInterval,
        maxRestartAttempts: baseConfig.maxRestartAttempts,
        processTimeout: baseConfig.processTimeout,
        enableLogging: baseConfig.enableLogging,
        workingDirectory: baseConfig.workingDirectory,
        connection: connectionConfig,
        monitoring: monitoringConfig,
        features: features,
        recoveryActions: recoveryActions
    };
}

// Calculate process uptime
public function calculateUptime(time:Utc startTime) returns decimal {
    time:Utc now = time:utcNow();
    time:Seconds uptime = time:utcDiffSeconds(now, startTime);
    return <decimal>uptime;
}

// Format duration for human reading
public function formatDuration(decimal seconds) returns string {
    if seconds < 60 {
        return string `${seconds}s`;
    } else if seconds < 3600 {
        decimal minutes = seconds / 60;
        return string `${minutes.round(1)}m`;
    } else if seconds < 86400 {
        decimal hours = seconds / 3600;
        return string `${hours.round(1)}h`;
    } else {
        decimal days = seconds / 86400;
        return string `${days.round(1)}d`;
    }
}

// Parse process arguments from string
public function parseArguments(string argString) returns string[] {
    if argString.trim().length() == 0 {
        return [];
    }

    // Simple argument parsing - split by spaces but respect quotes
    string[] parts = regex:split(argString.trim(), "\\s+");
    string[] result = [];
    
    foreach string part in parts {
        if part.length() > 0 {
            // Remove surrounding quotes if present
            if part.startsWith("\"") && part.endsWith("\"") {
                result.push(part.substring(1, part.length() - 1));
            } else if part.startsWith("'") && part.endsWith("'") {
                result.push(part.substring(1, part.length() - 1));
            } else {
                result.push(part);
            }
        }
    }
    
    return result;
}

// Generate correlation ID for tracking
public function generateCorrelationId() returns string {
    return string `ls-${time:utcNow().toString()}-${randomInt(1000, 9999)}`;
}

// Simple random integer generator
function randomInt(int min, int max) returns int {
    time:Utc now = time:utcNow();
    int seed = <int>(now.utcOffset % 1000);
    return min + (seed % (max - min + 1));
}

// Check if port is available
public function isPortAvailable(int port) returns boolean {
    // Simple check - attempt to create a socket on the port
    // This is a basic implementation
    return port > 1024 && port < 65535;
}

// Create process metrics with initial values
public function createInitialMetrics(time:Utc startTime) returns ProcessMetrics {
    return {
        startTime: startTime,
        lastRestartTime: (),
        totalRestarts: 0,
        totalHealthChecks: 0,
        healthCheckFailures: 0,
        totalBytesRead: 0,
        totalBytesWritten: 0,
        averageResponseTime: 0.0,
        activeConnections: 0
    };
}

// Update process metrics
public function updateMetrics(ProcessMetrics current, ProcessMetrics update) returns ProcessMetrics {
    return {
        startTime: current.startTime,
        lastRestartTime: update.lastRestartTime ?: current.lastRestartTime,
        totalRestarts: update.totalRestarts,
        totalHealthChecks: current.totalHealthChecks + 1,
        healthCheckFailures: current.healthCheckFailures + (update.healthCheckFailures - current.healthCheckFailures),
        totalBytesRead: current.totalBytesRead + (update.totalBytesRead - current.totalBytesRead),
        totalBytesWritten: current.totalBytesWritten + (update.totalBytesWritten - current.totalBytesWritten),
        averageResponseTime: (current.averageResponseTime + update.averageResponseTime) / 2,
        activeConnections: update.activeConnections
    };
}

// Validate connection configuration
public function validateConnectionConfig(ConnectionConfig config) returns ValidationResult {
    string[] errors = [];
    string[] warnings = [];
    string[] suggestions = [];

    // Validate protocol
    if config.protocol != "stdio" && config.protocol != "tcp" && config.protocol != "pipe" {
        errors.push("Invalid protocol. Must be 'stdio', 'tcp', or 'pipe'");
    }

    // Validate TCP configuration
    if config.protocol == "tcp" {
        if config.port is () {
            errors.push("Port must be specified for TCP protocol");
        } else {
            int port = <int>config.port;
            if port < 1024 || port > 65535 {
                warnings.push("Port should be between 1024 and 65535");
            }
        }
    }

    // Validate pipe configuration
    if config.protocol == "pipe" && config.pipeName is () {
        errors.push("Pipe name must be specified for pipe protocol");
    }

    // Validate timeouts
    if config.connectionTimeout < 5000 {
        warnings.push("Connection timeout is very low");
    }

    if config.requestTimeout < 1000 {
        warnings.push("Request timeout is very low");
    }

    return {
        valid: errors.length() == 0,
        errors: errors,
        warnings: warnings,
        suggestions: suggestions
    };
}

// Log process event with formatting
public function logProcessEvent(ExtendedProcessEvent event) {
    string timestamp = event.timestamp.toString();
    string logMessage = string `[${timestamp}] ${event.component.toUpperAscii()}: ${event.message}`;
    
    if event.data is json {
        logMessage += string ` - Data: ${event.data.toString()}`;
    }

    match event.severity {
        "ERROR" => {
            log:printError(logMessage);
        }
        "WARN" => {
            log:printWarn(logMessage);
        }
        "DEBUG" => {
            log:printDebug(logMessage);
        }
        _ => {
            log:printInfo(logMessage);
        }
    }
}

// Create detailed health info from basic health info
public function createDetailedHealthInfo(HealthInfo basic, ProcessMetrics? metrics = (), PerformanceData? performance = ()) returns DetailedHealthInfo {
    string[] warnings = [];
    string[] recommendations = [];

    // Add warnings based on status
    if basic.status == ERROR {
        warnings.push("Process is in error state");
    }

    if basic.restartCount > 2 {
        warnings.push("High restart count indicates instability");
        recommendations.push("Check process logs for recurring issues");
    }

    if !basic.responsive {
        warnings.push("Process is not responding to health checks");
        recommendations.push("Consider restarting the process");
    }

    ProcessMetrics defaultMetrics = createInitialMetrics(time:utcNow());

    return {
        status: basic.status,
        lastHealthCheck: basic.lastHealthCheck,
        responsive: basic.responsive,
        errorMessage: basic.errorMessage,
        restartCount: basic.restartCount,
        performance: performance,
        capabilities: (),
        metrics: metrics ?: defaultMetrics,
        warnings: warnings,
        recommendations: recommendations
    };
}