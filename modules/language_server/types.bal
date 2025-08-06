// Language Server Types and Error Definitions
// Defines custom error types and data structures for language server operations

// Language Server specific error types
public type LanguageServerError distinct error;
public type ProcessStartError distinct LanguageServerError;
public type ProcessStopError distinct LanguageServerError;
public type ProcessCommunicationError distinct LanguageServerError;
public type HealthCheckError distinct LanguageServerError;
public type ConfigurationError distinct LanguageServerError;

// Process metrics and statistics
public type ProcessMetrics record {|
    time:Utc startTime;
    time:Utc? lastRestartTime;
    int totalRestarts;
    int totalHealthChecks;
    int healthCheckFailures;
    int totalBytesRead;
    int totalBytesWritten;
    float averageResponseTime;
    int activeConnections;
|};

// Language Server capabilities information
public type LanguageServerCapabilities record {|
    boolean textDocumentSync;
    boolean completionProvider;
    boolean hoverProvider;
    boolean signatureHelpProvider;
    boolean definitionProvider;
    boolean referencesProvider;
    boolean documentHighlightProvider;
    boolean documentSymbolProvider;
    boolean workspaceSymbolProvider;
    boolean codeActionProvider;
    boolean documentFormattingProvider;
    boolean documentRangeFormattingProvider;
    boolean renameProvider;
    boolean foldingRangeProvider;
    boolean executeCommandProvider;
    string[] supportedCommands;
|};

// Process performance data
public type PerformanceData record {|
    float cpuUsage;
    int memoryUsage;
    int threadCount;
    time:Utc timestamp;
    boolean responsive;
|};

// Connection configuration for language server
public type ConnectionConfig record {|
    string host = "localhost";
    int port?;
    string protocol = "stdio"; // "stdio", "tcp", "pipe"
    string? pipeName;
    boolean useJsonRpc = true;
    int connectionTimeout = 30000;
    int requestTimeout = 10000;
|};

// Language server initialization parameters
public type InitializationParams record {|
    string rootPath?;
    string[] workspaceFolders;
    map<json> clientCapabilities;
    string? locale;
    json? initializationOptions;
    boolean trace = false;
|};

// Process monitoring configuration
public type MonitoringConfig record {|
    boolean enablePerformanceMonitoring = true;
    boolean enableLogCollection = true;
    boolean enableMetrics = true;
    int metricsCollectionInterval = 60000;
    int logRetentionDays = 7;
    string logLevel = "INFO";
|};

// Language server feature flags
public type FeatureFlags record {|
    boolean autoRestart = true;
    boolean healthMonitoring = true;
    boolean performanceTracking = true;
    boolean errorRecovery = true;
    boolean streamLogging = false;
    boolean detailedMetrics = false;
|};

// Error recovery strategies
public enum RecoveryStrategy {
    RESTART_PROCESS,
    REINITIALIZE_CONNECTION,
    RESET_CONFIGURATION,
    GRACEFUL_DEGRADATION,
    MANUAL_INTERVENTION
}

// Recovery action configuration
public type RecoveryAction record {|
    RecoveryStrategy strategy;
    int maxAttempts;
    int backoffDelay;
    boolean notifyUser;
    string? customAction;
|};

// Comprehensive process configuration
public type ExtendedProcessConfig record {|
    *ProcessConfig;
    ConnectionConfig connection?;
    MonitoringConfig monitoring?;
    FeatureFlags features?;
    RecoveryAction[] recoveryActions;
    InitializationParams? initParams;
|};

// Language server state information
public type ServerState record {|
    ProcessStatus status;
    boolean initialized;
    boolean connected;
    LanguageServerCapabilities? capabilities;
    ProcessMetrics metrics;
    PerformanceData? performance;
    time:Utc lastActivity;
    string? version;
|};

// Process event with extended data
public type ExtendedProcessEvent record {|
    *ProcessEvent;
    string severity; // "INFO", "WARN", "ERROR", "DEBUG"
    string component; // "process", "health", "connection", "stream"
    map<json>? metadata;
|};

// Health check result with detailed information
public type DetailedHealthInfo record {|
    *HealthInfo;
    PerformanceData? performance;
    LanguageServerCapabilities? capabilities;
    ProcessMetrics metrics;
    string[] warnings;
    string[] recommendations;
|};

// Process log entry
public type LogEntry record {|
    time:Utc timestamp;
    string level;
    string component;
    string message;
    json? data;
    string? correlationId;
|};

// Configuration validation result
public type ValidationResult record {|
    boolean valid;
    string[] errors;
    string[] warnings;
    string[] suggestions;
|};