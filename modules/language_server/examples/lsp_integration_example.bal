// LSP Integration Example
// Demonstrates how to integrate the LSP client with the MCP server

import ballerina/io;
import ballerina/log;
import ballerina/http;
import ballerina/lang.runtime;
import mcp_ballerina.language_server;

// Example: Ballerina Language Server Integration
public function integrateWithBallerinaLS() returns error? {
    log:printInfo("Starting Ballerina Language Server integration example");
    
    // Create LSP client pointing to Ballerina Language Server
    language_server:LSPClient client = new("http://localhost:9000");
    
    // Initialize with comprehensive capabilities
    language_server:InitializeParams initParams = {
        processId: (),
        rootUri: "file:///workspace",
        capabilities: language_server:createClientCapabilities(),
        initializationOptions: {
            "ballerina": {
                "enableSemanticTokens": true,
                "enableDiagnostics": true,
                "enableCompletion": true
            }
        },
        trace: "verbose"
    };
    
    // Initialize the language server
    json initResult = check client.initialize(initParams);
    log:printInfo("Language server initialized: " + initResult.toString());
    
    // Example workflow: Open, edit, get completions, close
    check demonstrateTextDocumentWorkflow(client);
    
    // Example: Code navigation features
    check demonstrateNavigationFeatures(client);
    
    // Example: Real-time diagnostics
    check demonstrateDiagnosticsHandling(client);
    
    // Graceful shutdown
    check client.shutdown();
    log:printInfo("Language server integration example completed");
}

// Demonstrate complete text document workflow
function demonstrateTextDocumentWorkflow(language_server:LSPClient client) returns error? {
    log:printInfo("=== Text Document Workflow Demo ===");
    
    // Create a Ballerina source file
    string sourceCode = string `import ballerina/io;
import ballerina/http;

type User record {|
    string name;
    int age;
    string email?;
|};

service /api on new http:Listener(8080) {
    resource function get users() returns User[] {
        return [
            {name: "Alice", age: 30, email: "alice@example.com"},
            {name: "Bob", age: 25}
        ];
    }
    
    resource function post users(@http:Payload User user) returns User|error {
        if (user.name.length() == 0) {
            return error("Name cannot be empty");
        }
        return user;
    }
}

public function main() {
    io:println("Server starting on port 8080");
}`;
    
    // Open document
    language_server:TextDocumentItem document = language_server:createTextDocumentItem(
        "file:///workspace/examples/user_service.bal",
        "ballerina",
        1,
        sourceCode
    );
    
    check client.didOpen(document);
    log:printInfo("Document opened: user_service.bal");
    
    // Simulate typing - add a new function
    string addition = "\n\nfunction validateUser(User user) returns boolean {\n    return user.name.length() > 0;\n}";
    
    language_server:VersionedTextDocumentIdentifier versionedDoc = 
        language_server:createVersionedTextDocumentIdentifier(
            "file:///workspace/examples/user_service.bal",
            2
        );
    
    language_server:TextDocumentContentChangeEvent[] changes = [
        {
            range: language_server:createRange(
                language_server:createPosition(26, 0),
                language_server:createPosition(26, 0)
            ),
            text: addition
        }
    ];
    
    check client.didChange(versionedDoc, changes);
    log:printInfo("Document updated with new function");
    
    // Request completions at various positions
    check requestCompletionsAtDifferentPositions(client, "file:///workspace/examples/user_service.bal");
    
    // Close the document
    check client.didClose(language_server:createTextDocumentIdentifier(
        "file:///workspace/examples/user_service.bal"
    ));
    log:printInfo("Document closed");
}

