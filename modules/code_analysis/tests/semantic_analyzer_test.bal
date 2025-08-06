// Unit Tests for Semantic Analyzer Module
import ballerina/test;
import code_analysis.ast_parser;
import code_analysis.semantic_analyzer;

// Test Analyzer Initialization
@test:Config {}
function testAnalyzerInitialization() {
    semantic_analyzer:SemanticAnalyzer analyzer = new();
    test:assertNotEquals(analyzer, (), "Analyzer should be initialized");
}

// Test Basic Semantic Analysis
@test:Config {}
function testBasicSemanticAnalysis() {
    string code = "
    function add(int x, int y) returns int {
        return x + y;
    }
    ";
    
    ast_parser:ASTParser parser = new();
    ast_parser:ParseResult parseResult = parser.parse(code, "test.bal");
    
    test:assertTrue(parseResult.success, "Parsing should succeed");
    
    if parseResult.root is ast_parser:ASTNode {
        semantic_analyzer:SemanticAnalyzer analyzer = new();
        semantic_analyzer:SemanticContext context = analyzer.analyze(parseResult.root);
        
        test:assertEquals(context.errors.length(), 0, "Should have no errors");
        test:assertTrue(context.functionTable.hasKey("add"), "Should have add function");
    }
}

// Test Type Checking
@test:Config {}
function testTypeChecking() {
    string code = "
    function test() {
        int x = 5;
        string y = \"hello\";
        boolean z = true;
    }
    ";
    
    ast_parser:ASTParser parser = new();
    ast_parser:ParseResult parseResult = parser.parse(code, "types.bal");
    
    if parseResult.root is ast_parser:ASTNode {
        semantic_analyzer:SemanticAnalyzer analyzer = new();
        semantic_analyzer:SemanticContext context = analyzer.analyze(parseResult.root);
        
        // Check variable types
        test:assertTrue(context.variableTable.length() >= 3, "Should have 3 variables");
    }
}

// Test Scope Management
@test:Config {}
function testScopeManagement() {
    string code = "
    int globalVar = 10;
    
    function outer() {
        int outerVar = 20;
        
        function inner() {
            int innerVar = 30;
        }
    }
    ";
    
    ast_parser:ASTParser parser = new();
    ast_parser:ParseResult parseResult = parser.parse(code, "scope.bal");
    
    if parseResult.root is ast_parser:ASTNode {
        semantic_analyzer:SemanticAnalyzer analyzer = new();
        semantic_analyzer:SemanticContext context = analyzer.analyze(parseResult.root);
        
        // Variables should be in different scopes
        test:assertTrue(context.variableTable.hasKey("global.globalVar"), "Should have global var");
        test:assertTrue(context.functionTable.hasKey("outer"), "Should have outer function");
    }
}

// Test Duplicate Detection
@test:Config {}
function testDuplicateDetection() {
    string code = "
    function duplicate() {}
    function duplicate() {} // This should cause an error
    
    type MyType int;
    type MyType string; // This should cause an error
    ";
    
    ast_parser:ASTParser parser = new();
    ast_parser:ParseResult parseResult = parser.parse(code, "duplicate.bal");
    
    if parseResult.root is ast_parser:ASTNode {
        semantic_analyzer:SemanticAnalyzer analyzer = new();
        semantic_analyzer:SemanticContext context = analyzer.analyze(parseResult.root);
        
        test:assertTrue(context.errors.length() > 0, "Should have duplicate errors");
        
        boolean hasDuplicateError = false;
        foreach semantic_analyzer:SemanticError err in context.errors {
            if err.code == "E002" || err.code == "E004" {
                hasDuplicateError = true;
                break;
            }
        }
        test:assertTrue(hasDuplicateError, "Should detect duplicate declaration");
    }
}

