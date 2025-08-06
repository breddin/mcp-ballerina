// Test Suite for Quick Fixes Provider
// Tests automated code fixes and actions

import ballerina/test;
import modules.refactoring;
import modules.code_analysis.ast_parser;

// Test missing import quick fix
@test:Config {
    groups: ["quickfix", "import"]
}
function testMissingImportQuickFix() {
    refactoring:QuickFixProvider provider = new();
    
    string sourceCode = string `
function main() {
    io:println("Hello");  // io module not imported
}`;
    
    ast_parser:Diagnostic diagnostic = {
        range: {
            start: {line: 2, column: 4},
            end: {line: 2, column: 6}
        },
        severity: ast_parser:ERROR,
        code: "E001",
        message: "Unknown module 'io'",
        source: "semantic"
    };
    
    refactoring:QuickFix[] fixes = provider.getQuickFixes(sourceCode, [diagnostic]);
    
    test:assertTrue(fixes.length() > 0, "Should provide import fixes");
    
    // Check if import fix is present
    boolean hasImportFix = false;
    foreach refactoring:QuickFix fix in fixes {
        if fix.type == refactoring:ADD_MISSING_IMPORT {
            hasImportFix = true;
            test:assertTrue(fix.edits.length() > 0, "Should have edits");
            test:assertTrue(fix.edits[0].newText.includes("import"), "Should add import statement");
            break;
        }
    }
    
    test:assertTrue(hasImportFix, "Should include import fix");
}

// Test type mismatch quick fix
@test:Config {
    groups: ["quickfix", "type"]
}
function testTypeMismatchQuickFix() {
    refactoring:QuickFixProvider provider = new();
    
    string sourceCode = string `
function process() {
    string text = 42;  // Type mismatch
}`;
    
    ast_parser:Diagnostic diagnostic = {
        range: {
            start: {line: 2, column: 18},
            end: {line: 2, column: 20}
        },
        severity: ast_parser:ERROR,
        code: "E002",
        message: "Type mismatch: expected 'string', found 'int'",
        source: "semantic"
    };
    
    refactoring:QuickFix[] fixes = provider.getQuickFixes(sourceCode, [diagnostic]);
    
    test:assertTrue(fixes.length() > 0, "Should provide type fixes");
    
    // Check for type cast fix
    boolean hasCastFix = false;
    foreach refactoring:QuickFix fix in fixes {
        if fix.type == refactoring:FIX_TYPE_MISMATCH {
            hasCastFix = true;
            test:assertTrue(fix.title.includes("Cast") || fix.title.includes("Change"), 
                "Should offer type fix");
            break;
        }
    }
    
    test:assertTrue(hasCastFix, "Should include type mismatch fix");
}

// Test missing return statement quick fix
@test:Config {
    groups: ["quickfix", "return"]
}
function testMissingReturnQuickFix() {
    refactoring:QuickFixProvider provider = new();
    
    string sourceCode = string `
function calculate() returns int {
    int result = 10 + 20;
    // Missing return
}`;
    
    ast_parser:Diagnostic diagnostic = {
        range: {
            start: {line: 3, column: 0},
            end: {line: 3, column: 21}
        },
        severity: ast_parser:ERROR,
        code: "E003",
        message: "Missing return statement",
        source: "semantic"
    };
    
    refactoring:QuickFix[] fixes = provider.getQuickFixes(sourceCode, [diagnostic]);
    
    test:assertTrue(fixes.length() > 0, "Should provide return fixes");
    
    // Check for return statement fix
    boolean hasReturnFix = false;
    foreach refactoring:QuickFix fix in fixes {
        if fix.type == refactoring:ADD_MISSING_RETURN {
            hasReturnFix = true;
            test:assertTrue(fix.edits[0].newText.includes("return"), "Should add return statement");
            break;
        }
    }
    
    test:assertTrue(hasReturnFix, "Should include return fix");
}

// Test unhandled error quick fix
@test:Config {
    groups: ["quickfix", "error"]
}
function testUnhandledErrorQuickFix() {
    refactoring:QuickFixProvider provider = new();
    
    string sourceCode = string `
function process() {
    string content = file:readString("data.txt");  // Returns error
}`;
    
    ast_parser:Diagnostic diagnostic = {
        range: {
            start: {line: 2, column: 21},
            end: {line: 2, column: 49}
        },
        severity: ast_parser:ERROR,
        code: "E004",
        message: "Unhandled error",
        source: "semantic"
    };
    
    refactoring:QuickFix[] fixes = provider.getQuickFixes(sourceCode, [diagnostic]);
    
    test:assertTrue(fixes.length() > 0, "Should provide error handling fixes");
    
    // Check for error handling fixes
    boolean hasCheckFix = false;
    boolean hasTryCatchFix = false;
    
    foreach refactoring:QuickFix fix in fixes {
        if fix.type == refactoring:ADD_ERROR_HANDLING {
            if fix.title.includes("check") {
                hasCheckFix = true;
                test:assertTrue(fix.preferred, "Check should be preferred fix");
            } else if fix.title.includes("try") {
                hasTryCatchFix = true;
            }
        }
    }
    
    test:assertTrue(hasCheckFix, "Should include check keyword fix");
    test:assertTrue(hasTryCatchFix, "Should include try-catch fix");
}

