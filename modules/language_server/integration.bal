// Language Server Integration with MCP Protocol
// Provides integration layer between process manager and MCP server

import mcp_ballerina.mcp_protocol;
import ballerina/log;
import ballerina/time;
import ballerina/regex;

// Language Server MCP Integration
public class LanguageServerIntegration {
    private ProcessManager processManager;
    private mcp_protocol:McpServer mcpServer;
    private LanguageServerCapabilities? capabilities = ();
    private ServerState serverState;
    private string[] registeredTools = [];
    private string[] registeredResources = [];

    public function init(ProcessManager processManager, mcp_protocol:McpServer mcpServer) {
        self.processManager = processManager;
        self.mcpServer = mcpServer;
        
        self.serverState = {
            status: STOPPED,
            initialized: false,
            connected: false,
            capabilities: (),
            metrics: createInitialMetrics(time:utcNow()),
            performance: (),
            lastActivity: time:utcNow(),
            version: ()
        };

        // Setup event listeners
        self.setupEventListeners();
        
        // Register MCP tools and resources
        self.registerMcpCapabilities();
    }

    // Start the integrated language server
    public function start() returns error? {
        log:printInfo("Starting Language Server MCP Integration");
        
        // Start process manager
        check self.processManager.start();
        
        // Wait for process to be ready
        int attempts = 0;
        while attempts < 10 {
            boolean|error healthy = self.processManager.isHealthy();
            if healthy is boolean && healthy {
                break;
            }
            time:sleep(1);
            attempts += 1;
        }
        
        if attempts >= 10 {
            return error("Language server failed to start within timeout");
        }
        
        // Initialize language server capabilities
        check self.initializeCapabilities();
        
        // Update server state
        self.serverState.status = RUNNING;
        self.serverState.initialized = true;
        self.serverState.connected = true;
        self.serverState.lastActivity = time:utcNow();
        
        log:printInfo("Language Server MCP Integration started successfully");
    }

    // Stop the integrated language server
    public function stop() returns error? {
        log:printInfo("Stopping Language Server MCP Integration");
        
        // Update state
        self.serverState.status = STOPPING;
        self.serverState.connected = false;
        
        // Stop process manager
        check self.processManager.stop();
        
        // Update final state
        self.serverState.status = STOPPED;
        self.serverState.initialized = false;
        
        log:printInfo("Language Server MCP Integration stopped");
    }

    // Get current server state
    public function getServerState() returns ServerState {
        // Update dynamic fields
        self.serverState.status = self.processManager.getStatus();
        HealthInfo healthInfo = self.processManager.getHealthInfo();
        
        // Update metrics if available
        // This would typically come from actual metrics collection
        
        return self.serverState;
    }

    // Execute language server command through MCP
    public function executeCommand(string command, json? params = ()) returns json|error {
        if self.serverState.status != RUNNING {
            return error("Language server is not running");
        }

        // Create LSP request
        json lspRequest = {
            "jsonrpc": "2.0",
            "id": generateCorrelationId(),
            "method": command,
            "params": params ?: {}
        };

        // Send to language server process
        check self.processManager.sendInput(lspRequest.toJsonString());
        
        // Read response (simplified - real implementation would handle async responses)
        string|error response = self.processManager.getOutput();
        if response is error {
            return error("Failed to get response from language server: " + response.message());
        }

        // Parse JSON response
        json|error jsonResponse = response.fromJsonString();
        if jsonResponse is error {
            return error("Invalid JSON response from language server");
        }

        self.serverState.lastActivity = time:utcNow();
        return jsonResponse;
    }

    // Get language server diagnostics
    public function getDiagnostics(string documentUri) returns json|error {
        return self.executeCommand("textDocument/diagnostic", {
            "textDocument": {
                "uri": documentUri
            }
        });
    }

    // Get completions for a document position
    public function getCompletions(string documentUri, int line, int character) returns json|error {
        return self.executeCommand("textDocument/completion", {
            "textDocument": {
                "uri": documentUri
            },
            "position": {
                "line": line,
                "character": character
            }
        });
    }

    // Get hover information
    public function getHover(string documentUri, int line, int character) returns json|error {
        return self.executeCommand("textDocument/hover", {
            "textDocument": {
                "uri": documentUri
            },
            "position": {
                "line": line,
                "character": character
            }
        });
    }

