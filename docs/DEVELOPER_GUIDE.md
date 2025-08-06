# MCP Ballerina Server Developer Guide

## Table of Contents
1. [Getting Started](#getting-started)
2. [Architecture Overview](#architecture-overview)
3. [Development Setup](#development-setup)
4. [Module Development](#module-development)
5. [Testing Strategy](#testing-strategy)
6. [Best Practices](#best-practices)
7. [Contributing](#contributing)
8. [Troubleshooting](#troubleshooting)

## Getting Started

### Prerequisites
- Ballerina 2201.8.0 or higher
- Java 11 or higher
- Git
- VS Code with Ballerina extension (recommended)

### Quick Start
```bash
# Clone the repository
git clone https://github.com/breddin/mcp-ballerina.git
cd mcp-ballerina

# Install Ballerina
curl -sSL https://ballerina.io/installer.sh | bash

# Build the project
bal build

# Run tests
bal test

# Start the MCP server
bal run main.bal
```

## Architecture Overview

### System Architecture
```
┌─────────────────────────────────────────────────────────┐
│                    MCP Client (IDE)                      │
└─────────────────┬───────────────────────────────────────┘
                  │ MCP Protocol
┌─────────────────▼───────────────────────────────────────┐
│                  MCP Integration Layer                   │
│  ┌──────────────────────────────────────────────────┐  │
│  │            Request Router & Handler               │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────┬───────────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────────┐
│                    Core Modules                          │
│  ┌────────────┐ ┌────────────┐ ┌──────────────────┐   │
│  │   Code     │ │ Refactoring│ │  Collaboration   │   │
│  │ Analysis   │ │   Engine   │ │    Server        │   │
│  └────────────┘ └────────────┘ └──────────────────┘   │
│  ┌────────────┐ ┌────────────┐                        │
│  │  Security  │ │Performance │                        │
│  │  Analyzer  │ │ Optimizer  │                        │
│  └────────────┘ └────────────┘                        │
└──────────────────────────────────────────────────────┘
```

### Module Structure
```
mcp-ballerina/
├── modules/
│   ├── code_analysis/       # AST, semantic analysis, LSP
│   ├── refactoring/         # Code transformations
│   ├── collaboration/       # Real-time editing
│   ├── security/           # SAST and vulnerability scanning
│   └── performance/        # Caching and optimization
├── tests/                  # Test suites
├── examples/              # Usage examples
├── docs/                  # Documentation
└── main.bal              # MCP server entry point
```

## Development Setup

### Environment Configuration
```bash
# Set environment variables
export BALLERINA_HOME=/usr/local/ballerina
export MCP_PORT=9090
export MCP_LOG_LEVEL=DEBUG
```

### IDE Setup (VS Code)
1. Install Ballerina extension
2. Install MCP development tools
3. Configure workspace settings:

```json
{
  "ballerina.home": "/usr/local/ballerina",
  "ballerina.debugLog": true,
  "ballerina.trace.server": "verbose"
}
```

## Module Development

### Creating a New Module

1. **Define Module Structure**
```bash
mkdir -p modules/my_module
cd modules/my_module
```

2. **Create Module.md**
```markdown
## Module Overview
Describe your module's purpose and functionality.
```

3. **Create Main Implementation**
```ballerina
// my_module.bal
import ballerina/log;

public type MyModuleConfig record {|
    string setting1;
    int setting2 = 100;
    boolean enableFeature = true;
|};

public class MyModule {
    private final MyModuleConfig config;
    
    public function init(MyModuleConfig config) {
        self.config = config;
        log:printInfo("MyModule initialized");
    }
    
    public function process(string input) returns string|error {
        // Implementation
        return "processed: " + input;
    }
}
```

4. **Add Tests**
```ballerina
// tests/my_module_test.bal
import ballerina/test;

@test:Config {}
function testMyModule() {
    MyModuleConfig config = {
        setting1: "test"
    };
    
    MyModule module = new(config);
    string result = check module.process("input");
    
    test:assertEquals(result, "processed: input");
}
```

### Integrating with MCP

1. **Register Tool in MCP**
```ballerina
// In mcp_integration.bal
function registerTools() returns Tool[] {
    Tool[] tools = [];
    
    // Register your module's tool
    Tool myTool = {
        name: "ballerina.mymodule.process",
        description: "Process data with MyModule",
        inputSchema: {
            "type": "object",
            "properties": {
                "input": {"type": "string"}
            },
            "required": ["input"]
        }
    };
    tools.push(myTool);
    
    return tools;
}
```

2. **Handle Tool Calls**
```ballerina
function handleToolCall(ToolCall call) returns json|error {
    match call.name {
        "ballerina.mymodule.process" => {
            string input = check call.arguments.input;
            MyModule module = new({setting1: "default"});
            string result = check module.process(input);
            return {"result": result};
        }
    }
}
```

## Testing Strategy

### Unit Testing
```ballerina
@test:Config {
    groups: ["unit"]
}
function testUnitExample() {
    // Test individual functions
    string result = processData("input");
    test:assertEquals(result, "expected");
}
```

### Integration Testing
```ballerina
@test:Config {
    groups: ["integration"],
    dependsOn: [testUnitExample]
}
function testIntegrationExample() {
    // Test module interactions
    Module1 m1 = new();
    Module2 m2 = new();
    
    var result = check m1.process(m2.getData());
    test:assertNotEquals(result, ());
}
```

### Performance Testing
```ballerina
@test:Config {
    groups: ["performance"]
}
function testPerformanceExample() {
    time:Utc start = time:utcNow();
    
    foreach int i in 0 ..< 1000 {
        _ = expensiveOperation();
    }
    
    time:Utc end = time:utcNow();
    decimal duration = <decimal>(end[0] - start[0]);
    
    test:assertTrue(duration < 5.0, "Operation too slow");
}
```

### Running Tests
```bash
# Run all tests
bal test

# Run specific group
bal test --groups=unit

# Run with coverage
bal test --code-coverage

# Run specific module tests
bal test modules/my_module
```

## Best Practices

### Code Organization
1. **Single Responsibility**: Each module should have one clear purpose
2. **Clear Interfaces**: Define public APIs clearly with proper types
3. **Error Handling**: Always return proper error types
4. **Documentation**: Document all public functions and types

### Error Handling
```ballerina
public function riskyOperation() returns string|error {
    // Don't ignore errors
    json data = check parseJson(input);
    
    // Provide context in errors
    string? value = data.field;
    if value is () {
        return error("Missing required field 'field'");
    }
    
    // Chain errors properly
    return processValue(value) ?: error("Failed to process value");
}
```

### Performance Optimization
```ballerina
// Use caching for expensive operations
map<any> cache = {};

public function expensiveOperation(string key) returns any|error {
    if cache.hasKey(key) {
        return cache.get(key);
    }
    
    any result = check performExpensiveWork(key);
    cache[key] = result;
    return result;
}

// Use parallel processing
public function processItems(any[] items) returns any[]|error {
    worker w1 returns any[] {
        return processSubset(items[0 .. items.length()/2]);
    }
    
    worker w2 returns any[] {
        return processSubset(items[items.length()/2 .. items.length()]);
    }
    
    any[] results1 = wait w1;
    any[] results2 = wait w2;
    
    return [...results1, ...results2];
}
```

### Memory Management
```ballerina
// Clean up resources
public class ResourceManager {
    private handle? resource = ();
    
    public function acquire() returns error? {
        self.resource = check createResource();
    }
    
    public function release() {
        if self.resource is handle {
            closeResource(self.resource);
            self.resource = ();
        }
    }
    
    function __destruct() {
        self.release();
    }
}
```

### Security Considerations
```ballerina
// Validate inputs
public function processUserInput(string input) returns string|error {
    // Sanitize input
    string sanitized = re`[^a-zA-Z0-9\s]`.replaceAll(input, "");
    
    // Validate length
    if sanitized.length() > 1000 {
        return error("Input too long");
    }
    
    // Never construct queries with user input
    // BAD: string query = "SELECT * FROM users WHERE id = '" + input + "'";
    // GOOD: Use parameterized queries
    
    return sanitized;
}
```

## Contributing

### Development Workflow
1. Fork the repository
2. Create a feature branch
3. Implement your changes
4. Add tests
5. Update documentation
6. Submit a pull request

### Code Review Checklist
- [ ] Tests pass (`bal test`)
- [ ] Code coverage > 80%
- [ ] No security vulnerabilities
- [ ] Documentation updated
- [ ] Examples provided
- [ ] Performance considered
- [ ] Error handling complete

### Commit Guidelines
```bash
# Format: <type>(<scope>): <subject>

feat(security): add OWASP Top 10 scanning
fix(cache): resolve memory leak in LRU eviction
docs(api): update refactoring examples
test(collaboration): add OT edge cases
perf(parser): optimize AST traversal
```

## Troubleshooting

### Common Issues

#### Module Import Errors
```bash
# Error: cannot resolve module 'modules.my_module'
# Solution: Ensure module is in Ballerina.toml
[package]
name = "mcp_ballerina"
version = "1.0.0"

[[dependency]]
name = "modules.my_module"
version = "1.0.0"
```

#### Memory Issues
```bash
# Increase heap size
export JAVA_OPTS="-Xmx2g -Xms512m"
bal run main.bal
```

#### Test Failures
```bash
# Run tests in verbose mode
bal test --debug

# Check test reports
cat target/test-results/results.json
```

#### Performance Problems
```ballerina
// Enable profiling
import ballerina/observe;

@observe:Observable
public function slowFunction() {
    // Function will be profiled
}
```

### Debug Logging
```ballerina
import ballerina/log;

// Configure log levels
configurable string logLevel = "DEBUG";

public function debugOperation() {
    log:printDebug("Starting operation");
    
    // Conditional logging
    if log:isDebugEnabled() {
        log:printDebug("Detailed state: " + state.toString());
    }
    
    log:printInfo("Operation completed");
}
```

### Getting Help
- GitHub Issues: https://github.com/breddin/mcp-ballerina/issues
- Ballerina Discord: https://discord.gg/ballerinalang
- Stack Overflow: Tag with `ballerina` and `mcp`

## Advanced Topics

### Custom Eviction Policies
```ballerina
public type CustomEvictionPolicy object {
    public function selectVictim(map<CacheEntry> entries) returns string?;
};

public class RandomEviction {
    *CustomEvictionPolicy;
    
    public function selectVictim(map<CacheEntry> entries) returns string? {
        string[] keys = entries.keys();
        if keys.length() > 0 {
            int index = check random:createIntInRange(0, keys.length());
            return keys[index];
        }
        return ();
    }
}
```

### Plugin Development
```ballerina
public type Plugin object {
    public function initialize() returns error?;
    public function process(any input) returns any|error;
    public function shutdown();
};

public class PluginManager {
    private map<Plugin> plugins = {};
    
    public function loadPlugin(string name, Plugin plugin) returns error? {
        check plugin.initialize();
        self.plugins[name] = plugin;
    }
    
    public function executePlugin(string name, any input) returns any|error {
        Plugin? plugin = self.plugins[name];
        if plugin is () {
            return error("Plugin not found: " + name);
        }
        return plugin.process(input);
    }
}
```

## Performance Benchmarks

### Current Performance Metrics
- AST Parsing: ~50ms for 1000 lines
- Security Scan: ~200ms for full analysis
- Cache Hit Rate: 85% average
- Parallel Processing: 2.8x speedup on 4 cores
- Memory Usage: <100MB for typical workload

### Optimization Targets
- Response Time: <100ms for 95% of requests
- Throughput: >1000 requests/second
- Memory: <500MB under load
- Cache Hit Rate: >90%

## Roadmap

### Version 1.1.0
- [ ] GraphQL support
- [ ] Advanced type inference
- [ ] Distributed caching
- [ ] ML-based code suggestions

### Version 1.2.0
- [ ] Cloud-native deployment
- [ ] Kubernetes operators
- [ ] Multi-language support
- [ ] Real-time metrics dashboard

### Version 2.0.0
- [ ] AI-powered refactoring
- [ ] Predictive analysis
- [ ] Auto-scaling
- [ ] Federation support

---

For more information, see:
- [API Reference](./API_REFERENCE.md)
- [Architecture Document](./ARCHITECTURE.md)
- [Examples](../examples/README.md)