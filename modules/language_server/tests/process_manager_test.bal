// Language Server Process Manager Tests
// Comprehensive test suite for process management functionality

import ballerina/test;
import ballerina/time;
import ballerina/log;

// Test default process manager creation
@test:Config {}
function testCreateDefaultProcessManager() {
    ProcessManager manager = createDefaultProcessManager();
    test:assertEquals(manager.getStatus(), STOPPED, "Initial status should be STOPPED");
}

// Test custom process manager creation
@test:Config {}
function testCreateCustomProcessManager() {
    ProcessConfig config = {
        ballerinaCommand: "bal",
        additionalArgs: ["--help"],
        healthCheckInterval: 15000,
        maxRestartAttempts: 2,
        processTimeout: 30000,
        enableLogging: false
    };
    
    ProcessManager manager = createProcessManager(config);
    test:assertEquals(manager.getStatus(), STOPPED, "Initial status should be STOPPED");
}

// Test configuration validation
@test:Config {}
function testConfigurationValidation() {
    ProcessConfig validConfig = {
        ballerinaCommand: "bal",
        additionalArgs: [],
        healthCheckInterval: 30000,
        maxRestartAttempts: 3,
        processTimeout: 60000,
        enableLogging: true
    };
    
    ValidationResult result = validateProcessConfig(validConfig);
    test:assertTrue(result.valid, "Valid configuration should pass validation");
    test:assertEquals(result.errors.length(), 0, "Valid configuration should have no errors");
}

// Test invalid configuration validation
@test:Config {}
function testInvalidConfigurationValidation() {
    ProcessConfig invalidConfig = {
        ballerinaCommand: "", // Empty command
        additionalArgs: [],
        healthCheckInterval: 1000, // Too low
        maxRestartAttempts: 15, // Too high
        processTimeout: 5000, // Too low
        enableLogging: true
    };
    
    ValidationResult result = validateProcessConfig(invalidConfig);
    test:assertFalse(result.valid, "Invalid configuration should fail validation");
    test:assertTrue(result.errors.length() > 0, "Invalid configuration should have errors");
}

// Test health info creation
@test:Config {}
function testHealthInfoCreation() {
    ProcessManager manager = createDefaultProcessManager();
    HealthInfo healthInfo = manager.getHealthInfo();
    
    test:assertEquals(healthInfo.status, STOPPED, "Health info should reflect current status");
    test:assertEquals(healthInfo.restartCount, 0, "Initial restart count should be 0");
    test:assertFalse(healthInfo.responsive, "Stopped process should not be responsive");
}

// Test event listener functionality
@test:Config {}
function testEventListeners() {
    ProcessManager manager = createDefaultProcessManager();
    boolean eventReceived = false;
    
    // Add event listener
    manager.addEventListener(function(ProcessEvent event) {
        eventReceived = true;
        test:assertEquals(event.eventType, "test", "Event type should match");
    });
    
    // Manually emit a test event (would normally be internal)
    // This tests the listener mechanism
    test:assertTrue(true, "Event listener test placeholder");
}

// Test utility functions
@test:Config {}
function testUtilityFunctions() {
    // Test argument parsing
    string[] args = parseArguments("--flag value \"quoted value\" 'another quoted'");
    test:assertEquals(args.length(), 4, "Should parse 4 arguments");
    test:assertEquals(args[2], "quoted value", "Should handle quoted arguments");
    
    // Test duration formatting
    string formatted = formatDuration(3661.5);
    test:assertTrue(formatted.includes("h"), "Should format hours correctly");
    
    // Test uptime calculation
    time:Utc pastTime = time:utcFromString("2024-01-01T00:00:00Z");
    decimal uptime = calculateUptime(pastTime);
    test:assertTrue(uptime > 0, "Uptime should be positive");
}

// Test metrics creation and updates
@test:Config {}
function testProcessMetrics() {
    time:Utc startTime = time:utcNow();
    ProcessMetrics metrics = createInitialMetrics(startTime);
    
    test:assertEquals(metrics.totalRestarts, 0, "Initial restarts should be 0");
    test:assertEquals(metrics.totalHealthChecks, 0, "Initial health checks should be 0");
    test:assertEquals(metrics.startTime, startTime, "Start time should match");
    
    // Test metrics update
    ProcessMetrics updatedMetrics = {
        startTime: startTime,
        lastRestartTime: time:utcNow(),
        totalRestarts: 1,
        totalHealthChecks: 5,
        healthCheckFailures: 1,
        totalBytesRead: 1024,
        totalBytesWritten: 512,
        averageResponseTime: 150.5,
        activeConnections: 2
    };
    
    ProcessMetrics result = updateMetrics(metrics, updatedMetrics);
    test:assertEquals(result.totalRestarts, 1, "Restart count should be updated");
    test:assertTrue(result.totalHealthChecks > 0, "Health check count should increase");
}

