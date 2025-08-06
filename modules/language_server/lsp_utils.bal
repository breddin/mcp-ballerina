// LSP Utility Functions and Helpers
// Additional utilities for working with LSP protocol and Ballerina integration

import ballerina/io;
import ballerina/log;
import ballerina/lang.'string;
import ballerina/regex;
import ballerina/file;

// LSP Protocol Constants
public const LSP_VERSION = "3.17.0";
public const JSONRPC_VERSION = "2.0";

// Message Types
public const MESSAGE_TYPE_ERROR = 1;
public const MESSAGE_TYPE_WARNING = 2;
public const MESSAGE_TYPE_INFO = 3;
public const MESSAGE_TYPE_LOG = 4;

// Diagnostic Severities
public const DIAGNOSTIC_SEVERITY_ERROR = 1;
public const DIAGNOSTIC_SEVERITY_WARNING = 2;
public const DIAGNOSTIC_SEVERITY_INFORMATION = 3;
public const DIAGNOSTIC_SEVERITY_HINT = 4;

// Completion Item Kinds
public const COMPLETION_ITEM_KIND_TEXT = 1;
public const COMPLETION_ITEM_KIND_METHOD = 2;
public const COMPLETION_ITEM_KIND_FUNCTION = 3;
public const COMPLETION_ITEM_KIND_CONSTRUCTOR = 4;
public const COMPLETION_ITEM_KIND_FIELD = 5;
public const COMPLETION_ITEM_KIND_VARIABLE = 6;
public const COMPLETION_ITEM_KIND_CLASS = 7;
public const COMPLETION_ITEM_KIND_INTERFACE = 8;
public const COMPLETION_ITEM_KIND_MODULE = 9;
public const COMPLETION_ITEM_KIND_PROPERTY = 10;
public const COMPLETION_ITEM_KIND_UNIT = 11;
public const COMPLETION_ITEM_KIND_VALUE = 12;
public const COMPLETION_ITEM_KIND_ENUM = 13;
public const COMPLETION_ITEM_KIND_KEYWORD = 14;
public const COMPLETION_ITEM_KIND_SNIPPET = 15;
public const COMPLETION_ITEM_KIND_COLOR = 16;
public const COMPLETION_ITEM_KIND_FILE = 17;
public const COMPLETION_ITEM_KIND_REFERENCE = 18;
public const COMPLETION_ITEM_KIND_FOLDER = 19;
public const COMPLETION_ITEM_KIND_ENUM_MEMBER = 20;
public const COMPLETION_ITEM_KIND_CONSTANT = 21;
public const COMPLETION_ITEM_KIND_STRUCT = 22;
public const COMPLETION_ITEM_KIND_EVENT = 23;
public const COMPLETION_ITEM_KIND_OPERATOR = 24;
public const COMPLETION_ITEM_KIND_TYPE_PARAMETER = 25;

// Symbol Kinds
public const SYMBOL_KIND_FILE = 1;
public const SYMBOL_KIND_MODULE = 2;
public const SYMBOL_KIND_NAMESPACE = 3;
public const SYMBOL_KIND_PACKAGE = 4;
public const SYMBOL_KIND_CLASS = 5;
public const SYMBOL_KIND_METHOD = 6;
public const SYMBOL_KIND_PROPERTY = 7;
public const SYMBOL_KIND_FIELD = 8;
public const SYMBOL_KIND_CONSTRUCTOR = 9;
public const SYMBOL_KIND_ENUM = 10;
public const SYMBOL_KIND_INTERFACE = 11;
public const SYMBOL_KIND_FUNCTION = 12;
public const SYMBOL_KIND_VARIABLE = 13;
public const SYMBOL_KIND_CONSTANT = 14;
public const SYMBOL_KIND_STRING = 15;
public const SYMBOL_KIND_NUMBER = 16;
public const SYMBOL_KIND_BOOLEAN = 17;
public const SYMBOL_KIND_ARRAY = 18;
public const SYMBOL_KIND_OBJECT = 19;
public const SYMBOL_KIND_KEY = 20;
public const SYMBOL_KIND_NULL = 21;
public const SYMBOL_KIND_ENUM_MEMBER = 22;
public const SYMBOL_KIND_STRUCT = 23;
public const SYMBOL_KIND_EVENT = 24;
public const SYMBOL_KIND_OPERATOR = 25;
public const SYMBOL_KIND_TYPE_PARAMETER = 26;

