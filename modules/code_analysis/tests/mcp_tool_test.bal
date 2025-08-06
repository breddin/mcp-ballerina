// MCP Tool Validation Tests
import ballerina/test;
import ballerina/io;
import code_analysis.mcp_integration;
import mcp_ballerina.mcp_protocol;

// Mock MCP Server for testing
class MockMcpServer {
    *mcp_protocol:McpServer;
    
    private map<json> registeredTools = {};
    
    public function registerTool(json toolDefinition) returns error? {
        string? name = toolDefinition.name;
        if name is string {
            self.registeredTools[name] = toolDefinition;
        }
        return;
    }
    
    public function getRegisteredTools() returns map<json> {
        return self.registeredTools;
    }
}

// Test MCP Integration initialization
@test:Config {}
function testMCPIntegrationInit() {
    MockMcpServer mockServer = new();
    mcp_integration:MCPCodeAnalysisIntegration integration = 
        new(mockServer);
    
    test:assertNotEquals(integration, (), "Integration should be initialized");
    
    // Check that tools are registered
    map<json> tools = mockServer.getRegisteredTools();
    test:assertTrue(tools.length() > 0, "Tools should be registered");
}

// Test parse_ast tool
@test:Config {}
function testParseASTTool() returns error? {
    MockMcpServer mockServer = new();
    mcp_integration:MCPCodeAnalysisIntegration integration = new(mockServer);
    
    json params = {
        "code": "function test() { return 42; }",
        "fileName": "test.bal"
    };
    
    json result = check integration.executeTool("mcp__ballerina__parse_ast", params);
    
    test:assertNotEquals(result, (), "Should return result");
    test:assertTrue(check result.success, "Parsing should succeed");
    test:assertNotEquals(result.ast, (), "Should have AST");
}

// Test analyze_semantics tool
@test:Config {}
function testAnalyzeSemanticsTool() returns error? {
    MockMcpServer mockServer = new();
    mcp_integration:MCPCodeAnalysisIntegration integration = new(mockServer);
    
    json params = {
        "code": "function add(int x, int y) returns int { return x + y; }",
        "includeWarnings": true
    };
    
    json result = check integration.executeTool("mcp__ballerina__analyze_semantics", params);
    
    test:assertNotEquals(result, (), "Should return result");
    test:assertNotEquals(result.errors, (), "Should have errors array");
    test:assertNotEquals(result.symbols, (), "Should have symbols");
}

// Test extract_symbols tool
@test:Config {}
function testExtractSymbolsTool() returns error? {
    MockMcpServer mockServer = new();
    mcp_integration:MCPCodeAnalysisIntegration integration = new(mockServer);
    
    json params = {
        "code": "
            function func1() {}
            type MyType int;
            class MyClass {}
        ",
        "symbolType": "all"
    };
    
    json result = check integration.executeTool("mcp__ballerina__extract_symbols", params);
    
    test:assertNotEquals(result, (), "Should return result");
    test:assertNotEquals(result.symbols, (), "Should have symbols");
    
    json? symbols = result.symbols;
    if symbols is json[] {
        test:assertTrue(symbols.length() >= 3, "Should have at least 3 symbols");
    }
}

// Test complete tool
@test:Config {}
function testCompleteTool() returns error? {
    MockMcpServer mockServer = new();
    mcp_integration:MCPCodeAnalysisIntegration integration = new(mockServer);
    
    json params = {
        "uri": "file:///test.bal",
        "line": 0,
        "character": 10,
        "code": "function test() {}"
    };
    
    json result = check integration.executeTool("mcp__ballerina__complete", params);
    
    test:assertNotEquals(result, (), "Should return completions");
    test:assertNotEquals(result.items, (), "Should have completion items");
}

// Test hover tool
@test:Config {}
function testHoverTool() returns error? {
    MockMcpServer mockServer = new();
    mcp_integration:MCPCodeAnalysisIntegration integration = new(mockServer);
    
    json params = {
        "uri": "file:///test.bal",
        "line": 0,
        "character": 9,
        "code": "function test() { return 42; }"
    };
    
    json result = check integration.executeTool("mcp__ballerina__hover", params);
    // Hover might return null if no symbol at position
}

// Test definition tool
@test:Config {}
function testDefinitionTool() returns error? {
    MockMcpServer mockServer = new();
    mcp_integration:MCPCodeAnalysisIntegration integration = new(mockServer);
    
    json params = {
        "uri": "file:///test.bal",
        "line": 2,
        "character": 10,
        "code": "
            function helper() { return 1; }
            function main() { helper(); }
        "
    };
    
    json result = check integration.executeTool("mcp__ballerina__definition", params);
    // Definition might be null if not found
}

// Test references tool
@test:Config {}
function testReferencesTool() returns error? {
    MockMcpServer mockServer = new();
    mcp_integration:MCPCodeAnalysisIntegration integration = new(mockServer);
    
    json params = {
        "uri": "file:///test.bal",
        "line": 0,
        "character": 4,
        "code": "int x = 10; function test() { int y = x; }"
    };
    
    json result = check integration.executeTool("mcp__ballerina__references", params);
    
    test:assertNotEquals(result, (), "Should return references");
    if result is json[] {
        // Should find references
    }
}

// Test document_symbols tool
@test:Config {}
function testDocumentSymbolsTool() returns error? {
    MockMcpServer mockServer = new();
    mcp_integration:MCPCodeAnalysisIntegration integration = new(mockServer);
    
    json params = {
        "uri": "file:///test.bal",
        "code": "
            function func1() {}
            function func2() {}
            type MyType int;
        "
    };
    
    json result = check integration.executeTool("mcp__ballerina__document_symbols", params);
    
    test:assertNotEquals(result, (), "Should return symbols");
    if result is json[] {
        test:assertTrue(result.length() >= 3, "Should have at least 3 symbols");
    }
}

