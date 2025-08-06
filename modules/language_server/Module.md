# Language Server Protocol (LSP) Client Module

This module provides a comprehensive LSP client implementation for the Ballerina MCP server, enabling seamless integration with language servers that support the Language Server Protocol.

## Features

### Core LSP Protocol Support
- **JSON-RPC 2.0 Communication**: Full compliance with JSON-RPC 2.0 specification
- **Request/Response Correlation**: Manages async request-response pairs with timeout handling
- **Notification Handling**: Processes server-sent notifications like diagnostics
- **Connection Management**: Handles initialization, shutdown, and connection lifecycle

### Text Document Operations
- **Document Lifecycle**: `didOpen`, `didChange`, `didClose` notifications
- **Code Completion**: `textDocument/completion` with full completion item support
- **Navigation**: `textDocument/definition`, `textDocument/references`
- **Hover Information**: `textDocument/hover` for symbol information
- **Diagnostics**: Real-time error and warning notifications

### Advanced Capabilities
- **Client Capabilities**: Comprehensive capability advertisement to servers
- **Error Handling**: Robust error handling with detailed error reporting
- **Logging Integration**: Integrated with Ballerina's logging framework
- **Timeout Management**: Automatic cleanup of expired requests

## Usage Examples

### Basic Client Setup
```ballerina
import mcp_ballerina.language_server;

public function main() returns error? {
    // Create LSP client
    language_server:LSPClient client = new("http://localhost:8080");
    
    // Initialize with full capabilities
    language_server:InitializeParams initParams = {
        processId: (),
        rootUri: "file:///workspace",
        capabilities: language_server:createClientCapabilities(),
        initializationOptions: {}
    };
    
    json initResult = check client.initialize(initParams);
    
    // Your LSP interactions here...
    
    // Shutdown gracefully
    check client.shutdown();
}
```

### Document Operations
```ballerina
// Open a document
language_server:TextDocumentItem document = language_server:createTextDocumentItem(
    "file:///workspace/example.bal",
    "ballerina",
    1,
    "import ballerina/io;\n\npublic function main() {\n    io:println(\"Hello!\");\n}"
);

check client.didOpen(document);

// Request completions
language_server:CompletionParams completionParams = language_server:createCompletionParams(
    "file:///workspace/example.bal",
    language_server:createPosition(3, 7)
);

language_server:CompletionList|language_server:CompletionItem[] completions = 
    check client.completion(completionParams);
```

### Handling Diagnostics
```ballerina
// The client automatically handles diagnostic notifications
// Diagnostics are logged with appropriate severity levels
// Custom handling can be implemented by extending the client
```

## Architecture

### Message Types
- `LSPRequestMessage`: JSON-RPC request with method and parameters
- `LSPResponseMessage`: JSON-RPC response with result or error
- `LSPNotificationMessage`: One-way notifications from server

### Client Capabilities
The module provides comprehensive client capabilities including:
- Text synchronization (full and incremental)
- Code completion with snippet support
- Hover, signature help, and navigation
- Document symbols and formatting
- Code actions and refactoring
- Workspace operations

### Request Correlation
The `RequestCorrelationManager` handles:
- Unique request ID generation
- Callback registration for responses
- Timeout handling for abandoned requests
- Error propagation and logging

## Integration with MCP Server

This LSP client is designed to work within the Ballerina MCP server architecture:
- Integrates with existing JSON-RPC infrastructure
- Follows established error handling patterns
- Uses consistent logging and monitoring approaches
- Supports the same HTTP transport mechanisms

## Error Handling

The module provides comprehensive error handling:
- Connection errors are propagated with context
- LSP protocol errors are mapped to Ballerina errors
- Timeout errors for unresponsive servers
- Validation errors for malformed messages

## Testing

Use the `testLSPClient()` function for basic functionality testing:
```ballerina
check language_server:testLSPClient();
```

This performs a complete initialization, document operations, and shutdown cycle.

## Thread Safety

The LSP client is designed for single-threaded use. For concurrent access:
- Use separate client instances per thread
- Implement external synchronization for shared clients
- Consider request queuing for high-throughput scenarios

## Configuration

Server connection details are provided during client initialization:
```ballerina
LSPClient client = new("http://localhost:8080"); // HTTP endpoint
// or
LSPClient client = new("ws://localhost:8080");   // WebSocket (future)
```

## Performance Considerations

- Request correlation uses in-memory maps (suitable for typical LSP usage)
- Automatic cleanup prevents memory leaks from expired requests
- JSON serialization overhead is minimal for typical LSP payloads
- HTTP connection reuse reduces latency for multiple requests