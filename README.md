# Ballerina MCP Server

A Model Context Protocol (MCP) server implementation for the Ballerina programming language, providing comprehensive language intelligence and development tools.

## 🚀 Quick Start

### Prerequisites
- Node.js 18+
- Ballerina 2201.x (Swan Lake)
- Java 17+

### Installation

```bash
# Clone the repository
git clone https://github.com/breddin/mcp-ballerina.git
cd mcp-ballerina

# Install dependencies
npm install

# Copy environment configuration
cp .env.example .env

# Build the project
npm run build
```

### Development

```bash
# Run in development mode with hot reload
npm run dev

# Run tests
npm test

# Run linter
npm run lint

# Format code
npm run format
```

### Production

```bash
# Build for production
npm run build

# Start server
npm start
```

## 📋 Features

### Implemented ✅
- Core MCP server with WebSocket/stdio support
- JSON-RPC 2.0 protocol handling
- Session management
- Connection gateway
- Request routing
- Ballerina CLI integration
- Tool registry system with Zod validation
- 4 Ballerina project tools (new, build, test, run)

### In Progress 🔄
- Resource management
- Prompt templates
- Language Server Protocol proxy

### Planned ⏳
- Ballerina Central integration
- Package management tools
- Code analysis tools
- Documentation generation
- AWS Lambda deployment patterns

## 🛠️ Architecture

The server follows a modular TypeScript architecture:

```
src/
├── server/          # Core MCP server
├── services/        # Service layer
├── tools/           # Ballerina tools
├── resources/       # Resource providers
├── integration/     # External integrations
├── utils/           # Utilities
├── types/           # TypeScript types
└── config/          # Configuration
```

## 📚 API Documentation

### Initialize
```json
{
  "method": "initialize",
  "params": {
    "protocolVersion": "1.0.0",
    "capabilities": {
      "tools": true,
      "resources": true,
      "prompts": true
    }
  }
}
```

### Available Tools

#### Project Management
- `ballerina.project.new` - Create new Ballerina project
- `ballerina.project.build` - Build project with options
- `ballerina.project.test` - Run tests with coverage
- `ballerina.project.run` - Execute Ballerina program

### Call Tool Example
```json
{
  "method": "tools/call",
  "params": {
    "name": "ballerina.project.new",
    "arguments": {
      "projectName": "my-service",
      "projectType": "service"
    }
  }
}
```

## 🧪 Testing

```bash
# Run all tests
npm test

# Run with coverage
npm run test:coverage

# Watch mode
npm run test:watch
```

## 📝 Configuration

Configuration is managed through environment variables:

- `MCP_PORT` - Server port (default: 3000)
- `MCP_HOST` - Server host (default: localhost)
- `MCP_TRANSPORT` - Transport type: websocket or stdio
- `BAL_HOME` - Ballerina installation directory
- `JAVA_HOME` - Java installation directory
- `LOG_LEVEL` - Logging level (debug, info, warn, error)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

MIT

## 🔗 Links

- [MCP Specification](https://modelcontextprotocol.io)
- [Ballerina Documentation](https://ballerina.io/learn/)
- [Project Issues](https://github.com/breddin/mcp-ballerina/issues)
- [Claude-Flow](https://github.com/ruvnet/claude-flow) - Swarm orchestration

---

Built with ❤️ using Claude Flow SPARC methodology

## Overview

This MCP server eliminates Claude Code's need to scrape ballerina.io web pages by providing:

- **Direct Language Server Integration** - Real-time syntax checking, completion, and type information
- **Structured Documentation Access** - Official Ballerina documentation and examples
- **Project Context Awareness** - Understanding of Ballerina project structure and dependencies  
- **Cloud-Specific Enhancements** - AWS Lambda deployment patterns and optimization guidance

## Features

### Tools (Dynamic Operations)
- `mcp__ballerina__syntax_check` - Validate Ballerina syntax and get diagnostics
- `mcp__ballerina__complete` - Get code completion suggestions
- `mcp__ballerina__package_info` - Package and dependency information
- `mcp__ballerina__deploy_lambda` - AWS Lambda deployment configuration

### Resources (Knowledge Base)
- `ballerina://docs/stdlib` - Standard library reference
- `ballerina://docs/lang-ref` - Language specification
- `ballerina://examples/cloud-patterns` - Cloud deployment patterns
- `ballerina://docs/lambda-optimization` - Lambda optimization guide

### Prompts (Conversation Starters)
- `design_lambda_service` - Design Lambda-optimized services
- `optimize_ballerina_code` - Code optimization assistance
- `ballerina_error_patterns` - Error handling patterns

## Installation

### Prerequisites
- Ballerina Swan Lake 2201.12.7 or later
- Claude Code or compatible MCP client

### Building
```bash
cd mcp_ballerina
bal build
```

### Usage with Claude Code
```bash
# Add to Claude Code MCP configuration
claude mcp add ballerina-server /path/to/mcp_ballerina/target/bin/mcp_ballerina.jar

# Or run directly
bal run
```

## Architecture

```
mcp_ballerina/
├── mcp_ballerina_server.bal      # Main entry point
├── modules/
│   ├── mcp_protocol/             # Core MCP protocol implementation
│   │   ├── types.bal            # MCP and JSON-RPC types
│   │   └── server.bal           # MCP server implementation
│   ├── language_server/         # Future: LSP integration
│   ├── tools/                   # Future: Tool implementations
│   └── resources/               # Future: Resource handlers
└── target/bin/mcp_ballerina.jar # Compiled executable
```

## Claude-Flow Compatibility

This implementation is fully compatible with the [ruvnet/claude-flow](https://github.com/ruvnet/claude-flow) ecosystem:

- Follows `mcp__ballerina__*` tool naming conventions
- Implements standard MCP v2024-11-05 protocol
- Uses JSON-RPC 2.0 for communication
- Supports batch operations for swarm coordination

## Development Status

✅ **Phase 1 Complete**: Foundation and core MCP protocol
- Full JSON-RPC 2.0 implementation
- MCP v2024-11-05 protocol support
- Tool/Resource/Prompt registration system
- Claude-flow compatible architecture

🚧 **Phase 2 In Progress**: Language server integration
- Ballerina language server connection
- Real syntax checking and completion
- Project context awareness

🔜 **Phase 3 Planned**: Cloud integration
- AWS Lambda deployment tools
- Performance optimization resources
- Serverless architecture prompts

## Contributing

This MCP server is designed to be part of a larger ecosystem of language-specific MCP servers. The modular architecture makes it easy to:

- Add new tools for specific Ballerina use cases
- Extend cloud platform support beyond AWS
- Integrate with additional development tools

## License

[Add your license here]

## Related Projects

- [Model Context Protocol Specification](https://github.com/modelcontextprotocol/specification)
- [Claude-Flow](https://github.com/ruvnet/claude-flow) - Swarm orchestration with MCP integration
- [Ballerina Language](https://ballerina.io) - Cloud-native programming language
>>>>>>> 90cea875a755f2a92068a982cfa267d71b4d1563
