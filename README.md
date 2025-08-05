# Ballerina MCP Server

Model Context Protocol (MCP) server implementation for the Ballerina programming language.

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

### Implemented
- ✅ Core MCP server with WebSocket/stdio support
- ✅ JSON-RPC 2.0 protocol handling
- ✅ Session management
- ✅ Connection gateway
- ✅ Request routing

### In Progress
- 🔄 Ballerina CLI integration
- 🔄 Tool registry system
- 🔄 Resource management
- 🔄 Prompt templates

### Planned
- ⏳ Language Server Protocol proxy
- ⏳ Ballerina Central integration
- ⏳ Package management tools
- ⏳ Code analysis tools
- ⏳ Documentation generation

## 🛠️ Architecture

The server follows a modular architecture:

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

### List Tools
```json
{
  "method": "tools/list"
}
```

### Call Tool
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

---

Built with ❤️ using Claude Flow SPARC methodology