// Test unused import quick fix
@test:Config {
    groups: ["quickfix", "unused"]
}
function testUnusedImportQuickFix() {
    refactoring:QuickFixProvider provider = new();
    
    string sourceCode = string `
import ballerina/http;  // Unused import

function main() {
    io:println("Hello");
}`;
    
    ast_parser:Diagnostic diagnostic = {
        range: {
            start: {line: 1, column: 0},
            end: {line: 1, column: 22}
        },
        severity: ast_parser:WARNING,
        code: "W001",
        message: "Unused import 'ballerina/http'",
        source: "semantic"
    };
    
    refactoring:QuickFix[] fixes = provider.getQuickFixes(sourceCode, [diagnostic]);
    
    test:assertTrue(fixes.length() > 0, "Should provide unused import fixes");
    
    // Check for remove import fix
    boolean hasRemoveFix = false;
    foreach refactoring:QuickFix fix in fixes {
        if fix.type == refactoring:REMOVE_UNUSED_IMPORT {
            hasRemoveFix = true;
            test:assertTrue(fix.preferred, "Remove should be preferred fix");
            test:assertEquals(fix.edits[0].newText, "", "Should remove the line");
            break;
        }
    }
    
    test:assertTrue(hasRemoveFix, "Should include remove import fix");
}

// Test dead code quick fix
@test:Config {
    groups: ["quickfix", "deadcode"]
}
function testDeadCodeQuickFix() {
    refactoring:QuickFixProvider provider = new();
    
    string sourceCode = string `
function process() {
    return;
    io:println("Never reached");  // Dead code
}`;
    
    ast_parser:Diagnostic diagnostic = {
        range: {
            start: {line: 3, column: 4},
            end: {line: 3, column: 32}
        },
        severity: ast_parser:WARNING,
        code: "W002",
        message: "Unreachable code",
        source: "semantic"
    };
    
    refactoring:QuickFix[] fixes = provider.getQuickFixes(sourceCode, [diagnostic]);
    
    test:assertTrue(fixes.length() > 0, "Should provide dead code fixes");
    
    // Check for remove dead code fix
    boolean hasRemoveFix = false;
    foreach refactoring:QuickFix fix in fixes {
        if fix.type == refactoring:REMOVE_DEAD_CODE {
            hasRemoveFix = true;
            test:assertEquals(fix.edits[0].newText, "", "Should remove dead code");
            break;
        }
    }
    
    test:assertTrue(hasRemoveFix, "Should include remove dead code fix");
}

// Test missing documentation quick fix
@test:Config {
    groups: ["quickfix", "documentation"]
}
function testMissingDocumentationQuickFix() {
    refactoring:QuickFixProvider provider = new();
    
    string sourceCode = string `
public function calculate(int a, int b) returns int {
    return a + b;
}`;
    
    ast_parser:Diagnostic diagnostic = {
        range: {
            start: {line: 1, column: 0},
            end: {line: 1, column: 52}
        },
        severity: ast_parser:WARNING,
        code: "W003",
        message: "Missing documentation for public function",
        source: "semantic"
    };
    
    refactoring:QuickFix[] fixes = provider.getQuickFixes(sourceCode, [diagnostic]);
    
    test:assertTrue(fixes.length() > 0, "Should provide documentation fixes");
    
    // Check for add documentation fix
    boolean hasDocFix = false;
    foreach refactoring:QuickFix fix in fixes {
        if fix.type == refactoring:ADD_DOCUMENTATION {
            hasDocFix = true;
            test:assertTrue(fix.edits[0].newText.includes("#"), "Should add doc comment");
            test:assertTrue(fix.edits[0].newText.includes("+ param"), "Should include param doc");
            test:assertTrue(fix.edits[0].newText.includes("+ return"), "Should include return doc");
            break;
        }
    }
    
    test:assertTrue(hasDocFix, "Should include add documentation fix");
}

