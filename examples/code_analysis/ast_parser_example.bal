import ballerina/io;
import modules.code_analysis.ast_parser;

public function main() returns error? {
    // Example 1: Parse a simple Ballerina function
    string sourceCode = string `
        import ballerina/http;
        
        service /api on new http:Listener(9090) {
            resource function get users() returns json {
                return {"users": ["Alice", "Bob", "Charlie"]};
            }
            
            resource function post users(@http:Payload json payload) returns json|error {
                string? name = check payload.name;
                if name is () {
                    return error("Name is required");
                }
                return {"message": "User created", "name": name};
            }
        }
    `;
    
    // Create parser instance
    ast_parser:ASTParser parser = new();
    
    // Parse the source code
    ast_parser:ParseResult parseResult = parser.parse(sourceCode, "api_service.bal");
    
    if parseResult.success {
        io:println("✅ Parsing successful!");
        
        // Get the AST root node
        ast_parser:ASTNode? ast = parseResult.ast;
        if ast is ast_parser:ASTNode {
            io:println("AST Root Type: ", ast.'type);
            io:println("Number of children: ", ast.children.length());
        }
        
        // Get all symbols in the document
        ast_parser:SymbolInfo[] symbols = parser.getSymbols();
        io:println("\n📋 Symbols found:");
        foreach ast_parser:SymbolInfo symbol in symbols {
            io:println(string `  - ${symbol.name} (${symbol.kind}) at line ${symbol.position.line}`);
        }
        
        // Get diagnostics (warnings, hints)
        ast_parser:Diagnostic[] diagnostics = parser.getDiagnostics();
        if diagnostics.length() > 0 {
            io:println("\n⚠️ Diagnostics:");
            foreach ast_parser:Diagnostic diagnostic in diagnostics {
                io:println(string `  - [${diagnostic.severity}] ${diagnostic.message} at line ${diagnostic.range.start.line}`);
            }
        }
    } else {
        io:println("❌ Parsing failed:");
        foreach ast_parser:ParseError err in parseResult.errors {
            io:println(string `  - ${err.message} at line ${err.line}, column ${err.column}`);
        }
    }
    
    // Example 2: Get symbol at specific position
    io:println("\n--- Symbol at Position Example ---");
    
    ast_parser:Position cursorPosition = {
        line: 5,
        character: 20
    };
    
    ast_parser:SymbolInfo? symbolAtCursor = parser.getSymbolAtPosition(cursorPosition);
    if symbolAtCursor is ast_parser:SymbolInfo {
        io:println(string `Symbol at line ${cursorPosition.line}: ${symbolAtCursor.name}`);
        io:println("Symbol type: ", symbolAtCursor.'type);
        io:println("Symbol kind: ", symbolAtCursor.kind);
    }
    
    // Example 3: Parse with error recovery
    io:println("\n--- Error Recovery Example ---");
    
    string invalidCode = string `
        function main() {
            int x = 10
            // Missing semicolon above
            string message = "Hello"
            // Missing semicolon above
            io:println(message)
        }
    `;
    
    ast_parser:ParseResult errorResult = parser.parse(invalidCode, "error_example.bal");
    
    // Parser can still produce partial AST with error recovery
    if errorResult.ast is ast_parser:ASTNode {
        io:println("✅ Partial AST created despite errors");
        io:println("Errors found: ", errorResult.errors.length());
    }
    
    // Example 4: Extract specific node types
    io:println("\n--- Extract Functions Example ---");
    
    string codeWithFunctions = string `
        function calculateSum(int a, int b) returns int {
            return a + b;
        }
        
        function calculateProduct(int a, int b) returns int {
            return a * b;
        }
        
        public function processData(int[] numbers) returns int {
            int sum = 0;
            foreach int num in numbers {
                sum += num;
            }
            return sum;
        }
    `;
    
    ast_parser:ParseResult functionsResult = parser.parse(codeWithFunctions, "functions.bal");
    
    if functionsResult.ast is ast_parser:ASTNode {
        ast_parser:ASTNode[] functions = extractNodesByType(functionsResult.ast, "FunctionDefinition");
        io:println("Functions found: ", functions.length());
        
        foreach ast_parser:ASTNode func in functions {
            string? funcName = func.properties["name"];
            string? visibility = func.properties["visibility"];
            io:println(string `  - ${visibility ?: "private"} function ${funcName ?: "unknown"}`);
        }
    }
}

// Helper function to extract nodes by type
function extractNodesByType(ast_parser:ASTNode node, string nodeType) returns ast_parser:ASTNode[] {
    ast_parser:ASTNode[] result = [];
    
    if node.'type == nodeType {
        result.push(node);
    }
    
    foreach ast_parser:ASTNode child in node.children {
        ast_parser:ASTNode[] childResults = extractNodesByType(child, nodeType);
        result.push(...childResults);
    }
    
    return result;
}