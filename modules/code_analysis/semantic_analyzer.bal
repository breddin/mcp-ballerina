// Semantic Analyzer Module for Ballerina Code Analysis
// Provides semantic analysis, type checking, and symbol resolution

import ballerina/log;
import ballerina/regex;

// Semantic analysis context
public type SemanticContext record {|
    map<TypeInfo> typeTable = {};
    map<VariableInfo> variableTable = {};
    map<FunctionInfo> functionTable = {};
    ScopeStack scopeStack;
    string[] importedModules = [];
    SemanticError[] errors = [];
    SemanticWarning[] warnings = [];
|};

// Type information
public type TypeInfo record {|
    string name;
    TypeKind kind;
    string? baseType?;
    TypeInfo[]? unionTypes?;
    map<TypeInfo>? fields?;
    boolean nullable = false;
    boolean readonly = false;
|};

public enum TypeKind {
    PRIMITIVE,
    RECORD,
    OBJECT,
    UNION,
    ARRAY,
    MAP,
    TUPLE,
    FUNCTION,
    ERROR,
    CUSTOM
}

// Variable information
public type VariableInfo record {|
    string name;
    TypeInfo type;
    string scope;
    boolean mutable = true;
    boolean initialized = false;
    Position? declaration?;
    json? defaultValue?;
|};

// Function information
public type FunctionInfo record {|
    string name;
    TypeInfo returnType;
    ParameterInfo[] parameters;
    string[] modifiers = [];
    boolean exported = false;
    string? documentation?;
    Position? declaration?;
|};

// Parameter information
public type ParameterInfo record {|
    string name;
    TypeInfo type;
    boolean required = true;
    json? defaultValue?;
|};

// Scope management
public type ScopeStack record {|
    Scope[] scopes = [];
    int currentLevel = 0;
|};

public type Scope record {|
    string id;
    ScopeType type;
    int level;
    map<VariableInfo> variables = {};
    map<TypeInfo> types = {};
    Scope? parent?;
|};

public enum ScopeType {
    MODULE,
    FUNCTION,
    BLOCK,
    CLASS,
    OBJECT,
    SERVICE
}

// Semantic errors and warnings
public type SemanticError record {|
    string message;
    Position position;
    string code;
    string? hint?;
|};

public type SemanticWarning record {|
    string message;
    Position position;
    string code;
|};

// Semantic Analyzer Implementation
public class SemanticAnalyzer {
    private SemanticContext context;
    private map<string> builtInTypes;
    
    public function init() {
        self.context = {
            scopeStack: {
                scopes: [{
                    id: "global",
                    type: MODULE,
                    level: 0
                }]
            }
        };
        
        // Initialize built-in types
        self.builtInTypes = {
            "int": "int",
            "float": "float",
            "decimal": "decimal",
            "string": "string",
            "boolean": "boolean",
            "byte": "byte",
            "json": "json",
            "xml": "xml",
            "any": "any",
            "anydata": "anydata",
            "error": "error",
            "never": "never",
            "readonly": "readonly",
            "handle": "handle"
        };
        
        self.initializeBuiltInTypes();
    }
    
    // Initialize built-in types in type table
    private function initializeBuiltInTypes() {
        foreach string typeName in self.builtInTypes {
            self.context.typeTable[typeName] = {
                name: typeName,
                kind: PRIMITIVE
            };
        }
    }
    
    // Analyze AST semantically
    public function analyze(ASTNode ast) returns SemanticContext {
        // Reset context for new analysis
        self.resetContext();
        
        // Start analysis from root
        self.analyzeNode(ast);
        
        // Perform additional checks
        self.performCrossReferenceChecks();
        self.checkUnusedDeclarations();
        
        return self.context;
    }
    
    // Reset context for new analysis
    private function resetContext() {
        self.context.errors = [];
        self.context.warnings = [];
        self.context.variableTable = {};
        self.context.functionTable = {};
        self.context.importedModules = [];
        
        // Keep built-in types
        map<TypeInfo> builtIns = {};
        foreach [string, TypeInfo] [name, typeInfo] in self.context.typeTable.entries() {
            if self.builtInTypes.hasKey(name) {
                builtIns[name] = typeInfo;
            }
        }
        self.context.typeTable = builtIns;
    }
    
