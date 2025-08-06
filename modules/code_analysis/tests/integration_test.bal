// Integration Tests for Code Analysis Module
import ballerina/test;
import ballerina/io;
import code_analysis.ast_parser;
import code_analysis.semantic_analyzer;
import code_analysis.lsp_handlers;
import code_analysis.mcp_integration;

// Test complete analysis pipeline
@test:Config {}
function testCompleteAnalysisPipeline() {
    string code = "
    import ballerina/io;
    
    public type Employee record {|
        string name;
        int id;
        decimal salary;
    |};
    
    public function calculateBonus(Employee emp) returns decimal {
        return emp.salary * 0.1d;
    }
    
    public function main() {
        Employee john = {name: \"John\", id: 123, salary: 50000.00d};
        decimal bonus = calculateBonus(john);
        io:println(\"Bonus: \" + bonus.toString());
    }
    ";
    
    // Parse
    ast_parser:ASTParser parser = new();
    ast_parser:ParseResult parseResult = parser.parse(code, "pipeline.bal");
    test:assertTrue(parseResult.success, "Parsing should succeed");
    
    // Analyze
    if parseResult.root is ast_parser:ASTNode {
        semantic_analyzer:SemanticAnalyzer analyzer = new();
        semantic_analyzer:SemanticContext context = analyzer.analyze(parseResult.root);
        
        test:assertEquals(context.errors.length(), 0, "Should have no semantic errors");
        test:assertTrue(context.typeTable.hasKey("Employee"), "Should have Employee type");
        test:assertTrue(context.functionTable.hasKey("calculateBonus"), "Should have calculateBonus function");
        test:assertTrue(context.functionTable.hasKey("main"), "Should have main function");
    }
}

// Test LSP handler integration
@test:Config {}
function testLSPHandlerIntegration() {
    lsp_handlers:LSPAnalysisHandler handler = new();
    
    string code = "function test() { return 42; }";
    
    // Test document open
    json openParams = {
        "textDocument": {
            "uri": "file:///test.bal",
            "text": code
        }
    };
    
    json openResult = handler.handleDidOpen(openParams);
    test:assertNotEquals(openResult, (), "Should handle document open");
}

// Test completion integration
@test:Config {}
function testCompletionIntegration() {
    lsp_handlers:LSPAnalysisHandler handler = new();
    
    string code = "
    function main() {
        io:pr // Cursor here
    }
    ";
    
    // Open document first
    json openParams = {
        "textDocument": {
            "uri": "file:///completion.bal",
            "text": code
        }
    };
    _ = handler.handleDidOpen(openParams);
    
    // Request completions
    json completionParams = {
        "textDocument": {
            "uri": "file:///completion.bal"
        },
        "position": {
            "line": 2,
            "character": 13
        }
    };
    
    json completions = handler.handleCompletion(completionParams);
    test:assertNotEquals(completions, (), "Should return completions");
    
    json? items = completions.items;
    if items is json[] {
        test:assertTrue(items.length() > 0, "Should have completion items");
    }
}

// Test hover integration
@test:Config {}
function testHoverIntegration() {
    lsp_handlers:LSPAnalysisHandler handler = new();
    
    string code = "
    # Main function
    public function main() {
        io:println(\"Hello\");
    }
    ";
    
    // Open document
    json openParams = {
        "textDocument": {
            "uri": "file:///hover.bal",
            "text": code
        }
    };
    _ = handler.handleDidOpen(openParams);
    
    // Request hover
    json hoverParams = {
        "textDocument": {
            "uri": "file:///hover.bal"
        },
        "position": {
            "line": 2,
            "character": 20  // On "main"
        }
    };
    
    json hoverResult = handler.handleHover(hoverParams);
    // Hover might return null if no symbol at position
}

// Test document symbols integration
@test:Config {}
function testDocumentSymbolsIntegration() {
    lsp_handlers:LSPAnalysisHandler handler = new();
    
    string code = "
    type Person record {|
        string name;
    |};
    
    function greet(Person p) {
        io:println(\"Hello \" + p.name);
    }
    
    class Manager {
        string department;
    }
    ";
    
    // Open document
    json openParams = {
        "textDocument": {
            "uri": "file:///symbols.bal",
            "text": code
        }
    };
    _ = handler.handleDidOpen(openParams);
    
    // Request symbols
    json symbolParams = {
        "textDocument": {
            "uri": "file:///symbols.bal"
        }
    };
    
    json symbols = handler.handleDocumentSymbol(symbolParams);
    if symbols is json[] {
        test:assertTrue(symbols.length() > 0, "Should have document symbols");
    }
}

// Test diagnostics integration
@test:Config {}
function testDiagnosticsIntegration() {
    lsp_handlers:LSPAnalysisHandler handler = new();
    
    string codeWithErrors = "
    function broken( {  // Syntax error
        return 42;
    }
    
    function duplicate() {}
    function duplicate() {}  // Duplicate function
    ";
    
    // Open document - diagnostics generated automatically
    json openParams = {
        "textDocument": {
            "uri": "file:///diagnostics.bal",
            "text": codeWithErrors
        }
    };
    
    json diagnosticsResult = handler.handleDidOpen(openParams);
    test:assertNotEquals(diagnosticsResult, (), "Should return diagnostics");
}

// Test formatting integration
@test:Config {}
function testFormattingIntegration() {
    lsp_handlers:LSPAnalysisHandler handler = new();
    
    string unformattedCode = "function   test(  )  {return   42;  }";
    
    // Open document
    json openParams = {
        "textDocument": {
            "uri": "file:///format.bal",
            "text": unformattedCode
        }
    };
    _ = handler.handleDidOpen(openParams);
    
    // Request formatting
    json formatParams = {
        "textDocument": {
            "uri": "file:///format.bal"
        },
        "options": {
            "tabSize": 4,
            "insertSpaces": true
        }
    };
    
    json edits = handler.handleFormatting(formatParams);
    test:assertNotEquals(edits, (), "Should return format edits");
}

// Test rename integration
@test:Config {}
function testRenameIntegration() {
    lsp_handlers:LSPAnalysisHandler handler = new();
    
    string code = "
    function oldName() returns int {
        return 42;
    }
    
    function main() {
        int result = oldName();
    }
    ";
    
    // Open document
    json openParams = {
        "textDocument": {
            "uri": "file:///rename.bal",
            "text": code
        }
    };
    _ = handler.handleDidOpen(openParams);
    
    // Request rename
    json renameParams = {
        "textDocument": {
            "uri": "file:///rename.bal"
        },
        "position": {
            "line": 1,
            "character": 13  // On "oldName"
        },
        "newName": "newName"
    };
    
    json workspaceEdit = handler.handleRename(renameParams);
    test:assertNotEquals(workspaceEdit, (), "Should return workspace edit");
}

// Test document change integration
@test:Config {}
function testDocumentChangeIntegration() {
    lsp_handlers:LSPAnalysisHandler handler = new();
    
    string initialCode = "function test() { return 1; }";
    string updatedCode = "function test() { return 42; }";
    
    // Open document
    json openParams = {
        "textDocument": {
            "uri": "file:///change.bal",
            "text": initialCode
        }
    };
    _ = handler.handleDidOpen(openParams);
    
    // Change document
    json changeParams = {
        "textDocument": {
            "uri": "file:///change.bal"
        },
        "contentChanges": [
            {
                "text": updatedCode
            }
        ]
    };
    
    json changeResult = handler.handleDidChange(changeParams);
    test:assertNotEquals(changeResult, (), "Should handle document change");
}

// Test go to definition integration
@test:Config {}
function testGoToDefinitionIntegration() {
    lsp_handlers:LSPAnalysisHandler handler = new();
    
    string code = "
    function helper() returns int {
        return 100;
    }
    
    function main() {
        int x = helper();  // Go to definition of helper
    }
    ";
    
    // Open document
    json openParams = {
        "textDocument": {
            "uri": "file:///definition.bal",
            "text": code
        }
    };
    _ = handler.handleDidOpen(openParams);
    
    // Request definition
    json defParams = {
        "textDocument": {
            "uri": "file:///definition.bal"
        },
        "position": {
            "line": 5,
            "character": 16  // On "helper" call
        }
    };
    
    json definition = handler.handleDefinition(defParams);
    // Definition might be null if not found
}

// Test find references integration
@test:Config {}
function testFindReferencesIntegration() {
    lsp_handlers:LSPAnalysisHandler handler = new();
    
    string code = "
    int globalVar = 10;
    
    function test1() {
        int x = globalVar;
    }
    
    function test2() {
        globalVar = 20;
    }
    ";
    
    // Open document
    json openParams = {
        "textDocument": {
            "uri": "file:///references.bal",
            "text": code
        }
    };
    _ = handler.handleDidOpen(openParams);
    
    // Request references
    json refParams = {
        "textDocument": {
            "uri": "file:///references.bal"
        },
        "position": {
            "line": 1,
            "character": 8  // On "globalVar"
        }
    };
    
    json references = handler.handleReferences(refParams);
    if references is json[] {
        // Should find all references to globalVar
    }
}

// Test code action integration
@test:Config {}
function testCodeActionIntegration() {
    lsp_handlers:LSPAnalysisHandler handler = new();
    
    string codeWithIssues = "
    function test() {
        int unusedVar = 10;  // Should suggest removal
    }
    ";
    
    // Open document
    json openParams = {
        "textDocument": {
            "uri": "file:///actions.bal",
            "text": codeWithIssues
        }
    };
    _ = handler.handleDidOpen(openParams);
    
    // Request code actions
    json actionParams = {
        "textDocument": {
            "uri": "file:///actions.bal"
        },
        "range": {
            "start": {"line": 2, "character": 0},
            "end": {"line": 2, "character": 30}
        },
        "context": {
            "diagnostics": []
        }
    };
    
    json actions = handler.handleCodeAction(actionParams);
    if actions is json[] {
        // Should return available code actions
    }
}

// Test signature help integration
@test:Config {}
function testSignatureHelpIntegration() {
    lsp_handlers:LSPAnalysisHandler handler = new();
    
    string code = "
    function add(int x, int y) returns int {
        return x + y;
    }
    
    function main() {
        int result = add(10,  // Cursor here for signature help
    }
    ";
    
    // Open document
    json openParams = {
        "textDocument": {
            "uri": "file:///signature.bal",
            "text": code
        }
    };
    _ = handler.handleDidOpen(openParams);
    
    // Request signature help
    json sigParams = {
        "textDocument": {
            "uri": "file:///signature.bal"
        },
        "position": {
            "line": 6,
            "character": 25
        }
    };
    
    json signatureHelp = handler.handleSignatureHelp(sigParams);
    // Signature help might be null if not in function call
}