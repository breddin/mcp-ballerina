// LSP Client Module for Ballerina MCP Server
// Implements Language Server Protocol communication with JSON-RPC 2.0

import ballerina/io;
import ballerina/log;
import ballerina/http;
import ballerina/lang.'string;
import ballerina/uuid;
import ballerina/time;
import ballerina/regex;

// LSP Message Types
public type LSPRequestMessage record {|
    string jsonrpc = "2.0";
    string id;
    string method;
    json params?;
|};

public type LSPResponseMessage record {|
    string jsonrpc = "2.0";
    string id;
    json result?;
    LSPError 'error?;
|};

public type LSPNotificationMessage record {|
    string jsonrpc = "2.0";
    string method;
    json params?;
|};

public type LSPError record {|
    int code;
    string message;
    json data?;
|};

// LSP Initialize Types
public type InitializeParams record {|
    int processId?;
    string? rootPath?;
    string? rootUri?;
    json initializationOptions?;
    ClientCapabilities capabilities;
    string? trace?;
    WorkspaceFolder[]? workspaceFolders?;
|};

public type ClientCapabilities record {|
    WorkspaceClientCapabilities? workspace?;
    TextDocumentClientCapabilities? textDocument?;
    json? experimental?;
|};

public type WorkspaceClientCapabilities record {|
    boolean? applyEdit?;
    WorkspaceEditCapabilities? workspaceEdit?;
    DidChangeConfigurationCapabilities? didChangeConfiguration?;
    DidChangeWatchedFilesCapabilities? didChangeWatchedFiles?;
    SymbolCapabilities? symbol?;
    ExecuteCommandCapabilities? executeCommand?;
|};

public type TextDocumentClientCapabilities record {|
    SynchronizationCapabilities? synchronization?;
    CompletionCapabilities? completion?;
    HoverCapabilities? hover?;
    SignatureHelpCapabilities? signatureHelp?;
    ReferencesCapabilities? references?;
    DocumentHighlightCapabilities? documentHighlight?;
    DocumentSymbolCapabilities? documentSymbol?;
    FormattingCapabilities? formatting?;
    RangeFormattingCapabilities? rangeFormatting?;
    OnTypeFormattingCapabilities? onTypeFormatting?;
    DefinitionCapabilities? definition?;
    CodeActionCapabilities? codeAction?;
    CodeLensCapabilities? codeLens?;
    DocumentLinkCapabilities? documentLink?;
    RenameCapabilities? rename?;
|};

public type SynchronizationCapabilities record {|
    boolean? dynamicRegistration?;
    boolean? willSave?;
    boolean? willSaveWaitUntil?;
    boolean? didSave?;
|};

public type CompletionCapabilities record {|
    boolean? dynamicRegistration?;
    CompletionItemCapabilities? completionItem?;
    CompletionItemKindCapabilities? completionItemKind?;
    boolean? contextSupport?;
|};

public type CompletionItemCapabilities record {|
    boolean? snippetSupport?;
    boolean? commitCharactersSupport?;
    string[]? documentationFormat?;
    boolean? deprecatedSupport?;
    boolean? preselectSupport?;
|};

public type CompletionItemKindCapabilities record {|
    int[]? valueSet?;
|};

public type HoverCapabilities record {|
    boolean? dynamicRegistration?;
    string[]? contentFormat?;
|};

public type SignatureHelpCapabilities record {|
    boolean? dynamicRegistration?;
    SignatureInformationCapabilities? signatureInformation?;
|};

public type SignatureInformationCapabilities record {|
    string[]? documentationFormat?;
|};

public type ReferencesCapabilities record {|
    boolean? dynamicRegistration?;
|};

public type DocumentHighlightCapabilities record {|
    boolean? dynamicRegistration?;
|};

public type DocumentSymbolCapabilities record {|
    boolean? dynamicRegistration?;
    SymbolKindCapabilities? symbolKind?;
|};

public type SymbolKindCapabilities record {|
    int[]? valueSet?;
|};

public type FormattingCapabilities record {|
    boolean? dynamicRegistration?;
|};

public type RangeFormattingCapabilities record {|
    boolean? dynamicRegistration?;
|};

public type OnTypeFormattingCapabilities record {|
    boolean? dynamicRegistration?;
|};

public type DefinitionCapabilities record {|
    boolean? dynamicRegistration?;
|};