    // Analyze a node
    private function analyzeNode(ASTNode node) {
        match node.nodeType {
            NODE_MODULE => {
                self.analyzeModule(node);
            }
            NODE_FUNCTION => {
                self.analyzeFunction(node);
            }
            NODE_CLASS => {
                self.analyzeClass(node);
            }
            NODE_TYPE_DEF => {
                self.analyzeTypeDefinition(node);
            }
            NODE_VARIABLE => {
                self.analyzeVariable(node);
            }
            NODE_EXPRESSION => {
                self.analyzeExpression(node);
            }
            NODE_STATEMENT => {
                self.analyzeStatement(node);
            }
            NODE_IMPORT => {
                self.analyzeImport(node);
            }
        }
        
        // Analyze children
        foreach ASTNode child in node.children {
            self.analyzeNode(child);
        }
    }
    
    // Analyze module node
    private function analyzeModule(ASTNode node) {
        // Module-level analysis
        log:printDebug("Analyzing module: " + (node.name ?: "unnamed"));
        
        // Process imports first
        foreach ASTNode child in node.children {
            if child.nodeType == NODE_IMPORT {
                self.analyzeImport(child);
            }
        }
    }
    
    // Analyze import statement
    private function analyzeImport(ASTNode node) {
        if node.name is string {
            self.context.importedModules.push(node.name);
            log:printDebug("Registered import: " + node.name);
        }
    }
    
