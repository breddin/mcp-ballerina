// MCP Integration for Code Analysis Tools
// Provides MCP tool registration and integration for code analysis features

import mcp_ballerina.mcp_protocol;
import ballerina/log;
import ballerina/uuid;

// MCP Code Analysis Integration
public class MCPCodeAnalysisIntegration {
    private LSPAnalysisHandler lspHandler;
    private ASTParser parser;
    private SemanticAnalyzer analyzer;
    private mcp_protocol:McpServer mcpServer;
    private map<string> registeredTools = {};
    
    public function init(mcp_protocol:McpServer mcpServer) {
        self.mcpServer = mcpServer;
        self.lspHandler = new LSPAnalysisHandler();
        self.parser = new ASTParser();
        self.analyzer = new SemanticAnalyzer();
        
        // Register MCP tools
        self.registerTools();
        
        log:printInfo("MCP Code Analysis Integration initialized");
    }
    
    // Register all code analysis tools with MCP
    private function registerTools() {
        // AST Parsing tool
        self.registerTool("mcp__ballerina__parse_ast", {
            "name": "mcp__ballerina__parse_ast",
            "description": "Parse Ballerina code and generate AST",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "code": {
                        "type": "string",
                        "description": "Ballerina source code to parse"
                    },
                    "fileName": {
                        "type": "string",
                        "description": "Optional file name for context"
                    }
                },
                "required": ["code"]
            }
        });
        
        // Semantic Analysis tool
        self.registerTool("mcp__ballerina__analyze_semantics", {
            "name": "mcp__ballerina__analyze_semantics",
            "description": "Perform semantic analysis on Ballerina code",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "code": {
                        "type": "string",
                        "description": "Ballerina source code to analyze"
                    },
                    "includeWarnings": {
                        "type": "boolean",
                        "description": "Include warnings in results",
                        "default": true
                    }
                },
                "required": ["code"]
            }
        });
        
        // Symbol Extraction tool
        self.registerTool("mcp__ballerina__extract_symbols", {
            "name": "mcp__ballerina__extract_symbols",
            "description": "Extract symbols from Ballerina code",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "code": {
                        "type": "string",
                        "description": "Ballerina source code"
                    },
                    "symbolType": {
                        "type": "string",
                        "enum": ["all", "functions", "types", "variables", "classes"],
                        "description": "Type of symbols to extract",
                        "default": "all"
                    }
                },
                "required": ["code"]
            }
        });
        
        // Code Completion tool
        self.registerTool("mcp__ballerina__complete", {
            "name": "mcp__ballerina__complete",
            "description": "Get code completions at a specific position",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "uri": {
                        "type": "string",
                        "description": "Document URI"
                    },
                    "line": {
                        "type": "integer",
                        "description": "Line number (0-based)"
                    },
                    "character": {
                        "type": "integer",
                        "description": "Character position (0-based)"
                    },
                    "code": {
                        "type": "string",
                        "description": "Current document content"
                    }
                },
                "required": ["uri", "line", "character", "code"]
            }
        });
        
        // Hover Information tool
        self.registerTool("mcp__ballerina__hover", {
            "name": "mcp__ballerina__hover",
            "description": "Get hover information at a specific position",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "uri": {
                        "type": "string",
                        "description": "Document URI"
                    },
                    "line": {
                        "type": "integer",
                        "description": "Line number (0-based)"
                    },
                    "character": {
                        "type": "integer",
                        "description": "Character position (0-based)"
                    },
                    "code": {
                        "type": "string",
                        "description": "Current document content"
                    }
                },
                "required": ["uri", "line", "character", "code"]
            }
        });
        
        // Go to Definition tool
        self.registerTool("mcp__ballerina__definition", {
            "name": "mcp__ballerina__definition",
            "description": "Find definition of symbol at position",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "uri": {
                        "type": "string",
                        "description": "Document URI"
                    },
                    "line": {
                        "type": "integer",
                        "description": "Line number (0-based)"
                    },
                    "character": {
                        "type": "integer",
                        "description": "Character position (0-based)"
                    },
                    "code": {
                        "type": "string",
                        "description": "Current document content"
                    }
                },
                "required": ["uri", "line", "character", "code"]
            }
        });
        
        // Find References tool
        self.registerTool("mcp__ballerina__references", {
            "name": "mcp__ballerina__references",
            "description": "Find all references to symbol at position",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "uri": {
                        "type": "string",
                        "description": "Document URI"
                    },
                    "line": {
                        "type": "integer",
                        "description": "Line number (0-based)"
                    },
                    "character": {
                        "type": "integer",
                        "description": "Character position (0-based)"
                    },
                    "code": {
                        "type": "string",
                        "description": "Current document content"
                    }
                },
                "required": ["uri", "line", "character", "code"]
            }
        });
        
        // Document Symbols tool
        self.registerTool("mcp__ballerina__document_symbols", {
            "name": "mcp__ballerina__document_symbols",
            "description": "Get all symbols in a document",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "uri": {
                        "type": "string",
                        "description": "Document URI"
                    },
                    "code": {
                        "type": "string",
                        "description": "Document content"
                    }
                },
                "required": ["uri", "code"]
            }
        });
        
        // Diagnostics tool
        self.registerTool("mcp__ballerina__diagnostics", {
            "name": "mcp__ballerina__diagnostics",
            "description": "Get diagnostics for Ballerina code",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "code": {
                        "type": "string",
                        "description": "Ballerina source code to check"
                    },
                    "uri": {
                        "type": "string",
                        "description": "Document URI for context"
                    },
                    "severity": {
                        "type": "string",
                        "enum": ["error", "warning", "info", "all"],
                        "description": "Minimum severity level",
                        "default": "all"
                    }
                },
                "required": ["code"]
            }
        });
        
        // Format Document tool
        self.registerTool("mcp__ballerina__format", {
            "name": "mcp__ballerina__format",
            "description": "Format Ballerina code",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "code": {
                        "type": "string",
                        "description": "Ballerina code to format"
                    },
                    "tabSize": {
                        "type": "integer",
                        "description": "Tab size for formatting",
                        "default": 4
                    },
                    "insertSpaces": {
                        "type": "boolean",
                        "description": "Use spaces instead of tabs",
                        "default": true
                    }
                },
                "required": ["code"]
            }
        });
        
        // Rename Symbol tool
        self.registerTool("mcp__ballerina__rename", {
            "name": "mcp__ballerina__rename",
            "description": "Rename a symbol across the document",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "uri": {
                        "type": "string",
                        "description": "Document URI"
                    },
                    "line": {
                        "type": "integer",
                        "description": "Line number of symbol"
                    },
                    "character": {
                        "type": "integer",
                        "description": "Character position of symbol"
                    },
                    "newName": {
                        "type": "string",
                        "description": "New name for the symbol"
                    },
                    "code": {
                        "type": "string",
                        "description": "Current document content"
                    }
                },
                "required": ["uri", "line", "character", "newName", "code"]
            }
        });
        
        // Type Check tool
        self.registerTool("mcp__ballerina__type_check", {
            "name": "mcp__ballerina__type_check",
            "description": "Perform type checking on Ballerina code",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "code": {
                        "type": "string",
                        "description": "Ballerina code to type check"
                    },
                    "strict": {
                        "type": "boolean",
                        "description": "Use strict type checking",
                        "default": false
                    }
                },
                "required": ["code"]
            }
        });
    }
    
    // Register a single tool
    private function registerTool(string name, json toolDefinition) {
        // Register with MCP server
        check self.mcpServer.registerTool(toolDefinition);
        self.registeredTools[name] = name;
        log:printDebug("Registered tool: " + name);
    }
    
    // Handle tool execution
    public function executeTool(string toolName, json params) returns json|error {
        match toolName {
            "mcp__ballerina__parse_ast" => {
                return self.handleParseAST(params);
            }
            "mcp__ballerina__analyze_semantics" => {
                return self.handleAnalyzeSemantics(params);
            }
            "mcp__ballerina__extract_symbols" => {
                return self.handleExtractSymbols(params);
            }
            "mcp__ballerina__complete" => {
                return self.handleCompletion(params);
            }
            "mcp__ballerina__hover" => {
                return self.handleHover(params);
            }
            "mcp__ballerina__definition" => {
                return self.handleDefinition(params);
            }
            "mcp__ballerina__references" => {
                return self.handleReferences(params);
            }
            "mcp__ballerina__document_symbols" => {
                return self.handleDocumentSymbols(params);
            }
            "mcp__ballerina__diagnostics" => {
                return self.handleDiagnostics(params);
            }
            "mcp__ballerina__format" => {
                return self.handleFormat(params);
            }
            "mcp__ballerina__rename" => {
                return self.handleRename(params);
            }
            "mcp__ballerina__type_check" => {
                return self.handleTypeCheck(params);
            }
            _ => {
                return error("Unknown tool: " + toolName);
            }
        }
    }
    
    // Tool handlers
    
    private function handleParseAST(json params) returns json|error {
        string code = check params.code;
        string? fileName = params.fileName;
        
        ParseResult result = self.parser.parse(code, fileName);
        
        return {
            "success": result.success,
            "ast": self.serializeAST(result.root),
            "diagnostics": self.serializeDiagnostics(result.diagnostics),
            "metadata": result.metadata
        };
    }
    
    private function handleAnalyzeSemantics(json params) returns json|error {
        string code = check params.code;
        boolean includeWarnings = check params.includeWarnings;
        
        // Parse first
        ParseResult parseResult = self.parser.parse(code);
        
        if parseResult.root is ASTNode {
            SemanticContext context = self.analyzer.analyze(parseResult.root);
            
            json response = {
                "errors": self.serializeSemanticErrors(context.errors),
                "symbols": self.serializeSymbols(context)
            };
            
            if includeWarnings {
                response["warnings"] = self.serializeSemanticWarnings(context.warnings);
            }
            
            return response;
        }
        
        return error("Failed to parse code for semantic analysis");
    }
    
    private function handleExtractSymbols(json params) returns json|error {
        string code = check params.code;
        string symbolType = check params.symbolType;
        
        ParseResult parseResult = self.parser.parse(code);
        
        if parseResult.root is ASTNode {
            SemanticContext context = self.analyzer.analyze(parseResult.root);
            map<SymbolInfo> allSymbols = self.analyzer.getSymbols();
            
            json[] symbols = [];
            foreach [string, SymbolInfo] [name, symbol] in allSymbols.entries() {
                if symbolType == "all" || symbol.kind == symbolType {
                    symbols.push({
                        "name": name,
                        "kind": symbol.kind,
                        "type": symbol.type,
                        "exported": symbol.exported,
                        "modifiers": symbol.modifiers,
                        "documentation": symbol.documentation
                    });
                }
            }
            
            return {
                "symbols": symbols,
                "count": symbols.length()
            };
        }
        
        return error("Failed to parse code for symbol extraction");
    }
    
    private function handleCompletion(json params) returns json|error {
        // Prepare parameters for LSP handler
        json lspParams = {
            "textDocument": {
                "uri": check params.uri
            },
            "position": {
                "line": check params.line,
                "character": check params.character
            }
        };
        
        // Update document cache with current content
        string code = check params.code;
        string uri = check params.uri;
        self.updateDocumentCache(uri, code);
        
        return self.lspHandler.handleCompletion(lspParams);
    }
    
    private function handleHover(json params) returns json|error {
        json lspParams = {
            "textDocument": {
                "uri": check params.uri
            },
            "position": {
                "line": check params.line,
                "character": check params.character
            }
        };
        
        string code = check params.code;
        string uri = check params.uri;
        self.updateDocumentCache(uri, code);
        
        return self.lspHandler.handleHover(lspParams);
    }
    
    private function handleDefinition(json params) returns json|error {
        json lspParams = {
            "textDocument": {
                "uri": check params.uri
            },
            "position": {
                "line": check params.line,
                "character": check params.character
            }
        };
        
        string code = check params.code;
        string uri = check params.uri;
        self.updateDocumentCache(uri, code);
        
        return self.lspHandler.handleDefinition(lspParams);
    }
    
    private function handleReferences(json params) returns json|error {
        json lspParams = {
            "textDocument": {
                "uri": check params.uri
            },
            "position": {
                "line": check params.line,
                "character": check params.character
            }
        };
        
        string code = check params.code;
        string uri = check params.uri;
        self.updateDocumentCache(uri, code);
        
        return self.lspHandler.handleReferences(lspParams);
    }
    
    private function handleDocumentSymbols(json params) returns json|error {
        json lspParams = {
            "textDocument": {
                "uri": check params.uri
            }
        };
        
        string code = check params.code;
        string uri = check params.uri;
        self.updateDocumentCache(uri, code);
        
        return self.lspHandler.handleDocumentSymbol(lspParams);
    }
    
    private function handleDiagnostics(json params) returns json|error {
        string code = check params.code;
        string? uri = params.uri;
        string severity = check params.severity;
        
        ParseResult parseResult = self.parser.parse(code, uri);
        
        json[] diagnostics = [];
        
        // Add parse diagnostics
        foreach Diagnostic diag in parseResult.diagnostics {
            if self.matchesSeverity(diag.severity, severity) {
                diagnostics.push(self.serializeDiagnostic(diag));
            }
        }
        
        // Add semantic diagnostics
        if parseResult.root is ASTNode {
            SemanticContext context = self.analyzer.analyze(parseResult.root);
            
            foreach SemanticError err in context.errors {
                if severity == "all" || severity == "error" {
                    diagnostics.push({
                        "severity": "error",
                        "message": err.message,
                        "code": err.code,
                        "position": err.position,
                        "hint": err.hint
                    });
                }
            }
            
            foreach SemanticWarning warn in context.warnings {
                if severity == "all" || severity == "warning" {
                    diagnostics.push({
                        "severity": "warning",
                        "message": warn.message,
                        "code": warn.code,
                        "position": warn.position
                    });
                }
            }
        }
        
        return {
            "diagnostics": diagnostics,
            "count": diagnostics.length()
        };
    }
    
    private function handleFormat(json params) returns json|error {
        json lspParams = {
            "textDocument": {
                "uri": "temp://format"
            },
            "options": {
                "tabSize": check params.tabSize,
                "insertSpaces": check params.insertSpaces
            }
        };
        
        string code = check params.code;
        self.updateDocumentCache("temp://format", code);
        
        json edits = self.lspHandler.handleFormatting(lspParams);
        
        // Apply edits to code and return formatted version
        return {
            "formattedCode": self.applyEdits(code, edits),
            "edits": edits
        };
    }
    
    private function handleRename(json params) returns json|error {
        json lspParams = {
            "textDocument": {
                "uri": check params.uri
            },
            "position": {
                "line": check params.line,
                "character": check params.character
            },
            "newName": check params.newName
        };
        
        string code = check params.code;
        string uri = check params.uri;
        self.updateDocumentCache(uri, code);
        
        return self.lspHandler.handleRename(lspParams);
    }
    
    private function handleTypeCheck(json params) returns json|error {
        string code = check params.code;
        boolean strict = check params.strict;
        
        ParseResult parseResult = self.parser.parse(code);
        
        if parseResult.root is ASTNode {
            SemanticContext context = self.analyzer.analyze(parseResult.root);
            
            json[] typeErrors = [];
            foreach SemanticError err in context.errors {
                if err.code.startsWith("T") { // Type errors
                    typeErrors.push({
                        "message": err.message,
                        "position": err.position,
                        "code": err.code
                    });
                }
            }
            
            return {
                "success": typeErrors.length() == 0,
                "errors": typeErrors,
                "typeInfo": self.extractTypeInfo(context)
            };
        }
        
        return error("Failed to parse code for type checking");
    }
    
    // Helper functions
    
    private function updateDocumentCache(string uri, string code) {
        json params = {
            "textDocument": {
                "uri": uri,
                "text": code
            }
        };
        
        _ = self.lspHandler.handleDidOpen(params);
    }
    
    private function serializeAST(ASTNode? node) returns json? {
        if node is () {
            return ();
        }
        
        json[] children = [];
        foreach ASTNode child in node.children {
            json? serializedChild = self.serializeAST(child);
            if serializedChild is json {
                children.push(serializedChild);
            }
        }
        
        return {
            "id": node.id,
            "type": node.nodeType,
            "name": node.name,
            "range": node.range,
            "children": children,
            "metadata": node.metadata,
            "symbol": node.symbol
        };
    }
    
    private function serializeDiagnostics(Diagnostic[] diagnostics) returns json[] {
        json[] result = [];
        foreach Diagnostic diag in diagnostics {
            result.push(self.serializeDiagnostic(diag));
        }
        return result;
    }
    
    private function serializeDiagnostic(Diagnostic diag) returns json {
        return {
            "severity": self.getSeverityString(diag.severity),
            "range": diag.range,
            "message": diag.message,
            "code": diag.code,
            "source": diag.source,
            "tags": diag.tags
        };
    }
    
    private function getSeverityString(DiagnosticSeverity severity) returns string {
        match severity {
            ERROR => { return "error"; }
            WARNING => { return "warning"; }
            INFORMATION => { return "info"; }
            HINT => { return "hint"; }
        }
    }
    
    private function matchesSeverity(DiagnosticSeverity diagSeverity, string filterSeverity) returns boolean {
        if filterSeverity == "all" {
            return true;
        }
        
        string diagSevStr = self.getSeverityString(diagSeverity);
        return diagSevStr == filterSeverity;
    }
    
    private function serializeSemanticErrors(SemanticError[] errors) returns json[] {
        json[] result = [];
        foreach SemanticError err in errors {
            result.push({
                "message": err.message,
                "position": err.position,
                "code": err.code,
                "hint": err.hint
            });
        }
        return result;
    }
    
    private function serializeSemanticWarnings(SemanticWarning[] warnings) returns json[] {
        json[] result = [];
        foreach SemanticWarning warn in warnings {
            result.push({
                "message": warn.message,
                "position": warn.position,
                "code": warn.code
            });
        }
        return result;
    }
    
    private function serializeSymbols(SemanticContext context) returns json {
        json functions = [];
        json types = [];
        json variables = [];
        
        foreach [string, FunctionInfo] [name, func] in context.functionTable.entries() {
            functions.push({
                "name": name,
                "returnType": func.returnType.name,
                "parameters": func.parameters,
                "exported": func.exported
            });
        }
        
        foreach [string, TypeInfo] [name, typeInfo] in context.typeTable.entries() {
            types.push({
                "name": name,
                "kind": typeInfo.kind.toString(),
                "nullable": typeInfo.nullable,
                "readonly": typeInfo.readonly
            });
        }
        
        foreach [string, VariableInfo] [name, varInfo] in context.variableTable.entries() {
            variables.push({
                "name": varInfo.name,
                "type": varInfo.type.name,
                "scope": varInfo.scope,
                "mutable": varInfo.mutable,
                "initialized": varInfo.initialized
            });
        }
        
        return {
            "functions": functions,
            "types": types,
            "variables": variables
        };
    }
    
    private function applyEdits(string code, json edits) returns string {
        // Simple implementation - would need proper text edit application
        return code;
    }
    
    private function extractTypeInfo(SemanticContext context) returns json {
        return {
            "typeCount": context.typeTable.length(),
            "functionCount": context.functionTable.length(),
            "variableCount": context.variableTable.length()
        };
    }
}