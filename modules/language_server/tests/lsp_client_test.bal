// LSP Client Test Suite
// Comprehensive tests for the Language Server Protocol client implementation

import ballerina/test;
import ballerina/log;
import ballerina/http;
import ballerina/lang.runtime;

// Mock LSP Server for testing
service /lsp on new http:Listener(8080) {
    private map<json> responses = {};
    private json[] notifications = [];
    
    resource function post .(http:Request req) returns http:Response|error {
        json payload = check req.getJsonPayload();
        http:Response response = new;
        
        // Handle different message types
        if (payload.id is string) {
            // It's a request - return appropriate response
            json result = self.handleRequest(<string>payload.id, <string>payload.method, payload.params);
            json responsePayload = {
                "jsonrpc": "2.0",
                "id": payload.id,
                "result": result
            };
            response.setJsonPayload(responsePayload);
        } else {
            // It's a notification - store it
            self.notifications.push(payload);
            response.setJsonPayload({});
        }
        
        response.statusCode = 200;
        response.setHeader("Content-Type", "application/json");
        return response;
    }
    
    private function handleRequest(string id, string method, json params) returns json {
        match method {
            "initialize" => {
                return {
                    "capabilities": {
                        "textDocumentSync": 1,
                        "completionProvider": {
                            "resolveProvider": true,
                            "triggerCharacters": ["."]
                        },
                        "hoverProvider": true,
                        "definitionProvider": true,
                        "referencesProvider": true
                    }
                };
            }
            "textDocument/completion" => {
                return {
                    "isIncomplete": false,
                    "items": [
                        {
                            "label": "println",
                            "kind": 3,
                            "detail": "function println(any... values)",
                            "documentation": "Prints values to stdout",
                            "insertText": "println"
                        },
                        {
                            "label": "main",
                            "kind": 3,
                            "detail": "public function main()",
                            "documentation": "Main function",
                            "insertText": "main"
                        }
                    ]
                };
            }
            "textDocument/hover" => {
                return {
                    "contents": {
                        "kind": "markdown",
                        "value": "**println**\n\nPrints values to standard output"
                    }
                };
            }
            "textDocument/definition" => {
                return [
                    {
                        "uri": "file:///workspace/stdlib.bal",
                        "range": {
                            "start": {"line": 10, "character": 0},
                            "end": {"line": 10, "character": 7}
                        }
                    }
                ];
            }
            "textDocument/references" => {
                return [
                    {
                        "uri": "file:///workspace/test.bal",
                        "range": {
                            "start": {"line": 3, "character": 4},
                            "end": {"line": 3, "character": 11}
                        }
                    }
                ];
            }
            "shutdown" => {
                return {};
            }
            _ => {
                return {"error": "Method not supported"};
            }
        }
    }
    
    public function getNotifications() returns json[] {
        return self.notifications.clone();
    }
    
    public function clearNotifications() {
        self.notifications = [];
    }
}

@test:Config {}
function testLSPClientInitialization() returns error? {
    // Start mock server
    runtime:sleep(1); // Allow server to start
    
    LSPClient client = new("http://localhost:8080");
    
    InitializeParams initParams = {
        processId: (),
        rootUri: "file:///workspace",
        capabilities: createClientCapabilities(),
        initializationOptions: {}
    };
    
    json result = check client.initialize(initParams);
    
    // Verify initialization response
    test:assertTrue(result.capabilities is json, "Should have capabilities");
    json capabilities = <json>result.capabilities;
    test:assertTrue(capabilities.textDocumentSync is json, "Should have textDocumentSync");
    test:assertTrue(capabilities.completionProvider is json, "Should have completionProvider");
    
    // Shutdown
    check client.shutdown();
}

@test:Config {dependsOn: [testLSPClientInitialization]}
function testTextDocumentOperations() returns error? {
    LSPClient client = new("http://localhost:8080");
    
    // Initialize
    InitializeParams initParams = {
        processId: (),
        rootUri: "file:///workspace",
        capabilities: createClientCapabilities()
    };
    _ = check client.initialize(initParams);
    
    // Test didOpen
    TextDocumentItem document = createTextDocumentItem(
        "file:///workspace/test.bal",
        "ballerina",
        1,
        "import ballerina/io;\n\npublic function main() {\n    io:println(\"Hello!\");\n}"
    );
    
    check client.didOpen(document);
    
    // Test didChange
    VersionedTextDocumentIdentifier versionedDoc = createVersionedTextDocumentIdentifier(
        "file:///workspace/test.bal",
        2
    );
    
    TextDocumentContentChangeEvent[] changes = [
        {
            range: createRange(createPosition(3, 15), createPosition(3, 22)),
            text: "World!"
        }
    ];
    
    check client.didChange(versionedDoc, changes);
    
    // Test didClose
    TextDocumentIdentifier docId = createTextDocumentIdentifier("file:///workspace/test.bal");
    check client.didClose(docId);
    
    check client.shutdown();
}

