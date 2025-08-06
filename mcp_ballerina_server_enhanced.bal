// Enhanced Ballerina MCP Server with Language Server Integration
// Main entry point for the Model Context Protocol server for Ballerina

import ballerina/log;
import mcp_ballerina.mcp_protocol as mcp;
import mcp_ballerina.language_server as ls;

public function main() returns error? {
    // Server information
    mcp:ServerInfo serverInfo = {
        name: "ballerina-mcp-server",
        version: "0.1.0"
    };

    // Server capabilities - enhanced with language server support
    mcp:ServerCapabilities capabilities = {
        tools: {
            listChanged: true
        },
        resources: {
            subscribe: true,
            listChanged: true
        },
        prompts: {
            listChanged: true
        },
        logging: {}
    };

    // Initialize MCP server
    mcp:McpServer server = new(serverInfo, capabilities);

    // Initialize Language Server Integration
    ls:LanguageServerIntegration|error lsIntegration = initializeLanguageServer(server);
    if lsIntegration is error {
        log:printWarn("Language server integration failed: " + lsIntegration.message());
        log:printInfo("Continuing with basic MCP server functionality");
    } else {
        log:printInfo("Language server integration initialized successfully");
    }

    // Register initial Ballerina-specific tools
    registerBallerinaTools(server);
    
    // Register initial resources
    registerBallerinaResources(server);
    
    // Register initial prompts
    registerBallerinaPrompts(server);

    // Start the server
    log:printInfo("Starting Enhanced Ballerina MCP Server v0.1.0");
    check server.'start();
}

// Initialize Language Server Integration
function initializeLanguageServer(mcp:McpServer mcpServer) returns ls:LanguageServerIntegration|error {
    // Create extended configuration for language server
    ls:ExtendedProcessConfig lsConfig = ls:createDefaultExtendedConfig();
    
    // Customize configuration for MCP integration
    lsConfig.enableLogging = true;
    lsConfig.healthCheckInterval = 30000;
    lsConfig.maxRestartAttempts = 3;
    
    // Enable features for better integration
    if lsConfig.features is ls:FeatureFlags {
        ls:FeatureFlags features = <ls:FeatureFlags>lsConfig.features;
        features.autoRestart = true;
        features.healthMonitoring = true;
        features.performanceTracking = true;
        features.errorRecovery = true;
    }

    // Check if Ballerina is available before initializing
    boolean|error ballerinaAvailable = ls:checkBallerinaAvailability();
    if ballerinaAvailable is error || !ballerinaAvailable {
        return error("Ballerina runtime not available for language server integration");
    }

    // Create and configure the integration
    ls:LanguageServerIntegration integration = check ls:createLanguageServerIntegration(lsConfig);
    
    // Set up event monitoring
    setupLanguageServerMonitoring(integration);
    
    return integration;
}

// Setup monitoring for language server events
function setupLanguageServerMonitoring(ls:LanguageServerIntegration integration) {
    // This would typically be done through the ProcessManager within the integration
    // For now, we'll log the setup
    log:printInfo("Language server monitoring configured");
    
    // In a real implementation, you might:
    // 1. Set up health check notifications
    // 2. Configure performance metric collection
    // 3. Setup error recovery workflows
    // 4. Enable diagnostic logging
}

