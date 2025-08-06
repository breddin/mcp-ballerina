# Ballerina Code Analysis Module

## Overview

The Code Analysis module provides comprehensive static analysis capabilities for Ballerina code, including AST parsing, semantic analysis, and LSP protocol support. This module integrates with the MCP server to expose code analysis features as tools accessible through the Model Context Protocol.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   MCP Integration Layer                 │
│                  (mcp_integration.bal)                  │
├─────────────────────────────────────────────────────────┤
│                    LSP Handler Layer                    │
│                   (lsp_handlers.bal)                    │
├─────────────────────────────────────────────────────────┤
│                  Semantic Analysis Layer                │
│                 (semantic_analyzer.bal)                 │
├─────────────────────────────────────────────────────────┤
│                    AST Parser Layer                     │
│                    (ast_parser.bal)                     │
└─────────────────────────────────────────────────────────┘
```

## Components

### 1. AST Parser (`ast_parser.bal`)

Provides syntax tree parsing and traversal capabilities:

- **Parse Ballerina code** into Abstract Syntax Tree (AST)
- **Extract symbols** (functions, types, variables, classes)
- **Generate diagnostics** for syntax errors
- **Track source positions** for all nodes
- **Build symbol table** for semantic analysis

Key Types:
- `ASTNode`: Represents a node in the syntax tree
- `SymbolInfo`: Contains symbol metadata
- `ParseResult`: Parsing result with AST and diagnostics
- `Diagnostic`: Syntax error/warning information

### 2. Semantic Analyzer (`semantic_analyzer.bal`)

Performs semantic analysis and type checking:

- **Type checking** and type inference
- **Scope management** with nested scopes
- **Symbol resolution** and cross-references
- **Semantic error detection**
- **Variable usage tracking**
- **Function signature analysis**

Key Types:
- `SemanticContext`: Analysis context with symbol tables
- `TypeInfo`: Type information and metadata
- `VariableInfo`: Variable declarations and usage
- `FunctionInfo`: Function signatures and metadata
- `Scope`: Scope hierarchy management

### 3. LSP Handlers (`lsp_handlers.bal`)

Implements Language Server Protocol message handlers:

- **Document synchronization** (didOpen, didChange)
- **Code completion** suggestions
- **Hover information** for symbols
- **Go to definition** navigation
- **Find references** across documents
- **Document symbols** outline
- **Diagnostics** reporting
- **Code formatting**
- **Symbol renaming**
- **Signature help**

### 4. MCP Integration (`mcp_integration.bal`)

Exposes code analysis features as MCP tools:

#### Available MCP Tools:

1. **`mcp__ballerina__parse_ast`**
   - Parse code and generate AST
   - Returns structured syntax tree

2. **`mcp__ballerina__analyze_semantics`**
   - Perform semantic analysis
   - Returns errors, warnings, and symbols

3. **`mcp__ballerina__extract_symbols`**
   - Extract symbols from code
   - Filter by type (functions, types, variables, classes)

4. **`mcp__ballerina__complete`**
   - Get code completions at position
   - Context-aware suggestions

5. **`mcp__ballerina__hover`**
   - Get hover information
   - Symbol documentation and types

6. **`mcp__ballerina__definition`**
   - Find symbol definition
   - Navigate to declaration

7. **`mcp__ballerina__references`**
   - Find all symbol references
   - Cross-file reference search

8. **`mcp__ballerina__document_symbols`**
   - Get document outline
   - Hierarchical symbol tree

9. **`mcp__ballerina__diagnostics`**
   - Get code diagnostics
   - Syntax and semantic errors

10. **`mcp__ballerina__format`**
    - Format code
    - Configurable formatting options

11. **`mcp__ballerina__rename`**
    - Rename symbols
    - Update all references

12. **`mcp__ballerina__type_check`**
    - Perform type checking
    - Type compatibility analysis

## Usage Examples

### Parse AST

```json
{
  "tool": "mcp__ballerina__parse_ast",
  "params": {
    "code": "function main() { io:println(\"Hello\"); }",
    "fileName": "example.bal"
  }
}
```

### Get Completions

```json
{
  "tool": "mcp__ballerina__complete",
  "params": {
    "uri": "file:///project/main.bal",
    "line": 10,
    "character": 15,
    "code": "// current file content"
  }
}
```

### Find Definition

```json
{
  "tool": "mcp__ballerina__definition",
  "params": {
    "uri": "file:///project/main.bal",
    "line": 5,
    "character": 20,
    "code": "// current file content"
  }
}
```

### Get Diagnostics

```json
{
  "tool": "mcp__ballerina__diagnostics",
  "params": {
    "code": "function test() { invalid syntax }",
    "severity": "error"
  }
}
```

## Features

### Syntax Analysis
- Full AST generation
- Symbol extraction
- Position tracking
- Error recovery

### Semantic Analysis
- Type checking
- Scope resolution
- Symbol validation
- Cross-reference checking

### Code Intelligence
- Intelligent completions
- Hover documentation
- Navigation features
- Reference finding

### Code Quality
- Diagnostics and errors
- Warning detection
- Code formatting
- Symbol renaming

## Integration

The module integrates seamlessly with:
- MCP protocol for tool exposure
- LSP protocol for IDE features
- Ballerina Language Server
- Claude Flow orchestration

## Performance

- Incremental parsing support
- Document caching
- Lazy semantic analysis
- Efficient symbol tables

## Future Enhancements

- Code actions and quick fixes
- Advanced refactoring
- Code generation
- Import optimization
- Dead code detection
- Complexity analysis
- Security scanning
- Performance profiling