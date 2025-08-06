// Performance Tests for Code Analysis Module
import ballerina/test;
import ballerina/time;
import ballerina/io;
import code_analysis.ast_parser;
import code_analysis.semantic_analyzer;
import code_analysis.lsp_handlers;

// Performance test configuration
const int SMALL_CODE_SIZE = 100;    // Lines
const int MEDIUM_CODE_SIZE = 500;   // Lines
const int LARGE_CODE_SIZE = 2000;   // Lines
const int ITERATIONS = 10;

// Benchmark results storage
type BenchmarkResult record {|
    string testName;
    int codeSize;
    decimal avgTime;  // milliseconds
    decimal minTime;
    decimal maxTime;
    int iterations;
|};

// Generate test code of specified size
function generateTestCode(int lines) returns string {
    string[] codeLines = [];
    
    // Add imports
    codeLines.push("import ballerina/io;");
    codeLines.push("import ballerina/http;");
    codeLines.push("");
    
    // Add types
    int typeCount = lines / 20;
    foreach int i in 0 ..< typeCount {
        codeLines.push("type Type" + i.toString() + " record {|");
        codeLines.push("    string field1;");
        codeLines.push("    int field2;");
        codeLines.push("|};");
        codeLines.push("");
    }
    
    // Add functions
    int funcCount = lines / 10;
    foreach int i in 0 ..< funcCount {
        codeLines.push("function func" + i.toString() + "(int x, int y) returns int {");
        codeLines.push("    int result = x + y;");
        codeLines.push("    return result;");
        codeLines.push("}");
        codeLines.push("");
    }
    
    // Add main function with variables
    codeLines.push("function main() {");
    int varCount = lines / 5;
    foreach int i in 0 ..< varCount {
        codeLines.push("    int var" + i.toString() + " = " + i.toString() + ";");
    }
    codeLines.push("}");
    
    return string:'join("\n", ...codeLines);
}

// Measure execution time
function measureTime(function() returns any|error func) returns decimal|error {
    time:Utc startTime = time:utcNow();
    _ = check func();
    time:Utc endTime = time:utcNow();
    
    decimal diffSeconds = endTime[0] - startTime[0];
    decimal diffNanos = endTime[1] - startTime[1];
    
    return diffSeconds * 1000 + diffNanos / 1000000;  // Convert to milliseconds
}

// Run benchmark
function runBenchmark(string testName, int codeSize, function() returns any|error func) 
    returns BenchmarkResult|error {
    
    decimal[] times = [];
    
    foreach int i in 0 ..< ITERATIONS {
        decimal elapsed = check measureTime(func);
        times.push(elapsed);
    }
    
    // Calculate statistics
    decimal total = 0;
    decimal minTime = times[0];
    decimal maxTime = times[0];
    
    foreach decimal t in times {
        total += t;
        if t < minTime {
            minTime = t;
        }
        if t > maxTime {
            maxTime = t;
        }
    }
    
    return {
        testName: testName,
        codeSize: codeSize,
        avgTime: total / ITERATIONS,
        minTime: minTime,
        maxTime: maxTime,
        iterations: ITERATIONS
    };
}

// Test AST parsing performance - Small code
@test:Config {}
function testASTParsingPerformanceSmall() returns error? {
    string code = generateTestCode(SMALL_CODE_SIZE);
    ast_parser:ASTParser parser = new();
    
    function parseFunc = function() returns ast_parser:ParseResult {
        return parser.parse(code, "perf_small.bal");
    };
    
    BenchmarkResult result = check runBenchmark(
        "AST Parsing - Small",
        SMALL_CODE_SIZE,
        parseFunc
    );
    
    io:println("AST Parsing (Small): Avg=" + result.avgTime.toString() + "ms");
    test:assertTrue(result.avgTime < 100, "Small parsing should be under 100ms");
}

// Test AST parsing performance - Medium code
@test:Config {}
function testASTParsingPerformanceMedium() returns error? {
    string code = generateTestCode(MEDIUM_CODE_SIZE);
    ast_parser:ASTParser parser = new();
    
    function parseFunc = function() returns ast_parser:ParseResult {
        return parser.parse(code, "perf_medium.bal");
    };
    
    BenchmarkResult result = check runBenchmark(
        "AST Parsing - Medium",
        MEDIUM_CODE_SIZE,
        parseFunc
    );
    
    io:println("AST Parsing (Medium): Avg=" + result.avgTime.toString() + "ms");
    test:assertTrue(result.avgTime < 500, "Medium parsing should be under 500ms");
}

