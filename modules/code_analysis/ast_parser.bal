// AST Parser Module for Ballerina Code Analysis
// Provides syntax tree parsing and traversal capabilities

import ballerina/io;
import ballerina/log;
import ballerina/regex;

// AST Node Types
public type ASTNodeType string;

public const ASTNodeType NODE_MODULE = "MODULE";
public const ASTNodeType NODE_FUNCTION = "FUNCTION";
public const ASTNodeType NODE_CLASS = "CLASS";
public const ASTNodeType NODE_SERVICE = "SERVICE";
public const ASTNodeType NODE_RECORD = "RECORD";
public const ASTNodeType NODE_OBJECT = "OBJECT";
public const ASTNodeType NODE_VARIABLE = "VARIABLE";
public const ASTNodeType NODE_CONSTANT = "CONSTANT";
public const ASTNodeType NODE_TYPE_DEF = "TYPE_DEFINITION";
public const ASTNodeType NODE_IMPORT = "IMPORT";
public const ASTNodeType NODE_ANNOTATION = "ANNOTATION";
public const ASTNodeType NODE_EXPRESSION = "EXPRESSION";
public const ASTNodeType NODE_STATEMENT = "STATEMENT";
public const ASTNodeType NODE_BLOCK = "BLOCK";
public const ASTNodeType NODE_PARAMETER = "PARAMETER";

// Position in source code
public type Position record {|
    int line;
    int column;
    int offset?;
|};

// Range in source code
public type Range record {|
    Position 'start;
    Position end;
|};

// AST Node base structure
public type ASTNode record {|
    string id;
    ASTNodeType nodeType;
    string name?;
    Range range;
    ASTNode[] children = [];
    map<json> metadata = {};
    SymbolInfo? symbol = ();
|};

// Symbol information for semantic analysis
public type SymbolInfo record {|
    string name;
    string kind; // "function", "variable", "type", etc.
    string? type?;
    string? documentation?;
    boolean exported = false;
    string[] modifiers = [];
    map<json> properties = {};
|};

// Parse result
public type ParseResult record {|
    ASTNode? root;
    Diagnostic[] diagnostics = [];
    boolean success;
    map<string> metadata = {};
|};

// Diagnostic information
public type Diagnostic record {|
    DiagnosticSeverity severity;
    Range range;
    string message;
    string? code?;
    string? source?;
    DiagnosticTag[]? tags?;
|};

public enum DiagnosticSeverity {
    ERROR = 1,
    WARNING = 2,
    INFORMATION = 3,
    HINT = 4
}

public enum DiagnosticTag {
    UNNECESSARY = 1,
    DEPRECATED = 2
}

// AST Parser Implementation
public class ASTParser {
    private map<ASTNode> nodeCache = {};
    private map<SymbolInfo> symbolTable = {};
    private Diagnostic[] diagnostics = [];
    
    public function init() {
        log:printDebug("Initializing AST Parser");
    }
    
    // Parse source code into AST
    public function parse(string sourceCode, string? fileName = ()) returns ParseResult {
        self.diagnostics = [];
        self.nodeCache = {};
        
        // Tokenize and build AST
        ASTNode? root = self.buildAST(sourceCode, fileName);
        
        // Perform semantic analysis
        if root is ASTNode {
            self.analyzeSemantics(root);
        }
        
        return {
            root: root,
            diagnostics: self.diagnostics,
            success: root !== (),
            metadata: {
                "fileName": fileName ?: "unknown",
                "nodeCount": self.nodeCache.length().toString(),
                "symbolCount": self.symbolTable.length().toString()
            }
        };
    }
    
    // Build AST from source code
    private function buildAST(string sourceCode, string? fileName) returns ASTNode? {
        // Split into lines for processing
        string[] lines = regex:split(sourceCode, "\n");
        
        // Create root module node
        ASTNode moduleNode = {
            id: generateNodeId(),
            nodeType: NODE_MODULE,
            name: fileName ?: "module",
            range: {
                'start: {line: 0, column: 0},
                end: {line: lines.length() - 1, column: 0}
            }
        };
        
        // Parse imports
        ASTNode[] imports = self.parseImports(lines);
        moduleNode.children.push(...imports);
        
        // Parse top-level declarations
        ASTNode[] declarations = self.parseDeclarations(lines);
        moduleNode.children.push(...declarations);
        
        // Cache the module node
        self.nodeCache[moduleNode.id] = moduleNode;
        
        return moduleNode;
    }
    