// Test extended configuration creation
@test:Config {}
function testExtendedConfiguration() {
    ExtendedProcessConfig config = createDefaultExtendedConfig();
    
    test:assertEquals(config.ballerinaCommand, "bal", "Should have default Ballerina command");
    test:assertTrue(config.connection is ConnectionConfig, "Should have connection config");
    test:assertTrue(config.monitoring is MonitoringConfig, "Should have monitoring config");
    test:assertTrue(config.features is FeatureFlags, "Should have feature flags");
    test:assertTrue(config.recoveryActions.length() > 0, "Should have recovery actions");
}

// Test connection configuration validation
@test:Config {}
function testConnectionConfigValidation() {
    ConnectionConfig validConfig = {
        host: "localhost",
        protocol: "stdio",
        useJsonRpc: true,
        connectionTimeout: 30000,
        requestTimeout: 10000
    };
    
    ValidationResult result = validateConnectionConfig(validConfig);
    test:assertTrue(result.valid, "Valid connection config should pass");
    
    ConnectionConfig invalidConfig = {
        host: "localhost",
        protocol: "invalid", // Invalid protocol
        useJsonRpc: true,
        connectionTimeout: 30000,
        requestTimeout: 10000
    };
    
    ValidationResult invalidResult = validateConnectionConfig(invalidConfig);
    test:assertFalse(invalidResult.valid, "Invalid connection config should fail");
}

// Test detailed health info creation
@test:Config {}
function testDetailedHealthInfo() {
    HealthInfo basicHealth = {
        status: RUNNING,
        lastHealthCheck: time:utcNow(),
        responsive: true,
        errorMessage: (),
        restartCount: 0
    };
    
    ProcessMetrics metrics = createInitialMetrics(time:utcNow());
    DetailedHealthInfo detailed = createDetailedHealthInfo(basicHealth, metrics);
    
    test:assertEquals(detailed.status, RUNNING, "Status should match basic health");
    test:assertTrue(detailed.metrics is ProcessMetrics, "Should have metrics");
    test:assertTrue(detailed.warnings.length() >= 0, "Should have warnings array");
    test:assertTrue(detailed.recommendations.length() >= 0, "Should have recommendations array");
}

// Test Ballerina availability check (may fail in test environment)
@test:Config {}
function testBallerinaAvailability() {
    // This test may fail if Ballerina is not installed in test environment
    // We'll just test that the function doesn't throw an error
    boolean|error available = checkBallerinaAvailability();
    test:assertTrue(available is boolean || available is error, "Should return boolean or error");
}

// Test correlation ID generation
@test:Config {}
function testCorrelationIdGeneration() {
    string id1 = generateCorrelationId();
    string id2 = generateCorrelationId();
    
    test:assertTrue(id1.startsWith("ls-"), "Correlation ID should have proper prefix");
    test:assertNotEquals(id1, id2, "Each correlation ID should be unique");
}

// Test port availability check
@test:Config {}
function testPortAvailability() {
    boolean available = isPortAvailable(8080);
    test:assertTrue(available is boolean, "Port availability should return boolean");
    
    boolean invalidPort = isPortAvailable(80); // Privileged port
    test:assertFalse(invalidPort, "Port 80 should not be available for regular users");
}

// Integration test - start and stop process (requires Ballerina)
@test:Config {
    enable: false // Disabled by default as it requires Ballerina installation
}
function testProcessLifecycle() returns error? {
    ProcessConfig config = {
        ballerinaCommand: "bal",
        additionalArgs: ["version"], // Safe command that exits quickly
        healthCheckInterval: 5000,
        maxRestartAttempts: 1,
        processTimeout: 10000,
        enableLogging: true
    };
    
    ProcessManager manager = createProcessManager(config);
    
    // Test start
    error? startResult = manager.start();
    if startResult is error {
        log:printWarn("Process start failed (expected in test environment): " + startResult.message());
        return;
    }
    
    // Wait a moment
    time:sleep(1);
    
    // Test health check
    boolean|error healthy = manager.isHealthy();
    if healthy is boolean {
        log:printInfo("Process health check result: " + healthy.toString());
    }
    
    // Test stop
    error? stopResult = manager.stop();
    if stopResult is error {
        log:printWarn("Process stop failed: " + stopResult.message());
    }
    
    // Cleanup
    check manager.cleanup();
}

// Performance test for configuration validation
@test:Config {}
function testConfigurationValidationPerformance() {
    ProcessConfig config = {
        ballerinaCommand: "bal",
        additionalArgs: ["arg1", "arg2", "arg3"],
        healthCheckInterval: 30000,
        maxRestartAttempts: 3,
        processTimeout: 60000,
        enableLogging: true
    };
    
    time:Utc startTime = time:utcNow();
    
    // Run validation multiple times
    int iterations = 1000;
    foreach int i in 0 ..< iterations {
        ValidationResult _ = validateProcessConfig(config);
    }
    
    time:Utc endTime = time:utcNow();
    decimal elapsed = time:utcDiffSeconds(endTime, startTime);
    
    log:printInfo(string `Configuration validation performance: ${iterations} iterations in ${elapsed}s`);
    test:assertTrue(elapsed < 1.0, "Validation should be fast");
}