@test:Config {dependsOn: [testTextDocumentOperations]}
function testCompletion() returns error? {
    LSPClient client = new("http://localhost:8080");
    
    // Initialize
    InitializeParams initParams = {
        processId: (),
        rootUri: "file:///workspace",
        capabilities: createClientCapabilities()
    };
    _ = check client.initialize(initParams);
    
    // Open document
    TextDocumentItem document = createTextDocumentItem(
        "file:///workspace/test.bal",
        "ballerina",
        1,
        "import ballerina/io;\n\npublic function main() {\n    io:\n}"
    );
    check client.didOpen(document);
    
    // Request completion
    CompletionParams params = createCompletionParams(
        "file:///workspace/test.bal",
        createPosition(3, 7)
    );
    
    CompletionList|CompletionItem[] result = check client.completion(params);
    
    // Verify completion results
    if (result is CompletionList) {
        test:assertTrue(result.items.length() > 0, "Should have completion items");
        test:assertEquals(result.items[0].label, "println", "First item should be println");
    } else if (result is CompletionItem[]) {
        test:assertTrue(result.length() > 0, "Should have completion items");
        test:assertEquals(result[0].label, "println", "First item should be println");
    }
    
    check client.shutdown();
}

@test:Config {dependsOn: [testCompletion]}
function testHover() returns error? {
    LSPClient client = new("http://localhost:8080");
    
    // Initialize
    InitializeParams initParams = {
        processId: (),
        rootUri: "file:///workspace",
        capabilities: createClientCapabilities()
    };
    _ = check client.initialize(initParams);
    
    // Open document
    TextDocumentItem document = createTextDocumentItem(
        "file:///workspace/test.bal",
        "ballerina",
        1,
        "import ballerina/io;\n\npublic function main() {\n    io:println(\"Hello!\");\n}"
    );
    check client.didOpen(document);
    
    // Request hover
    TextDocumentIdentifier docId = createTextDocumentIdentifier("file:///workspace/test.bal");
    Position position = createPosition(3, 7);
    
    json result = check client.hover(docId, position);
    
    // Verify hover result
    test:assertTrue(result.contents is json, "Should have contents");
    json contents = <json>result.contents;
    test:assertTrue(contents.value is string, "Should have value");
    test:assertTrue((<string>contents.value).includes("println"), "Should contain 'println'");
    
    check client.shutdown();
}

