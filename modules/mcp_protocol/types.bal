// MCP Protocol Types and Data Structures
// Based on Model Context Protocol specification

// JSON-RPC 2.0 Base Types
public type JsonRpcVersion "2.0";

public type RequestId string|int;

// Base JSON-RPC Request
public type JsonRpcRequest record {
    JsonRpcVersion jsonrpc = "2.0";
    RequestId id;
    string method;
    json params?;
};

// Base JSON-RPC Response
public type JsonRpcResponse record {
    JsonRpcVersion jsonrpc = "2.0";
    RequestId id;
    json result?;
    JsonRpcError 'error?;
};

// Base JSON-RPC Notification
public type JsonRpcNotification record {
    JsonRpcVersion jsonrpc = "2.0";
    string method;
    json params?;
};

// JSON-RPC Error
public type JsonRpcError record {
    int code;
    string message;
    json data?;
};

// MCP Protocol Version
public type McpVersion "2024-11-05";

// MCP Capabilities
public type ServerCapabilities record {
    ToolsCapability tools?;
    ResourcesCapability resources?;
    PromptsCapability prompts?;
    LoggingCapability logging?;
};

public type ClientCapabilities record {
    SamplingCapability sampling?;
    RootsCapability roots?;
};

public type ToolsCapability record {
    boolean listChanged?;
};

public type ResourcesCapability record {
    boolean subscribe?;
    boolean listChanged?;
};

public type PromptsCapability record {
    boolean listChanged?;
};

public type LoggingCapability record {};

public type SamplingCapability record {};

public type RootsCapability record {
    boolean listChanged?;
};

// MCP Tool Definitions
public type Tool record {
    string name;
    string description;
    json inputSchema;
};

public type ToolCall record {
    string name;
    json arguments?;
};

public type ToolResult record {
    json content;
    boolean isError?;
};

// MCP Resource Definitions
public type Resource record {
    string uri;
    string name;
    string description?;
    string mimeType?;
};

public type ResourceContents record {
    string uri;
    string mimeType;
    string|byte[] contents;
};

// MCP Prompt Definitions
public type Prompt record {
    string name;
    string description;
    PromptArgument[] arguments?;
};

public type PromptArgument record {
    string name;
    string description;
    boolean required?;
};

public type PromptMessage record {
    string role;
    string content;
};

// MCP Initialization
public type InitializeRequest record {
    JsonRpcVersion jsonrpc = "2.0";
    RequestId id;
    "initialize" method = "initialize";
    InitializeParams params;
};

public type InitializeParams record {
    McpVersion protocolVersion;
    ClientCapabilities capabilities;
    ClientInfo clientInfo;
};

public type ClientInfo record {
    string name;
    string version;
};

public type InitializeResult record {
    McpVersion protocolVersion;
    ServerCapabilities capabilities;
    ServerInfo serverInfo;
};

public type ServerInfo record {
    string name;
    string version;
};

// Standard MCP Methods
public const string INITIALIZE = "initialize";
public const string INITIALIZED = "initialized";
public const string TOOLS_LIST = "tools/list";
public const string TOOLS_CALL = "tools/call";
public const string RESOURCES_LIST = "resources/list";
public const string RESOURCES_READ = "resources/read";
public const string PROMPTS_LIST = "prompts/list";
public const string PROMPTS_GET = "prompts/get";

// Error Codes
public const int PARSE_ERROR = -32700;
public const int INVALID_REQUEST = -32600;
public const int METHOD_NOT_FOUND = -32601;
public const int INVALID_PARAMS = -32602;
public const int INTERNAL_ERROR = -32603;
