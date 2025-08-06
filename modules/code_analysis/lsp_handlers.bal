// LSP Protocol Handlers for Ballerina Code Analysis
// Implements LSP message handlers for code analysis features

import ballerina/log;
import ballerina/regex;

// LSP Handler for code analysis features
public class LSPAnalysisHandler {
    private ASTParser parser;
    private SemanticAnalyzer analyzer;
    private map<ParseResult> documentCache = {};
    private map<SemanticContext> semanticCache = {};
    
    public function init() {
        self.parser = new ASTParser();
        self.analyzer = new SemanticAnalyzer();
        log:printInfo("Initialized LSP Analysis Handler");
    }
    
    // Handle textDocument/didOpen
    public function handleDidOpen(json params) returns json {
        json textDocument = check params.textDocument;
        string uri = check textDocument.uri;
        string text = check textDocument.text;
        
        // Parse and analyze the document
        ParseResult parseResult = self.parser.parse(text, uri);
        self.documentCache[uri] = parseResult;
        
        if parseResult.root is ASTNode {
            SemanticContext semanticContext = self.analyzer.analyze(parseResult.root);
            self.semanticCache[uri] = semanticContext;
        }
        
        // Return diagnostics
        return self.createDiagnosticsResponse(uri, parseResult);
    }
    
    // Handle textDocument/didChange
    public function handleDidChange(json params) returns json {
        json textDocument = check params.textDocument;
        string uri = check textDocument.uri;
        
        json[] contentChanges = check params.contentChanges;
        if contentChanges.length() > 0 {
            string text = check contentChanges[0].text;
            
            // Re-parse and analyze
            ParseResult parseResult = self.parser.parse(text, uri);
            self.documentCache[uri] = parseResult;
            
            if parseResult.root is ASTNode {
                SemanticContext semanticContext = self.analyzer.analyze(parseResult.root);
                self.semanticCache[uri] = semanticContext;
            }
            
            // Return updated diagnostics
            return self.createDiagnosticsResponse(uri, parseResult);
        }
        
        return {};
    }
    
    // Handle textDocument/completion
    public function handleCompletion(json params) returns json {
        json textDocument = check params.textDocument;
        string uri = check textDocument.uri;
        
        json position = check params.position;
        int line = check position.line;
        int character = check position.character;
        
        Position pos = {line: line, column: character};
        
        // Get completions based on context
        json[] completionItems = self.getCompletionItems(uri, pos);
        
        return {
            "isIncomplete": false,
            "items": completionItems
        };
    }
    
    // Handle textDocument/hover
    public function handleHover(json params) returns json {
        json textDocument = check params.textDocument;
        string uri = check textDocument.uri;
        
        json position = check params.position;
        int line = check position.line;
        int character = check position.character;
        
        Position pos = {line: line, column: character};
        
        // Get symbol at position
        ParseResult? parseResult = self.documentCache[uri];
        if parseResult is ParseResult {
            SymbolInfo? symbol = self.parser.getSymbolAtPosition(pos);
            if symbol is SymbolInfo {
                return self.createHoverResponse(symbol);
            }
        }
        
        return null;
    }
    
    // Handle textDocument/definition
    public function handleDefinition(json params) returns json {
        json textDocument = check params.textDocument;
        string uri = check textDocument.uri;
        
        json position = check params.position;
        int line = check position.line;
        int character = check position.character;
        
        Position pos = {line: line, column: character};
        
        // Find definition
        json? definition = self.findDefinition(uri, pos);
        
        return definition ?: null;
    }
    
    // Handle textDocument/references
    public function handleReferences(json params) returns json {
        json textDocument = check params.textDocument;
        string uri = check textDocument.uri;
        
        json position = check params.position;
        int line = check position.line;
        int character = check position.character;
        
        Position pos = {line: line, column: character};
        
        // Find references
        json[] references = self.findReferences(uri, pos);
        
        return references;
    }
    
    // Handle textDocument/documentSymbol
    public function handleDocumentSymbol(json params) returns json {
        json textDocument = check params.textDocument;
        string uri = check textDocument.uri;
        
        ParseResult? parseResult = self.documentCache[uri];
        if parseResult is ParseResult {
            json[] symbols = self.extractDocumentSymbols(parseResult);
            return symbols;
        }
        
        return [];
    }
    
    // Handle textDocument/codeAction
    public function handleCodeAction(json params) returns json {
        json textDocument = check params.textDocument;
        string uri = check textDocument.uri;
        
        json range = check params.range;
        json context = check params.context;
        
        // Get code actions based on diagnostics
        json[] codeActions = self.getCodeActions(uri, range, context);
        
        return codeActions;
    }
    
