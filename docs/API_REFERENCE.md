# MCP Ballerina Server API Reference

## Table of Contents
1. [Code Analysis Module](#code-analysis-module)
2. [Refactoring Module](#refactoring-module)
3. [Collaboration Module](#collaboration-module)
4. [Security Module](#security-module)
5. [Performance Module](#performance-module)

---

## Code Analysis Module

### AST Parser

#### `ASTParser`
Parses Ballerina source code into an Abstract Syntax Tree.

```ballerina
import modules.code_analysis.ast_parser;

ast_parser:ASTParser parser = new();
ast_parser:ParseResult result = parser.parse(sourceCode, "example.bal");
```

**Methods:**
- `parse(string sourceCode, string? fileName)` - Parse source code
- `getSymbolAtPosition(Position position)` - Get symbol at cursor position
- `getSymbols()` - Get all symbols in document
- `getDiagnostics()` - Get parsing diagnostics

### Semantic Analyzer

#### `SemanticAnalyzer`
Performs semantic analysis including type checking and scope resolution.

```ballerina
import modules.code_analysis.semantic_analyzer;

semantic_analyzer:SemanticAnalyzer analyzer = new();
semantic_analyzer:SemanticContext context = analyzer.analyze(ast);
```

**Methods:**
- `analyze(ASTNode ast)` - Perform semantic analysis
- `getTypeInfo(string symbol)` - Get type information for symbol
- `checkTypes(ASTNode node)` - Type check AST node
- `resolveScope(string symbol)` - Resolve symbol scope

### LSP Handlers

#### `LSPHandler`
Implements Language Server Protocol handlers.

```ballerina
import modules.code_analysis.lsp_handlers;

lsp_handlers:LSPHandler handler = new();
json response = handler.handleRequest(request);
```

**Supported LSP Methods:**
- `textDocument/completion` - Code completion
- `textDocument/hover` - Hover information
- `textDocument/definition` - Go to definition
- `textDocument/references` - Find references
- `textDocument/documentSymbol` - Document symbols
- `textDocument/codeAction` - Code actions

---

## Refactoring Module

### Refactor Engine

#### `RefactorEngine`
Performs automated code refactoring operations.

```ballerina
import modules.refactoring.refactor_engine;

refactor_engine:RefactorEngine engine = new();
refactor_engine:RefactorRequest request = {
    type: refactor_engine:EXTRACT_METHOD,
    sourceCode: code,
    selection: range,
    parameters: {"methodName": "extracted"}
};
refactor_engine:RefactorResult result = check engine.refactor(request);
```

**Refactoring Types:**
- `EXTRACT_METHOD` - Extract selected code into method
- `INLINE_VARIABLE` - Inline variable at usage sites
- `INLINE_FUNCTION` - Inline function at call sites
- `RENAME_SYMBOL` - Rename with dependency tracking
- `MOVE_DECLARATION` - Move to different scope
- `CHANGE_SIGNATURE` - Modify function signature

### Template Manager

#### `TemplateManager`
Generates code from templates.

```ballerina
import modules.refactoring.code_templates;

code_templates:TemplateManager manager = new();
code_templates:GenerationRequest request = {
    templateType: code_templates:SERVICE,
    templateName: "rest_service",
    variables: {
        "serviceName": "UserAPI",
        "port": "9090"
    }
};
code_templates:GenerationResult result = check manager.generate(request);
```

**Template Types:**
- `FUNCTION` - Function templates
- `CLASS` - Class templates
- `SERVICE` - Service templates (REST, gRPC, WebSocket)
- `RECORD` - Record type templates
- `TEST` - Test templates
- `DATABASE_QUERY` - Database query templates

### Quick Fix Provider

#### `QuickFixProvider`
Provides automated fixes for common issues.

```ballerina
import modules.refactoring.quick_fixes;

quick_fixes:QuickFixProvider provider = new();
quick_fixes:QuickFix[] fixes = provider.getQuickFixes(sourceCode, diagnostics);
```

**Fix Types:**
- `ADD_MISSING_IMPORT` - Add missing import
- `FIX_TYPE_MISMATCH` - Fix type mismatches
- `ADD_ERROR_HANDLING` - Add error handling
- `REMOVE_UNUSED_IMPORT` - Remove unused imports
- `ADD_DOCUMENTATION` - Add documentation

---

## Collaboration Module

### WebSocket Server

#### `WebSocketCollaborationServer`
Real-time collaborative editing server.

```ballerina
import modules.collaboration.websocket_server;

websocket_server:ServerConfig config = {
    port: 8090,
    enableAuth: true,
    maxConnections: 100
};
websocket_server:WebSocketCollaborationServer server = new(config);
check server.start();
```

**Message Types:**
- `CONNECT` - Client connection
- `AUTHENTICATE` - Authentication
- `JOIN_DOCUMENT` - Join document session
- `TEXT_OPERATION` - Text edit operation
- `CURSOR_POSITION` - Cursor update
- `SELECTION_CHANGE` - Selection change

### Operational Transform Engine

#### `OperationalTransformEngine`
Implements OT algorithm for concurrent editing.

```ballerina
import modules.collaboration.ot_engine;

ot_engine:OperationalTransformEngine engine = new();
ot_engine:TransformResult result = engine.transform(op1, op2);
```

**Operations:**
- `insert` - Insert text
- `delete` - Delete text
- `format` - Format text
- `move` - Move text

### Presence Manager

#### `PresenceManager`
Manages user presence and activity.

```ballerina
import modules.collaboration.presence_manager;

presence_manager:PresenceManager manager = new();
presence_manager:UserPresence presence = check manager.addUser(
    documentId, userId, clientId
);
```

**Features:**
- User status tracking (online, idle, typing, away)
- Cursor position tracking
- Selection tracking
- Activity monitoring
- Color assignment

---

## Security Module

### Security Analyzer

#### `SecurityAnalyzer`
Static Application Security Testing (SAST) engine.

```ballerina
import modules.security.security_analyzer;

security_analyzer:ScanConfig config = {
    enableTaintAnalysis: true,
    enableCryptoAnalysis: true,
    minSeverity: security_analyzer:MEDIUM
};
security_analyzer:SecurityAnalyzer analyzer = new(config);
security_analyzer:ScanResult result = analyzer.scan(sourceCode, filePath);
```

**Security Rules:**
- SQL Injection detection
- Command Injection detection
- Path Traversal detection
- Weak Cryptography detection
- Hardcoded Secrets detection
- Missing Authentication detection

### Vulnerability Scanner

#### `VulnerabilityScanner`
Scans dependencies for known vulnerabilities.

```ballerina
import modules.security.vulnerability_scanner;

vulnerability_scanner:VulnerabilityScanConfig config = {
    checkCVE: true,
    checkGHSA: true,
    includeTransitive: true
};
vulnerability_scanner:VulnerabilityScanner scanner = new(config);
vulnerability_scanner:VulnerabilityScanResult result = check scanner.scanProject(projectPath);
```

**Features:**
- CVE database integration
- GitHub Security Advisory support
- OWASP Top 10 mapping
- Dependency tree analysis
- Version range matching

### Security Reporter

#### `SecurityReporter`
Generates security analysis reports.

```ballerina
import modules.security.security_reporter;

security_reporter:ReportConfig config = {
    format: security_reporter:MARKDOWN,
    includeRemediation: true,
    includeCompliance: true
};
security_reporter:SecurityReporter reporter = new(config);
security_reporter:SecurityReport report = check reporter.generateReport(scanResult);
check reporter.exportReport(report);
```

**Report Formats:**
- `HTML` - HTML reports
- `JSON` - JSON format
- `MARKDOWN` - Markdown format
- `SARIF` - SARIF format
- `XML` - XML format
- `PDF` - PDF reports

---

## Performance Module

### Cache Manager

#### `CacheManager`
Multi-level caching with eviction policies.

```ballerina
import modules.performance.cache_manager;

cache_manager:CacheConfig config = {
    maxSizeBytes: 104857600, // 100MB
    maxEntries: 10000,
    evictionPolicy: cache_manager:LRU
};
cache_manager:CacheManager cache = new(config);

// Store value
check cache.put("key", value, 3600);

// Retrieve value
any? cachedValue = cache.get("key");

// Get statistics
cache_manager:CacheStats stats = cache.getStats();
```

**Eviction Policies:**
- `LRU` - Least Recently Used
- `LFU` - Least Frequently Used
- `FIFO` - First In First Out
- `TTL` - Time To Live based

### Parallel Processor

#### `ParallelProcessor`
Concurrent task execution with worker pools.

```ballerina
import modules.performance.parallel_processor;

parallel_processor:WorkerPoolConfig config = {
    corePoolSize: 4,
    maxPoolSize: 10,
    queueCapacity: 100
};
parallel_processor:ParallelProcessor processor = new(config);

// Execute tasks in parallel
function()[] tasks = [task1, task2, task3];
parallel_processor:TaskResult[] results = check processor.executeParallel(tasks);

// Map operation
any[] items = [1, 2, 3, 4, 5];
any[] mapped = check processor.map(items, function(any item) returns any {
    return <int>item * 2;
});
```

**Execution Strategies:**
- `PARALLEL` - Execute all in parallel
- `SEQUENTIAL` - Execute sequentially
- `BATCH` - Execute in batches
- `PIPELINE` - Pipeline execution
- `MAP_REDUCE` - Map-reduce pattern

### Memory Optimizer

#### `MemoryOptimizer`
Memory pooling and garbage collection optimization.

```ballerina
import modules.performance.memory_optimizer;

memory_optimizer:MemoryPoolConfig config = {
    initialSize: 100,
    maxSize: 1000,
    gcThreshold: 80
};
memory_optimizer:MemoryOptimizer optimizer = new(config);

// Acquire object from pool
any obj = optimizer.acquire(string);

// Release object back to pool
optimizer.release(obj);

// Pre-allocate objects
optimizer.preallocate(string, 50);

// Get memory statistics
memory_optimizer:MemoryStats stats = optimizer.getStats();
```

**Features:**
- Object pooling
- Memory usage monitoring
- GC optimization
- Pre-allocation
- Lazy loading support

---

## MCP Protocol Integration

All modules expose their functionality through the Model Context Protocol (MCP).

### Registered Tools

The server registers the following MCP tools:

1. **Code Analysis Tools**
   - `ballerina.parse` - Parse Ballerina code
   - `ballerina.analyze` - Semantic analysis
   - `ballerina.symbols` - Get symbols
   - `ballerina.diagnostics` - Get diagnostics

2. **Refactoring Tools**
   - `ballerina.refactor.extract` - Extract method
   - `ballerina.refactor.inline` - Inline variable/function
   - `ballerina.refactor.rename` - Rename symbol
   - `ballerina.quickfix` - Get quick fixes

3. **Security Tools**
   - `ballerina.security.scan` - Security scan
   - `ballerina.security.vulnerabilities` - Scan dependencies
   - `ballerina.security.report` - Generate report

4. **Performance Tools**
   - `ballerina.cache.get` - Get from cache
   - `ballerina.cache.put` - Store in cache
   - `ballerina.parallel.execute` - Execute in parallel

### Usage Example

```typescript
// Using MCP client
const result = await mcpClient.callTool('ballerina.parse', {
    sourceCode: 'function main() { io:println("Hello"); }',
    fileName: 'example.bal'
});

const refactored = await mcpClient.callTool('ballerina.refactor.extract', {
    sourceCode: code,
    selection: { start: { line: 5, column: 0 }, end: { line: 10, column: 0 } },
    methodName: 'processData'
});
```

---

## Error Handling

All API methods follow consistent error handling:

```ballerina
// Success case
{
    "success": true,
    "result": <data>
}

// Error case
{
    "success": false,
    "error": {
        "code": "ERROR_CODE",
        "message": "Error description",
        "details": {}
    }
}
```

## Rate Limiting

API endpoints implement rate limiting:
- Default: 100 requests per minute
- Burst: 20 requests
- Headers: `X-RateLimit-Limit`, `X-RateLimit-Remaining`

## Authentication

WebSocket and security-sensitive operations require authentication:

```ballerina
// JWT authentication
{
    "type": "AUTHENTICATE",
    "payload": {
        "token": "eyJhbGciOiJIUzI1NiIs..."
    }
}
```

---

## Version Information

**Current Version:** 1.0.0  
**Ballerina Version:** 2201.8.0  
**MCP Protocol Version:** 1.0.0  
**Last Updated:** 2025-08-06