public type CodeActionCapabilities record {|
    boolean? dynamicRegistration?;
    CodeActionLiteralSupportCapabilities? codeActionLiteralSupport?;
|};

public type CodeActionLiteralSupportCapabilities record {|
    CodeActionKindCapabilities? codeActionKind?;
|};

public type CodeActionKindCapabilities record {|
    string[]? valueSet?;
|};

public type CodeLensCapabilities record {|
    boolean? dynamicRegistration?;
|};

public type DocumentLinkCapabilities record {|
    boolean? dynamicRegistration?;
|};

public type RenameCapabilities record {|
    boolean? dynamicRegistration?;
    boolean? prepareSupport?;
|};

public type WorkspaceEditCapabilities record {|
    boolean? documentChanges?;
    string[]? resourceOperations?;
    string[]? failureHandling?;
|};

public type DidChangeConfigurationCapabilities record {|
    boolean? dynamicRegistration?;
|};

public type DidChangeWatchedFilesCapabilities record {|
    boolean? dynamicRegistration?;
|};

public type SymbolCapabilities record {|
    boolean? dynamicRegistration?;
    SymbolKindCapabilities? symbolKind?;
|};

public type ExecuteCommandCapabilities record {|
    boolean? dynamicRegistration?;
|};

public type WorkspaceFolder record {|
    string uri;
    string name;
|};

// Text Document Types
public type TextDocumentItem record {|
    string uri;
    string languageId;
    int version;
    string text;
|};

public type TextDocumentIdentifier record {|
    string uri;
|};

public type VersionedTextDocumentIdentifier record {|
    *TextDocumentIdentifier;
    int? version;
|};

public type Position record {|
    int line;
    int character;
|};

public type Range record {|
    Position 'start;
    Position end;
|};

public type Location record {|
    string uri;
    Range range;
|};

// Diagnostic Types
public type Diagnostic record {|
    Range range;
    int? severity?;
    string? code?;
    string? 'source?;
    string message;
    DiagnosticRelatedInformation[]? relatedInformation?;
|};

public type DiagnosticRelatedInformation record {|
    Location location;
    string message;
|};

public type PublishDiagnosticsParams record {|
    string uri;
    Diagnostic[] diagnostics;
|};

// Completion Types
public type CompletionParams record {|
    *TextDocumentIdentifier;
    Position position;
    CompletionContext? context?;
|};

public type CompletionContext record {|
    int triggerKind;
    string? triggerCharacter?;
|};

public type CompletionItem record {|
    string label;
    int? kind?;
    string? detail?;
    string? documentation?;
    boolean? deprecated?;
    boolean? preselect?;
    string? sortText?;
    string? filterText?;
    string? insertText?;
    int? insertTextFormat?;
    TextEdit? textEdit?;
    TextEdit[]? additionalTextEdits?;
    string[]? commitCharacters?;
    Command? command?;
    json? data?;
|};

public type CompletionList record {|
    boolean isIncomplete;
    CompletionItem[] items;
|};

public type TextEdit record {|
    Range range;
    string newText;
|};

public type Command record {|
    string title;
    string command;
    json[]? arguments?;
|};

// LSP Client class
public class LSPClient {
    private http:Client httpClient;
    private map<function (json) returns ()> pendingRequests = {};
    private int requestIdCounter = 0;
    private boolean initialized = false;
    private string serverUri;
    
    public function init(string serverUri) returns error? {
        self.serverUri = serverUri;
        self.httpClient = check new (serverUri);
        log:printInfo("LSP Client initialized for server: " + serverUri);
    }
    
    // Initialize the language server
    public function initialize(InitializeParams params) returns json|error {
        LSPRequestMessage request = {
            id: self.generateRequestId(),
            method: "initialize",
            params: params.toJson()
        };
        
        json response = check self.sendRequest(request);
        self.initialized = true;
        log:printInfo("LSP Server initialized successfully");
        
        // Send initialized notification
        check self.sendNotification("initialized", {});
        
        return response;
    }
    
    // Send textDocument/didOpen notification
    public function didOpen(TextDocumentItem document) returns error? {
        if (!self.initialized) {
            return error("LSP Client not initialized");
        }
        
        json params = {
            textDocument: document.toJson()
        };
        
        return self.sendNotification("textDocument/didOpen", params);
    }
    