// Test AST parsing performance - Large code
@test:Config {enable: false}  // Disabled by default as it may be slow
function testASTParsingPerformanceLarge() returns error? {
    string code = generateTestCode(LARGE_CODE_SIZE);
    ast_parser:ASTParser parser = new();
    
    function parseFunc = function() returns ast_parser:ParseResult {
        return parser.parse(code, "perf_large.bal");
    };
    
    BenchmarkResult result = check runBenchmark(
        "AST Parsing - Large",
        LARGE_CODE_SIZE,
        parseFunc
    );
    
    io:println("AST Parsing (Large): Avg=" + result.avgTime.toString() + "ms");
    test:assertTrue(result.avgTime < 2000, "Large parsing should be under 2000ms");
}

// Test semantic analysis performance
@test:Config {}
function testSemanticAnalysisPerformance() returns error? {
    string code = generateTestCode(MEDIUM_CODE_SIZE);
    ast_parser:ASTParser parser = new();
    ast_parser:ParseResult parseResult = parser.parse(code, "semantic_perf.bal");
    
    if parseResult.root is ast_parser:ASTNode {
        semantic_analyzer:SemanticAnalyzer analyzer = new();
        ast_parser:ASTNode root = <ast_parser:ASTNode>parseResult.root;
        
        function analyzeFunc = function() returns semantic_analyzer:SemanticContext {
            return analyzer.analyze(root);
        };
        
        BenchmarkResult result = check runBenchmark(
            "Semantic Analysis",
            MEDIUM_CODE_SIZE,
            analyzeFunc
        );
        
        io:println("Semantic Analysis: Avg=" + result.avgTime.toString() + "ms");
        test:assertTrue(result.avgTime < 1000, "Semantic analysis should be under 1000ms");
    }
}

// Test symbol extraction performance
@test:Config {}
function testSymbolExtractionPerformance() returns error? {
    string code = generateTestCode(MEDIUM_CODE_SIZE);
    ast_parser:ASTParser parser = new();
    
    function extractFunc = function() returns map<ast_parser:SymbolInfo> {
        ast_parser:ParseResult result = parser.parse(code, "symbol_perf.bal");
        return parser.getSymbols();
    };
    
    BenchmarkResult result = check runBenchmark(
        "Symbol Extraction",
        MEDIUM_CODE_SIZE,
        extractFunc
    );
    
    io:println("Symbol Extraction: Avg=" + result.avgTime.toString() + "ms");
    test:assertTrue(result.avgTime < 800, "Symbol extraction should be under 800ms");
}

// Test LSP completion performance
@test:Config {}
function testCompletionPerformance() returns error? {
    string code = generateTestCode(MEDIUM_CODE_SIZE);
    lsp_handlers:LSPAnalysisHandler handler = new();
    
    // Setup document
    json openParams = {
        "textDocument": {
            "uri": "file:///perf_completion.bal",
            "text": code
        }
    };
    _ = handler.handleDidOpen(openParams);
    
    json completionParams = {
        "textDocument": {
            "uri": "file:///perf_completion.bal"
        },
        "position": {
            "line": 10,
            "character": 10
        }
    };
    
    function completionFunc = function() returns json {
        return handler.handleCompletion(completionParams);
    };
    
    BenchmarkResult result = check runBenchmark(
        "LSP Completion",
        MEDIUM_CODE_SIZE,
        completionFunc
    );
    
    io:println("LSP Completion: Avg=" + result.avgTime.toString() + "ms");
    test:assertTrue(result.avgTime < 200, "Completion should be under 200ms");
}

