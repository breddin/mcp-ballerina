// Quick Fixes and Code Actions for Ballerina
// Provides automated fixes for common issues and code improvements

import ballerina/log;
import code_analysis.ast_parser;
import code_analysis.semantic_analyzer;

// Quick fix types
public enum QuickFixType {
    ADD_MISSING_IMPORT,
    REMOVE_UNUSED_IMPORT,
    ADD_MISSING_RETURN,
    FIX_TYPE_MISMATCH,
    ADD_ERROR_HANDLING,
    EXTRACT_CONSTANT,
    SIMPLIFY_EXPRESSION,
    REMOVE_DEAD_CODE,
    ADD_DOCUMENTATION,
    IMPLEMENT_INTERFACE,
    GENERATE_GETTER_SETTER,
    CONVERT_TO_ASYNC,
    ADD_NULL_CHECK,
    FIX_VISIBILITY,
    ORGANIZE_IMPORTS
}

// Quick fix definition
public type QuickFix record {|
    QuickFixType type;
    string title;
    string description;
    ast_parser:Diagnostic diagnostic;
    CodeEdit[] edits;
    boolean preferred = false;
|};

// Code edit
public type CodeEdit record {|
    ast_parser:Range range;
    string newText;
    string? annotation?;
|};

// Code action
public type CodeAction record {|
    string title;
    string kind; // "quickfix", "refactor", "source"
    CodeEdit[] edits;
    ast_parser:Diagnostic[] diagnostics?;
    boolean isPreferred = false;
|};

// Quick Fix Provider
public class QuickFixProvider {
    private ast_parser:ASTParser parser;
    private semantic_analyzer:SemanticAnalyzer analyzer;
    private map<string, QuickFixHandler> handlers;
    
    public function init() {
        self.parser = new();
        self.analyzer = new();
        self.initializeHandlers();
    }
    
    // Initialize quick fix handlers
    private function initializeHandlers() {
        self.handlers = {
            "E001": new MissingImportHandler(),
            "E002": new TypeMismatchHandler(),
            "E003": new MissingReturnHandler(),
            "E004": new UnhandledErrorHandler(),
            "W001": new UnusedImportHandler(),
            "W002": new DeadCodeHandler(),
            "W003": new MissingDocHandler()
        };
    }
    
    // Get quick fixes for diagnostics
    public function getQuickFixes(string sourceCode, ast_parser:Diagnostic[] diagnostics) 
        returns QuickFix[] {
        
        QuickFix[] fixes = [];
        
        foreach ast_parser:Diagnostic diagnostic in diagnostics {
            QuickFix[] diagFixes = self.getFixesForDiagnostic(sourceCode, diagnostic);
            fixes.push(...diagFixes);
        }
        
        return fixes;
    }
    
    // Get fixes for single diagnostic
    private function getFixesForDiagnostic(string sourceCode, ast_parser:Diagnostic diagnostic) 
        returns QuickFix[] {
        
        QuickFix[] fixes = [];
        
        // Get handler for diagnostic code
        string? code = diagnostic.code;
        if code is string {
            QuickFixHandler? handler = self.handlers[code];
            if handler is QuickFixHandler {
                QuickFix[] handlerFixes = handler.getFixes(sourceCode, diagnostic);
                fixes.push(...handlerFixes);
            }
        }
        
        // Add generic fixes
        fixes.push(...self.getGenericFixes(sourceCode, diagnostic));
        
        return fixes;
    }
    
    // Get generic fixes applicable to any diagnostic
    private function getGenericFixes(string sourceCode, ast_parser:Diagnostic diagnostic) 
        returns QuickFix[] {
        
        QuickFix[] fixes = [];
        
        // Suppress warning
        if diagnostic.severity == ast_parser:WARNING {
            fixes.push({
                type: ADD_DOCUMENTATION,
                title: "Suppress warning",
                description: "Add @SuppressWarnings annotation",
                diagnostic: diagnostic,
                edits: [{
                    range: {
                        start: {line: diagnostic.range.start.line - 1, column: 0},
                        end: {line: diagnostic.range.start.line - 1, column: 0}
                    },
                    newText: "@SuppressWarnings(\"" + (diagnostic.code ?: "all") + "\")\n"
                }]
            });
        }
        
        return fixes;
    }
    