    // Parse import statements
    private function parseImports(string[] lines) returns ASTNode[] {
        ASTNode[] imports = [];
        
        foreach int i in 0 ..< lines.length() {
            string line = lines[i].trim();
            if line.startsWith("import ") {
                ASTNode importNode = {
                    id: generateNodeId(),
                    nodeType: NODE_IMPORT,
                    name: self.extractImportName(line),
                    range: {
                        'start: {line: i, column: 0},
                        end: {line: i, column: line.length()}
                    }
                };
                imports.push(importNode);
                self.nodeCache[importNode.id] = importNode;
            }
        }
        
        return imports;
    }
    
    // Parse declarations (functions, types, etc.)
    private function parseDeclarations(string[] lines) returns ASTNode[] {
        ASTNode[] declarations = [];
        int i = 0;
        
        while i < lines.length() {
            string line = lines[i].trim();
            
            // Parse function declarations
            if regex:matches(line, ".*function\\s+\\w+.*") {
                ASTNode? funcNode = self.parseFunctionDeclaration(lines, i);
                if funcNode is ASTNode {
                    declarations.push(funcNode);
                    i = funcNode.range.end.line + 1;
                    continue;
                }
            }
            
            // Parse type definitions
            if regex:matches(line, ".*type\\s+\\w+.*") {
                ASTNode? typeNode = self.parseTypeDefinition(lines, i);
                if typeNode is ASTNode {
                    declarations.push(typeNode);
                    i = typeNode.range.end.line + 1;
                    continue;
                }
            }
            
            // Parse class definitions
            if regex:matches(line, ".*class\\s+\\w+.*") {
                ASTNode? classNode = self.parseClassDefinition(lines, i);
                if classNode is ASTNode {
                    declarations.push(classNode);
                    i = classNode.range.end.line + 1;
                    continue;
                }
            }
            
            // Parse service definitions
            if regex:matches(line, ".*service\\s+.*") {
                ASTNode? serviceNode = self.parseServiceDefinition(lines, i);
                if serviceNode is ASTNode {
                    declarations.push(serviceNode);
                    i = serviceNode.range.end.line + 1;
                    continue;
                }
            }
            
            i += 1;
        }
        
        return declarations;
    }
    
    // Parse function declaration
    private function parseFunctionDeclaration(string[] lines, int startLine) returns ASTNode? {
        string line = lines[startLine];
        
        // Extract function name
        string? funcName = self.extractFunctionName(line);
        if funcName is () {
            return ();
        }
        
        // Find function end
        int endLine = self.findBlockEnd(lines, startLine);
        
        // Create function node
        ASTNode funcNode = {
            id: generateNodeId(),
            nodeType: NODE_FUNCTION,
            name: funcName,
            range: {
                'start: {line: startLine, column: 0},
                end: {line: endLine, column: lines[endLine].length()}
            }
        };
        
        // Extract function metadata
        funcNode.metadata["visibility"] = self.extractVisibility(line);
        funcNode.metadata["returnType"] = self.extractReturnType(line);
        
        // Create symbol info
        funcNode.symbol = {
            name: funcName,
            kind: "function",
            type: self.extractFunctionSignature(line),
            exported: line.contains("public"),
            modifiers: self.extractModifiers(line)
        };
        
        // Add to symbol table
        self.symbolTable[funcName] = funcNode.symbol;
        
        // Cache the node
        self.nodeCache[funcNode.id] = funcNode;
        
        return funcNode;
    }
    
