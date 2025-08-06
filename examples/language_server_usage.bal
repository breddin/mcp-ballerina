// Language Server Process Manager Usage Example
// Demonstrates how to use the language server module in practice

import mcp_ballerina.language_server;
import mcp_ballerina.mcp_protocol;
import ballerina/io;
import ballerina/log;
import ballerina/time;

public function main() returns error? {
    log:printInfo("Starting Ballerina Language Server Example");
    
    // Example 1: Basic Process Manager Usage
    check basicProcessManagerExample();
    
    // Example 2: Advanced Configuration
    check advancedConfigurationExample();
    
    // Example 3: Event Handling
    check eventHandlingExample();
    
    // Example 4: Integration with MCP Server
    check mcpIntegrationExample();
    
    // Example 5: Error Recovery
    check errorRecoveryExample();
    
    log:printInfo("All examples completed successfully");
}

// Example 1: Basic Process Manager Usage
function basicProcessManagerExample() returns error? {
    log:printInfo("=== Basic Process Manager Example ===");
    
    // Create default process manager
    language_server:ProcessManager manager = language_server:createDefaultProcessManager();
    
    // Check initial status
    language_server:ProcessStatus status = manager.getStatus();
    log:printInfo(string `Initial status: ${status}`);
    
    // Get health information
    language_server:HealthInfo healthInfo = manager.getHealthInfo();
    log:printInfo(string `Initial health - Status: ${healthInfo.status}, Responsive: ${healthInfo.responsive}`);
    
    // Note: We don't actually start the process in this example
    // as it requires Ballerina to be installed and configured
    
    log:printInfo("Basic example completed");
}

// Example 2: Advanced Configuration
function advancedConfigurationExample() returns error? {
    log:printInfo("=== Advanced Configuration Example ===");
    
    // Create custom configuration
    language_server:ProcessConfig customConfig = {
        ballerinaCommand: "bal",
        additionalArgs: ["--debug"], // Add debug flag
        healthCheckInterval: 15000,   // Check every 15 seconds
        maxRestartAttempts: 5,        // Allow more restart attempts
        processTimeout: 90000,        // Longer timeout
        enableLogging: true,
        workingDirectory: "/workspace/mcp-ballerina"
    };
    
    // Validate configuration
    language_server:ValidationResult validation = language_server:validateProcessConfig(customConfig);
    if !validation.valid {
        log:printError("Configuration validation failed:");
        foreach string err in validation.errors {
            log:printError("  - " + err);
        }
        return error("Invalid configuration");
    }
    
    // Show warnings and suggestions
    foreach string warning in validation.warnings {
        log:printWarn("Configuration warning: " + warning);
    }
    
    foreach string suggestion in validation.suggestions {
        log:printInfo("Configuration suggestion: " + suggestion);
    }
    
    // Create process manager with custom config
    language_server:ProcessManager manager = language_server:createProcessManager(customConfig);
    log:printInfo("Advanced configuration applied successfully");
    
    // Test extended configuration
    language_server:ExtendedProcessConfig extendedConfig = language_server:createDefaultExtendedConfig();
    log:printInfo(string `Extended config - Connection protocol: ${extendedConfig.connection?.protocol ?: "unknown"}`);
    log:printInfo(string `Extended config - Monitoring enabled: ${extendedConfig.monitoring?.enablePerformanceMonitoring ?: false}`);
    
    log:printInfo("Advanced configuration example completed");
}

// Example 3: Event Handling
function eventHandlingExample() returns error? {
    log:printInfo("=== Event Handling Example ===");
    
    // Create process manager
    language_server:ProcessManager manager = language_server:createDefaultProcessManager();
    
    // Event counter for demonstration
    int eventCount = 0;
    
    // Add event listener
    manager.addEventListener(function(language_server:ProcessEvent event) {
        eventCount += 1;
        log:printInfo(string `Event ${eventCount}: ${event.eventType} - ${event.message}`);
        log:printInfo(string `Event timestamp: ${event.timestamp}`);
        
        if event.data is json {
            log:printInfo(string `Event data: ${event.data.toString()}`);
        }
    });
    
    // Add another event listener for error handling
    manager.addEventListener(function(language_server:ProcessEvent event) {
        if event.eventType == "error" {
            log:printError(string `Critical error detected: ${event.message}`);
            // In real application, you might trigger recovery actions here
        }
    });
    
    log:printInfo("Event listeners configured");
    
    // Simulate some events by getting health info multiple times
    foreach int i in 0 ..< 3 {
        language_server:HealthInfo _ = manager.getHealthInfo();
        time:sleep(0.1); // Small delay between calls
    }
    
    log:printInfo("Event handling example completed");
}

