# Ballerina MCP Resources Module

This module manages resource content loading and serving for the Ballerina MCP server.

## Features

- **Dynamic Resource Loading**: Load resources from files, documentation, and templates
- **Content Caching**: Cache resource content for improved performance
- **Auto-reload**: Automatic resource refresh at configurable intervals
- **Multiple URI Schemes**: Support for various resource URI patterns
- **MIME Type Detection**: Automatic content type detection

## Resource Types

### Documentation Resources
- `ballerina://docs/stdlib` - Standard library reference
- `ballerina://docs/lang-ref` - Language specification
- `ballerina://docs/lambda-optimization` - AWS Lambda optimization guide
- Custom documentation from files

### Example Resources
- `ballerina://examples/cloud-patterns` - Cloud deployment patterns
- Custom examples from `.bal` files

### Template Resources
- Project templates
- Code generation templates
- Configuration templates

### File Resources
- `file://` - Direct file system access
- Binary and text file support

## Usage

```ballerina
import mcp_ballerina.resources;

public function main() {
    resources:ResourceLoader loader = new();
    
    // Register a resource
    loader.registerResource({
        uri: "ballerina://docs/my-guide",
        name: "My Guide",
        description: "Custom documentation",
        mimeType: "text/markdown"
    });
    
    // Read resource content
    resources:ResourceContent content = check loader.readResource("ballerina://docs/stdlib");
    io:println(content.contents);
}
```

## Configuration

```ballerina
resources:LoaderConfig config = {
    resourcePath: "./resources",
    enableCache: true,
    cacheSize: 50,
    autoReload: true,
    reloadInterval: 60000
};

resources:ResourceLoader loader = new(config);
```

## Resource Content Structure

```ballerina
type ResourceContent record {|
    string uri;           // Resource URI
    string mimeType;      // Content MIME type
    string|byte[] contents; // Actual content
    json? metadata;       // Optional metadata
|};
```

## Built-in Resources

### Standard Library Documentation
Comprehensive reference for all Ballerina standard library modules including:
- Core modules (io, http, grpc, sql)
- Utility modules (time, file, log, crypto)
- Language modules (lang.array, lang.string, etc.)

### Language Reference
Complete Ballerina language specification covering:
- Data types and type system
- Control flow constructs
- Concurrency primitives
- Error handling
- Transactions

### Cloud Patterns
Best practices and examples for cloud deployments:
- Serverless functions
- Microservices
- Event-driven architectures
- Container deployments

### Lambda Optimization Guide
Performance optimization strategies for AWS Lambda:
- Cold start optimization
- Memory configuration
- Connection pooling
- Monitoring and logging

## Directory Structure

```
resources/
├── docs/           # Documentation files
│   ├── *.md       # Markdown documentation
│   └── *.html     # HTML documentation
├── examples/       # Example code
│   └── *.bal      # Ballerina examples
└── templates/      # Templates
    └── *.template # Template files
```

## Caching Strategy

- **In-memory cache**: Fast access to frequently used resources
- **Configurable size**: Limit cache memory usage
- **Auto-invalidation**: Cache cleared on resource reload
- **TTL support**: Time-based cache expiration

## Error Handling

The loader provides comprehensive error handling for:
- Missing resources
- File access errors
- Invalid URIs
- Content loading failures

## Performance Considerations

- Lazy loading of resource content
- Efficient caching mechanism
- Minimal memory footprint
- Background auto-reload

## Extensibility

Easy to extend with new resource types:
1. Add new URI scheme handler
2. Implement content loading logic
3. Register with the loader

## Dependencies

- `mcp_protocol` - Core MCP protocol types
- Ballerina standard library modules (io, file, log, http, regex)