    // Parse type definition
    private function parseTypeDefinition(string[] lines, int startLine) returns ASTNode? {
        string line = lines[startLine];
        
        // Extract type name
        string? typeName = self.extractTypeName(line);
        if typeName is () {
            return ();
        }
        
        // Find type definition end
        int endLine = startLine;
        if line.contains("record") || line.contains("object") {
            endLine = self.findBlockEnd(lines, startLine);
        }
        
        // Create type node
        ASTNode typeNode = {
            id: generateNodeId(),
            nodeType: NODE_TYPE_DEF,
            name: typeName,
            range: {
                'start: {line: startLine, column: 0},
                end: {line: endLine, column: lines[endLine].length()}
            }
        };
        
        // Create symbol info
        typeNode.symbol = {
            name: typeName,
            kind: "type",
            exported: line.contains("public")
        };
        
        // Add to symbol table
        self.symbolTable[typeName] = typeNode.symbol;
        
        // Cache the node
        self.nodeCache[typeNode.id] = typeNode;
        
        return typeNode;
    }
    
    // Parse class definition
    private function parseClassDefinition(string[] lines, int startLine) returns ASTNode? {
        string line = lines[startLine];
        
        // Extract class name
        string? className = self.extractClassName(line);
        if className is () {
            return ();
        }
        
        // Find class end
        int endLine = self.findBlockEnd(lines, startLine);
        
        // Create class node
        ASTNode classNode = {
            id: generateNodeId(),
            nodeType: NODE_CLASS,
            name: className,
            range: {
                'start: {line: startLine, column: 0},
                end: {line: endLine, column: lines[endLine].length()}
            }
        };
        
        // Create symbol info
        classNode.symbol = {
            name: className,
            kind: "class",
            exported: line.contains("public")
        };
        
        // Add to symbol table
        self.symbolTable[className] = classNode.symbol;
        
        // Cache the node
        self.nodeCache[classNode.id] = classNode;
        
        return classNode;
    }
    
    // Parse service definition
    private function parseServiceDefinition(string[] lines, int startLine) returns ASTNode? {
        string line = lines[startLine];
        
        // Extract service path/name
        string serviceName = "service_" + startLine.toString();
        
        // Find service end
        int endLine = self.findBlockEnd(lines, startLine);
        
        // Create service node
        ASTNode serviceNode = {
            id: generateNodeId(),
            nodeType: NODE_SERVICE,
            name: serviceName,
            range: {
                'start: {line: startLine, column: 0},
                end: {line: endLine, column: lines[endLine].length()}
            }
        };
        
        // Cache the node
        self.nodeCache[serviceNode.id] = serviceNode;
        
        return serviceNode;
    }
    
    // Analyze semantics of the AST
    private function analyzeSemantics(ASTNode node) {
        // Traverse the AST and perform semantic analysis
        self.traverseAndAnalyze(node);
        
        // Check for undefined symbols
        self.checkUndefinedSymbols(node);
        
        // Type checking would go here
        // self.performTypeChecking(node);
    }
    
    // Traverse AST and analyze
    private function traverseAndAnalyze(ASTNode node) {
        // Process current node
        self.analyzeNode(node);
        
        // Process children
        foreach ASTNode child in node.children {
            self.traverseAndAnalyze(child);
        }
    }
    
    // Analyze individual node
    private function analyzeNode(ASTNode node) {
        // Perform node-specific analysis
        match node.nodeType {
            NODE_FUNCTION => {
                self.analyzeFunctionNode(node);
            }
            NODE_CLASS => {
                self.analyzeClassNode(node);
            }
            NODE_TYPE_DEF => {
                self.analyzeTypeNode(node);
            }
        }
    }
    
    // Analyze function node
    private function analyzeFunctionNode(ASTNode node) {
        if node.name is string {
            // Check for duplicate definitions
            // Add more semantic checks here
        }
    }
    
    // Analyze class node
    private function analyzeClassNode(ASTNode node) {
        if node.name is string {
            // Check class semantics
        }
    }
    
    // Analyze type node
    private function analyzeTypeNode(ASTNode node) {
        if node.name is string {
            // Check type semantics
        }
    }
    