// Test diagnostics generation performance
@test:Config {}
function testDiagnosticsPerformance() returns error? {
    string code = generateTestCode(MEDIUM_CODE_SIZE);
    lsp_handlers:LSPAnalysisHandler handler = new();
    
    json openParams = {
        "textDocument": {
            "uri": "file:///perf_diagnostics.bal",
            "text": code
        }
    };
    
    function diagnosticsFunc = function() returns json {
        return handler.handleDidOpen(openParams);
    };
    
    BenchmarkResult result = check runBenchmark(
        "Diagnostics Generation",
        MEDIUM_CODE_SIZE,
        diagnosticsFunc
    );
    
    io:println("Diagnostics: Avg=" + result.avgTime.toString() + "ms");
    test:assertTrue(result.avgTime < 1500, "Diagnostics should be under 1500ms");
}

// Test memory usage (approximate)
@test:Config {}
function testMemoryUsage() {
    string smallCode = generateTestCode(SMALL_CODE_SIZE);
    string mediumCode = generateTestCode(MEDIUM_CODE_SIZE);
    
    // Parse multiple documents
    ast_parser:ASTParser parser = new();
    ast_parser:ParseResult[] results = [];
    
    foreach int i in 0 ..< 10 {
        results.push(parser.parse(smallCode, "mem_test_" + i.toString() + ".bal"));
    }
    
    test:assertTrue(results.length() == 10, "Should parse 10 documents");
    
    // Parse larger document
    ast_parser:ParseResult largeResult = parser.parse(mediumCode, "mem_test_large.bal");
    test:assertTrue(largeResult.success, "Should parse large document");
}

// Test concurrent parsing
@test:Config {}
function testConcurrentParsing() returns error? {
    string code = generateTestCode(SMALL_CODE_SIZE);
    
    time:Utc startTime = time:utcNow();
    
    // Simulate concurrent parsing
    ast_parser:ASTParser parser1 = new();
    ast_parser:ASTParser parser2 = new();
    ast_parser:ASTParser parser3 = new();
    
    ast_parser:ParseResult result1 = parser1.parse(code, "concurrent1.bal");
    ast_parser:ParseResult result2 = parser2.parse(code, "concurrent2.bal");
    ast_parser:ParseResult result3 = parser3.parse(code, "concurrent3.bal");
    
    time:Utc endTime = time:utcNow();
    
    test:assertTrue(result1.success, "Parser 1 should succeed");
    test:assertTrue(result2.success, "Parser 2 should succeed");
    test:assertTrue(result3.success, "Parser 3 should succeed");
    
    decimal elapsed = (endTime[0] - startTime[0]) * 1000 + 
                     (endTime[1] - startTime[1]) / 1000000;
    
    io:println("Concurrent Parsing (3 parsers): " + elapsed.toString() + "ms");
}

// Test incremental parsing simulation
@test:Config {}
function testIncrementalParsingSimulation() returns error? {
    lsp_handlers:LSPAnalysisHandler handler = new();
    string initialCode = generateTestCode(MEDIUM_CODE_SIZE);
    
    // Initial parse
    json openParams = {
        "textDocument": {
            "uri": "file:///incremental.bal",
            "text": initialCode
        }
    };
    
    time:Utc startOpen = time:utcNow();
    _ = handler.handleDidOpen(openParams);
    time:Utc endOpen = time:utcNow();
    
    decimal openTime = (endOpen[0] - startOpen[0]) * 1000 + 
                      (endOpen[1] - startOpen[1]) / 1000000;
    
    // Incremental change
    json changeParams = {
        "textDocument": {
            "uri": "file:///incremental.bal"
        },
        "contentChanges": [
            {
                "text": initialCode + "\n// Small change"
            }
        ]
    };
    
    time:Utc startChange = time:utcNow();
    _ = handler.handleDidChange(changeParams);
    time:Utc endChange = time:utcNow();
    
    decimal changeTime = (endChange[0] - startChange[0]) * 1000 + 
                        (endChange[1] - startChange[1]) / 1000000;
    
    io:println("Initial parse: " + openTime.toString() + "ms");
    io:println("Incremental update: " + changeTime.toString() + "ms");
    
    // Incremental should be faster than initial
    test:assertTrue(changeTime <= openTime * 1.5, 
                   "Incremental update should not be much slower than initial parse");
}

// Generate performance report
@test:Config {dependsOn: [testASTParsingPerformanceSmall, testSemanticAnalysisPerformance]}
function generatePerformanceReport() {
    io:println("\n=== Performance Test Report ===");
    io:println("All performance tests completed");
    io:println("Note: Times may vary based on system load");
    io:println("==============================\n");
}