    // Handle textDocument/formatting
    public function handleFormatting(json params) returns json {
        json textDocument = check params.textDocument;
        string uri = check textDocument.uri;
        
        json options = check params.options;
        
        // Format document
        json[] edits = self.formatDocument(uri, options);
        
        return edits;
    }
    
    // Handle textDocument/rename
    public function handleRename(json params) returns json {
        json textDocument = check params.textDocument;
        string uri = check textDocument.uri;
        
        json position = check params.position;
        string newName = check params.newName;
        
        int line = check position.line;
        int character = check position.character;
        
        Position pos = {line: line, column: character};
        
        // Perform rename
        json workspaceEdit = self.performRename(uri, pos, newName);
        
        return workspaceEdit;
    }
    
    // Handle textDocument/signatureHelp
    public function handleSignatureHelp(json params) returns json {
        json textDocument = check params.textDocument;
        string uri = check textDocument.uri;
        
        json position = check params.position;
        int line = check position.line;
        int character = check position.character;
        
        Position pos = {line: line, column: character};
        
        // Get signature help
        json? signatureHelp = self.getSignatureHelp(uri, pos);
        
        return signatureHelp ?: null;
    }
    
    // Helper functions
    
    private function createDiagnosticsResponse(string uri, ParseResult parseResult) returns json {
        json[] diagnostics = [];
        
        // Add parse diagnostics
        foreach Diagnostic diag in parseResult.diagnostics {
            diagnostics.push({
                "range": {
                    "start": {
                        "line": diag.range.'start.line,
                        "character": diag.range.'start.column
                    },
                    "end": {
                        "line": diag.range.end.line,
                        "character": diag.range.end.column
                    }
                },
                "severity": diag.severity,
                "code": diag.code,
                "source": "ballerina",
                "message": diag.message
            });
        }
        
        // Add semantic diagnostics
        SemanticContext? semanticContext = self.semanticCache[uri];
        if semanticContext is SemanticContext {
            foreach SemanticError err in semanticContext.errors {
                diagnostics.push({
                    "range": {
                        "start": {
                            "line": err.position.line,
                            "character": err.position.column
                        },
                        "end": {
                            "line": err.position.line,
                            "character": err.position.column
                        }
                    },
                    "severity": 1, // Error
                    "code": err.code,
                    "source": "ballerina-semantic",
                    "message": err.message
                });
            }
            
            foreach SemanticWarning warn in semanticContext.warnings {
                diagnostics.push({
                    "range": {
                        "start": {
                            "line": warn.position.line,
                            "character": warn.position.column
                        },
                        "end": {
                            "line": warn.position.line,
                            "character": warn.position.column
                        }
                    },
                    "severity": 2, // Warning
                    "code": warn.code,
                    "source": "ballerina-semantic",
                    "message": warn.message
                });
            }
        }
        
        return {
            "uri": uri,
            "diagnostics": diagnostics
        };
    }
    
    private function createHoverResponse(SymbolInfo symbol) returns json {
        string content = "**" + symbol.name + "**\n\n";
        
        if symbol.kind is string {
            content += "Kind: " + symbol.kind + "\n";
        }
        
        if symbol.type is string {
            content += "Type: `" + symbol.type + "`\n";
        }
        
        if symbol.documentation is string {
            content += "\n" + symbol.documentation;
        }
        
        return {
            "contents": {
                "kind": "markdown",
                "value": content
            }
        };
    }
    
    private function getCompletionItems(string uri, Position pos) returns json[] {
        json[] items = [];
        
        // Get semantic context
        SemanticContext? semanticContext = self.semanticCache[uri];
        if semanticContext is SemanticContext {
            // Add function completions
            foreach [string, FunctionInfo] [name, funcInfo] in semanticContext.functionTable.entries() {
                items.push({
                    "label": name,
                    "kind": 3, // Function
                    "detail": self.getFunctionSignature(funcInfo),
                    "documentation": funcInfo.documentation ?: ""
                });
            }
            
            // Add type completions
            foreach [string, TypeInfo] [name, typeInfo] in semanticContext.typeTable.entries() {
                items.push({
                    "label": name,
                    "kind": 7, // Class/Type
                    "detail": "type " + name
                });
            }
            
            // Add variable completions
            foreach [string, VariableInfo] [name, varInfo] in semanticContext.variableTable.entries() {
                items.push({
                    "label": varInfo.name,
                    "kind": 6, // Variable
                    "detail": varInfo.type.name
                });
            }
        }
        
        // Add keywords
        string[] keywords = [
            "function", "returns", "if", "else", "while", "foreach",
            "match", "check", "panic", "return", "break", "continue",
            "type", "record", "object", "class", "service", "resource",
            "public", "private", "isolated", "remote", "transactional"
        ];
        
        foreach string keyword in keywords {
            items.push({
                "label": keyword,
                "kind": 14, // Keyword
                "detail": "keyword"
            });
        }
        
        return items;
    }
    