// Register Enhanced Ballerina-specific MCP tools (with Language Server support)
function registerBallerinaTools(mcp:McpServer server) {
    // Enhanced syntax check tool with Language Server backend
    mcp:Tool syntaxCheckTool = {
        name: "mcp__ballerina__syntax_check",
        description: "Validate Ballerina code syntax using the Language Server for accurate diagnostics",
        inputSchema: {
            "type": "object",
            "properties": {
                "code": {
                    "type": "string",
                    "description": "Ballerina source code to validate"
                },
                "uri": {
                    "type": "string", 
                    "description": "Optional file URI for context"
                },
                "includeWarnings": {
                    "type": "boolean",
                    "description": "Include warnings in addition to errors",
                    "default": true
                }
            },
            "required": ["code"]
        }
    };
    server.registerTool(syntaxCheckTool);

    // Enhanced code completion tool with Language Server integration
    mcp:Tool completionTool = {
        name: "mcp__ballerina__complete",
        description: "Get intelligent code completion suggestions using Ballerina Language Server",
        inputSchema: {
            "type": "object",
            "properties": {
                "code": {
                    "type": "string",
                    "description": "Ballerina source code"
                },
                "position": {
                    "type": "object",
                    "properties": {
                        "line": {"type": "integer"},
                        "character": {"type": "integer"}
                    },
                    "required": ["line", "character"]
                },
                "uri": {
                    "type": "string",
                    "description": "Document URI for better context"
                },
                "triggerKind": {
                    "type": "integer",
                    "description": "Completion trigger kind (1=Invoked, 2=TriggerCharacter)",
                    "default": 1
                }
            },
            "required": ["code", "position"]
        }
    };
    server.registerTool(completionTool);

    // Hover information tool
    mcp:Tool hoverTool = {
        name: "mcp__ballerina__hover",
        description: "Get detailed information about symbols at cursor position",
        inputSchema: {
            "type": "object",
            "properties": {
                "code": {
                    "type": "string",
                    "description": "Ballerina source code"
                },
                "position": {
                    "type": "object",
                    "properties": {
                        "line": {"type": "integer"},
                        "character": {"type": "integer"}
                    },
                    "required": ["line", "character"]
                },
                "uri": {
                    "type": "string",
                    "description": "Document URI"
                }
            },
            "required": ["code", "position"]
        }
    };
    server.registerTool(hoverTool);

    // Go to definition tool
    mcp:Tool definitionTool = {
        name: "mcp__ballerina__definition",
        description: "Navigate to the definition of symbols in Ballerina code",
        inputSchema: {
            "type": "object",
            "properties": {
                "code": {
                    "type": "string",
                    "description": "Ballerina source code"
                },
                "position": {
                    "type": "object",
                    "properties": {
                        "line": {"type": "integer"},
                        "character": {"type": "integer"}
                    },
                    "required": ["line", "character"]
                },
                "uri": {
                    "type": "string",
                    "description": "Document URI"
                }
            },
            "required": ["code", "position"]
        }
    };
    server.registerTool(definitionTool);

    // Document formatting tool
    mcp:Tool formatTool = {
        name: "mcp__ballerina__format",
        description: "Format Ballerina code using the Language Server formatter",
        inputSchema: {
            "type": "object",
            "properties": {
                "code": {
                    "type": "string",
                    "description": "Ballerina source code to format"
                },
                "uri": {
                    "type": "string",
                    "description": "Document URI"
                },
                "options": {
                    "type": "object",
                    "properties": {
                        "tabSize": {"type": "integer", "default": 4},
                        "insertSpaces": {"type": "boolean", "default": true}
                    }
                }
            },
            "required": ["code"]
        }
    };
    server.registerTool(formatTool);

    // Document symbols tool
    mcp:Tool symbolsTool = {
        name: "mcp__ballerina__symbols",
        description: "Extract symbols and structure from Ballerina documents",
        inputSchema: {
            "type": "object",
            "properties": {
                "code": {
                    "type": "string",
                    "description": "Ballerina source code"
                },
                "uri": {
                    "type": "string",
                    "description": "Document URI"
                },
                "hierarchical": {
                    "type": "boolean",
                    "description": "Return hierarchical symbol structure",
                    "default": true
                }
            },
            "required": ["code"]
        }
    };
    server.registerTool(symbolsTool);

    // Package info tool (enhanced)
    mcp:Tool packageInfoTool = {
        name: "mcp__ballerina__package_info",
        description: "Get comprehensive information about Ballerina packages and dependencies",
        inputSchema: {
            "type": "object",
            "properties": {
                "packageName": {
                    "type": "string",
                    "description": "Name of the Ballerina package"
                },
                "includeTransitive": {
                    "type": "boolean",
                    "description": "Include transitive dependencies",
                    "default": false
                },
                "version": {
                    "type": "string",
                    "description": "Specific version to query"
                }
            },
            "required": ["packageName"]
        }
    };
    server.registerTool(packageInfoTool);

    // Language Server health check tool
    mcp:Tool healthCheckTool = {
        name: "mcp__ballerina__ls_health",
        description: "Check the health and status of the Ballerina Language Server",
        inputSchema: {
            "type": "object",
            "properties": {
                "detailed": {
                    "type": "boolean",
                    "description": "Include detailed health metrics",
                    "default": false
                }
            }
        }
    };
    server.registerTool(healthCheckTool);

    // Lambda deployment tool (preserved from original)
    mcp:Tool lambdaDeployTool = {
        name: "mcp__ballerina__deploy_lambda",
        description: "Generate AWS Lambda deployment configuration for Ballerina",
        inputSchema: {
            "type": "object",
            "properties": {
                "serviceName": {
                    "type": "string",
                    "description": "Name of the Ballerina service"
                },
                "runtime": {
                    "type": "string",
                    "description": "Lambda runtime version",
                    "default": "java21"
                }
            },
            "required": ["serviceName"]
        }
    };
    server.registerTool(lambdaDeployTool);
}