@test:Config {dependsOn: [testHover]}
function testDefinition() returns error? {
    LSPClient client = new("http://localhost:8080");
    
    // Initialize
    InitializeParams initParams = {
        processId: (),
        rootUri: "file:///workspace",
        capabilities: createClientCapabilities()
    };
    _ = check client.initialize(initParams);
    
    // Open document
    TextDocumentItem document = createTextDocumentItem(
        "file:///workspace/test.bal",
        "ballerina",
        1,
        "import ballerina/io;\n\npublic function main() {\n    io:println(\"Hello!\");\n}"
    );
    check client.didOpen(document);
    
    // Request definition
    TextDocumentIdentifier docId = createTextDocumentIdentifier("file:///workspace/test.bal");
    Position position = createPosition(3, 7);
    
    Location[] locations = check client.definition(docId, position);
    
    // Verify definition results
    test:assertTrue(locations.length() > 0, "Should have definition locations");
    test:assertEquals(locations[0].uri, "file:///workspace/stdlib.bal", "Should point to stdlib");
    test:assertEquals(locations[0].range.'start.line, 10, "Should be at line 10");
    
    check client.shutdown();
}

@test:Config {dependsOn: [testDefinition]}
function testReferences() returns error? {
    LSPClient client = new("http://localhost:8080");
    
    // Initialize
    InitializeParams initParams = {
        processId: (),
        rootUri: "file:///workspace",
        capabilities: createClientCapabilities()
    };
    _ = check client.initialize(initParams);
    
    // Open document
    TextDocumentItem document = createTextDocumentItem(
        "file:///workspace/test.bal",
        "ballerina",
        1,
        "import ballerina/io;\n\npublic function main() {\n    io:println(\"Hello!\");\n}"
    );
    check client.didOpen(document);
    
    // Request references
    TextDocumentIdentifier docId = createTextDocumentIdentifier("file:///workspace/test.bal");
    Position position = createPosition(3, 7);
    
    Location[] locations = check client.references(docId, position, true);
    
    // Verify references results
    test:assertTrue(locations.length() > 0, "Should have reference locations");
    test:assertEquals(locations[0].uri, "file:///workspace/test.bal", "Should reference current file");
    
    check client.shutdown();
}

@test:Config {dependsOn: [testReferences]}
function testRequestCorrelationManager() returns error? {
    RequestCorrelationManager manager = new();
    
    boolean callbackExecuted = false;
    function (json) returns () testCallback = function(json result) {
        callbackExecuted = true;
    };
    
    // Add request
    manager.addRequest("test-1", "textDocument/completion", testCallback);
    
    // Handle response
    manager.handleResponse("test-1", {"items": []}, ());
    
    test:assertTrue(callbackExecuted, "Callback should have been executed");
    
    // Test error handling
    boolean errorLogged = false;
    manager.addRequest("test-2", "textDocument/hover", function(json result) {
        // This should not be called
        test:assertFail("Callback should not be called for error response");
    });
    
    LSPError testError = {
        code: -32601,
        message: "Method not found"
    };
    
    manager.handleResponse("test-2", (), testError);
    
    // Test cleanup (requires time manipulation in real scenario)
    // For now, just test the method exists
    manager.cleanupExpiredRequests(30);
}

@test:Config {dependsOn: [testRequestCorrelationManager]}
function testUtilityFunctions() returns error? {
    // Test position creation
    Position pos = createPosition(10, 5);
    test:assertEquals(pos.line, 10, "Line should be 10");
    test:assertEquals(pos.character, 5, "Character should be 5");
    
    // Test range creation
    Position start = createPosition(1, 0);
    Position end = createPosition(1, 10);
    Range range = createRange(start, end);
    test:assertEquals(range.'start.line, 1, "Start line should be 1");
    test:assertEquals(range.end.character, 10, "End character should be 10");
    
    // Test document identifier creation
    TextDocumentIdentifier docId = createTextDocumentIdentifier("file:///test.bal");
    test:assertEquals(docId.uri, "file:///test.bal", "URI should match");
    
    // Test versioned document identifier
    VersionedTextDocumentIdentifier versionedDocId = 
        createVersionedTextDocumentIdentifier("file:///test.bal", 5);
    test:assertEquals(versionedDocId.uri, "file:///test.bal", "URI should match");
    test:assertEquals(versionedDocId.version, 5, "Version should be 5");
    
    // Test text document item creation
    TextDocumentItem docItem = createTextDocumentItem(
        "file:///test.bal",
        "ballerina", 
        1, 
        "public function main() {}"
    );
    test:assertEquals(docItem.uri, "file:///test.bal", "URI should match");
    test:assertEquals(docItem.languageId, "ballerina", "Language ID should be ballerina");
    test:assertEquals(docItem.version, 1, "Version should be 1");
    test:assertEquals(docItem.text, "public function main() {}", "Text should match");
    
    // Test completion params creation
    CompletionParams completionParams = createCompletionParams(
        "file:///test.bal",
        createPosition(0, 5)
    );
    test:assertEquals(completionParams.uri, "file:///test.bal", "URI should match");
    test:assertEquals(completionParams.position.line, 0, "Position line should be 0");
    test:assertEquals(completionParams.position.character, 5, "Position character should be 5");
    
    // Test client capabilities creation
    ClientCapabilities caps = createClientCapabilities();
    test:assertTrue(caps.textDocument is TextDocumentClientCapabilities, 
                   "Should have text document capabilities");
    test:assertTrue(caps.workspace is WorkspaceClientCapabilities, 
                   "Should have workspace capabilities");
    
    // Test nested capabilities
    if (caps.textDocument is TextDocumentClientCapabilities) {
        TextDocumentClientCapabilities textCaps = <TextDocumentClientCapabilities>caps.textDocument;
        test:assertTrue(textCaps.completion is CompletionCapabilities, 
                       "Should have completion capabilities");
        test:assertTrue(textCaps.hover is HoverCapabilities, 
                       "Should have hover capabilities");
        test:assertTrue(textCaps.definition is DefinitionCapabilities, 
                       "Should have definition capabilities");
    }
}

@test:Config {}
function testErrorHandling() returns error? {
    // Test uninitialized client operations
    LSPClient client = new("http://localhost:8080");
    
    // These should fail because client is not initialized
    TextDocumentItem document = createTextDocumentItem(
        "file:///test.bal",
        "ballerina",
        1,
        "test content"
    );
    
    error? result = client.didOpen(document);
    test:assertTrue(result is error, "didOpen should fail on uninitialized client");
    
    CompletionParams params = createCompletionParams(
        "file:///test.bal",
        createPosition(0, 0)
    );
    
    CompletionList|CompletionItem[]|error completionResult = client.completion(params);
    test:assertTrue(completionResult is error, "completion should fail on uninitialized client");
    
    // Test with invalid server URL
    LSPClient invalidClient = new("http://invalid-server:9999");
    
    InitializeParams initParams = {
        processId: (),
        rootUri: "file:///workspace",
        capabilities: createClientCapabilities()
    };
    
    json|error initResult = invalidClient.initialize(initParams);
    test:assertTrue(initResult is error, "Should fail to connect to invalid server");
}

// Performance test for request correlation
@test:Config {}
function testRequestCorrelationPerformance() returns error? {
    RequestCorrelationManager manager = new();
    
    // Add many requests
    int numRequests = 1000;
    foreach int i in 1...numRequests {
        manager.addRequest("test-" + i.toString(), "test/method", function(json result) {
            // No-op callback
        });
    }
    
    // Measure cleanup time (simplified test)
    int startTime = checkpanic time:utcNow()[0];
    manager.cleanupExpiredRequests(0); // This should clean all as they're "expired"
    int endTime = checkpanic time:utcNow()[0];
    
    int duration = endTime - startTime;
    test:assertTrue(duration < 5, "Cleanup should be fast even with many requests");
    
    log:printInfo(string `Cleaned up ${numRequests} requests in ${duration} seconds`);
}