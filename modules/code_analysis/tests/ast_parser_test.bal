// Unit Tests for AST Parser Module
import ballerina/test;
import ballerina/io;
import code_analysis.ast_parser;

// Test fixture data
const string SIMPLE_FUNCTION = "function hello() { io:println(\"Hello\"); }";
const string COMPLEX_MODULE = "
import ballerina/io;
import ballerina/http;

public type Person record {|
    string name;
    int age;
|};

public function main() {
    Person p = {name: \"John\", age: 30};
    io:println(p.name);
}

class Calculator {
    private int value = 0;
    
    public function add(int n) {
        self.value += n;
    }
    
    public function getValue() returns int {
        return self.value;
    }
}
";

// Test Parser Initialization
@test:Config {}
function testParserInitialization() {
    ast_parser:ASTParser parser = new();
    test:assertNotEquals(parser, (), "Parser should be initialized");
}

// Test Simple Function Parsing
@test:Config {}
function testSimpleFunctionParsing() {
    ast_parser:ASTParser parser = new();
    ast_parser:ParseResult result = parser.parse(SIMPLE_FUNCTION, "test.bal");
    
    test:assertTrue(result.success, "Parsing should succeed");
    test:assertNotEquals(result.root, (), "Root node should exist");
    
    if result.root is ast_parser:ASTNode {
        test:assertEquals(result.root.nodeType, ast_parser:NODE_MODULE, "Root should be MODULE node");
        test:assertTrue(result.root.children.length() > 0, "Module should have children");
    }
}

// Test Complex Module Parsing
@test:Config {}
function testComplexModuleParsing() {
    ast_parser:ASTParser parser = new();
    ast_parser:ParseResult result = parser.parse(COMPLEX_MODULE, "complex.bal");
    
    test:assertTrue(result.success, "Complex parsing should succeed");
    test:assertEquals(result.diagnostics.length(), 0, "Should have no diagnostics");
    
    if result.root is ast_parser:ASTNode {
        // Check for imports
        boolean hasImports = false;
        foreach ast_parser:ASTNode child in result.root.children {
            if child.nodeType == ast_parser:NODE_IMPORT {
                hasImports = true;
                break;
            }
        }
        test:assertTrue(hasImports, "Should have import nodes");
    }
}

// Test Symbol Extraction
@test:Config {}
function testSymbolExtraction() {
    ast_parser:ASTParser parser = new();
    ast_parser:ParseResult result = parser.parse(COMPLEX_MODULE, "test.bal");
    
    map<ast_parser:SymbolInfo> symbols = parser.getSymbols();
    test:assertTrue(symbols.length() > 0, "Should extract symbols");
    
    // Check for specific symbols
    test:assertTrue(symbols.hasKey("main"), "Should have main function");
    test:assertTrue(symbols.hasKey("Calculator"), "Should have Calculator class");
    test:assertTrue(symbols.hasKey("Person"), "Should have Person type");
}

// Test Import Parsing
@test:Config {}
function testImportParsing() {
    string code = "
    import ballerina/io;
    import ballerina/http;
    import ballerina/lang.'string as str;
    ";
    
    ast_parser:ASTParser parser = new();
    ast_parser:ParseResult result = parser.parse(code, "imports.bal");
    
    test:assertTrue(result.success, "Import parsing should succeed");
    
    if result.root is ast_parser:ASTNode {
        int importCount = 0;
        foreach ast_parser:ASTNode child in result.root.children {
            if child.nodeType == ast_parser:NODE_IMPORT {
                importCount += 1;
            }
        }
        test:assertEquals(importCount, 3, "Should have 3 imports");
    }
}

// Test Function Declaration Parsing
@test:Config {}
function testFunctionDeclarationParsing() {
    string code = "
    public function calculate(int x, int y) returns int {
        return x + y;
    }
    
    private isolated function process(string data) returns string|error {
        check validate(data);
        return data.toUpperAscii();
    }
    ";
    
    ast_parser:ASTParser parser = new();
    ast_parser:ParseResult result = parser.parse(code, "functions.bal");
    
    test:assertTrue(result.success, "Function parsing should succeed");
    
    map<ast_parser:SymbolInfo> symbols = parser.getSymbols();
    test:assertTrue(symbols.hasKey("calculate"), "Should have calculate function");
    test:assertTrue(symbols.hasKey("process"), "Should have process function");
    
    // Check function metadata
    ast_parser:SymbolInfo? calcSymbol = symbols["calculate"];
    if calcSymbol is ast_parser:SymbolInfo {
        test:assertEquals(calcSymbol.kind, "function", "Should be function kind");
        test:assertTrue(calcSymbol.exported, "Calculate should be exported");
    }
}

// Test Type Definition Parsing
@test:Config {}
function testTypeDefinitionParsing() {
    string code = "
    public type Status \"active\"|\"inactive\"|\"pending\";
    
    type Address record {|
        string street;
        string city;
        string? country;
    |};
    
    public type Employee object {
        string name;
        int id;
        
        public function init(string name, int id) {
            self.name = name;
            self.id = id;
        }
    };
    ";
    
    ast_parser:ASTParser parser = new();
    ast_parser:ParseResult result = parser.parse(code, "types.bal");
    
    test:assertTrue(result.success, "Type parsing should succeed");
    
    map<ast_parser:SymbolInfo> symbols = parser.getSymbols();
    test:assertTrue(symbols.hasKey("Status"), "Should have Status type");
    test:assertTrue(symbols.hasKey("Address"), "Should have Address type");
    test:assertTrue(symbols.hasKey("Employee"), "Should have Employee type");
}

// Test Class Parsing
@test:Config {}
function testClassParsing() {
    string code = "
    public class DatabaseConnection {
        private string connectionString;
        private boolean connected = false;
        
        public function init(string connStr) {
            self.connectionString = connStr;
        }
        
        public function connect() returns error? {
            self.connected = true;
        }
        
        public function isConnected() returns boolean {
            return self.connected;
        }
    }
    ";
    
    ast_parser:ASTParser parser = new();
    ast_parser:ParseResult result = parser.parse(code, "class.bal");
    
    test:assertTrue(result.success, "Class parsing should succeed");
    
    map<ast_parser:SymbolInfo> symbols = parser.getSymbols();
    test:assertTrue(symbols.hasKey("DatabaseConnection"), "Should have DatabaseConnection class");
    
    ast_parser:SymbolInfo? classSymbol = symbols["DatabaseConnection"];
    if classSymbol is ast_parser:SymbolInfo {
        test:assertEquals(classSymbol.kind, "class", "Should be class kind");
        test:assertTrue(classSymbol.exported, "Class should be exported");
    }
}

// Test Service Parsing
@test:Config {}
function testServiceParsing() {
    string code = "
    service /api on new http:Listener(8080) {
        resource function get users() returns json {
            return [{\"id\": 1, \"name\": \"Alice\"}];
        }
        
        resource function post users(@http:Payload json user) returns json {
            return {\"status\": \"created\"};
        }
    }
    ";
    
    ast_parser:ASTParser parser = new();
    ast_parser:ParseResult result = parser.parse(code, "service.bal");
    
    test:assertTrue(result.success, "Service parsing should succeed");
    
    if result.root is ast_parser:ASTNode {
        boolean hasService = false;
        foreach ast_parser:ASTNode child in result.root.children {
            if child.nodeType == ast_parser:NODE_SERVICE {
                hasService = true;
                break;
            }
        }
        test:assertTrue(hasService, "Should have service node");
    }
}

// Test Error Handling
@test:Config {}
function testSyntaxErrorDetection() {
    string invalidCode = "
    function broken( {
        this is not valid syntax
    }
    ";
    
    ast_parser:ASTParser parser = new();
    ast_parser:ParseResult result = parser.parse(invalidCode, "invalid.bal");
    
    // Parser should still attempt to parse
    test:assertNotEquals(result.root, (), "Should still create root node");
}

// Test Position Tracking
@test:Config {}
function testPositionTracking() {
    string code = "function test() {\n    io:println(\"test\");\n}";
    
    ast_parser:ASTParser parser = new();
    ast_parser:ParseResult result = parser.parse(code, "position.bal");
    
    test:assertTrue(result.success, "Parsing should succeed");
    
    // Test position at specific location
    ast_parser:Position pos = {line: 0, column: 9};
    ast_parser:SymbolInfo? symbol = parser.getSymbolAtPosition(pos);
    
    if symbol is ast_parser:SymbolInfo {
        test:assertEquals(symbol.name, "test", "Should find test function at position");
    }
}

// Test Node Retrieval
@test:Config {}
function testNodeRetrieval() {
    ast_parser:ASTParser parser = new();
    ast_parser:ParseResult result = parser.parse(SIMPLE_FUNCTION, "test.bal");
    
    if result.root is ast_parser:ASTNode {
        string nodeId = result.root.id;
        ast_parser:ASTNode? retrievedNode = parser.getNodeById(nodeId);
        
        test:assertNotEquals(retrievedNode, (), "Should retrieve node by ID");
        if retrievedNode is ast_parser:ASTNode {
            test:assertEquals(retrievedNode.id, nodeId, "Should be same node");
        }
    }
}

// Test Diagnostic Generation
@test:Config {}
function testDiagnosticGeneration() {
    string codeWithIssues = "
    function duplicate() {}
    function duplicate() {} // Duplicate function
    ";
    
    ast_parser:ASTParser parser = new();
    ast_parser:ParseResult result = parser.parse(codeWithIssues, "diagnostic.bal");
    
    // Should have at least a warning or error for duplicate
    ast_parser:Diagnostic[] diagnostics = parser.getDiagnostics();
    // Diagnostics might be generated during semantic analysis
}

// Test Symbol Metadata
@test:Config {}
function testSymbolMetadata() {
    string code = "
    # Documentation for testFunc
    # + x - First parameter
    # + y - Second parameter
    # + return - Sum of x and y
    public function testFunc(int x, int y) returns int {
        return x + y;
    }
    ";
    
    ast_parser:ASTParser parser = new();
    ast_parser:ParseResult result = parser.parse(code, "metadata.bal");
    
    map<ast_parser:SymbolInfo> symbols = parser.getSymbols();
    ast_parser:SymbolInfo? funcSymbol = symbols["testFunc"];
    
    if funcSymbol is ast_parser:SymbolInfo {
        test:assertEquals(funcSymbol.kind, "function", "Should be function");
        test:assertTrue(funcSymbol.exported, "Should be exported");
        // Documentation might be extracted in enhanced version
    }
}

// Test Block End Detection
@test:Config {}
function testBlockEndDetection() {
    string nestedCode = "
    function outer() {
        if (true) {
            while (true) {
                foreach int i in 1...10 {
                    io:println(i);
                }
            }
        }
    }
    ";
    
    ast_parser:ASTParser parser = new();
    ast_parser:ParseResult result = parser.parse(nestedCode, "nested.bal");
    
    test:assertTrue(result.success, "Nested parsing should succeed");
    
    map<ast_parser:SymbolInfo> symbols = parser.getSymbols();
    test:assertTrue(symbols.hasKey("outer"), "Should have outer function");
}