    // Analyze function declaration
    private function analyzeFunction(ASTNode node) {
        string? funcName = node.name;
        if funcName is () {
            self.addError("Function without name", node.range.'start, "E001");
            return;
        }
        
        // Check for duplicate function
        if self.context.functionTable.hasKey(funcName) {
            self.addError("Duplicate function: " + funcName, node.range.'start, "E002");
            return;
        }
        
        // Create new scope for function
        self.pushScope(funcName, FUNCTION);
        
        // Extract function information
        FunctionInfo funcInfo = self.extractFunctionInfo(node);
        self.context.functionTable[funcName] = funcInfo;
        
        // Analyze function body
        foreach ASTNode child in node.children {
            self.analyzeNode(child);
        }
        
        // Pop function scope
        self.popScope();
    }
    
    // Analyze class declaration
    private function analyzeClass(ASTNode node) {
        string? className = node.name;
        if className is () {
            self.addError("Class without name", node.range.'start, "E003");
            return;
        }
        
        // Check for duplicate type
        if self.context.typeTable.hasKey(className) {
            self.addError("Duplicate type: " + className, node.range.'start, "E004");
            return;
        }
        
        // Create new scope for class
        self.pushScope(className, CLASS);
        
        // Register class type
        self.context.typeTable[className] = {
            name: className,
            kind: OBJECT
        };
        
        // Analyze class members
        foreach ASTNode child in node.children {
            self.analyzeNode(child);
        }
        
        // Pop class scope
        self.popScope();
    }
    
    // Analyze type definition
    private function analyzeTypeDefinition(ASTNode node) {
        string? typeName = node.name;
        if typeName is () {
            self.addError("Type definition without name", node.range.'start, "E005");
            return;
        }
        
        // Check for duplicate type
        if self.context.typeTable.hasKey(typeName) {
            self.addError("Duplicate type: " + typeName, node.range.'start, "E006");
            return;
        }
        
        // Extract and register type information
        TypeInfo typeInfo = self.extractTypeInfo(node);
        self.context.typeTable[typeName] = typeInfo;
    }
    
    // Analyze variable declaration
    private function analyzeVariable(ASTNode node) {
        string? varName = node.name;
        if varName is () {
            self.addError("Variable without name", node.range.'start, "E007");
            return;
        }
        
        // Check for duplicate variable in current scope
        Scope currentScope = self.getCurrentScope();
        if currentScope.variables.hasKey(varName) {
            self.addError("Duplicate variable: " + varName, node.range.'start, "E008");
            return;
        }
        
        // Extract variable information
        VariableInfo varInfo = self.extractVariableInfo(node);
        varInfo.scope = currentScope.id;
        
        // Register variable
        currentScope.variables[varName] = varInfo;
        self.context.variableTable[currentScope.id + "." + varName] = varInfo;
    }
    
    // Analyze expression
    private function analyzeExpression(ASTNode node) {
        // Type checking for expressions
        TypeInfo? exprType = self.inferExpressionType(node);
        
        if exprType is () {
            self.addWarning("Cannot infer expression type", node.range.'start, "W001");
        }
    }
    
    // Analyze statement
    private function analyzeStatement(ASTNode node) {
        // Statement analysis
        // Check for unreachable code, control flow, etc.
    }
    
    // Extract function information from node
    private function extractFunctionInfo(ASTNode node) returns FunctionInfo {
        FunctionInfo funcInfo = {
            name: node.name ?: "unknown",
            returnType: {name: "any", kind: PRIMITIVE},
            parameters: [],
            declaration: node.range.'start
        };
        
        // Extract from metadata if available
        if node.metadata.hasKey("returnType") {
            string? returnType = node.metadata["returnType"].toString();
            if returnType is string {
                funcInfo.returnType = self.resolveType(returnType);
            }
        }
        
        if node.symbol is SymbolInfo {
            funcInfo.exported = node.symbol.exported;
            funcInfo.modifiers = node.symbol.modifiers;
            funcInfo.documentation = node.symbol.documentation;
        }
        
        return funcInfo;
    }
    
    // Extract type information from node
    private function extractTypeInfo(ASTNode node) returns TypeInfo {
        TypeInfo typeInfo = {
            name: node.name ?: "unknown",
            kind: CUSTOM
        };
        
        // Determine type kind based on metadata
        if node.metadata.hasKey("typeKind") {
            string? kind = node.metadata["typeKind"].toString();
            if kind == "record" {
                typeInfo.kind = RECORD;
            } else if kind == "object" {
                typeInfo.kind = OBJECT;
            } else if kind == "union" {
                typeInfo.kind = UNION;
            }
        }
        
        return typeInfo;
    }
    
    // Extract variable information from node
    private function extractVariableInfo(ASTNode node) returns VariableInfo {
        VariableInfo varInfo = {
            name: node.name ?: "unknown",
            type: {name: "any", kind: PRIMITIVE},
            scope: self.getCurrentScope().id,
            declaration: node.range.'start
        };
        
        // Extract type if available
        if node.metadata.hasKey("type") {
            string? typeName = node.metadata["type"].toString();
            if typeName is string {
                varInfo.type = self.resolveType(typeName);
            }
        }
        
        return varInfo;
    }
    
    // Infer expression type
    private function inferExpressionType(ASTNode node) returns TypeInfo? {
        // Simple type inference based on expression structure
        // This would be expanded with full type inference logic
        
        if node.metadata.hasKey("expressionType") {
            string? typeName = node.metadata["expressionType"].toString();
            if typeName is string {
                return self.resolveType(typeName);
            }
        }
        
        return ();
    }
    
    // Resolve type by name
    private function resolveType(string typeName) returns TypeInfo {
        // Check if it's a known type
        if self.context.typeTable.hasKey(typeName) {
            return self.context.typeTable[typeName] ?: {name: typeName, kind: CUSTOM};
        }
        
        // Check for array types
        if typeName.endsWith("[]") {
            string elementType = typeName.substring(0, typeName.length() - 2);
            return {
                name: typeName,
                kind: ARRAY,
                baseType: elementType
            };
        }
        
        // Check for nullable types
        if typeName.endsWith("?") {
            string baseType = typeName.substring(0, typeName.length() - 1);
            TypeInfo base = self.resolveType(baseType);
            base.nullable = true;
            return base;
        }
        
        // Unknown type
        return {name: typeName, kind: CUSTOM};
    }
    
    // Scope management
    
    private function pushScope(string id, ScopeType scopeType) {
        Scope currentScope = self.getCurrentScope();
        Scope newScope = {
            id: id,
            type: scopeType,
            level: self.context.scopeStack.currentLevel + 1,
            parent: currentScope
        };
        
        self.context.scopeStack.scopes.push(newScope);
        self.context.scopeStack.currentLevel += 1;
    }
    
    private function popScope() {
        if self.context.scopeStack.scopes.length() > 1 {
            _ = self.context.scopeStack.scopes.pop();
            self.context.scopeStack.currentLevel -= 1;
        }
    }
    
    private function getCurrentScope() returns Scope {
        int lastIndex = self.context.scopeStack.scopes.length() - 1;
        return self.context.scopeStack.scopes[lastIndex];
    }
    
    // Cross-reference checks
    private function performCrossReferenceChecks() {
        // Check for undefined types
        self.checkUndefinedTypes();
        
        // Check for undefined variables
        self.checkUndefinedVariables();
        
        // Check for undefined functions
        self.checkUndefinedFunctions();
    }
    
    private function checkUndefinedTypes() {
        // Implementation would check for undefined type references
    }
    
    private function checkUndefinedVariables() {
        // Implementation would check for undefined variable references
    }
    
    private function checkUndefinedFunctions() {
        // Implementation would check for undefined function calls
    }
    
    // Check for unused declarations
    private function checkUnusedDeclarations() {
        // Check for unused variables
        foreach [string, VariableInfo] [name, varInfo] in self.context.variableTable.entries() {
            if !varInfo.initialized {
                self.addWarning("Unused variable: " + name, varInfo.declaration ?: {line: 0, column: 0}, "W002");
            }
        }
        
        // Check for unused functions
        // This would require usage tracking
    }
    
    // Error and warning management
    
    private function addError(string message, Position position, string code, string? hint = ()) {
        self.context.errors.push({
            message: message,
            position: position,
            code: code,
            hint: hint
        });
    }
    
    private function addWarning(string message, Position position, string code) {
        self.context.warnings.push({
            message: message,
            position: position,
            code: code
        });
    }
    
    // Get analysis results
    
    public function getErrors() returns SemanticError[] {
        return self.context.errors;
    }
    
    public function getWarnings() returns SemanticWarning[] {
        return self.context.warnings;
    }
    
    public function getSymbols() returns map<SymbolInfo> {
        map<SymbolInfo> symbols = {};
        
        // Convert function table to symbols
        foreach [string, FunctionInfo] [name, funcInfo] in self.context.functionTable.entries() {
            symbols[name] = {
                name: name,
                kind: "function",
                type: funcInfo.returnType.name,
                exported: funcInfo.exported,
                modifiers: funcInfo.modifiers,
                documentation: funcInfo.documentation
            };
        }
        
        // Add type symbols
        foreach [string, TypeInfo] [name, typeInfo] in self.context.typeTable.entries() {
            if !self.builtInTypes.hasKey(name) {
                symbols[name] = {
                    name: name,
                    kind: "type",
                    type: typeInfo.kind.toString()
                };
            }
        }
        
        return symbols;
    }
    
    // Type checking utilities
    
    public function isAssignable(TypeInfo target, TypeInfo source) returns boolean {
        // Check if source type can be assigned to target type
        
        // Same type
        if target.name == source.name {
            return true;
        }
        
        // Any type accepts everything
        if target.name == "any" || target.name == "anydata" {
            return true;
        }
        
        // Never type can't be assigned
        if source.name == "never" {
            return false;
        }
        
        // Nullable handling
        if target.nullable && !source.nullable {
            return self.isAssignable(
                {...target, nullable: false},
                source
            );
        }
        
        // Union type handling
        if target.kind == UNION && target.unionTypes is TypeInfo[] {
            foreach TypeInfo unionType in target.unionTypes {
                if self.isAssignable(unionType, source) {
                    return true;
                }
            }
        }
        
        // More complex type compatibility would be checked here
        
        return false;
    }
}