    // Send textDocument/didChange notification
    public function didChange(VersionedTextDocumentIdentifier document, 
                             TextDocumentContentChangeEvent[] changes) returns error? {
        if (!self.initialized) {
            return error("LSP Client not initialized");
        }
        
        json params = {
            textDocument: document.toJson(),
            contentChanges: changes.map(change => change.toJson())
        };
        
        return self.sendNotification("textDocument/didChange", params);
    }
    
    // Send textDocument/didClose notification
    public function didClose(TextDocumentIdentifier document) returns error? {
        if (!self.initialized) {
            return error("LSP Client not initialized");
        }
        
        json params = {
            textDocument: document.toJson()
        };
        
        return self.sendNotification("textDocument/didClose", params);
    }
    
    // Request textDocument/completion
    public function completion(CompletionParams params) returns CompletionList|CompletionItem[]|error {
        if (!self.initialized) {
            return error("LSP Client not initialized");
        }
        
        LSPRequestMessage request = {
            id: self.generateRequestId(),
            method: "textDocument/completion",
            params: params.toJson()
        };
        
        json response = check self.sendRequest(request);
        
        // Parse response as CompletionList or CompletionItem[]
        if (response is json[] && response.length() > 0) {
            return response.map(item => check item.cloneWithType(CompletionItem));
        } else if (response is json) {
            return check response.cloneWithType(CompletionList);
        }
        
        return [];
    }
    
    // Request textDocument/hover
    public function hover(TextDocumentIdentifier document, Position position) returns json|error {
        if (!self.initialized) {
            return error("LSP Client not initialized");
        }
        
        LSPRequestMessage request = {
            id: self.generateRequestId(),
            method: "textDocument/hover",
            params: {
                textDocument: document.toJson(),
                position: position.toJson()
            }
        };
        
        return self.sendRequest(request);
    }
    
    // Request textDocument/definition
    public function definition(TextDocumentIdentifier document, Position position) returns Location[]|error {
        if (!self.initialized) {
            return error("LSP Client not initialized");
        }
        
        LSPRequestMessage request = {
            id: self.generateRequestId(),
            method: "textDocument/definition",
            params: {
                textDocument: document.toJson(),
                position: position.toJson()
            }
        };
        
        json response = check self.sendRequest(request);
        
        if (response is json[]) {
            return response.map(loc => check loc.cloneWithType(Location));
        }
        
        return [];
    }
    
    // Request textDocument/references
    public function references(TextDocumentIdentifier document, Position position, 
                              boolean includeDeclaration) returns Location[]|error {
        if (!self.initialized) {
            return error("LSP Client not initialized");
        }
        
        LSPRequestMessage request = {
            id: self.generateRequestId(),
            method: "textDocument/references",
            params: {
                textDocument: document.toJson(),
                position: position.toJson(),
                context: {
                    includeDeclaration: includeDeclaration
                }
            }
        };
        
        json response = check self.sendRequest(request);
        
        if (response is json[]) {
            return response.map(loc => check loc.cloneWithType(Location));
        }
        
        return [];
    }
    
    // Send shutdown request
    public function shutdown() returns error? {
        if (!self.initialized) {
            return error("LSP Client not initialized");
        }
        
        LSPRequestMessage request = {
            id: self.generateRequestId(),
            method: "shutdown",
            params: ()
        };
        
        _ = check self.sendRequest(request);
        
        // Send exit notification
        check self.sendNotification("exit", {});
        
        self.initialized = false;
        log:printInfo("LSP Server shutdown successfully");
    }
    
    // Handle incoming notifications (like diagnostics)
    public function handleNotification(LSPNotificationMessage notification) {
        match notification.method {
            "textDocument/publishDiagnostics" => {
                self.handleDiagnostics(notification.params);
            }
            "window/showMessage" => {
                self.handleShowMessage(notification.params);
            }
            "window/logMessage" => {
                self.handleLogMessage(notification.params);
            }
            _ => {
                log:printDebug("Unhandled notification: " + notification.method);
            }
        }
    }
    
