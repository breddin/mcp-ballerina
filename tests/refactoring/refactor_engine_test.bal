// Test Suite for Refactoring Engine
// Tests all refactoring operations

import ballerina/test;
import modules.refactoring;
import modules.code_analysis.ast_parser;

// Test data
const string SAMPLE_CODE = string `
function calculateSum(int a, int b) returns int {
    int result = a + b;
    return result;
}

function main() {
    int x = 10;
    int y = 20;
    int sum = calculateSum(x, y);
    io:println("Sum: " + sum.toString());
}
`;

// Test Extract Method refactoring
@test:Config {
    groups: ["refactoring", "extract-method"]
}
function testExtractMethod() returns error? {
    refactoring:RefactorEngine engine = new();
    
    refactoring:RefactorRequest request = {
        type: refactoring:EXTRACT_METHOD,
        sourceCode: SAMPLE_CODE,
        selection: {
            start: {line: 7, column: 4},
            end: {line: 9, column: 45}
        },
        parameters: {
            "methodName": "calculateAndPrint"
        }
    };
    
    refactoring:RefactorResult result = check engine.refactor(request);
    
    test:assertTrue(result.success, "Extract method should succeed");
    test:assertNotEquals(result.refactoredCode, (), "Should produce refactored code");
    test:assertTrue(result.changes.length() > 0, "Should have changes");
}

// Test Inline Variable refactoring
@test:Config {
    groups: ["refactoring", "inline-variable"]
}
function testInlineVariable() returns error? {
    refactoring:RefactorEngine engine = new();
    
    refactoring:RefactorRequest request = {
        type: refactoring:INLINE_VARIABLE,
        sourceCode: SAMPLE_CODE,
        selection: {
            start: {line: 2, column: 4},
            end: {line: 2, column: 24}
        },
        parameters: {
            "variableName": "result"
        }
    };
    
    refactoring:RefactorResult result = check engine.refactor(request);
    
    test:assertTrue(result.success, "Inline variable should succeed");
    test:assertNotEquals(result.refactoredCode, (), "Should produce refactored code");
}

// Test Rename Symbol refactoring
@test:Config {
    groups: ["refactoring", "rename"]
}
function testRenameSymbol() returns error? {
    refactoring:RefactorEngine engine = new();
    
    refactoring:RefactorRequest request = {
        type: refactoring:RENAME_SYMBOL,
        sourceCode: SAMPLE_CODE,
        selection: {
            start: {line: 1, column: 9},
            end: {line: 1, column: 21}
        },
        parameters: {
            "oldName": "calculateSum",
            "newName": "computeTotal"
        }
    };
    
    refactoring:RefactorResult result = check engine.refactor(request);
    
    test:assertTrue(result.success, "Rename should succeed");
    test:assertNotEquals(result.refactoredCode, (), "Should produce refactored code");
    test:assertTrue(result.metadata?.changesCount > 0, "Should track changes");
}

// Test invalid rename (invalid identifier)
@test:Config {
    groups: ["refactoring", "rename", "negative"]
}
function testInvalidRename() {
    refactoring:RefactorEngine engine = new();
    
    refactoring:RefactorRequest request = {
        type: refactoring:RENAME_SYMBOL,
        sourceCode: SAMPLE_CODE,
        selection: {
            start: {line: 1, column: 9},
            end: {line: 1, column: 21}
        },
        parameters: {
            "oldName": "calculateSum",
            "newName": "123invalid"  // Invalid identifier
        }
    };
    
    refactoring:RefactorResult|error result = engine.refactor(request);
    
    test:assertTrue(result is error, "Should fail for invalid identifier");
}

// Test Extract Variable refactoring
@test:Config {
    groups: ["refactoring", "extract-variable"]
}
function testExtractVariable() returns error? {
    refactoring:RefactorEngine engine = new();
    
    string code = string `
function compute() {
    int value = 10 * 20 + 30;
    return value;
}`;
    
    refactoring:RefactorRequest request = {
        type: refactoring:EXTRACT_VARIABLE,
        sourceCode: code,
        selection: {
            start: {line: 2, column: 16},
            end: {line: 2, column: 29}  // Select "10 * 20 + 30"
        },
        parameters: {
            "variableName": "calculation"
        }
    };
    
    refactoring:RefactorResult result = check engine.refactor(request);
    
    test:assertTrue(result.success, "Extract variable should succeed");
}