    // Get symbol definitions
    public function getDefinition(string documentUri, int line, int character) returns json|error {
        return self.executeCommand("textDocument/definition", {
            "textDocument": {
                "uri": documentUri
            },
            "position": {
                "line": line,
                "character": character
            }
        });
    }

    // Format document
    public function formatDocument(string documentUri) returns json|error {
        return self.executeCommand("textDocument/formatting", {
            "textDocument": {
                "uri": documentUri
            },
            "options": {
                "tabSize": 4,
                "insertSpaces": true
            }
        });
    }

    // Get document symbols
    public function getDocumentSymbols(string documentUri) returns json|error {
        return self.executeCommand("textDocument/documentSymbol", {
            "textDocument": {
                "uri": documentUri
            }
        });
    }

    // Private method to setup event listeners
    private function setupEventListeners() {
        self.processManager.addEventListener(function(ProcessEvent event) {
            self.handleProcessEvent(event);
        });
    }

    // Private method to handle process events
    private function handleProcessEvent(ProcessEvent event) {
        log:printInfo(string `Process event: ${event.eventType} - ${event.message}`);
        
        match event.eventType {
            "started" => {
                self.serverState.status = RUNNING;
                self.serverState.connected = true;
            }
            "stopped" => {
                self.serverState.status = STOPPED;
                self.serverState.connected = false;
                self.serverState.initialized = false;
            }
            "error" => {
                self.serverState.status = ERROR;
            }
            "health_check" => {
                self.serverState.lastActivity = time:utcNow();
            }
        }
    }

    // Private method to initialize language server capabilities
    private function initializeCapabilities() returns error? {
        // Send initialize request to language server
        json|error initResponse = self.executeCommand("initialize", {
            "processId": (),
            "clientInfo": {
                "name": "Ballerina MCP Server",
                "version": "1.0.0"
            },
            "capabilities": {
                "textDocument": {
                    "completion": {
                        "completionItem": {
                            "snippetSupport": true
                        }
                    },
                    "hover": {
                        "contentFormat": ["markdown", "plaintext"]
                    },
                    "signatureHelp": {
                        "signatureInformation": {
                            "documentationFormat": ["markdown", "plaintext"]
                        }
                    }
                }
            }
        });

        if initResponse is error {
            return error("Failed to initialize language server: " + initResponse.message());
        }

        // Parse capabilities from response
        self.parseCapabilities(initResponse);
        
        // Send initialized notification
        json|error _ = self.executeCommand("initialized", {});
    }

    // Private method to parse language server capabilities
    private function parseCapabilities(json initResponse) {
        // Extract capabilities from init response
        // This is a simplified version - real implementation would parse all capabilities
        self.capabilities = {
            textDocumentSync: true,
            completionProvider: true,
            hoverProvider: true,
            signatureHelpProvider: true,
            definitionProvider: true,
            referencesProvider: true,
            documentHighlightProvider: true,
            documentSymbolProvider: true,
            workspaceSymbolProvider: true,
            codeActionProvider: true,
            documentFormattingProvider: true,
            documentRangeFormattingProvider: true,
            renameProvider: true,
            foldingRangeProvider: true,
            executeCommandProvider: true,
            supportedCommands: ["ballerina.build", "ballerina.test", "ballerina.run"]
        };
        
        self.serverState.capabilities = self.capabilities;
    }

    // Private method to register MCP capabilities
    private function registerMcpCapabilities() {
        // Register tools for language server operations
        self.registerLanguageServerTools();
        
        // Register resources for project files
        self.registerProjectResources();
    }