// Example 4: Integration with MCP Server
function mcpIntegrationExample() returns error? {
    log:printInfo("=== MCP Integration Example ===");
    
    // Create extended configuration
    language_server:ExtendedProcessConfig config = language_server:createDefaultExtendedConfig();
    
    // Create integrated language server
    language_server:LanguageServerIntegration|error integration = 
        language_server:createLanguageServerIntegration(config);
    
    if integration is error {
        log:printError("Failed to create integration: " + integration.message());
        return integration;
    }
    
    language_server:LanguageServerIntegration lsIntegration = integration;
    
    // Get server state
    language_server:ServerState state = lsIntegration.getServerState();
    log:printInfo(string `Server state - Status: ${state.status}, Initialized: ${state.initialized}`);
    log:printInfo(string `Server state - Connected: ${state.connected}, Version: ${state.version ?: "unknown"}`);
    
    // Get registered tools and resources
    string[] tools = lsIntegration.getRegisteredTools();
    string[] resources = lsIntegration.getRegisteredResources();
    
    log:printInfo(string `Registered ${tools.length()} tools:`);
    foreach string tool in tools {
        log:printInfo("  - " + tool);
    }
    
    log:printInfo(string `Registered ${resources.length()} resources:`);
    foreach string 'resource in resources {
        log:printInfo("  - " + 'resource);
    }
    
    // Cleanup
    check lsIntegration.cleanup();
    
    log:printInfo("MCP integration example completed");
}

// Example 5: Error Recovery
function errorRecoveryExample() returns error? {
    log:printInfo("=== Error Recovery Example ===");
    
    // Create configuration with aggressive restart settings
    language_server:ProcessConfig recoveryConfig = {
        ballerinaCommand: "bal",
        additionalArgs: [],
        healthCheckInterval: 5000,    // Check every 5 seconds
        maxRestartAttempts: 2,        // Only 2 restart attempts
        processTimeout: 30000,
        enableLogging: true
    };
    
    language_server:ProcessManager manager = language_server:createProcessManager(recoveryConfig);
    
    // Set up monitoring for recovery scenarios
    manager.addEventListener(function(language_server:ProcessEvent event) {
        match event.eventType {
            "error" => {
                log:printWarn(string `Process error detected: ${event.message}`);
                log:printInfo("Recovery strategy: Will attempt automatic restart if within limits");
            }
            "health_check" => {
                language_server:HealthInfo health = manager.getHealthInfo();
                if !health.responsive {
                    log:printWarn("Health check failed - process may need restart");
                }
                if health.restartCount > 0 {
                    log:printInfo(string `Process has been restarted ${health.restartCount} times`);
                }
            }
        }
    });
    
    // Demonstrate configuration validation for error prevention
    language_server:ValidationResult validation = language_server:validateProcessConfig(recoveryConfig);
    if !validation.valid {
        log:printError("Configuration has errors that could cause runtime issues:");
        foreach string err in validation.errors {
            log:printError("  - " + err);
        }
    }
    
    // Test utility functions for error handling
    string[] testArgs = language_server:parseArguments("--flag \"value with spaces\" --another=value");
    log:printInfo(string `Parsed arguments: ${testArgs.toString()}`);
    
    // Test correlation ID generation for request tracking
    string correlationId = language_server:generateCorrelationId();
    log:printInfo(string `Generated correlation ID: ${correlationId}`);
    
    // Test detailed health info creation
    language_server:HealthInfo basicHealth = {
        status: language_server:RUNNING,
        lastHealthCheck: time:utcNow(),
        responsive: true,
        errorMessage: (),
        restartCount: 1
    };
    
    language_server:ProcessMetrics metrics = language_server:createInitialMetrics(time:utcNow());
    language_server:DetailedHealthInfo detailedHealth = 
        language_server:createDetailedHealthInfo(basicHealth, metrics);
    
    log:printInfo(string `Detailed health - Warnings: ${detailedHealth.warnings.length()}`);
    log:printInfo(string `Detailed health - Recommendations: ${detailedHealth.recommendations.length()}`);
    
    foreach string warning in detailedHealth.warnings {
        log:printWarn("Health warning: " + warning);
    }
    
    foreach string recommendation in detailedHealth.recommendations {
        log:printInfo("Health recommendation: " + recommendation);
    }
    
    log:printInfo("Error recovery example completed");
}