// Request completions at different code positions
function requestCompletionsAtDifferentPositions(language_server:LSPClient client, string uri) returns error? {
    log:printInfo("--- Testing completions at different positions ---");
    
    // Test positions for different completion scenarios
    map<language_server:Position> testPositions = {
        "import_completion": language_server:createPosition(1, 7),     // After "import "
        "type_completion": language_server:createPosition(7, 4),       // Inside resource function
        "variable_completion": language_server:createPosition(15, 12), // After "user."
        "function_completion": language_server:createPosition(20, 8)   // Inside main function
    };
    
    foreach string scenario in testPositions.keys() {
        language_server:Position position = testPositions.get(scenario);
        
        language_server:CompletionParams params = language_server:createCompletionParams(uri, position);
        
        language_server:CompletionList|language_server:CompletionItem[]|error result = 
            client.completion(params);
        
        if (result is error) {
            log:printError(string `Completion failed for ${scenario}: ${result.message()}`);
        } else {
            int itemCount = 0;
            if (result is language_server:CompletionList) {
                itemCount = result.items.length();
                log:printInfo(string `${scenario}: ${itemCount} completions (isIncomplete: ${result.isIncomplete})`);
            } else {
                itemCount = result.length();
                log:printInfo(string `${scenario}: ${itemCount} completions`);
            }
            
            // Log first few completion items for debugging
            language_server:CompletionItem[] items = result is language_server:CompletionList ? 
                result.items : result;
            
            int maxItems = itemCount < 3 ? itemCount : 3;
            foreach int i in 0..<maxItems {
                language_server:CompletionItem item = items[i];
                log:printDebug(string `  - ${item.label} (kind: ${item.kind ?: 0})`);
            }
        }
    }
}

// Demonstrate code navigation features
function demonstrateNavigationFeatures(language_server:LSPClient client) returns error? {
    log:printInfo("=== Navigation Features Demo ===");
    
    // Create a simple file for navigation testing
    string navTestCode = string `import ballerina/io;

public function calculateSum(int a, int b) returns int {
    return a + b;
}

public function main() {
    int result = calculateSum(5, 3);
    io:println("Result: " + result.toString());
}`;
    
    language_server:TextDocumentItem navDoc = language_server:createTextDocumentItem(
        "file:///workspace/examples/navigation_test.bal",
        "ballerina",
        1,
        navTestCode
    );
    
    check client.didOpen(navDoc);
    
    string uri = "file:///workspace/examples/navigation_test.bal";
    
    // Test hover information
    log:printInfo("--- Testing hover ---");
    language_server:Position hoverPos = language_server:createPosition(6, 17); // On "calculateSum"
    
    json|error hoverResult = client.hover(
        language_server:createTextDocumentIdentifier(uri), 
        hoverPos
    );
    
    if (hoverResult is json) {
        log:printInfo("Hover result: " + hoverResult.toString());
    } else {
        log:printError("Hover failed: " + hoverResult.message());
    }
    
    // Test go to definition
    log:printInfo("--- Testing go to definition ---");
    language_server:Location[]|error defResult = client.definition(
        language_server:createTextDocumentIdentifier(uri),
        hoverPos
    );
    
    if (defResult is language_server:Location[]) {
        log:printInfo(string `Found ${defResult.length()} definition(s)`);
        foreach language_server:Location location in defResult {
            log:printInfo(string `  Definition at: ${location.uri} (${location.range.'start.line}:${location.range.'start.character})`);
        }
    } else {
        log:printError("Definition lookup failed: " + defResult.message());
    }
    
    // Test find references
    log:printInfo("--- Testing find references ---");
    language_server:Position refPos = language_server:createPosition(2, 16); // On function name
    
    language_server:Location[]|error refResult = client.references(
        language_server:createTextDocumentIdentifier(uri),
        refPos,
        true // Include declaration
    );
    
    if (refResult is language_server:Location[]) {
        log:printInfo(string `Found ${refResult.length()} reference(s)`);
        foreach language_server:Location location in refResult {
            log:printInfo(string `  Reference at: ${location.uri} (${location.range.'start.line}:${location.range.'start.character})`);
        }
    } else {
        log:printError("References lookup failed: " + refResult.message());
    }
    
    check client.didClose(language_server:createTextDocumentIdentifier(uri));
}

