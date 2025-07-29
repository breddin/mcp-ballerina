# MCP Protocol Module

This module contains the core Model Context Protocol (MCP) implementation for Ballerina, including:

- JSON-RPC 2.0 communication handling
- MCP protocol types and structures  
- Server implementation for handling MCP requests
- Tool, Resource, and Prompt management

## Key Components

- `types.bal` - MCP protocol data types and structures
- `server.bal` - Core MCP server implementation with JSON-RPC handling

## Usage

```ballerina
import mcp_ballerina.mcp_protocol as mcp;

// Create server info
mcp:ServerInfo serverInfo = {
    name: "my-mcp-server",
    version: "1.0.0"
};

// Define capabilities
mcp:ServerCapabilities capabilities = {
    tools: { listChanged: false },
    resources: { subscribe: false },
    prompts: { listChanged: false }
};

// Initialize and start server
mcp:McpServer server = new(serverInfo, capabilities);
check server.'start();
```