// Helper function to demonstrate process metrics
function demonstrateProcessMetrics() returns error? {
    log:printInfo("=== Process Metrics Demonstration ===");
    
    time:Utc startTime = time:utcFromString("2024-01-01T10:00:00Z");
    language_server:ProcessMetrics initialMetrics = language_server:createInitialMetrics(startTime);
    
    log:printInfo(string `Initial metrics - Start time: ${initialMetrics.startTime}`);
    log:printInfo(string `Initial metrics - Total restarts: ${initialMetrics.totalRestarts}`);
    log:printInfo(string `Initial metrics - Health checks: ${initialMetrics.totalHealthChecks}`);
    
    // Calculate uptime
    decimal uptime = language_server:calculateUptime(startTime);
    string formattedUptime = language_server:formatDuration(uptime);
    log:printInfo(string `Uptime: ${formattedUptime}`);
    
    // Update metrics
    language_server:ProcessMetrics updatedMetrics = {
        startTime: startTime,
        lastRestartTime: time:utcNow(),
        totalRestarts: 2,
        totalHealthChecks: 100,
        healthCheckFailures: 5,
        totalBytesRead: 10240,
        totalBytesWritten: 5120,
        averageResponseTime: 250.5,
        activeConnections: 3
    };
    
    language_server:ProcessMetrics finalMetrics = 
        language_server:updateMetrics(initialMetrics, updatedMetrics);
    
    log:printInfo(string `Updated metrics - Restarts: ${finalMetrics.totalRestarts}`);
    log:printInfo(string `Updated metrics - Health checks: ${finalMetrics.totalHealthChecks}`);
    log:printInfo(string `Updated metrics - Avg response time: ${finalMetrics.averageResponseTime}ms`);
    
    log:printInfo("Process metrics demonstration completed");
}

// Helper function to demonstrate connection configuration
function demonstrateConnectionConfig() returns error? {
    log:printInfo("=== Connection Configuration Demonstration ===");
    
    // Test different connection configurations
    language_server:ConnectionConfig stdioConfig = {
        protocol: "stdio",
        useJsonRpc: true,
        connectionTimeout: 30000,
        requestTimeout: 10000
    };
    
    language_server:ValidationResult stdioValidation = 
        language_server:validateConnectionConfig(stdioConfig);
    log:printInfo(string `STDIO config valid: ${stdioValidation.valid}`);
    
    language_server:ConnectionConfig tcpConfig = {
        host: "localhost",
        port: 8080,
        protocol: "tcp",
        useJsonRpc: true,
        connectionTimeout: 30000,
        requestTimeout: 10000
    };
    
    language_server:ValidationResult tcpValidation = 
        language_server:validateConnectionConfig(tcpConfig);
    log:printInfo(string `TCP config valid: ${tcpValidation.valid}`);
    
    // Test port availability
    boolean portAvailable = language_server:isPortAvailable(8080);
    log:printInfo(string `Port 8080 available: ${portAvailable}`);
    
    log:printInfo("Connection configuration demonstration completed");
}

// Entry point for individual examples
public function runExample(string exampleName) returns error? {
    match exampleName {
        "basic" => {
            check basicProcessManagerExample();
        }
        "advanced" => {
            check advancedConfigurationExample();
        }
        "events" => {
            check eventHandlingExample();
        }
        "mcp" => {
            check mcpIntegrationExample();
        }
        "recovery" => {
            check errorRecoveryExample();
        }
        "metrics" => {
            check demonstrateProcessMetrics();
        }
        "connection" => {
            check demonstrateConnectionConfig();
        }
        _ => {
            return error(string `Unknown example: ${exampleName}`);
        }
    }
}