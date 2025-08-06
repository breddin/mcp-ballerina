# Ballerina MCP Tools Module

This module provides the actual tool execution implementation for the Ballerina MCP server.

## Features

- **Tool Execution**: Execute all registered MCP tools with proper argument validation
- **LSP Integration**: Leverage Language Server Protocol for advanced features
- **CLI Wrapper**: Direct integration with Ballerina CLI commands
- **Result Caching**: Cache tool execution results for improved performance
- **Error Handling**: Comprehensive error handling and reporting

## Available Tools

### Project Management
- `mcp__ballerina__project_new` - Create new Ballerina projects
- `mcp__ballerina__project_build` - Build projects with various options
- `mcp__ballerina__project_test` - Run tests with coverage support
- `mcp__ballerina__project_run` - Execute Ballerina programs

### Code Intelligence
- `mcp__ballerina__syntax_check` - Validate Ballerina syntax
- `mcp__ballerina__complete` - Get code completion suggestions
- `mcp__ballerina__hover` - Get hover information
- `mcp__ballerina__definition` - Go to definition
- `mcp__ballerina__format` - Format Ballerina code

### Package Management
- `mcp__ballerina__package_info` - Get package information from Ballerina Central

### Cloud Deployment
- `mcp__ballerina__deploy_lambda` - Generate AWS Lambda deployment configuration

## Usage

```ballerina
import mcp_ballerina.tools;

public function main() {
    tools:ToolExecutor executor = new();
    
    // Execute syntax check
    tools:ExecutionResult result = check executor.execute(
        "mcp__ballerina__syntax_check",
        {
            code: "import ballerina/io;\n\npublic function main() {\n    io:println(\"Hello\");\n}"
        }
    );
    
    if result.success {
        io:println("Syntax is valid!");
    } else {
        io:println("Syntax errors: ", result.content);
    }
}
```

## Configuration

```ballerina
tools:ExecutorConfig config = {
    ballerinaHome: "/usr/local/ballerina",
    javaHome: "/usr/lib/jvm/java-17",
    timeout: 30000,
    enableCache: true,
    cacheSize: 100,
    cacheTtl: 60000
};

tools:ToolExecutor executor = new(config);
```

## Tool Implementation Details

### Syntax Check
- Uses LSP for real-time diagnostics when available
- Falls back to CLI compilation check
- Returns detailed error messages and positions

### Code Completion
- Requires active LSP connection
- Provides context-aware suggestions
- Includes documentation snippets

### Project Build
- Supports offline mode
- Optional test skipping
- Code coverage generation
- Artifact discovery

### Project Test
- Group-based test execution
- Individual test selection
- Coverage report generation
- Detailed result parsing

## Error Handling

All tool executions return an `ExecutionResult` with:
- `success`: Boolean indicating success/failure
- `content`: Tool-specific result data
- `errorMessage`: Optional error description
- `exitCode`: Process exit code (for CLI tools)
- `duration`: Execution time in milliseconds

## Performance

- **Caching**: Results are cached based on tool and arguments
- **LSP Reuse**: Single LSP instance for all code intelligence tools
- **Process Management**: Proper cleanup of spawned processes
- **Timeout Protection**: Configurable timeouts for long-running operations

## Dependencies

- `mcp_protocol` - Core MCP protocol types
- `language_server` - LSP client and process management
- Ballerina standard library modules (io, os, file, log)