    // Handle incoming responses
    public function handleResponse(LSPResponseMessage response) {
        string id = response.id;
        if (self.pendingRequests.hasKey(id)) {
            function (json) returns () callback = self.pendingRequests.get(id);
            if (response.'error is LSPError) {
                log:printError("LSP Error for request " + id + ": " + 
                               response.'error.toString());
            } else {
                callback(response.result ?: {});
            }
            _ = self.pendingRequests.remove(id);
        } else {
            log:printWarn("Received response for unknown request: " + id);
        }
    }
    
    // Private helper methods
    private function sendRequest(LSPRequestMessage request) returns json|error {
        string requestJson = request.toJsonString();
        log:printDebug("Sending LSP request: " + requestJson);
        
        http:Response response = check self.httpClient->post("/lsp", requestJson, 
            {"Content-Type": "application/json"});
        
        if (response.statusCode != 200) {
            return error("LSP request failed with status: " + response.statusCode.toString());
        }
        
        json responsePayload = check response.getJsonPayload();
        LSPResponseMessage lspResponse = check responsePayload.cloneWithType(LSPResponseMessage);
        
        if (lspResponse.'error is LSPError) {
            return error("LSP Error: " + lspResponse.'error.message);
        }
        
        return lspResponse.result ?: {};
    }
    
    private function sendNotification(string method, json params) returns error? {
        LSPNotificationMessage notification = {
            method: method,
            params: params
        };
        
        string notificationJson = notification.toJsonString();
        log:printDebug("Sending LSP notification: " + notificationJson);
        
        http:Response response = check self.httpClient->post("/lsp", notificationJson,
            {"Content-Type": "application/json"});
        
        if (response.statusCode != 200) {
            return error("LSP notification failed with status: " + response.statusCode.toString());
        }
    }
    
    private function generateRequestId() returns string {
        self.requestIdCounter += 1;
        return "lsp-" + self.requestIdCounter.toString();
    }
    
    private function handleDiagnostics(json? params) {
        if (params is json) {
            PublishDiagnosticsParams diagnosticsParams = 
                params.cloneWithType(PublishDiagnosticsParams) ?: return;
            
            log:printInfo("Received diagnostics for: " + diagnosticsParams.uri);
            foreach Diagnostic diagnostic in diagnosticsParams.diagnostics {
                string severity = diagnostic.severity == 1 ? "ERROR" : 
                                diagnostic.severity == 2 ? "WARNING" : 
                                diagnostic.severity == 3 ? "INFO" : "HINT";
                
                log:printInfo(string `${severity}: ${diagnostic.message} at line ${diagnostic.range.'start.line + 1}`);
            }
        }
    }
    
    private function handleShowMessage(json? params) {
        if (params is json) {
            string message = params.message is string ? params.message.toString() : "Unknown message";
            int messageType = params.type is int ? <int>params.type : 1;
            
            string typeStr = messageType == 1 ? "ERROR" : 
                           messageType == 2 ? "WARNING" : 
                           messageType == 3 ? "INFO" : "LOG";
            
            log:printInfo(string `LSP ${typeStr}: ${message}`);
        }
    }
    
    private function handleLogMessage(json? params) {
        if (params is json) {
            string message = params.message is string ? params.message.toString() : "Unknown message";
            log:printDebug("LSP Log: " + message);
        }
    }
}

// Text Document Content Change Event
public type TextDocumentContentChangeEvent record {|
    Range? range?;
    int? rangeLength?;
    string text;
|};

// Utility functions for creating common LSP structures
public function createClientCapabilities() returns ClientCapabilities {
    return {
        textDocument: {
            synchronization: {
                dynamicRegistration: true,
                willSave: true,
                willSaveWaitUntil: true,
                didSave: true
            },
            completion: {
                dynamicRegistration: true,
                completionItem: {
                    snippetSupport: true,
                    commitCharactersSupport: true,
                    documentationFormat: ["markdown", "plaintext"],
                    deprecatedSupport: true,
                    preselectSupport: true
                },
                completionItemKind: {
                    valueSet: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25]
                },
                contextSupport: true
            },
            hover: {
                dynamicRegistration: true,
                contentFormat: ["markdown", "plaintext"]
            },
            signatureHelp: {
                dynamicRegistration: true,
                signatureInformation: {
                    documentationFormat: ["markdown", "plaintext"]
                }
            },
            references: {
                dynamicRegistration: true
            },
            documentHighlight: {
                dynamicRegistration: true
            },
            documentSymbol: {
                dynamicRegistration: true,
                symbolKind: {
                    valueSet: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26]
                }
            },
            formatting: {
                dynamicRegistration: true
            },
            rangeFormatting: {
                dynamicRegistration: true
            },
            onTypeFormatting: {
                dynamicRegistration: true
            },
            definition: {
                dynamicRegistration: true
            },
            codeAction: {
                dynamicRegistration: true,
                codeActionLiteralSupport: {
                    codeActionKind: {
                        valueSet: ["quickfix", "refactor", "refactor.extract", "refactor.inline", "refactor.rewrite", "source", "source.organizeImports"]
                    }
                }
            },
            codeLens: {
                dynamicRegistration: true
            },
            documentLink: {
                dynamicRegistration: true
            },
            rename: {
                dynamicRegistration: true,
                prepareSupport: true
            }
        },
        workspace: {
            applyEdit: true,
            workspaceEdit: {
                documentChanges: true,
                resourceOperations: ["create", "rename", "delete"],
                failureHandling: ["textOnlyTransactional", "undo", "abort"]
            },
            didChangeConfiguration: {
                dynamicRegistration: true
            },
            didChangeWatchedFiles: {
                dynamicRegistration: true
            },
            symbol: {
                dynamicRegistration: true,
                symbolKind: {
                    valueSet: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26]
                }
            },
            executeCommand: {
                dynamicRegistration: true
            }
        }
    };
}

