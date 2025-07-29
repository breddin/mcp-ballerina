// Ballerina MCP Server
// Main entry point for the Model Context Protocol server for Ballerina

import ballerina/log;
import mcp_ballerina.mcp_protocol as mcp;

public function main() returns error? {
    // Server information
    mcp:ServerInfo serverInfo = {
        name: "ballerina-mcp-server",
        version: "0.1.0"
    };

    // Server capabilities - start with basic tool support
    mcp:ServerCapabilities capabilities = {
        tools: {
            listChanged: false
        },
        resources: {
            subscribe: false,
            listChanged: false
        },
        prompts: {
            listChanged: false
        }
    };

    // Initialize MCP server
    mcp:McpServer server = new(serverInfo, capabilities);

    // Register initial Ballerina-specific tools
    registerBallerinaTools(server);
    
    // Register initial resources
    registerBallerinaResources(server);
    
    // Register initial prompts
    registerBallerinaPrompts(server);

    // Start the server
    log:printInfo("Starting Ballerina MCP Server v0.1.0");
    check server.'start();
}

// Register Ballerina-specific MCP tools
function registerBallerinaTools(mcp:McpServer server) {
    // Syntax check tool
    mcp:Tool syntaxCheckTool = {
        name: "mcp__ballerina__syntax_check",
        description: "Validate Ballerina code syntax and get diagnostics",
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
                }
            },
            "required": ["code"]
        }
    };
    server.registerTool(syntaxCheckTool);

    // Code completion tool
    mcp:Tool completionTool = {
        name: "mcp__ballerina__complete",
        description: "Get code completion suggestions for Ballerina",
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
                }
            },
            "required": ["code", "position"]
        }
    };
    server.registerTool(completionTool);

    // Package info tool
    mcp:Tool packageInfoTool = {
        name: "mcp__ballerina__package_info",
        description: "Get information about Ballerina packages and dependencies",
        inputSchema: {
            "type": "object",
            "properties": {
                "packageName": {
                    "type": "string",
                    "description": "Name of the Ballerina package"
                }
            },
            "required": ["packageName"]
        }
    };
    server.registerTool(packageInfoTool);

    // Lambda deployment tool
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

// Register Ballerina knowledge resources
function registerBallerinaResources(mcp:McpServer server) {
    // Standard library reference
    mcp:Resource stdlibResource = {
        uri: "ballerina://docs/stdlib",
        name: "Ballerina Standard Library Reference",
        description: "Comprehensive reference for Ballerina standard library modules",
        mimeType: "text/markdown"
    };
    server.registerResource(stdlibResource);

    // Language reference
    mcp:Resource langRefResource = {
        uri: "ballerina://docs/lang-ref",
        name: "Ballerina Language Reference",
        description: "Official Ballerina language specification and syntax guide",
        mimeType: "text/markdown"
    };
    server.registerResource(langRefResource);

    // Cloud patterns
    mcp:Resource cloudPatternsResource = {
        uri: "ballerina://examples/cloud-patterns",
        name: "Ballerina Cloud Deployment Patterns",
        description: "Best practices and examples for cloud deployments",
        mimeType: "text/markdown"
    };
    server.registerResource(cloudPatternsResource);

    // Lambda optimization guide
    mcp:Resource lambdaOptResource = {
        uri: "ballerina://docs/lambda-optimization",
        name: "AWS Lambda Optimization Guide",
        description: "Performance optimization strategies for Ballerina on AWS Lambda",
        mimeType: "text/markdown"
    };
    server.registerResource(lambdaOptResource);
}

// Register Ballerina-specific prompts
function registerBallerinaPrompts(mcp:McpServer server) {
    // Lambda service design prompt
    mcp:Prompt lambdaServicePrompt = {
        name: "design_lambda_service",
        description: "Design a Ballerina service optimized for AWS Lambda deployment",
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
            }
        ]
    };
    server.registerPrompt(lambdaServicePrompt);

    // Code optimization prompt
    mcp:Prompt optimizeCodePrompt = {
        name: "optimize_ballerina_code",
        description: "Analyze and optimize Ballerina code for better performance",
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
            }
        ]
    };
    server.registerPrompt(optimizeCodePrompt);

    // Error handling prompt
    mcp:Prompt errorHandlingPrompt = {
        name: "ballerina_error_patterns",
        description: "Generate robust error handling patterns for Ballerina applications",
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
            }
        ]
    };
    server.registerPrompt(errorHandlingPrompt);
}