// Test available refactorings at position
@test:Config {
    groups: ["refactoring", "availability"]
}
function testGetAvailableRefactorings() {
    refactoring:RefactorEngine engine = new();
    
    // Test at function position
    ast_parser:Position funcPos = {line: 1, column: 10};
    refactoring:RefactorType[] available = engine.getAvailableRefactorings(SAMPLE_CODE, funcPos);
    
    test:assertTrue(available.length() > 0, "Should have available refactorings");
    test:assertTrue(containsRefactoring(available, refactoring:RENAME_SYMBOL), 
        "Should include rename at function");
    
    // Test at variable position
    ast_parser:Position varPos = {line: 2, column: 8};
    available = engine.getAvailableRefactorings(SAMPLE_CODE, varPos);
    
    test:assertTrue(containsRefactoring(available, refactoring:INLINE_VARIABLE), 
        "Should include inline variable");
}

// Test refactoring with validation
@test:Config {
    groups: ["refactoring", "validation"]
}
function testRefactoringWithValidation() returns error? {
    refactoring:RefactorEngine engine = new();
    
    refactoring:RefactorRequest request = {
        type: refactoring:RENAME_SYMBOL,
        sourceCode: SAMPLE_CODE,
        selection: {
            start: {line: 1, column: 9},
            end: {line: 1, column: 21}
        },
        parameters: {
            "oldName": "calculateSum",
            "newName": "add"
        },
        options: {
            validateResult: true,
            updateReferences: true
        }
    };
    
    refactoring:RefactorResult result = check engine.refactor(request);
    
    test:assertTrue(result.success, "Refactoring with validation should succeed");
    test:assertEquals(result.errors.length(), 0, "Should have no errors");
}

// Test batch refactoring operations
@test:Config {
    groups: ["refactoring", "batch"]
}
function testBatchRefactoring() returns error? {
    refactoring:RefactorEngine engine = new();
    
    // First refactoring: rename function
    refactoring:RefactorRequest rename = {
        type: refactoring:RENAME_SYMBOL,
        sourceCode: SAMPLE_CODE,
        selection: {
            start: {line: 1, column: 9},
            end: {line: 1, column: 21}
        },
        parameters: {
            "oldName": "calculateSum",
            "newName": "add"
        }
    };
    
    refactoring:RefactorResult result1 = check engine.refactor(rename);
    test:assertTrue(result1.success, "First refactoring should succeed");
    
    // Second refactoring: inline variable on refactored code
    refactoring:RefactorRequest inline = {
        type: refactoring:INLINE_VARIABLE,
        sourceCode: result1.refactoredCode ?: SAMPLE_CODE,
        selection: {
            start: {line: 2, column: 4},
            end: {line: 2, column: 24}
        },
        parameters: {
            "variableName": "result"
        }
    };
    
    refactoring:RefactorResult result2 = check engine.refactor(inline);
    test:assertTrue(result2.success, "Second refactoring should succeed");
}

// Test refactoring with empty source
@test:Config {
    groups: ["refactoring", "negative"]
}
function testRefactoringWithEmptySource() {
    refactoring:RefactorEngine engine = new();
    
    refactoring:RefactorRequest request = {
        type: refactoring:EXTRACT_METHOD,
        sourceCode: "",
        selection: {
            start: {line: 0, column: 0},
            end: {line: 0, column: 0}
        }
    };
    
    refactoring:RefactorResult|error result = engine.refactor(request);
    
    test:assertTrue(result is error, "Should fail for empty source");
}

// Test refactoring with invalid selection
@test:Config {
    groups: ["refactoring", "negative"]
}
function testRefactoringWithInvalidSelection() {
    refactoring:RefactorEngine engine = new();
    
    refactoring:RefactorRequest request = {
        type: refactoring:EXTRACT_METHOD,
        sourceCode: SAMPLE_CODE,
        selection: {
            start: {line: -1, column: -1},
            end: {line: 0, column: 0}
        }
    };
    
    refactoring:RefactorResult|error result = engine.refactor(request);
    
    test:assertTrue(result is error, "Should fail for invalid selection");
}

// Helper function to check if refactoring type is in array
function containsRefactoring(refactoring:RefactorType[] types, refactoring:RefactorType target) 
    returns boolean {
    foreach refactoring:RefactorType t in types {
        if t == target {
            return true;
        }
    }
    return false;
}