public function createPosition(int line, int character) returns Position {
    return {
        line: line,
        character: character
    };
}

public function createRange(Position 'start, Position end) returns Range {
    return {
        'start: 'start,
        end: end
    };
}

public function createTextDocumentIdentifier(string uri) returns TextDocumentIdentifier {
    return {
        uri: uri
    };
}

public function createVersionedTextDocumentIdentifier(string uri, int? version) 
    returns VersionedTextDocumentIdentifier {
    return {
        uri: uri,
        version: version
    };
}

public function createTextDocumentItem(string uri, string languageId, int version, string text) 
    returns TextDocumentItem {
    return {
        uri: uri,
        languageId: languageId,
        version: version,
        text: text
    };
}

public function createCompletionParams(string uri, Position position) returns CompletionParams {
    return {
        uri: uri,
        position: position
    };
}

// Example usage and testing functions
public function testLSPClient() returns error? {
    LSPClient client = new("http://localhost:8080");
    
    // Initialize
    InitializeParams initParams = {
        processId: (),
        rootUri: "file:///workspace",
        capabilities: createClientCapabilities(),
        initializationOptions: {}
    };
    
    json initResult = check client.initialize(initParams);
    log:printInfo("Initialize result: " + initResult.toString());
    
    // Open a document
    TextDocumentItem document = createTextDocumentItem(
        "file:///workspace/test.bal",
        "ballerina",
        1,
        "import ballerina/io;\n\npublic function main() {\n    io:println(\"Hello, World!\");\n}"
    );
    
    check client.didOpen(document);
    
    // Request completion
    CompletionParams completionParams = createCompletionParams(
        "file:///workspace/test.bal",
        createPosition(3, 7)
    );
    
    CompletionList|CompletionItem[] completions = check client.completion(completionParams);
    log:printInfo("Completions received: " + completions.toString());
    
    // Shutdown
    check client.shutdown();
    
    return;
}

// Request correlation manager for handling async responses
public class RequestCorrelationManager {
    private map<RequestInfo> pendingRequests = {};
    
    public function addRequest(string id, string method, function (json) returns () callback) {
        RequestInfo info = {
            id: id,
            method: method,
            callback: callback,
            timestamp: time:utcNow()[0]
        };
        self.pendingRequests[id] = info;
    }
    
    public function handleResponse(string id, json result, LSPError? 'error) {
        if (self.pendingRequests.hasKey(id)) {
            RequestInfo info = self.pendingRequests.get(id);
            if ('error is LSPError) {
                log:printError(string `Request ${id} failed: ${'error.message}`);
            } else {
                info.callback(result);
            }
            _ = self.pendingRequests.remove(id);
        }
    }
    
    public function cleanupExpiredRequests(int timeoutSeconds = 30) {
        int currentTime = time:utcNow()[0];
        string[] expiredIds = [];
        
        foreach string id in self.pendingRequests.keys() {
            RequestInfo info = self.pendingRequests.get(id);
            if (currentTime - info.timestamp > timeoutSeconds) {
                expiredIds.push(id);
            }
        }
        
        foreach string id in expiredIds {
            _ = self.pendingRequests.remove(id);
            log:printWarn("Request " + id + " expired and removed");
        }
    }
}

type RequestInfo record {|
    string id;
    string method;
    function (json) returns () callback;
    int timestamp;
|};