// URI Utilities
public class URIUtils {
    // Convert file path to URI
    public function filePathToUri(string filePath) returns string {
        string normalizedPath = filePath.startsWith("/") ? filePath : "/" + filePath;
        return "file://" + normalizedPath;
    }
    
    // Convert URI to file path
    public function uriToFilePath(string uri) returns string|error {
        if (!uri.startsWith("file://")) {
            return error("Invalid file URI: " + uri);
        }
        return uri.substring(7); // Remove "file://" prefix
    }
    
    // Check if URI represents a Ballerina file
    public function isBallerinaFile(string uri) returns boolean {
        return uri.endsWith(".bal");
    }
    
    // Extract filename from URI
    public function getFileNameFromUri(string uri) returns string {
        string[] parts = regex:split(uri, "/");
        return parts[parts.length() - 1];
    }
    
    // Get directory URI from file URI
    public function getDirectoryUri(string fileUri) returns string|error {
        if (!fileUri.startsWith("file://")) {
            return error("Invalid file URI: " + fileUri);
        }
        
        string[] parts = regex:split(fileUri, "/");
        if (parts.length() <= 3) { // file://
            return error("Cannot get directory from root URI");
        }
        
        return 'string:join("/", ...parts.slice(0, parts.length() - 1));
    }
}

// Position and Range Utilities
public class PositionUtils {
    // Create position from line and column (0-based)
    public function createPosition(int line, int character) returns Position {
        return {line: line, character: character};
    }
    
    // Create range from start and end positions
    public function createRange(Position 'start, Position end) returns Range {
        return {'start: 'start, end: end};
    }
    
    // Create single-point range (start == end)
    public function createPointRange(Position position) returns Range {
        return {'start: position, end: position};
    }
    
    // Check if position is within range
    public function isPositionInRange(Position position, Range range) returns boolean {
        if (position.line < range.'start.line || position.line > range.end.line) {
            return false;
        }
        
        if (position.line == range.'start.line && position.character < range.'start.character) {
            return false;
        }
        
        if (position.line == range.end.line && position.character > range.end.character) {
            return false;
        }
        
        return true;
    }
    
    // Compare two positions (-1: pos1 < pos2, 0: equal, 1: pos1 > pos2)
    public function comparePositions(Position pos1, Position pos2) returns int {
        if (pos1.line < pos2.line) {
            return -1;
        } else if (pos1.line > pos2.line) {
            return 1;
        } else {
            // Same line, compare characters
            if (pos1.character < pos2.character) {
                return -1;
            } else if (pos1.character > pos2.character) {
                return 1;
            } else {
                return 0;
            }
        }
    }
    
    // Get range length in characters (approximate, single line only)
    public function getRangeLength(Range range) returns int {
        if (range.'start.line != range.end.line) {
            return -1; // Multi-line ranges not supported
        }
        return range.end.character - range.'start.character;
    }
}

// Text Document Utilities
public class TextDocumentUtils {
    // Create text document identifier
    public function createTextDocumentIdentifier(string uri) returns TextDocumentIdentifier {
        return {uri: uri};
    }
    
    // Create versioned text document identifier
    public function createVersionedTextDocumentIdentifier(string uri, int? version) 
        returns VersionedTextDocumentIdentifier {
        return {uri: uri, version: version};
    }
    
    // Create text document item
    public function createTextDocumentItem(string uri, string languageId, int version, string text) 
        returns TextDocumentItem {
        return {
            uri: uri,
            languageId: languageId,
            version: version,
            text: text
        };
    }
    
    // Create text document content change event for full document
    public function createFullDocumentChange(string newText) returns TextDocumentContentChangeEvent {
        return {text: newText};
    }
    
    // Create text document content change event for range
    public function createRangeChange(Range range, string newText) returns TextDocumentContentChangeEvent {
        return {
            range: range,
            text: newText
        };
    }
    
    // Extract line from text content
    public function getLineFromContent(string content, int lineNumber) returns string {
        string[] lines = regex:split(content, "\n");
        if (lineNumber < 0 || lineNumber >= lines.length()) {
            return "";
        }
        return lines[lineNumber];
    }
    