// Demonstrate diagnostics handling
function demonstrateDiagnosticsHandling(language_server:LSPClient client) returns error? {
    log:printInfo("=== Diagnostics Handling Demo ===");
    
    // Create a file with intentional errors
    string errorCode = string `import ballerina/io;

public function main() {
    // Error: undefined variable
    io:println(undefinedVar);
    
    // Error: type mismatch
    string name = 123;
    
    // Error: missing return statement
    public function getName() returns string {
        // Missing return
    }
    
    // Warning: unused variable
    int unusedVar = 42;
}`;
    
    language_server:TextDocumentItem errorDoc = language_server:createTextDocumentItem(
        "file:///workspace/examples/error_test.bal",
        "ballerina",
        1,
        errorCode
    );
    
    check client.didOpen(errorDoc);
    log:printInfo("Opened document with intentional errors - waiting for diagnostics...");
    
    // In a real scenario, diagnostics would be pushed by the server
    // Here we simulate by waiting a bit and then requesting completion to trigger analysis
    runtime:sleep(2);
    
    // Trigger server analysis by requesting completion
    _ = client.completion(language_server:createCompletionParams(
        "file:///workspace/examples/error_test.bal",
        language_server:createPosition(4, 15)
    ));
    
    log:printInfo("Diagnostics should have been received (check logs above)");
    
    check client.didClose(language_server:createTextDocumentIdentifier(
        "file:///workspace/examples/error_test.bal"
    ));
}

// Advanced example: LSP client with custom diagnostics handler
public class ExtendedLSPClient {
    private language_server:LSPClient baseClient;
    private DiagnosticsCollector diagnosticsCollector;
    
    public function init(string serverUri) returns error? {
        self.baseClient = new(serverUri);
        self.diagnosticsCollector = new();
    }
    
    public function initialize(language_server:InitializeParams params) returns json|error {
        return self.baseClient.initialize(params);
    }
    
    public function didOpen(language_server:TextDocumentItem document) returns error? {
        return self.baseClient.didOpen(document);
    }
    
    public function completion(language_server:CompletionParams params) 
        returns language_server:CompletionList|language_server:CompletionItem[]|error {
        return self.baseClient.completion(params);
    }
    
    public function getDiagnostics(string uri) returns language_server:Diagnostic[] {
        return self.diagnosticsCollector.getDiagnosticsForUri(uri);
    }
    
    public function getAllDiagnostics() returns map<language_server:Diagnostic[]> {
        return self.diagnosticsCollector.getAllDiagnostics();
    }
    
    public function shutdown() returns error? {
        return self.baseClient.shutdown();
    }
}

// Diagnostics collector for tracking diagnostics across files
class DiagnosticsCollector {
    private map<language_server:Diagnostic[]> diagnosticsByUri = {};
    
    public function addDiagnostics(string uri, language_server:Diagnostic[] diagnostics) {
        self.diagnosticsByUri[uri] = diagnostics.clone();
    }
    
    public function getDiagnosticsForUri(string uri) returns language_server:Diagnostic[] {
        return self.diagnosticsByUri.get(uri).clone();
    }
    
    public function getAllDiagnostics() returns map<language_server:Diagnostic[]> {
        return self.diagnosticsByUri.clone();
    }
    
    public function clearDiagnostics(string uri) {
        _ = self.diagnosticsByUri.remove(uri);
    }
    
    public function clearAllDiagnostics() {
        self.diagnosticsByUri = {};
    }
}