    private function getFunctionSignature(FunctionInfo funcInfo) returns string {
        string signature = "function " + funcInfo.name + "(";
        
        string[] params = [];
        foreach ParameterInfo param in funcInfo.parameters {
            params.push(param.type.name + " " + param.name);
        }
        
        signature += string:'join(", ", ...params);
        signature += ") returns " + funcInfo.returnType.name;
        
        return signature;
    }
    
    private function findDefinition(string uri, Position pos) returns json? {
        // Find symbol at position
        ParseResult? parseResult = self.documentCache[uri];
        if parseResult is ParseResult {
            SymbolInfo? symbol = self.parser.getSymbolAtPosition(pos);
            if symbol is SymbolInfo {
                // Look for definition in semantic context
                SemanticContext? semanticContext = self.semanticCache[uri];
                if semanticContext is SemanticContext {
                    // Find function definition
                    FunctionInfo? funcInfo = semanticContext.functionTable[symbol.name];
                    if funcInfo is FunctionInfo && funcInfo.declaration is Position {
                        return {
                            "uri": uri,
                            "range": {
                                "start": {
                                    "line": funcInfo.declaration.line,
                                    "character": funcInfo.declaration.column
                                },
                                "end": {
                                    "line": funcInfo.declaration.line,
                                    "character": funcInfo.declaration.column
                                }
                            }
                        };
                    }
                }
            }
        }
        
        return ();
    }
    
    private function findReferences(string uri, Position pos) returns json[] {
        json[] references = [];
        
        // Find symbol at position
        ParseResult? parseResult = self.documentCache[uri];
        if parseResult is ParseResult {
            SymbolInfo? symbol = self.parser.getSymbolAtPosition(pos);
            if symbol is SymbolInfo {
                // Search for references in the document
                // This would require a more sophisticated reference tracking system
                // For now, return empty array
            }
        }
        
        return references;
    }
    
    private function extractDocumentSymbols(ParseResult parseResult) returns json[] {
        json[] symbols = [];
        
        map<SymbolInfo> symbolTable = self.parser.getSymbols();
        foreach [string, SymbolInfo] [name, symbol] in symbolTable.entries() {
            int symbolKind = self.getSymbolKind(symbol.kind);
            symbols.push({
                "name": name,
                "kind": symbolKind,
                "location": {
                    "uri": parseResult.metadata["fileName"] ?: "",
                    "range": {
                        "start": {"line": 0, "character": 0},
                        "end": {"line": 0, "character": 0}
                    }
                }
            });
        }
        
        return symbols;
    }
    
    private function getSymbolKind(string kind) returns int {
        // Map to LSP SymbolKind
        match kind {
            "function" => { return 12; }
            "variable" => { return 13; }
            "type" => { return 5; }
            "class" => { return 5; }
            _ => { return 0; }
        }
    }
    
    private function getCodeActions(string uri, json range, json context) returns json[] {
        json[] actions = [];
        
        // Get diagnostics from context
        json[] diagnostics = check context.diagnostics;
        
        foreach json diagnostic in diagnostics {
            string? code = diagnostic.code;
            if code is string {
                // Create quick fix actions based on diagnostic code
                json? action = self.createQuickFix(uri, diagnostic);
                if action is json {
                    actions.push(action);
                }
            }
        }
        
        return actions;
    }
    
    private function createQuickFix(string uri, json diagnostic) returns json? {
        string? code = diagnostic.code;
        
        match code {
            "E001" => {
                // Fix for missing function name
                return {
                    "title": "Add function name",
                    "kind": "quickfix",
                    "diagnostics": [diagnostic],
                    "edit": {
                        "changes": {
                            [uri]: []
                        }
                    }
                };
            }
            _ => {
                return ();
            }
        }
    }
    
    private function formatDocument(string uri, json options) returns json[] {
        // Simple formatting - would be expanded with proper formatter
        return [];
    }
    
    private function performRename(string uri, Position pos, string newName) returns json {
        map<json[]> changes = {};
        
        // Find all references and create edits
        json[] references = self.findReferences(uri, pos);
        json[] edits = [];
        
        foreach json reference in references {
            edits.push({
                "range": reference.range,
                "newText": newName
            });
        }
        
        if edits.length() > 0 {
            changes[uri] = edits;
        }
        
        return {
            "changes": changes
        };
    }
    
    private function getSignatureHelp(string uri, Position pos) returns json? {
        // Find function call at position
        // This would require parsing the current line to identify function calls
        
        return ();
    }
}