    // Get text at position range
    public function getTextInRange(string content, Range range) returns string {
        string[] lines = regex:split(content, "\n");
        
        if (range.'start.line == range.end.line) {
            // Single line range
            if (range.'start.line >= lines.length()) {
                return "";
            }
            string line = lines[range.'start.line];
            int startChar = range.'start.character < 0 ? 0 : range.'start.character;
            int endChar = range.end.character > line.length() ? line.length() : range.end.character;
            
            if (startChar >= endChar) {
                return "";
            }
            return line.substring(startChar, endChar);
        } else {
            // Multi-line range
            string result = "";
            foreach int i in range.'start.line...range.end.line {
                if (i >= lines.length()) {
                    break;
                }
                
                string line = lines[i];
                if (i == range.'start.line) {
                    // First line - from start character to end
                    int startChar = range.'start.character < 0 ? 0 : range.'start.character;
                    result += line.substring(startChar);
                } else if (i == range.end.line) {
                    // Last line - from beginning to end character
                    int endChar = range.end.character > line.length() ? line.length() : range.end.character;
                    result += line.substring(0, endChar);
                } else {
                    // Middle lines - full line
                    result += line;
                }
                
                if (i < range.end.line) {
                    result += "\n";
                }
            }
            return result;
        }
    }
}

// Diagnostic Utilities
public class DiagnosticUtils {
    // Create diagnostic
    public function createDiagnostic(Range range, string message, int? severity = (), 
                                   string? code = (), string? 'source = ()) returns Diagnostic {
        return {
            range: range,
            message: message,
            severity: severity,
            code: code,
            'source: 'source
        };
    }
    