// Test diagnostics tool
@test:Config {}
function testDiagnosticsTool() returns error? {
    MockMcpServer mockServer = new();
    mcp_integration:MCPCodeAnalysisIntegration integration = new(mockServer);
    
    json params = {
        "code": "function broken( { return 42; }",  // Syntax error
        "uri": "file:///test.bal",
        "severity": "all"
    };
    
    json result = check integration.executeTool("mcp__ballerina__diagnostics", params);
    
    test:assertNotEquals(result, (), "Should return diagnostics");
    test:assertNotEquals(result.diagnostics, (), "Should have diagnostics array");
}

// Test format tool
@test:Config {}
function testFormatTool() returns error? {
    MockMcpServer mockServer = new();
    mcp_integration:MCPCodeAnalysisIntegration integration = new(mockServer);
    
    json params = {
        "code": "function   test(  )  {return   42;  }",
        "tabSize": 4,
        "insertSpaces": true
    };
    
    json result = check integration.executeTool("mcp__ballerina__format", params);
    
    test:assertNotEquals(result, (), "Should return formatted code");
    test:assertNotEquals(result.formattedCode, (), "Should have formatted code");
}

// Test rename tool
@test:Config {}
function testRenameTool() returns error? {
    MockMcpServer mockServer = new();
    mcp_integration:MCPCodeAnalysisIntegration integration = new(mockServer);
    
    json params = {
        "uri": "file:///test.bal",
        "line": 0,
        "character": 9,
        "newName": "newFunction",
        "code": "function oldFunction() { return 42; }"
    };
    
    json result = check integration.executeTool("mcp__ballerina__rename", params);
    
    test:assertNotEquals(result, (), "Should return workspace edit");
}

// Test type_check tool
@test:Config {}
function testTypeCheckTool() returns error? {
    MockMcpServer mockServer = new();
    mcp_integration:MCPCodeAnalysisIntegration integration = new(mockServer);
    
    json params = {
        "code": "
            function test() {
                int x = 42;
                string s = \"hello\";
                boolean b = true;
            }
        ",
        "strict": false
    };
    
    json result = check integration.executeTool("mcp__ballerina__type_check", params);
    
    test:assertNotEquals(result, (), "Should return type check result");
    test:assertTrue(check result.success, "Type check should succeed for valid code");
}

// Test error handling for unknown tool
@test:Config {}
function testUnknownToolError() {
    MockMcpServer mockServer = new();
    mcp_integration:MCPCodeAnalysisIntegration integration = new(mockServer);
    
    json params = {};
    
    json|error result = integration.executeTool("mcp__ballerina__unknown_tool", params);
    
    test:assertTrue(result is error, "Should return error for unknown tool");
    if result is error {
        test:assertTrue(result.message().includes("Unknown tool"), 
                       "Error message should mention unknown tool");
    }
}

// Test tool registration
@test:Config {}
function testToolRegistration() {
    MockMcpServer mockServer = new();
    mcp_integration:MCPCodeAnalysisIntegration integration = new(mockServer);
    
    map<json> tools = mockServer.getRegisteredTools();
    
    // Check all expected tools are registered
    string[] expectedTools = [
        "mcp__ballerina__parse_ast",
        "mcp__ballerina__analyze_semantics",
        "mcp__ballerina__extract_symbols",
        "mcp__ballerina__complete",
        "mcp__ballerina__hover",
        "mcp__ballerina__definition",
        "mcp__ballerina__references",
        "mcp__ballerina__document_symbols",
        "mcp__ballerina__diagnostics",
        "mcp__ballerina__format",
        "mcp__ballerina__rename",
        "mcp__ballerina__type_check"
    ];
    
    foreach string toolName in expectedTools {
        test:assertTrue(tools.hasKey(toolName), 
                       "Tool should be registered: " + toolName);
    }
    
    test:assertEquals(tools.length(), expectedTools.length(), 
                     "Should have exactly " + expectedTools.length().toString() + " tools");
}

// Test tool input validation
@test:Config {}
function testToolInputValidation() {
    MockMcpServer mockServer = new();
    mcp_integration:MCPCodeAnalysisIntegration integration = new(mockServer);
    
    // Test with missing required parameter
    json invalidParams = {
        // Missing "code" parameter
        "fileName": "test.bal"
    };
    
    json|error result = integration.executeTool("mcp__ballerina__parse_ast", invalidParams);
    
    test:assertTrue(result is error, "Should fail with missing required parameter");
}

// Test batch tool execution
@test:Config {}
function testBatchToolExecution() returns error? {
    MockMcpServer mockServer = new();
    mcp_integration:MCPCodeAnalysisIntegration integration = new(mockServer);
    
    string code = "function test() { return 42; }";
    
    // Execute multiple tools on same code
    json parseResult = check integration.executeTool("mcp__ballerina__parse_ast", {
        "code": code,
        "fileName": "batch.bal"
    });
    
    json semanticResult = check integration.executeTool("mcp__ballerina__analyze_semantics", {
        "code": code,
        "includeWarnings": true
    });
    
    json symbolResult = check integration.executeTool("mcp__ballerina__extract_symbols", {
        "code": code,
        "symbolType": "all"
    });
    
    test:assertNotEquals(parseResult, (), "Parse should succeed");
    test:assertNotEquals(semanticResult, (), "Semantic analysis should succeed");
    test:assertNotEquals(symbolResult, (), "Symbol extraction should succeed");
}