// Performance testing example
public function performanceTest() returns error? {
    log:printInfo("=== LSP Client Performance Test ===");
    
    language_server:LSPClient client = new("http://localhost:9000");
    
    language_server:InitializeParams initParams = {
        processId: (),
        rootUri: "file:///workspace",
        capabilities: language_server:createClientCapabilities()
    };
    
    // Measure initialization time
    int startTime = checkpanic runtime:getCurrentTimeMillis();
    _ = check client.initialize(initParams);
    int initTime = checkpanic runtime:getCurrentTimeMillis() - startTime;
    
    log:printInfo(string `Initialization took: ${initTime}ms`);
    
    // Test multiple file operations
    int numFiles = 10;
    int totalOpenTime = 0;
    int totalCompletionTime = 0;
    
    foreach int i in 1...numFiles {
        string uri = string `file:///workspace/perf_test_${i}.bal`;
        string content = string `import ballerina/io;

public function main() {
    io:println("File ${i}");
}`;
        
        // Measure file open time
        startTime = checkpanic runtime:getCurrentTimeMillis();
        language_server:TextDocumentItem doc = language_server:createTextDocumentItem(
            uri, "ballerina", 1, content
        );
        check client.didOpen(doc);
        totalOpenTime += checkpanic runtime:getCurrentTimeMillis() - startTime;
        
        // Measure completion request time
        startTime = checkpanic runtime:getCurrentTimeMillis();
        _ = client.completion(language_server:createCompletionParams(
            uri, language_server:createPosition(3, 7)
        ));
        totalCompletionTime += checkpanic runtime:getCurrentTimeMillis() - startTime;
        
        // Close file
        check client.didClose(language_server:createTextDocumentIdentifier(uri));
    }
    
    log:printInfo(string `Average file open time: ${totalOpenTime / numFiles}ms`);
    log:printInfo(string `Average completion time: ${totalCompletionTime / numFiles}ms`);
    
    check client.shutdown();
}

// Batch operations example
public function batchOperationsExample() returns error? {
    log:printInfo("=== Batch Operations Example ===");
    
    language_server:LSPClient client = new("http://localhost:9000");
    
    _ = check client.initialize({
        processId: (),
        rootUri: "file:///workspace",
        capabilities: language_server:createClientCapabilities()
    });
    
    // Open multiple related files
    string[] filenames = [
        "models/user.bal",
        "services/user_service.bal", 
        "tests/user_test.bal",
        "utils/validation.bal"
    ];
    
    // Batch open files
    foreach string filename in filenames {
        string content = generateSampleContent(filename);
        language_server:TextDocumentItem doc = language_server:createTextDocumentItem(
            string `file:///workspace/${filename}`,
            "ballerina",
            1,
            content
        );
        check client.didOpen(doc);
        log:printInfo("Opened: " + filename);
    }
    
    // Batch completion requests for all files
    foreach string filename in filenames {
        language_server:CompletionParams params = language_server:createCompletionParams(
            string `file:///workspace/${filename}`,
            language_server:createPosition(2, 0) // Beginning of third line
        );
        
        language_server:CompletionList|language_server:CompletionItem[]|error result = 
            client.completion(params);
        
        if (result is error) {
            log:printError(string `Completion failed for ${filename}: ${result.message()}`);
        } else {
            int count = result is language_server:CompletionList ? 
                result.items.length() : result.length();
            log:printInfo(string `${filename}: ${count} completions available`);
        }
    }
    
    // Batch close files
    foreach string filename in filenames {
        check client.didClose(language_server:createTextDocumentIdentifier(
            string `file:///workspace/${filename}`
        ));
    }
    
    check client.shutdown();
}

function generateSampleContent(string filename) returns string {
    match filename {
        "models/user.bal" => {
            return string `public type User record {|
    string id;
    string name;
    string email;
    int age?;
|};`;
        }
        "services/user_service.bal" => {
            return string `import ballerina/http;

service /users on new http:Listener(8080) {
    resource function get .() returns json {
        return {"message": "User service"};
    }
}`;
        }
        "tests/user_test.bal" => {
            return string `import ballerina/test;

@test:Config {}
function testUserCreation() {
    // Test implementation
}`;
        }
        _ => {
            return string `// Generated content for ${filename}

public function main() {
    // Implementation here
}`;
        }
    }
}

// Main demonstration function
public function main() returns error? {
    log:printInfo("Starting LSP Integration Examples");
    
    // Run basic integration example
    check integrateWithBallerinaLS();
    
    // Run performance test
    check performanceTest();
    
    // Run batch operations example  
    check batchOperationsExample();
    
    log:printInfo("All LSP integration examples completed successfully");
}