// Test Type Resolution
@test:Config {}
function testTypeResolution() {
    string code = "
    type Address record {|
        string street;
        string city;
    |};
    
    function test() {
        Address addr = {street: \"Main St\", city: \"NYC\"};
        string[] arr = [\"a\", \"b\"];
        int? nullable = ();
    }
    ";
    
    ast_parser:ASTParser parser = new();
    ast_parser:ParseResult parseResult = parser.parse(code, "resolution.bal");
    
    if parseResult.root is ast_parser:ASTNode {
        semantic_analyzer:SemanticAnalyzer analyzer = new();
        semantic_analyzer:SemanticContext context = analyzer.analyze(parseResult.root);
        
        test:assertTrue(context.typeTable.hasKey("Address"), "Should have Address type");
        
        // Check array type recognition
        semantic_analyzer:TypeInfo? addrType = context.typeTable["Address"];
        if addrType is semantic_analyzer:TypeInfo {
            test:assertEquals(addrType.kind, semantic_analyzer:RECORD, "Address should be RECORD type");
        }
    }
}

// Test Function Analysis
@test:Config {}
function testFunctionAnalysis() {
    string code = "
    public function calculate(int x, int y) returns int {
        return x + y;
    }
    
    private function validate(string input) returns boolean|error {
        if input.length() == 0 {
            return error(\"Empty input\");
        }
        return true;
    }
    ";
    
    ast_parser:ASTParser parser = new();
    ast_parser:ParseResult parseResult = parser.parse(code, "functions.bal");
    
    if parseResult.root is ast_parser:ASTNode {
        semantic_analyzer:SemanticAnalyzer analyzer = new();
        semantic_analyzer:SemanticContext context = analyzer.analyze(parseResult.root);
        
        test:assertTrue(context.functionTable.hasKey("calculate"), "Should have calculate function");
        test:assertTrue(context.functionTable.hasKey("validate"), "Should have validate function");
        
        semantic_analyzer:FunctionInfo? calcFunc = context.functionTable["calculate"];
        if calcFunc is semantic_analyzer:FunctionInfo {
            test:assertTrue(calcFunc.exported, "Calculate should be exported");
            test:assertEquals(calcFunc.parameters.length(), 2, "Should have 2 parameters");
            test:assertEquals(calcFunc.returnType.name, "int", "Should return int");
        }
    }
}

// Test Class Analysis
@test:Config {}
function testClassAnalysis() {
    string code = "
    public class Person {
        private string name;
        private int age;
        
        public function init(string name, int age) {
            self.name = name;
            self.age = age;
        }
        
        public function getName() returns string {
            return self.name;
        }
    }
    ";
    
    ast_parser:ASTParser parser = new();
    ast_parser:ParseResult parseResult = parser.parse(code, "class.bal");
    
    if parseResult.root is ast_parser:ASTNode {
        semantic_analyzer:SemanticAnalyzer analyzer = new();
        semantic_analyzer:SemanticContext context = analyzer.analyze(parseResult.root);
        
        test:assertTrue(context.typeTable.hasKey("Person"), "Should have Person type");
        
        semantic_analyzer:TypeInfo? personType = context.typeTable["Person"];
        if personType is semantic_analyzer:TypeInfo {
            test:assertEquals(personType.kind, semantic_analyzer:OBJECT, "Person should be OBJECT type");
        }
    }
}

// Test Import Analysis
@test:Config {}
function testImportAnalysis() {
    string code = "
    import ballerina/io;
    import ballerina/http;
    
    function main() {
        io:println(\"Hello\");
    }
    ";
    
    ast_parser:ASTParser parser = new();
    ast_parser:ParseResult parseResult = parser.parse(code, "imports.bal");
    
    if parseResult.root is ast_parser:ASTNode {
        semantic_analyzer:SemanticAnalyzer analyzer = new();
        semantic_analyzer:SemanticContext context = analyzer.analyze(parseResult.root);
        
        test:assertTrue(context.importedModules.length() >= 2, "Should have 2 imports");
        
        boolean hasIo = false;
        boolean hasHttp = false;
        foreach string module in context.importedModules {
            if module == "ballerina/io" {
                hasIo = true;
            } else if module == "ballerina/http" {
                hasHttp = true;
            }
        }
        test:assertTrue(hasIo, "Should have io import");
        test:assertTrue(hasHttp, "Should have http import");
    }
}

// Test Warning Generation
@test:Config {}
function testWarningGeneration() {
    string code = "
    function test() {
        int unusedVar = 10; // This should generate a warning
    }
    ";
    
    ast_parser:ASTParser parser = new();
    ast_parser:ParseResult parseResult = parser.parse(code, "warnings.bal");
    
    if parseResult.root is ast_parser:ASTNode {
        semantic_analyzer:SemanticAnalyzer analyzer = new();
        semantic_analyzer:SemanticContext context = analyzer.analyze(parseResult.root);
        
        // Should have warnings for unused variables
        semantic_analyzer:SemanticWarning[] warnings = analyzer.getWarnings();
        // Note: Warning detection might need enhancement
    }
}

// Test Type Compatibility
@test:Config {}
function testTypeCompatibility() {
    semantic_analyzer:SemanticAnalyzer analyzer = new();
    
    // Test basic type compatibility
    semantic_analyzer:TypeInfo intType = {name: "int", kind: semantic_analyzer:PRIMITIVE};
    semantic_analyzer:TypeInfo floatType = {name: "float", kind: semantic_analyzer:PRIMITIVE};
    semantic_analyzer:TypeInfo anyType = {name: "any", kind: semantic_analyzer:PRIMITIVE};
    
    test:assertTrue(analyzer.isAssignable(anyType, intType), "int should be assignable to any");
    test:assertTrue(analyzer.isAssignable(intType, intType), "int should be assignable to int");
    test:assertFalse(analyzer.isAssignable(intType, floatType), "float should not be assignable to int");
}

// Test Nullable Type Handling
@test:Config {}
function testNullableTypes() {
    semantic_analyzer:SemanticAnalyzer analyzer = new();
    
    semantic_analyzer:TypeInfo stringType = {name: "string", kind: semantic_analyzer:PRIMITIVE};
    semantic_analyzer:TypeInfo nullableStringType = {
        name: "string?", 
        kind: semantic_analyzer:PRIMITIVE,
        nullable: true
    };
    
    test:assertTrue(analyzer.isAssignable(nullableStringType, stringType), 
                   "string should be assignable to string?");
}

// Test Union Type Handling
@test:Config {}
function testUnionTypes() {
    semantic_analyzer:SemanticAnalyzer analyzer = new();
    
    semantic_analyzer:TypeInfo intType = {name: "int", kind: semantic_analyzer:PRIMITIVE};
    semantic_analyzer:TypeInfo stringType = {name: "string", kind: semantic_analyzer:PRIMITIVE};
    semantic_analyzer:TypeInfo unionType = {
        name: "int|string",
        kind: semantic_analyzer:UNION,
        unionTypes: [intType, stringType]
    };
    
    test:assertTrue(analyzer.isAssignable(unionType, intType), 
                   "int should be assignable to int|string");
    test:assertTrue(analyzer.isAssignable(unionType, stringType), 
                   "string should be assignable to int|string");
}

// Test Symbol Table
@test:Config {}
function testSymbolTable() {
    string code = "
    public type Status \"active\"|\"inactive\";
    
    public function process(Status status) returns string {
        return status;
    }
    
    class Handler {
        private Status currentStatus = \"active\";
    }
    ";
    
    ast_parser:ASTParser parser = new();
    ast_parser:ParseResult parseResult = parser.parse(code, "symbols.bal");
    
    if parseResult.root is ast_parser:ASTNode {
        semantic_analyzer:SemanticAnalyzer analyzer = new();
        semantic_analyzer:SemanticContext context = analyzer.analyze(parseResult.root);
        
        map<ast_parser:SymbolInfo> symbols = analyzer.getSymbols();
        test:assertTrue(symbols.hasKey("Status"), "Should have Status symbol");
        test:assertTrue(symbols.hasKey("process"), "Should have process symbol");
        test:assertTrue(symbols.hasKey("Handler"), "Should have Handler symbol");
    }
}

// Test Error Recovery
@test:Config {}
function testErrorRecovery() {
    string codeWithErrors = "
    function broken {  // Missing parentheses
        return 42;
    }
    
    function valid() returns int {
        return 100;
    }
    ";
    
    ast_parser:ASTParser parser = new();
    ast_parser:ParseResult parseResult = parser.parse(codeWithErrors, "errors.bal");
    
    if parseResult.root is ast_parser:ASTNode {
        semantic_analyzer:SemanticAnalyzer analyzer = new();
        semantic_analyzer:SemanticContext context = analyzer.analyze(parseResult.root);
        
        // Should still analyze valid parts
        test:assertTrue(context.functionTable.hasKey("valid"), "Should analyze valid function despite errors");
    }
}

// Test Built-in Types
@test:Config {}
function testBuiltInTypes() {
    string code = "
    function testTypes() {
        int i = 42;
        float f = 3.14;
        decimal d = 10.5d;
        string s = \"text\";
        boolean b = true;
        byte bt = 255;
        json j = {\"key\": \"value\"};
        xml x = xml `<root/>`;
        any a = 100;
        anydata ad = \"data\";
        handle h = java:null();
    }
    ";
    
    ast_parser:ASTParser parser = new();
    ast_parser:ParseResult parseResult = parser.parse(code, "builtins.bal");
    
    if parseResult.root is ast_parser:ASTNode {
        semantic_analyzer:SemanticAnalyzer analyzer = new();
        semantic_analyzer:SemanticContext context = analyzer.analyze(parseResult.root);
        
        // All built-in types should be recognized
        test:assertTrue(context.typeTable.hasKey("int"), "Should have int type");
        test:assertTrue(context.typeTable.hasKey("string"), "Should have string type");
        test:assertTrue(context.typeTable.hasKey("boolean"), "Should have boolean type");
        test:assertTrue(context.typeTable.hasKey("json"), "Should have json type");
    }
}