    // Get code actions at position
    public function getCodeActions(string sourceCode, ast_parser:Position position) 
        returns CodeAction[] {
        
        CodeAction[] actions = [];
        
        // Parse source
        ast_parser:ParseResult parseResult = self.parser.parse(sourceCode, "actions.bal");
        if !parseResult.success || parseResult.root is () {
            return actions;
        }
        
        // Get symbol at position
        ast_parser:SymbolInfo? symbol = self.parser.getSymbolAtPosition(position);
        
        // Add refactoring actions
        actions.push(...self.getRefactorActions(symbol, position));
        
        // Add source actions
        actions.push(...self.getSourceActions(parseResult, position));
        
        return actions;
    }
    
    // Get refactoring actions
    private function getRefactorActions(ast_parser:SymbolInfo? symbol, ast_parser:Position position) 
        returns CodeAction[] {
        
        CodeAction[] actions = [];
        
        if symbol is ast_parser:SymbolInfo {
            // Extract constant
            if symbol.kind == "variable" {
                actions.push({
                    title: "Extract constant",
                    kind: "refactor.extract",
                    edits: []
                });
            }
            
            // Generate getter/setter
            if symbol.kind == "field" {
                actions.push({
                    title: "Generate getter and setter",
                    kind: "source.generate",
                    edits: []
                });
            }
        }
        
        return actions;
    }
    
    // Get source generation actions
    private function getSourceActions(ast_parser:ParseResult parseResult, ast_parser:Position position) 
        returns CodeAction[] {
        
        CodeAction[] actions = [];
        
        // Organize imports
        actions.push({
            title: "Organize imports",
            kind: "source.organizeImports",
            edits: self.organizeImports(parseResult)
        });
        
        // Add documentation
        actions.push({
            title: "Add documentation",
            kind: "source.documentation",
            edits: []
        });
        
        return actions;
    }
    
    // Organize imports
    private function organizeImports(ast_parser:ParseResult parseResult) returns CodeEdit[] {
        // Sort and organize import statements
        return [];
    }
}

// Base quick fix handler
type QuickFixHandler object {
    public function getFixes(string sourceCode, ast_parser:Diagnostic diagnostic) returns QuickFix[];
};

// Missing import handler
class MissingImportHandler {
    *QuickFixHandler;
    
    public function getFixes(string sourceCode, ast_parser:Diagnostic diagnostic) returns QuickFix[] {
        QuickFix[] fixes = [];
        
        // Extract missing symbol from diagnostic message
        string? missingSymbol = self.extractMissingSymbol(diagnostic.message);
        if missingSymbol is string {
            // Find possible imports
            string[] possibleImports = self.findPossibleImports(missingSymbol);
            
            foreach string imp in possibleImports {
                fixes.push({
                    type: ADD_MISSING_IMPORT,
                    title: "Import " + imp,
                    description: "Add import statement for " + imp,
                    diagnostic: diagnostic,
                    edits: [{
                        range: {
                            start: {line: 0, column: 0},
                            end: {line: 0, column: 0}
                        },
                        newText: "import " + imp + ";\n"
                    }],
                    preferred: possibleImports.length() == 1
                });
            }
        }
        
        return fixes;
    }
    
    private function extractMissingSymbol(string message) returns string? {
        // Extract symbol name from error message
        return ();
    }
    
    private function findPossibleImports(string symbol) returns string[] {
        // Find modules that export this symbol
        return ["ballerina/io", "ballerina/http"];
    }
}

// Type mismatch handler
class TypeMismatchHandler {
    *QuickFixHandler;
    
    public function getFixes(string sourceCode, ast_parser:Diagnostic diagnostic) returns QuickFix[] {
        QuickFix[] fixes = [];
        
        // Extract expected and actual types
        [string, string]? types = self.extractTypes(diagnostic.message);
        if types is [string, string] {
            string [expectedType, actualType] = types;
            
            // Add type cast
            fixes.push({
                type: FIX_TYPE_MISMATCH,
                title: "Cast to " + expectedType,
                description: "Add type cast to fix mismatch",
                diagnostic: diagnostic,
                edits: [{
                    range: diagnostic.range,
                    newText: "<" + expectedType + ">"
                }]
            });
            
            // Change variable type
            fixes.push({
                type: FIX_TYPE_MISMATCH,
                title: "Change type to " + actualType,
                description: "Change variable type declaration",
                diagnostic: diagnostic,
                edits: []
            });
        }
        
        return fixes;
    }
    