    // Check for undefined symbols
    private function checkUndefinedSymbols(ASTNode node) {
        // Implementation would check for undefined references
    }
    
    // Helper functions
    
    private function extractImportName(string line) returns string {
        string[] parts = regex:split(line, "\\s+");
        if parts.length() >= 2 {
            return parts[1].trim().replace(";", "");
        }
        return "unknown";
    }
    
    private function extractFunctionName(string line) returns string? {
        string pattern = "function\\s+(\\w+)";
        var result = regex:findFirst(line, pattern);
        if result is regex:Match {
            var groups = result.groups;
            if groups.length() > 0 {
                return groups[0].matched;
            }
        }
        return ();
    }
    
    private function extractTypeName(string line) returns string? {
        string pattern = "type\\s+(\\w+)";
        var result = regex:findFirst(line, pattern);
        if result is regex:Match {
            var groups = result.groups;
            if groups.length() > 0 {
                return groups[0].matched;
            }
        }
        return ();
    }
    
    private function extractClassName(string line) returns string? {
        string pattern = "class\\s+(\\w+)";
        var result = regex:findFirst(line, pattern);
        if result is regex:Match {
            var groups = result.groups;
            if groups.length() > 0 {
                return groups[0].matched;
            }
        }
        return ();
    }
    
    private function extractVisibility(string line) returns string {
        if line.contains("public") {
            return "public";
        } else if line.contains("private") {
            return "private";
        }
        return "module";
    }
    
    private function extractReturnType(string line) returns string {
        if line.contains("returns") {
            string pattern = "returns\\s+([^{]+)";
            var result = regex:findFirst(line, pattern);
            if result is regex:Match {
                return result.matched.trim();
            }
        }
        return "void";
    }
    
    private function extractFunctionSignature(string line) returns string {
        string pattern = "function\\s+\\w+\\s*\\([^)]*\\)\\s*returns\\s+[^{]+";
        var result = regex:findFirst(line, pattern);
        if result is regex:Match {
            return result.matched;
        }
        return line;
    }
    
    private function extractModifiers(string line) returns string[] {
        string[] modifiers = [];
        if line.contains("public") {
            modifiers.push("public");
        }
        if line.contains("isolated") {
            modifiers.push("isolated");
        }
        if line.contains("remote") {
            modifiers.push("remote");
        }
        if line.contains("transactional") {
            modifiers.push("transactional");
        }
        return modifiers;
    }
    
    private function findBlockEnd(string[] lines, int startLine) returns int {
        int braceCount = 0;
        boolean inBlock = false;
        
        foreach int i in startLine ..< lines.length() {
            string line = lines[i];
            foreach var char in line {
                if char == "{" {
                    braceCount += 1;
                    inBlock = true;
                } else if char == "}" {
                    braceCount -= 1;
                    if braceCount == 0 && inBlock {
                        return i;
                    }
                }
            }
        }
        
        return lines.length() - 1;
    }
    
    // Get all symbols
    public function getSymbols() returns map<SymbolInfo> {
        return self.symbolTable;
    }
    
    // Get symbol at position
    public function getSymbolAtPosition(Position pos) returns SymbolInfo? {
        foreach ASTNode node in self.nodeCache {
            if self.isPositionInRange(pos, node.range) {
                return node.symbol;
            }
        }
        return ();
    }
    
    // Check if position is in range
    private function isPositionInRange(Position pos, Range range) returns boolean {
        if pos.line < range.'start.line || pos.line > range.end.line {
            return false;
        }
        if pos.line == range.'start.line && pos.column < range.'start.column {
            return false;
        }
        if pos.line == range.end.line && pos.column > range.end.column {
            return false;
        }
        return true;
    }
    
    // Get AST node by ID
    public function getNodeById(string id) returns ASTNode? {
        return self.nodeCache[id];
    }
    
    // Get diagnostics
    public function getDiagnostics() returns Diagnostic[] {
        return self.diagnostics;
    }
}

// Generate unique node ID
function generateNodeId() returns string {
    return "node_" + time:utcNow().toString();
}