    // Create error diagnostic
    public function createError(Range range, string message, string? code = (), 
                              string? 'source = ()) returns Diagnostic {
        return self.createDiagnostic(range, message, DIAGNOSTIC_SEVERITY_ERROR, code, 'source);
    }
    
    // Create warning diagnostic
    public function createWarning(Range range, string message, string? code = (), 
                                string? 'source = ()) returns Diagnostic {
        return self.createDiagnostic(range, message, DIAGNOSTIC_SEVERITY_WARNING, code, 'source);
    }
    
    // Create info diagnostic
    public function createInfo(Range range, string message, string? code = (), 
                             string? 'source = ()) returns Diagnostic {
        return self.createDiagnostic(range, message, DIAGNOSTIC_SEVERITY_INFORMATION, code, 'source);
    }
    
    // Create hint diagnostic
    public function createHint(Range range, string message, string? code = (), 
                             string? 'source = ()) returns Diagnostic {
        return self.createDiagnostic(range, message, DIAGNOSTIC_SEVERITY_HINT, code, 'source);
    }
    
    // Get severity name
    public function getSeverityName(int severity) returns string {
        match severity {
            DIAGNOSTIC_SEVERITY_ERROR => { return "ERROR"; }
            DIAGNOSTIC_SEVERITY_WARNING => { return "WARNING"; }
            DIAGNOSTIC_SEVERITY_INFORMATION => { return "INFO"; }
            DIAGNOSTIC_SEVERITY_HINT => { return "HINT"; }
            _ => { return "UNKNOWN"; }
        }
    }
    
    // Filter diagnostics by severity
    public function filterBySeverity(Diagnostic[] diagnostics, int severity) returns Diagnostic[] {
        return diagnostics.filter(d => d.severity == severity);
    }
    
    // Group diagnostics by severity
    public function groupBySeverity(Diagnostic[] diagnostics) returns map<Diagnostic[]> {
        map<Diagnostic[]> groups = {};
        
        foreach Diagnostic diagnostic in diagnostics {
            int severity = diagnostic.severity ?: DIAGNOSTIC_SEVERITY_ERROR;
            string severityName = self.getSeverityName(severity);
            
            if (groups.hasKey(severityName)) {
                groups.get(severityName).push(diagnostic);
            } else {
                groups[severityName] = [diagnostic];
            }
        }
        
        return groups;
    }
}

// Completion Utilities
public class CompletionUtils {
    // Create completion item
    public function createCompletionItem(string label, int? kind = (), string? detail = (), 
                                       string? documentation = (), string? insertText = ()) 
                                       returns CompletionItem {
        return {
            label: label,
            kind: kind,
            detail: detail,
            documentation: documentation,
            insertText: insertText
        };
    }
    
    // Create function completion item
    public function createFunctionCompletion(string name, string signature, string? documentation = ()) 
                                            returns CompletionItem {
        return self.createCompletionItem(
            name,
            COMPLETION_ITEM_KIND_FUNCTION,
            signature,
            documentation,
            name
        );
    }
    
    // Create variable completion item
    public function createVariableCompletion(string name, string varType, string? documentation = ()) 
                                           returns CompletionItem {
        return self.createCompletionItem(
            name,
            COMPLETION_ITEM_KIND_VARIABLE,
            varType,
            documentation,
            name
        );
    }
    
    // Create module completion item
    public function createModuleCompletion(string name, string? documentation = ()) 
                                         returns CompletionItem {
        return self.createCompletionItem(
            name,
            COMPLETION_ITEM_KIND_MODULE,
            "module " + name,
            documentation,
            name
        );
    }
    
    // Create keyword completion item
    public function createKeywordCompletion(string keyword, string? documentation = ()) 
                                          returns CompletionItem {
        return self.createCompletionItem(
            keyword,
            COMPLETION_ITEM_KIND_KEYWORD,
            "keyword",
            documentation,
            keyword
        );
    }
    
    // Get completion kind name
    public function getCompletionKindName(int kind) returns string {
        match kind {
            COMPLETION_ITEM_KIND_TEXT => { return "Text"; }
            COMPLETION_ITEM_KIND_METHOD => { return "Method"; }
            COMPLETION_ITEM_KIND_FUNCTION => { return "Function"; }
            COMPLETION_ITEM_KIND_CONSTRUCTOR => { return "Constructor"; }
            COMPLETION_ITEM_KIND_FIELD => { return "Field"; }
            COMPLETION_ITEM_KIND_VARIABLE => { return "Variable"; }
            COMPLETION_ITEM_KIND_CLASS => { return "Class"; }
            COMPLETION_ITEM_KIND_INTERFACE => { return "Interface"; }
            COMPLETION_ITEM_KIND_MODULE => { return "Module"; }
            COMPLETION_ITEM_KIND_PROPERTY => { return "Property"; }
            COMPLETION_ITEM_KIND_UNIT => { return "Unit"; }
            COMPLETION_ITEM_KIND_VALUE => { return "Value"; }
            COMPLETION_ITEM_KIND_ENUM => { return "Enum"; }
            COMPLETION_ITEM_KIND_KEYWORD => { return "Keyword"; }
            COMPLETION_ITEM_KIND_SNIPPET => { return "Snippet"; }
            COMPLETION_ITEM_KIND_COLOR => { return "Color"; }
            COMPLETION_ITEM_KIND_FILE => { return "File"; }
            COMPLETION_ITEM_KIND_REFERENCE => { return "Reference"; }
            COMPLETION_ITEM_KIND_FOLDER => { return "Folder"; }
            COMPLETION_ITEM_KIND_ENUM_MEMBER => { return "EnumMember"; }
            COMPLETION_ITEM_KIND_CONSTANT => { return "Constant"; }
            COMPLETION_ITEM_KIND_STRUCT => { return "Struct"; }
            COMPLETION_ITEM_KIND_EVENT => { return "Event"; }
            COMPLETION_ITEM_KIND_OPERATOR => { return "Operator"; }
            COMPLETION_ITEM_KIND_TYPE_PARAMETER => { return "TypeParameter"; }
            _ => { return "Unknown"; }
        }
    }
    
    // Sort completion items by relevance
    public function sortByRelevance(CompletionItem[] items) returns CompletionItem[] {
        // Simple sorting by label for now
        // In a real implementation, this would consider context, frequency, etc.
        return items.sort(function(CompletionItem a, CompletionItem b) returns int {
            return a.label < b.label ? -1 : (a.label > b.label ? 1 : 0);
        });
    }
    
    // Filter completion items by prefix
    public function filterByPrefix(CompletionItem[] items, string prefix) returns CompletionItem[] {
        string lowerPrefix = prefix.toLowerAscii();
        return items.filter(function(CompletionItem item) returns boolean {
            return item.label.toLowerAscii().startsWith(lowerPrefix) ||
                   (item.insertText is string && 
                    (<string>item.insertText).toLowerAscii().startsWith(lowerPrefix));
        });
    }
}

// Workspace Utilities
public class WorkspaceUtils {
    // Find Ballerina files in directory
    public function findBallerinaFiles(string directoryPath) returns string[]|error {
        string[] ballerinaFiles = [];
        
        if (!check file:exists(directoryPath)) {
            return error("Directory does not exist: " + directoryPath);
        }
        
        file:MetaData[] entries = check file:readDir(directoryPath);
        
        foreach file:MetaData entry in entries {
            if (entry.dir) {
                // Recursively search subdirectories
                string[] subFiles = check self.findBallerinaFiles(entry.absPath);
                ballerinaFiles.push(...subFiles);
            } else if (entry.absPath.endsWith(".bal")) {
                ballerinaFiles.push(entry.absPath);
            }
        }
        
        return ballerinaFiles;
    }
    
    // Create workspace folder
    public function createWorkspaceFolder(string uri, string name) returns WorkspaceFolder {
        return {uri: uri, name: name};
    }
    
    // Check if path is within workspace
    public function isWithinWorkspace(string filePath, string workspaceRoot) returns boolean {
        return filePath.startsWith(workspaceRoot);
    }
    
    // Get relative path within workspace
    public function getRelativePath(string filePath, string workspaceRoot) returns string {
        if (!filePath.startsWith(workspaceRoot)) {
            return filePath; // Not within workspace
        }
        
        string relativePath = filePath.substring(workspaceRoot.length());
        return relativePath.startsWith("/") ? relativePath.substring(1) : relativePath;
    }
}

// Logging and Debug Utilities
public class LSPLogger {
    private string component;
    
    public function init(string component) {
        self.component = component;
    }
    
    public function logRequest(string method, string id, json? params = ()) {
        log:printDebug(string `[${self.component}] Request ${id}: ${method}`, params = params);
    }
    
    public function logResponse(string method, string id, json? result = (), LSPError? 'error = ()) {
        if ('error is LSPError) {
            log:printError(string `[${self.component}] Response ${id} ERROR: ${'error.message}`, 
                          params = 'error);
        } else {
            log:printDebug(string `[${self.component}] Response ${id}: ${method}`, params = result);
        }
    }
    
    public function logNotification(string method, json? params = ()) {
        log:printDebug(string `[${self.component}] Notification: ${method}`, params = params);
    }
    
    public function logDiagnostics(string uri, Diagnostic[] diagnostics) {
        DiagnosticUtils diagnosticUtils = new();
        map<Diagnostic[]> grouped = diagnosticUtils.groupBySeverity(diagnostics);
        
        foreach string severity in grouped.keys() {
            Diagnostic[] severityDiagnostics = grouped.get(severity);
            log:printInfo(string `[${self.component}] ${uri}: ${severityDiagnostics.length()} ${severity}(s)`);
        }
    }
}

// Configuration for LSP clients
public type LSPClientConfig record {|
    string serverUri;
    string? rootPath?;
    string? rootUri?;
    int requestTimeoutMs?;
    boolean enableDiagnostics?;
    boolean enableCompletion?;
    boolean enableHover?;
    boolean enableDefinition?;
    boolean enableReferences?;
    string logLevel?;
|};

// Factory for creating configured LSP clients
public class LSPClientFactory {
    public function createClient(LSPClientConfig config) returns LSPClient|error {
        LSPClient client = new(config.serverUri);
        
        // Configure client based on config
        // This would be extended to set various client options
        
        return client;
    }
    
    public function createClientWithDefaults(string serverUri) returns LSPClient|error {
        LSPClientConfig defaultConfig = {
            serverUri: serverUri,
            requestTimeoutMs: 30000,
            enableDiagnostics: true,
            enableCompletion: true,
            enableHover: true,
            enableDefinition: true,
            enableReferences: true,
            logLevel: "INFO"
        };
        
        return self.createClient(defaultConfig);
    }
}

// Export utility instances for convenient access
public final URIUtils uriUtils = new();
public final PositionUtils positionUtils = new();
public final TextDocumentUtils textDocumentUtils = new();
public final DiagnosticUtils diagnosticUtils = new();
public final CompletionUtils completionUtils = new();
public final WorkspaceUtils workspaceUtils = new();
public final LSPClientFactory clientFactory = new();