// Test suppress warning quick fix
@test:Config {
    groups: ["quickfix", "suppress"]
}
function testSuppressWarningQuickFix() {
    refactoring:QuickFixProvider provider = new();
    
    string sourceCode = string `
function process() {
    int unused = 42;  // Unused variable warning
}`;
    
    ast_parser:Diagnostic diagnostic = {
        range: {
            start: {line: 2, column: 8},
            end: {line: 2, column: 14}
        },
        severity: ast_parser:WARNING,
        code: "W004",
        message: "Unused variable 'unused'",
        source: "semantic"
    };
    
    refactoring:QuickFix[] fixes = provider.getQuickFixes(sourceCode, [diagnostic]);
    
    // Check for suppress warning fix
    boolean hasSuppressFix = false;
    foreach refactoring:QuickFix fix in fixes {
        if fix.title.includes("Suppress") {
            hasSuppressFix = true;
            test:assertTrue(fix.edits[0].newText.includes("@SuppressWarnings"), 
                "Should add suppress annotation");
            break;
        }
    }
    
    test:assertTrue(hasSuppressFix, "Should include suppress warning fix");
}

// Test code actions at position
@test:Config {
    groups: ["quickfix", "actions"]
}
function testGetCodeActions() {
    refactoring:QuickFixProvider provider = new();
    
    string sourceCode = string `
function main() {
    string message = "Hello World";
    io:println(message);
}`;
    
    // Test at variable position
    ast_parser:Position varPos = {line: 2, column: 11};
    refactoring:CodeAction[] actions = provider.getCodeActions(sourceCode, varPos);
    
    test:assertTrue(actions.length() > 0, "Should provide code actions");
    
    // Check for refactoring actions
    boolean hasRefactorAction = false;
    foreach refactoring:CodeAction action in actions {
        if action.kind == "refactor.extract" {
            hasRefactorAction = true;
            break;
        }
    }
    
    test:assertTrue(hasRefactorAction, "Should include refactoring actions");
}

// Test organize imports action
@test:Config {
    groups: ["quickfix", "organize"]
}
function testOrganizeImportsAction() {
    refactoring:QuickFixProvider provider = new();
    
    string sourceCode = string `
import ballerina/io;
import ballerina/http;
import ballerina/file;

function main() {
    io:println("Hello");
}`;
    
    ast_parser:Position pos = {line: 0, column: 0};
    refactoring:CodeAction[] actions = provider.getCodeActions(sourceCode, pos);
    
    // Check for organize imports action
    boolean hasOrganizeAction = false;
    foreach refactoring:CodeAction action in actions {
        if action.kind == "source.organizeImports" {
            hasOrganizeAction = true;
            test:assertEquals(action.title, "Organize imports", "Should have organize imports action");
            break;
        }
    }
    
    test:assertTrue(hasOrganizeAction, "Should include organize imports action");
}

// Test multiple diagnostics
@test:Config {
    groups: ["quickfix", "multiple"]
}
function testMultipleDiagnostics() {
    refactoring:QuickFixProvider provider = new();
    
    string sourceCode = string `
function process() {
    string text = 42;
    io:println(text);
}`;
    
    ast_parser:Diagnostic[] diagnostics = [
        {
            range: {start: {line: 2, column: 18}, end: {line: 2, column: 20}},
            severity: ast_parser:ERROR,
            code: "E002",
            message: "Type mismatch",
            source: "semantic"
        },
        {
            range: {start: {line: 3, column: 4}, end: {line: 3, column: 6}},
            severity: ast_parser:ERROR,
            code: "E001",
            message: "Unknown module 'io'",
            source: "semantic"
        }
    ];
    
    refactoring:QuickFix[] fixes = provider.getQuickFixes(sourceCode, diagnostics);
    
    test:assertTrue(fixes.length() >= 2, "Should provide fixes for multiple diagnostics");
    
    // Verify fixes for both diagnostics
    boolean hasTypeFix = false;
    boolean hasImportFix = false;
    
    foreach refactoring:QuickFix fix in fixes {
        if fix.type == refactoring:FIX_TYPE_MISMATCH {
            hasTypeFix = true;
        } else if fix.type == refactoring:ADD_MISSING_IMPORT {
            hasImportFix = true;
        }
    }
    
    test:assertTrue(hasTypeFix, "Should include type mismatch fix");
    test:assertTrue(hasImportFix, "Should include import fix");
}

// Test generate getter/setter action
@test:Config {
    groups: ["quickfix", "generate"]
}
function testGenerateGetterSetterAction() {
    refactoring:QuickFixProvider provider = new();
    
    string sourceCode = string `
public class Person {
    private string name;
    private int age;
}`;
    
    // Position on field
    ast_parser:Position fieldPos = {line: 2, column: 19};
    refactoring:CodeAction[] actions = provider.getCodeActions(sourceCode, fieldPos);
    
    // Check for generate getter/setter action
    boolean hasGenerateAction = false;
    foreach refactoring:CodeAction action in actions {
        if action.kind == "source.generate" && action.title.includes("getter") {
            hasGenerateAction = true;
            break;
        }
    }
    
    test:assertTrue(hasGenerateAction, "Should include generate getter/setter action");
}