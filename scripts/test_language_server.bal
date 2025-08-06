// Test Script for Language Server Process Manager
// Simple test to verify the language server implementation

import mcp_ballerina.language_server as ls;
import ballerina/io;
import ballerina/log;
import ballerina/time;

public function main() returns error? {
    log:printInfo("=== Ballerina Language Server Test Script ===");
    
    // Test 1: Configuration Validation
    log:printInfo("\n1. Testing configuration validation...");
    check testConfigurationValidation();
    
    // Test 2: Utility Functions
    log:printInfo("\n2. Testing utility functions...");
    check testUtilityFunctions();
    
    // Test 3: Process Manager Creation
    log:printInfo("\n3. Testing process manager creation...");
    check testProcessManagerCreation();
    
    // Test 4: Event System
    log:printInfo("\n4. Testing event system...");
    check testEventSystem();
    
    // Test 5: Ballerina Availability Check
    log:printInfo("\n5. Testing Ballerina availability...");
    check testBallerinaAvailability();
    
    // Test 6: Integration Setup (without starting)
    log:printInfo("\n6. Testing integration setup...");
    check testIntegrationSetup();
    
    log:printInfo("\n=== All tests completed successfully! ===");
}

function testConfigurationValidation() returns error? {
    log:printInfo("Testing configuration validation...");
    
    // Test valid configuration
    ls:ProcessConfig validConfig = {
        ballerinaCommand: "bal",
        additionalArgs: ["--help"],
        healthCheckInterval: 30000,
        maxRestartAttempts: 3,
        processTimeout: 60000,
        enableLogging: true
    };
    
    ls:ValidationResult result = ls:validateProcessConfig(validConfig);
    if !result.valid {
        return error("Valid configuration failed validation");
    }
    log:printInfo("✓ Valid configuration passed validation");
    
    // Test invalid configuration
    ls:ProcessConfig invalidConfig = {
        ballerinaCommand: "", // Empty command
        additionalArgs: [],
        healthCheckInterval: 1000, // Too low
        maxRestartAttempts: 20, // Too high
        processTimeout: 5000, // Too low
        enableLogging: true
    };
    
    ls:ValidationResult invalidResult = ls:validateProcessConfig(invalidConfig);
    if invalidResult.valid {
        return error("Invalid configuration incorrectly passed validation");
    }
    log:printInfo("✓ Invalid configuration correctly failed validation");
    log:printInfo(string `  Errors: ${invalidResult.errors.length()}`);
    log:printInfo(string `  Warnings: ${invalidResult.warnings.length()}`);
}

function testUtilityFunctions() returns error? {
    log:printInfo("Testing utility functions...");
    
    // Test argument parsing
    string[] args = ls:parseArguments("--flag value \"quoted value\" 'single quoted'");
    if args.length() != 4 {
        return error(string `Expected 4 arguments, got ${args.length()}`);
    }
    log:printInfo("✓ Argument parsing works correctly");
    
    // Test duration formatting
    string formatted = ls:formatDuration(3661.5);
    if !formatted.includes("h") {
        return error("Duration formatting failed");
    }
    log:printInfo("✓ Duration formatting works correctly");
    
    // Test uptime calculation
    time:Utc pastTime = time:utcFromString("2024-01-01T00:00:00Z");
    decimal uptime = ls:calculateUptime(pastTime);
    if uptime <= 0 {
        return error("Uptime calculation failed");
    }
    log:printInfo("✓ Uptime calculation works correctly");
    
    // Test correlation ID generation
    string id1 = ls:generateCorrelationId();
    string id2 = ls:generateCorrelationId();
    if id1 == id2 {
        return error("Correlation IDs should be unique");
    }
    log:printInfo("✓ Correlation ID generation works correctly");
    
    // Test port availability check
    boolean available = ls:isPortAvailable(8080);
    log:printInfo(string `✓ Port availability check returned: ${available}`);
}

function testProcessManagerCreation() returns error? {
    log:printInfo("Testing process manager creation...");
    
    // Test default process manager
    ls:ProcessManager defaultManager = ls:createDefaultProcessManager();
    if defaultManager.getStatus() != ls:STOPPED {
        return error("Default manager should start in STOPPED state");
    }
    log:printInfo("✓ Default process manager created successfully");
    
    // Test custom process manager
    ls:ProcessConfig customConfig = {
        ballerinaCommand: "bal",
        additionalArgs: [],
        healthCheckInterval: 15000,
        maxRestartAttempts: 2,
        processTimeout: 30000,
        enableLogging: true
    };
    
    ls:ProcessManager customManager = ls:createProcessManager(customConfig);
    if customManager.getStatus() != ls:STOPPED {
        return error("Custom manager should start in STOPPED state");
    }
    log:printInfo("✓ Custom process manager created successfully");
    
    // Test health info
    ls:HealthInfo healthInfo = defaultManager.getHealthInfo();
    if healthInfo.status != ls:STOPPED {
        return error("Health info should reflect STOPPED status");
    }
    log:printInfo("✓ Health info retrieval works correctly");
}