    private function extractTypes(string message) returns [string, string]? {
        // Extract expected and actual types from error message
        return ["string", "int"];
    }
}

// Missing return handler
class MissingReturnHandler {
    *QuickFixHandler;
    
    public function getFixes(string sourceCode, ast_parser:Diagnostic diagnostic) returns QuickFix[] {
        QuickFix[] fixes = [];
        
        // Add return statement
        fixes.push({
            type: ADD_MISSING_RETURN,
            title: "Add return statement",
            description: "Add missing return statement",
            diagnostic: diagnostic,
            edits: [{
                range: {
                    start: diagnostic.range.end,
                    end: diagnostic.range.end
                },
                newText: "\n    return ();"
            }]
        });
        
        return fixes;
    }
}

// Unhandled error handler
class UnhandledErrorHandler {
    *QuickFixHandler;
    
    public function getFixes(string sourceCode, ast_parser:Diagnostic diagnostic) returns QuickFix[] {
        QuickFix[] fixes = [];
        
        // Add check keyword
        fixes.push({
            type: ADD_ERROR_HANDLING,
            title: "Add 'check' keyword",
            description: "Propagate error with check",
            diagnostic: diagnostic,
            edits: [{
                range: {
                    start: diagnostic.range.start,
                    end: diagnostic.range.start
                },
                newText: "check "
            }],
            preferred: true
        });
        
        // Add try-catch
        fixes.push({
            type: ADD_ERROR_HANDLING,
            title: "Surround with try-catch",
            description: "Handle error with try-catch block",
            diagnostic: diagnostic,
            edits: [{
                range: {
                    start: diagnostic.range.start,
                    end: diagnostic.range.start
                },
                newText: "do {\n    "
            }, {
                range: {
                    start: diagnostic.range.end,
                    end: diagnostic.range.end
                },
                newText: "\n} on fail error e {\n    // Handle error\n}"
            }]
        });
        
        return fixes;
    }
}

// Unused import handler
class UnusedImportHandler {
    *QuickFixHandler;
    
    public function getFixes(string sourceCode, ast_parser:Diagnostic diagnostic) returns QuickFix[] {
        QuickFix[] fixes = [];
        
        // Remove import
        fixes.push({
            type: REMOVE_UNUSED_IMPORT,
            title: "Remove unused import",
            description: "Remove the unused import statement",
            diagnostic: diagnostic,
            edits: [{
                range: {
                    start: {line: diagnostic.range.start.line, column: 0},
                    end: {line: diagnostic.range.end.line + 1, column: 0}
                },
                newText: ""
            }],
            preferred: true
        });
        
        return fixes;
    }
}

// Dead code handler
class DeadCodeHandler {
    *QuickFixHandler;
    
    public function getFixes(string sourceCode, ast_parser:Diagnostic diagnostic) returns QuickFix[] {
        QuickFix[] fixes = [];
        
        // Remove dead code
        fixes.push({
            type: REMOVE_DEAD_CODE,
            title: "Remove unreachable code",
            description: "Remove code that will never be executed",
            diagnostic: diagnostic,
            edits: [{
                range: diagnostic.range,
                newText: ""
            }]
        });
        
        return fixes;
    }
}

// Missing documentation handler
class MissingDocHandler {
    *QuickFixHandler;
    
    public function getFixes(string sourceCode, ast_parser:Diagnostic diagnostic) returns QuickFix[] {
        QuickFix[] fixes = [];
        
        // Add documentation template
        fixes.push({
            type: ADD_DOCUMENTATION,
            title: "Add documentation",
            description: "Add documentation comment",
            diagnostic: diagnostic,
            edits: [{
                range: {
                    start: {line: diagnostic.range.start.line - 1, column: 0},
                    end: {line: diagnostic.range.start.line - 1, column: 0}
                },
                newText: "# Description\n# + param - Parameter description\n# + return - Return description\n"
            }]
        });
        
        return fixes;
    }
}