// Register Enhanced Ballerina knowledge resources
function registerBallerinaResources(mcp:McpServer server) {
    // Language Server status resource
    mcp:Resource lsStatusResource = {
        uri: "ballerina://language-server/status",
        name: "Language Server Status",
        description: "Real-time status and metrics of the Ballerina Language Server",
        mimeType: "application/json"
    };
    server.registerResource(lsStatusResource);

    // Language Server capabilities resource
    mcp:Resource lsCapabilitiesResource = {
        uri: "ballerina://language-server/capabilities",
        name: "Language Server Capabilities",
        description: "Available features and capabilities of the Language Server",
        mimeType: "application/json"
    };
    server.registerResource(lsCapabilitiesResource);

    // Standard library reference (preserved)
    mcp:Resource stdlibResource = {
        uri: "ballerina://docs/stdlib",
        name: "Ballerina Standard Library Reference",
        description: "Comprehensive reference for Ballerina standard library modules",
        mimeType: "text/markdown"
    };
    server.registerResource(stdlibResource);

    // Language reference (preserved)
    mcp:Resource langRefResource = {
        uri: "ballerina://docs/lang-ref",
        name: "Ballerina Language Reference",
        description: "Official Ballerina language specification and syntax guide",
        mimeType: "text/markdown"
    };
    server.registerResource(langRefResource);

    // Enhanced cloud patterns with Language Server integration
    mcp:Resource cloudPatternsResource = {
        uri: "ballerina://examples/cloud-patterns",
        name: "Ballerina Cloud Deployment Patterns",
        description: "Best practices and examples for cloud deployments with IDE support",
        mimeType: "text/markdown"
    };
    server.registerResource(cloudPatternsResource);

    // Lambda optimization guide (preserved)
    mcp:Resource lambdaOptResource = {
        uri: "ballerina://docs/lambda-optimization",
        name: "AWS Lambda Optimization Guide",
        description: "Performance optimization strategies for Ballerina on AWS Lambda",
        mimeType: "text/markdown"
    };
    server.registerResource(lambdaOptResource);

    // Language Server integration guide
    mcp:Resource lsIntegrationResource = {
        uri: "ballerina://docs/language-server-integration",
        name: "Language Server Integration Guide",
        description: "Guide for integrating and using the Ballerina Language Server",
        mimeType: "text/markdown"
    };
    server.registerResource(lsIntegrationResource);
}

// Register Enhanced Ballerina-specific prompts
function registerBallerinaPrompts(mcp:McpServer server) {
    // Enhanced lambda service design prompt with Language Server support
    mcp:Prompt lambdaServicePrompt = {
        name: "design_lambda_service",
        description: "Design a Ballerina service optimized for AWS Lambda with IDE integration",
        arguments: [
            {
                name: "serviceType",
                description: "Type of service (REST API, event handler, webhook, etc.)",
                required: true
            },
            {
                name: "dataFormats",
                description: "Expected data formats (JSON, XML, etc.)",
                required: false
            },
            {
                name: "performance",
                description: "Performance requirements (low latency, high throughput, etc.)",
                required: false
            },
            {
                name: "useLanguageServer",
                description: "Include Language Server features for development",
                required: false
            }
        ]
    };
    server.registerPrompt(lambdaServicePrompt);

    // Enhanced code optimization prompt
    mcp:Prompt optimizeCodePrompt = {
        name: "optimize_ballerina_code",
        description: "Analyze and optimize Ballerina code using Language Server insights",
        arguments: [
            {
                name: "codeSnippet",
                description: "Ballerina code to optimize",
                required: true
            },
            {
                name: "target",
                description: "Optimization target (memory, speed, cloud deployment)",
                required: false
            },
            {
                name: "useLSAnalysis",
                description: "Use Language Server analysis for optimization recommendations",
                required: false
            }
        ]
    };
    server.registerPrompt(optimizeCodePrompt);

    // Enhanced error handling prompt
    mcp:Prompt errorHandlingPrompt = {
        name: "ballerina_error_patterns",
        description: "Generate robust error handling patterns with Language Server validation",
        arguments: [
            {
                name: "context",
                description: "Application context (web service, data processing, integration)",
                required: true
            },
            {
                name: "errorTypes",
                description: "Types of errors to handle (network, validation, business logic)",
                required: false
            },
            {
                name: "validateWithLS",
                description: "Validate error patterns using Language Server",
                required: false
            }
        ]
    };
    server.registerPrompt(errorHandlingPrompt);

    // Language Server development workflow prompt
    mcp:Prompt lsWorkflowPrompt = {
        name: "ballerina_ls_workflow",
        description: "Establish an efficient development workflow using Ballerina Language Server",
        arguments: [
            {
                name: "projectType",
                description: "Type of Ballerina project (service, library, integration)",
                required: true
            },
            {
                name: "teamSize",
                description: "Development team size for workflow optimization",
                required: false
            },
            {
                name: "cicdIntegration",
                description: "CI/CD requirements and integrations",
                required: false
            }
        ]
    };
    server.registerPrompt(lsWorkflowPrompt);
}