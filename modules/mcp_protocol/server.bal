// Core MCP Protocol Handler
// Handles JSON-RPC communication and MCP method routing

import ballerina/io;
import ballerina/log;
import ballerina/uuid;

// MCP Server instance
public class McpServer {
    private ServerInfo serverInfo;
    private ServerCapabilities capabilities;
    private map<Tool> tools = {};
    private map<Resource> resources = {};
    private map<Prompt> prompts = {};
    private boolean initialized = false;

    public function init(ServerInfo serverInfo, ServerCapabilities capabilities) {
        self.serverInfo = serverInfo;
        self.capabilities = capabilities;
    }

    // Main message processing loop
    public function 'start() returns error? {
        log:printInfo("Starting Ballerina MCP Server...");
        
        while true {
            string? input = io:readln();
            if input is () {
                break;
            }
            
            json|error message = input.fromJsonString();
            if message is error {
                self.sendErrorResponse(null, PARSE_ERROR, "Parse error", ());
                continue;
            }
            
            check self.handleMessage(message);
        }
    }

    // Handle incoming JSON-RPC messages
    private function handleMessage(json message) returns error? {
        // Check if it's a request (has id) or notification (no id)
        if message.id is () {
            return self.handleNotification(message);
        } else {
            return self.handleRequest(message);
        }
    }

    // Handle JSON-RPC requests
    private function handleRequest(json message) returns error? {
        json|error idField = message.id;
        json|error methodField = message.method;
        json|error paramsField = message.params;
        
        if idField is error || methodField is error {
            self.sendErrorResponse(null, INVALID_REQUEST, "Invalid request", ());
            return;
        }
        
        RequestId id = <RequestId>idField;
        string method = <string>methodField;
        json? params = paramsField is json ? paramsField : ();

        match method {
            INITIALIZE => {
                return self.handleInitialize(id, params);
            }
            TOOLS_LIST => {
                return self.handleToolsList(id);
            }
            TOOLS_CALL => {
                return self.handleToolsCall(id, params);
            }
            RESOURCES_LIST => {
                return self.handleResourcesList(id);
            }
            RESOURCES_READ => {
                return self.handleResourcesRead(id, params);
            }
            PROMPTS_LIST => {
                return self.handlePromptsList(id);
            }
            PROMPTS_GET => {
                return self.handlePromptsGet(id, params);
            }
            _ => {
                self.sendErrorResponse(id, METHOD_NOT_FOUND, "Method not found", ());
            }
        }
    }

    // Handle JSON-RPC notifications
    private function handleNotification(json message) returns error? {
        json|error methodField = message.method;
        
        if methodField is error {
            return;
        }

        string method = <string>methodField;

        match method {
            INITIALIZED => {
                self.initialized = true;
                log:printInfo("MCP Server initialized successfully");
            }
            _ => {
                log:printWarn("Unknown notification method: " + method);
            }
        }
    }

    // Initialize handler
    private function handleInitialize(RequestId id, json? params) returns error? {
        if !self.initialized {
            InitializeResult result = {
                protocolVersion: "2024-11-05",
                capabilities: self.capabilities,
                serverInfo: self.serverInfo
            };
            
            self.sendSuccessResponse(id, result.toJson());
        } else {
            self.sendErrorResponse(id, INVALID_REQUEST, "Already initialized", ());
        }
    }

    // Tools list handler
    private function handleToolsList(RequestId id) returns error? {
        Tool[] toolList = self.tools.toArray();
        json result = {tools: toolList.toJson()};
        self.sendSuccessResponse(id, result);
    }

    // Tools call handler
    private function handleToolsCall(RequestId id, json? params) returns error? {
        if params is () {
            self.sendErrorResponse(id, INVALID_PARAMS, "Missing params", ());
            return;
        }
        
        // TODO: Implement actual tool calling logic
        ToolResult result = {
            content: "Tool execution not yet implemented",
            isError: true
        };
        
        self.sendSuccessResponse(id, result.toJson());
    }

    // Resources list handler
    private function handleResourcesList(RequestId id) returns error? {
        Resource[] resourceList = self.resources.toArray();
        json result = {resources: resourceList.toJson()};
        self.sendSuccessResponse(id, result);
    }

    // Resources read handler
    private function handleResourcesRead(RequestId id, json? params) returns error? {
        if params is () {
            self.sendErrorResponse(id, INVALID_PARAMS, "Missing params", ());
            return;
        }
        
        // TODO: Implement actual resource reading logic
        ResourceContents result = {
            uri: "ballerina://placeholder",
            mimeType: "text/plain",
            contents: "Resource reading not yet implemented"
        };
        
        self.sendSuccessResponse(id, result.toJson());
    }

    // Prompts list handler
    private function handlePromptsList(RequestId id) returns error? {
        Prompt[] promptList = self.prompts.toArray();
        json result = {prompts: promptList.toJson()};
        self.sendSuccessResponse(id, result);
    }

    // Prompts get handler
    private function handlePromptsGet(RequestId id, json? params) returns error? {
        if params is () {
            self.sendErrorResponse(id, INVALID_PARAMS, "Missing params", ());
            return;
        }
        
        // TODO: Implement actual prompt generation logic
        PromptMessage[] messages = [
            {
                role: "user",
                content: "Prompt generation not yet implemented"
            }
        ];
        
        json result = {messages: messages.toJson()};
        self.sendSuccessResponse(id, result);
    }

    // Register a tool
    public function registerTool(Tool tool) {
        self.tools[tool.name] = tool;
    }

    // Register a resource
    public function registerResource(Resource 'resource) {
        self.resources['resource.uri] = 'resource;
    }

    // Register a prompt
    public function registerPrompt(Prompt prompt) {
        self.prompts[prompt.name] = prompt;
    }

    // Send successful response
    private function sendSuccessResponse(RequestId id, json result) {
        JsonRpcResponse response = {
            jsonrpc: "2.0",
            id: id,
            result: result
        };
        
        io:println(response.toJsonString());
    }

    // Send error response
    private function sendErrorResponse(RequestId? id, int code, string message, json? data) {
        JsonRpcError errorRecord = {
            code: code,
            message: message,
            data: data
        };
        
        JsonRpcResponse response = {
            jsonrpc: "2.0",
            id: id ?: uuid:createType1AsString(),
            'error: errorRecord
        };
        
        io:println(response.toJsonString());
    }
}