    // Private method to register language server tools
    private function registerLanguageServerTools() {
        // Completion tool
        mcp_protocol:Tool completionTool = {
            name: "ballerina_completion",
            description: "Get code completions for Ballerina files",
            inputSchema: {
                "type": "object",
                "properties": {
                    "documentUri": {"type": "string"},
                    "line": {"type": "integer"},
                    "character": {"type": "integer"}
                },
                "required": ["documentUri", "line", "character"]
            }
        };
        self.mcpServer.registerTool(completionTool);
        self.registeredTools.push("ballerina_completion");

        // Hover tool
        mcp_protocol:Tool hoverTool = {
            name: "ballerina_hover",
            description: "Get hover information for Ballerina code",
            inputSchema: {
                "type": "object",
                "properties": {
                    "documentUri": {"type": "string"},
                    "line": {"type": "integer"},
                    "character": {"type": "integer"}
                },
                "required": ["documentUri", "line", "character"]
            }
        };
        self.mcpServer.registerTool(hoverTool);
        self.registeredTools.push("ballerina_hover");

        // Definition tool
        mcp_protocol:Tool definitionTool = {
            name: "ballerina_definition",
            description: "Go to definition for Ballerina symbols",
            inputSchema: {
                "type": "object",
                "properties": {
                    "documentUri": {"type": "string"},
                    "line": {"type": "integer"},
                    "character": {"type": "integer"}
                },
                "required": ["documentUri", "line", "character"]
            }
        };
        self.mcpServer.registerTool(definitionTool);
        self.registeredTools.push("ballerina_definition");

        // Format tool
        mcp_protocol:Tool formatTool = {
            name: "ballerina_format",
            description: "Format Ballerina document",
            inputSchema: {
                "type": "object",
                "properties": {
                    "documentUri": {"type": "string"}
                },
                "required": ["documentUri"]
            }
        };
        self.mcpServer.registerTool(formatTool);
        self.registeredTools.push("ballerina_format");

        // Diagnostics tool
        mcp_protocol:Tool diagnosticsTool = {
            name: "ballerina_diagnostics",
            description: "Get diagnostics for Ballerina document",
            inputSchema: {
                "type": "object",
                "properties": {
                    "documentUri": {"type": "string"}
                },
                "required": ["documentUri"]
            }
        };
        self.mcpServer.registerTool(diagnosticsTool);
        self.registeredTools.push("ballerina_diagnostics");
    }

    // Private method to register project resources
    private function registerProjectResources() {
        // Project structure resource
        mcp_protocol:Resource projectResource = {
            uri: "ballerina://project",
            name: "Project Structure",
            description: "Ballerina project structure and metadata",
            mimeType: "application/json"
        };
        self.mcpServer.registerResource(projectResource);
        self.registeredResources.push("ballerina://project");

        // Dependencies resource
        mcp_protocol:Resource depsResource = {
            uri: "ballerina://dependencies",
            name: "Project Dependencies",
            description: "Project dependencies and their versions",
            mimeType: "application/json"
        };
        self.mcpServer.registerResource(depsResource);
        self.registeredResources.push("ballerina://dependencies");

        // Build info resource
        mcp_protocol:Resource buildResource = {
            uri: "ballerina://build",
            name: "Build Information",
            description: "Build status and configuration",
            mimeType: "application/json"
        };
        self.mcpServer.registerResource(buildResource);
        self.registeredResources.push("ballerina://build");
    }

    // Get registered tools
    public function getRegisteredTools() returns string[] {
        return self.registeredTools.clone();
    }

    // Get registered resources
    public function getRegisteredResources() returns string[] {
        return self.registeredResources.clone();
    }

    // Cleanup resources
    public function cleanup() returns error? {
        log:printInfo("Cleaning up Language Server MCP Integration");
        
        // Stop process manager
        check self.processManager.cleanup();
        
        // Clear registrations
        self.registeredTools = [];
        self.registeredResources = [];
        
        // Reset state
        self.serverState.status = STOPPED;
        self.serverState.initialized = false;
        self.serverState.connected = false;
        
        log:printInfo("Language Server MCP Integration cleanup completed");
    }
}

// Utility function to create a fully configured integration
public function createLanguageServerIntegration(ExtendedProcessConfig? config = ()) returns LanguageServerIntegration|error {
    // Create process manager
    ProcessConfig processConfig = config ?: createDefaultExtendedConfig();
    ProcessManager processManager = createProcessManager(processConfig);
    
    // Create MCP server
    mcp_protocol:ServerInfo serverInfo = {
        name: "Ballerina Language Server MCP",
        version: "1.0.0"
    };
    
    mcp_protocol:ServerCapabilities capabilities = {
        tools: {listChanged: true},
        resources: {subscribe: true, listChanged: true},
        prompts: {listChanged: true},
        logging: {}
    };
    
    mcp_protocol:McpServer mcpServer = new(serverInfo, capabilities);
    
    // Create integration
    return new LanguageServerIntegration(processManager, mcpServer);
}