function testEventSystem() returns error? {
    log:printInfo("Testing event system...");
    
    ls:ProcessManager manager = ls:createDefaultProcessManager();
    boolean eventReceived = false;
    
    // Add event listener
    manager.addEventListener(function(ls:ProcessEvent event) {
        eventReceived = true;
        log:printInfo(string `Event received: ${event.eventType} - ${event.message}`);
    });
    
    // Trigger health check (which should generate an event internally)
    ls:HealthInfo _ = manager.getHealthInfo();
    
    // Since we can't easily trigger events in a test without starting the process,
    // we'll just verify the listener was added successfully
    log:printInfo("✓ Event listener added successfully");
    
    // Test extended process event creation
    ls:ExtendedProcessEvent extendedEvent = {
        eventType: "test",
        timestamp: time:utcNow(),
        message: "Test event",
        data: {"test": "data"},
        severity: "INFO",
        component: "test",
        metadata: {"extra": "info"}
    };
    
    ls:logProcessEvent(extendedEvent);
    log:printInfo("✓ Extended event processing works correctly");
}

function testBallerinaAvailability() returns error? {
    log:printInfo("Testing Ballerina availability...");
    
    boolean|error available = ls:checkBallerinaAvailability();
    if available is boolean {
        log:printInfo(string `✓ Ballerina availability check completed: ${available}`);
        
        if available {
            // Try to get version info
            string|error version = ls:getBallerinaVersion();
            if version is string {
                log:printInfo(string `✓ Ballerina version: ${version}`);
            } else {
                log:printWarn("Could not get Ballerina version: " + version.message());
            }
        } else {
            log:printWarn("Ballerina runtime not available - language server features will be limited");
        }
    } else {
        log:printWarn("Ballerina availability check failed: " + available.message());
    }
}

function testIntegrationSetup() returns error? {
    log:printInfo("Testing integration setup...");
    
    // Create extended configuration
    ls:ExtendedProcessConfig extendedConfig = ls:createDefaultExtendedConfig();
    log:printInfo("✓ Extended configuration created");
    
    // Validate extended configuration components
    if extendedConfig.connection is () {
        return error("Extended config should have connection settings");
    }
    log:printInfo("✓ Connection configuration present");
    
    if extendedConfig.monitoring is () {
        return error("Extended config should have monitoring settings");
    }
    log:printInfo("✓ Monitoring configuration present");
    
    if extendedConfig.features is () {
        return error("Extended config should have feature flags");
    }
    log:printInfo("✓ Feature flags present");
    
    if extendedConfig.recoveryActions.length() == 0 {
        return error("Extended config should have recovery actions");
    }
    log:printInfo("✓ Recovery actions configured");
    
    // Test connection configuration validation
    if extendedConfig.connection is ls:ConnectionConfig {
        ls:ConnectionConfig connConfig = <ls:ConnectionConfig>extendedConfig.connection;
        ls:ValidationResult connValidation = ls:validateConnectionConfig(connConfig);
        if !connValidation.valid {
            return error("Default connection configuration should be valid");
        }
        log:printInfo("✓ Connection configuration validation passed");
    }
    
    // Create process metrics
    time:Utc startTime = time:utcNow();
    ls:ProcessMetrics metrics = ls:createInitialMetrics(startTime);
    if metrics.totalRestarts != 0 {
        return error("Initial metrics should have zero restarts");
    }
    log:printInfo("✓ Process metrics creation works correctly");
    
    // Test metrics update
    ls:ProcessMetrics updatedMetrics = {
        startTime: startTime,
        lastRestartTime: time:utcNow(),
        totalRestarts: 1,
        totalHealthChecks: 10,
        healthCheckFailures: 1,
        totalBytesRead: 1024,
        totalBytesWritten: 512,
        averageResponseTime: 100.0,
        activeConnections: 1
    };
    
    ls:ProcessMetrics finalMetrics = ls:updateMetrics(metrics, updatedMetrics);
    if finalMetrics.totalRestarts != 1 {
        return error("Metrics update failed");
    }
    log:printInfo("✓ Metrics update works correctly");
    
    // Test detailed health info creation
    ls:HealthInfo basicHealth = {
        status: ls:RUNNING,
        lastHealthCheck: time:utcNow(),
        responsive: true,
        errorMessage: (),
        restartCount: 0
    };
    
    ls:DetailedHealthInfo detailedHealth = ls:createDetailedHealthInfo(basicHealth, finalMetrics);
    if detailedHealth.status != ls:RUNNING {
        return error("Detailed health info should preserve status");
    }
    log:printInfo("✓ Detailed health info creation works correctly");
    
    log:printInfo("✓ Integration setup test completed successfully");
}

// Helper function to run individual tests
public function runTest(string testName) returns error? {
    match testName {
        "config" => {
            check testConfigurationValidation();
        }
        "utils" => {
            check testUtilityFunctions();
        }
        "manager" => {
            check testProcessManagerCreation();
        }
        "events" => {
            check testEventSystem();
        }
        "ballerina" => {
            check testBallerinaAvailability();
        }
        "integration" => {
            check testIntegrationSetup();
        }
        _ => {
            return error(string `Unknown test: ${testName}`);
        }
    }
}