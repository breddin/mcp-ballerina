// WebSocket Collaboration Server for Ballerina
// Provides real-time collaborative editing capabilities

import ballerina/websocket;
import ballerina/log;
import ballerina/uuid;
import ballerina/time;
import ballerina/jwt;

// Server configuration
public type ServerConfig record {|
    int port = 8090;
    string host = "0.0.0.0";
    boolean enableAuth = true;
    int maxConnections = 100;
    int heartbeatInterval = 30000; // 30 seconds
    int messageQueueSize = 1000;
|};

// Client connection info
public type ClientInfo record {|
    string clientId;
    string userId;
    string sessionId;
    string documentId?;
    websocket:Caller caller;
    time:Utc connectedAt;
    ClientState state;
    map<any> metadata = {};
|};

// Client state
public enum ClientState {
    CONNECTED,
    AUTHENTICATED,
    JOINED_DOCUMENT,
    IDLE,
    DISCONNECTED
}

// Collaboration message types
public enum MessageType {
    // Connection management
    CONNECT,
    AUTHENTICATE,
    DISCONNECT,
    HEARTBEAT,
    
    // Document operations
    JOIN_DOCUMENT,
    LEAVE_DOCUMENT,
    DOCUMENT_STATE,
    
    // Editing operations
    TEXT_OPERATION,
    CURSOR_POSITION,
    SELECTION_CHANGE,
    
    // Presence
    USER_JOIN,
    USER_LEAVE,
    USER_STATE,
    PRESENCE_UPDATE,
    
    // Synchronization
    SYNC_REQUEST,
    SYNC_RESPONSE,
    ACKNOWLEDGMENT,
    
    // Errors
    ERROR,
    CONFLICT
}

// Base message structure
public type CollaborationMessage record {|
    MessageType type;
    string messageId = uuid:createType1AsString();
    time:Utc timestamp = time:utcNow();
    string? clientId?;
    string? documentId?;
    json payload?;
    map<string> metadata = {};
|};

// Operation message for OT
public type OperationMessage record {|
    *CollaborationMessage;
    Operation operation;
    int version;
    string? parentVersion?;
|};

// Operation types
public type Operation record {|
    string type; // "insert", "delete", "format", "move"
    int position;
    string? text?;
    int? length?;
    map<any> attributes?;
|};

// Cursor position
public type CursorPosition record {|
    int line;
    int column;
    string? clientId;
    string? userId;
    string? color?;
|};

// Selection range
public type SelectionRange record {|
    CursorPosition 'start;
    CursorPosition end;
    string? clientId;
    string? userId;
|};

// Document state
public type DocumentState record {|
    string documentId;
    string content;
    int version;
    Operation[] pendingOperations = [];
    map<CursorPosition> cursors = {};
    map<SelectionRange> selections = {};
    ClientInfo[] collaborators = [];
    time:Utc lastModified;
|};

// WebSocket Collaboration Server
public class WebSocketCollaborationServer {
    private ServerConfig config;
    private map<ClientInfo> clients = {};
    private map<DocumentState> documents = {};
    private websocket:Listener? wsListener = ();
    private SessionManager sessionManager;
    private OperationalTransformEngine otEngine;
    private PresenceManager presenceManager;
    private boolean running = false;
    
    public function init(ServerConfig? config = ()) {
        self.config = config ?: {};
        self.sessionManager = new();
        self.otEngine = new();
        self.presenceManager = new();
    }
    
    // Start the WebSocket server
    public function start() returns error? {
        websocket:Listener listener = check new(self.config.port, {
            host: self.config.host,
            secureSocket: {
                key: {
                    path: "/path/to/private.key",
                    password: "keypassword"
                },
                cert: {
                    path: "/path/to/public.crt"
                }
            }
        });
        
        self.wsListener = listener;
        self.running = true;
        
        // Attach service
        check listener.attach(self.getWebSocketService());
        check listener.'start();
        
        log:printInfo("WebSocket Collaboration Server started on " + 
            self.config.host + ":" + self.config.port.toString());
        
        // Start heartbeat monitor
        _ = @strand {thread: "any"} start self.heartbeatMonitor();
        
        return;
    }
    
    // Get WebSocket service
    private function getWebSocketService() returns websocket:Service {
        return @websocket:ServiceConfig {
            maxFrameSize: 65536
        } service object {
            
            // Handle new connections
            resource function get .(websocket:Caller caller) returns websocket:Service|error {
                string clientId = uuid:createType1AsString();
                
                ClientInfo client = {
                    clientId: clientId,
                    userId: "",
                    sessionId: uuid:createType1AsString(),
                    caller: caller,
                    connectedAt: time:utcNow(),
                    state: CONNECTED
                };
                
                lock {
                    self.clients[clientId] = client;
                }
                
                // Send connection acknowledgment
                CollaborationMessage connectMsg = {
                    type: CONNECT,
                    clientId: clientId,
                    payload: {
                        "status": "connected",
                        "clientId": clientId,
                        "sessionId": client.sessionId
                    }
                };
                
                check caller->writeMessage(connectMsg);
                
                log:printInfo("Client connected: " + clientId);
                
                return self.getClientService(clientId);
            }
        };
    }
    
    // Get client-specific WebSocket service
    private function getClientService(string clientId) returns websocket:Service {
        return service object {
            
            // Handle incoming messages
            remote function onMessage(websocket:Caller caller, CollaborationMessage message) 
                returns error? {
                check self.handleMessage(clientId, message);
            }
            
            // Handle ping
            remote function onPing(websocket:Caller caller, byte[] data) returns error? {
                check caller->pong(data);
            }
            
            // Handle client disconnect
            remote function onClose(websocket:Caller caller, int statusCode, string reason) {
                self.handleDisconnect(clientId, statusCode, reason);
            }
            
            // Handle errors
            remote function onError(websocket:Caller caller, error err) {
                log:printError("WebSocket error for client " + clientId, 'error = err);
                self.handleDisconnect(clientId, 1011, err.message());
            }
        };
    }
    
    // Handle incoming messages
    private function handleMessage(string clientId, CollaborationMessage message) returns error? {
        ClientInfo? client = self.clients[clientId];
        if client is () {
            return error("Client not found: " + clientId);
        }
        
        match message.type {
            AUTHENTICATE => {
                check self.handleAuthentication(client, message);
            }
            JOIN_DOCUMENT => {
                check self.handleJoinDocument(client, message);
            }
            LEAVE_DOCUMENT => {
                check self.handleLeaveDocument(client, message);
            }
            TEXT_OPERATION => {
                check self.handleTextOperation(client, <OperationMessage>message);
            }
            CURSOR_POSITION => {
                check self.handleCursorUpdate(client, message);
            }
            SELECTION_CHANGE => {
                check self.handleSelectionChange(client, message);
            }
            SYNC_REQUEST => {
                check self.handleSyncRequest(client, message);
            }
            HEARTBEAT => {
                check self.handleHeartbeat(client);
            }
            _ => {
                log:printWarn("Unknown message type: " + message.type.toString());
            }
        }
    }
    
    // Handle authentication
    private function handleAuthentication(ClientInfo client, CollaborationMessage message) 
        returns error? {
        json? payload = message.payload;
        if payload is () {
            return error("Authentication payload missing");
        }
        
        // Validate JWT token
        string token = check payload.token;
        jwt:Payload jwtPayload = check jwt:decode(token);
        
        // Update client info
        client.userId = check jwtPayload.sub;
        client.state = AUTHENTICATED;
        client.metadata["username"] = check jwtPayload.username;
        
        // Store authenticated session
        check self.sessionManager.createSession(client.sessionId, client.userId);
        
        // Send authentication success
        CollaborationMessage response = {
            type: AUTHENTICATE,
            clientId: client.clientId,
            payload: {
                "status": "authenticated",
                "userId": client.userId
            }
        };
        
        check client.caller->writeMessage(response);
        
        log:printInfo("Client authenticated: " + client.clientId + " as " + client.userId);
    }
    
    // Handle join document request
    private function handleJoinDocument(ClientInfo client, CollaborationMessage message) 
        returns error? {
        json? payload = message.payload;
        if payload is () {
            return error("Document ID missing");
        }
        
        string documentId = check payload.documentId;
        
        // Get or create document state
        DocumentState document;
        lock {
            if self.documents.hasKey(documentId) {
                document = self.documents[documentId];
            } else {
                document = {
                    documentId: documentId,
                    content: check payload.initialContent,
                    version: 0,
                    lastModified: time:utcNow()
                };
                self.documents[documentId] = document;
            }
            
            // Add client to document
            document.collaborators.push(client);
            client.documentId = documentId;
            client.state = JOINED_DOCUMENT;
        }
        
        // Send document state to client
        CollaborationMessage stateMsg = {
            type: DOCUMENT_STATE,
            clientId: client.clientId,
            documentId: documentId,
            payload: document.toJson()
        };
        
        check client.caller->writeMessage(stateMsg);
        
        // Notify other collaborators
        check self.broadcastToDocument(documentId, {
            type: USER_JOIN,
            clientId: client.clientId,
            payload: {
                "userId": client.userId,
                "username": client.metadata["username"]
            }
        }, client.clientId);
        
        // Update presence
        check self.presenceManager.addUser(documentId, client);
        
        log:printInfo("Client " + client.clientId + " joined document: " + documentId);
    }
    
    // Handle leave document request
    private function handleLeaveDocument(ClientInfo client, CollaborationMessage message) 
        returns error? {
        string? documentId = client.documentId;
        if documentId is () {
            return;
        }
        
        lock {
            DocumentState? document = self.documents[documentId];
            if document is DocumentState {
                // Remove client from collaborators
                ClientInfo[] newCollaborators = [];
                foreach ClientInfo collab in document.collaborators {
                    if collab.clientId != client.clientId {
                        newCollaborators.push(collab);
                    }
                }
                document.collaborators = newCollaborators;
                
                // Remove cursor and selection
                _ = document.cursors.remove(client.clientId);
                _ = document.selections.remove(client.clientId);
                
                // Clean up empty documents
                if document.collaborators.length() == 0 {
                    _ = self.documents.remove(documentId);
                }
            }
            
            client.documentId = ();
            client.state = AUTHENTICATED;
        }
        
        // Notify other collaborators
        check self.broadcastToDocument(documentId, {
            type: USER_LEAVE,
            clientId: client.clientId,
            payload: {
                "userId": client.userId
            }
        }, client.clientId);
        
        // Update presence
        check self.presenceManager.removeUser(documentId, client.clientId);
        
        log:printInfo("Client " + client.clientId + " left document: " + documentId);
    }
    
    // Handle text operation
    private function handleTextOperation(ClientInfo client, OperationMessage message) 
        returns error? {
        string? documentId = client.documentId;
        if documentId is () {
            return error("Client not in document");
        }
        
        DocumentState document = self.documents[documentId] ?: 
            {documentId: "", content: "", version: 0, lastModified: time:utcNow()};
        
        // Apply operational transform
        TransformResult result = check self.otEngine.transform(
            message.operation,
            document.pendingOperations,
            document.version
        );
        
        if result.conflict {
            // Send conflict notification
            CollaborationMessage conflictMsg = {
                type: CONFLICT,
                clientId: client.clientId,
                documentId: documentId,
                payload: {
                    "originalOperation": message.operation,
                    "transformedOperation": result.transformedOperation,
                    "conflictType": result.conflictType
                }
            };
            
            check client.caller->writeMessage(conflictMsg);
        }
        
        // Apply operation to document
        lock {
            document.content = check self.applyOperation(
                document.content,
                result.transformedOperation
            );
            document.version += 1;
            document.lastModified = time:utcNow();
        }
        
        // Broadcast operation to other clients
        OperationMessage broadcastMsg = {
            type: TEXT_OPERATION,
            operation: result.transformedOperation,
            version: document.version,
            clientId: client.clientId,
            documentId: documentId
        };
        
        check self.broadcastToDocument(documentId, broadcastMsg, client.clientId);
        
        // Send acknowledgment
        CollaborationMessage ackMsg = {
            type: ACKNOWLEDGMENT,
            clientId: client.clientId,
            payload: {
                "messageId": message.messageId,
                "version": document.version
            }
        };
        
        check client.caller->writeMessage(ackMsg);
    }
    
    // Handle cursor update
    private function handleCursorUpdate(ClientInfo client, CollaborationMessage message) 
        returns error? {
        string? documentId = client.documentId;
        if documentId is () {
            return;
        }
        
        json? payload = message.payload;
        if payload is () {
            return error("Cursor position missing");
        }
        
        CursorPosition cursor = check payload.cloneWithType(CursorPosition);
        cursor.clientId = client.clientId;
        cursor.userId = client.userId;
        
        // Update document state
        lock {
            DocumentState? document = self.documents[documentId];
            if document is DocumentState {
                document.cursors[client.clientId] = cursor;
            }
        }
        
        // Broadcast cursor update
        check self.broadcastToDocument(documentId, {
            type: CURSOR_POSITION,
            clientId: client.clientId,
            payload: cursor.toJson()
        }, client.clientId);
        
        // Update presence
        check self.presenceManager.updateCursor(documentId, client.clientId, cursor);
    }
    
    // Handle selection change
    private function handleSelectionChange(ClientInfo client, CollaborationMessage message) 
        returns error? {
        string? documentId = client.documentId;
        if documentId is () {
            return;
        }
        
        json? payload = message.payload;
        if payload is () {
            return error("Selection range missing");
        }
        
        SelectionRange selection = check payload.cloneWithType(SelectionRange);
        selection.clientId = client.clientId;
        selection.userId = client.userId;
        
        // Update document state
        lock {
            DocumentState? document = self.documents[documentId];
            if document is DocumentState {
                document.selections[client.clientId] = selection;
            }
        }
        
        // Broadcast selection update
        check self.broadcastToDocument(documentId, {
            type: SELECTION_CHANGE,
            clientId: client.clientId,
            payload: selection.toJson()
        }, client.clientId);
    }
    
    // Handle sync request
    private function handleSyncRequest(ClientInfo client, CollaborationMessage message) 
        returns error? {
        string? documentId = client.documentId;
        if documentId is () {
            return error("Client not in document");
        }
        
        DocumentState? document = self.documents[documentId];
        if document is () {
            return error("Document not found");
        }
        
        // Send full document state
        CollaborationMessage syncResponse = {
            type: SYNC_RESPONSE,
            clientId: client.clientId,
            documentId: documentId,
            payload: {
                "content": document.content,
                "version": document.version,
                "cursors": document.cursors.toJson(),
                "selections": document.selections.toJson(),
                "collaborators": self.getCollaboratorInfo(document.collaborators)
            }
        };
        
        check client.caller->writeMessage(syncResponse);
    }
    
    // Handle heartbeat
    private function handleHeartbeat(ClientInfo client) returns error? {
        client.metadata["lastHeartbeat"] = time:utcNow().toString();
        
        // Send heartbeat response
        CollaborationMessage response = {
            type: HEARTBEAT,
            clientId: client.clientId
        };
        
        check client.caller->writeMessage(response);
    }
    
    // Handle client disconnect
    private function handleDisconnect(string clientId, int statusCode, string reason) {
        ClientInfo? client = self.clients[clientId];
        if client is () {
            return;
        }
        
        // Leave document if joined
        if client.documentId is string {
            error? result = self.handleLeaveDocument(client, {
                type: LEAVE_DOCUMENT,
                clientId: clientId
            });
            if result is error {
                log:printError("Error leaving document on disconnect", 'error = result);
            }
        }
        
        // Clean up session
        error? sessionResult = self.sessionManager.endSession(client.sessionId);
        if sessionResult is error {
            log:printError("Error ending session", 'error = sessionResult);
        }
        
        // Remove client
        lock {
            _ = self.clients.remove(clientId);
        }
        
        log:printInfo("Client disconnected: " + clientId + 
            " (code: " + statusCode.toString() + ", reason: " + reason + ")");
    }
    
    // Broadcast message to document collaborators
    private function broadcastToDocument(string documentId, CollaborationMessage message, 
        string? excludeClient = ()) returns error? {
        
        DocumentState? document = self.documents[documentId];
        if document is () {
            return;
        }
        
        foreach ClientInfo collaborator in document.collaborators {
            if excludeClient is () || collaborator.clientId != excludeClient {
                error? result = collaborator.caller->writeMessage(message);
                if result is error {
                    log:printError("Failed to send message to " + 
                        collaborator.clientId, 'error = result);
                }
            }
        }
    }
    
    // Apply operation to content
    private function applyOperation(string content, Operation operation) returns string|error {
        match operation.type {
            "insert" => {
                string text = operation.text ?: "";
                int pos = operation.position;
                return content.substring(0, pos) + text + content.substring(pos);
            }
            "delete" => {
                int pos = operation.position;
                int length = operation.length ?: 0;
                return content.substring(0, pos) + content.substring(pos + length);
            }
            _ => {
                return error("Unknown operation type: " + operation.type);
            }
        }
    }
    
    // Get collaborator info
    private function getCollaboratorInfo(ClientInfo[] collaborators) returns json[] {
        json[] info = [];
        foreach ClientInfo collab in collaborators {
            info.push({
                "clientId": collab.clientId,
                "userId": collab.userId,
                "username": collab.metadata["username"],
                "state": collab.state.toString()
            });
        }
        return info;
    }
    
    // Heartbeat monitor
    private function heartbeatMonitor() {
        while self.running {
            runtime:sleep(self.config.heartbeatInterval);
            
            time:Utc now = time:utcNow();
            string[] disconnectedClients = [];
            
            lock {
                foreach [string, ClientInfo] [clientId, client] in self.clients.entries() {
                    time:Utc? lastHeartbeat = client.metadata["lastHeartbeat"];
                    if lastHeartbeat is time:Utc {
                        time:Seconds elapsed = time:utcDiffSeconds(now, lastHeartbeat);
                        if elapsed > <time:Seconds>(self.config.heartbeatInterval * 2 / 1000) {
                            disconnectedClients.push(clientId);
                        }
                    }
                }
            }
            
            // Disconnect inactive clients
            foreach string clientId in disconnectedClients {
                self.handleDisconnect(clientId, 1001, "Heartbeat timeout");
            }
        }
    }
    
    // Stop the server
    public function stop() returns error? {
        self.running = false;
        
        // Disconnect all clients
        foreach ClientInfo client in self.clients {
            check client.caller->close(1001, "Server shutting down");
        }
        
        // Stop listener
        if self.wsListener is websocket:Listener {
            check self.wsListener.gracefulStop();
        }
        
        log:printInfo("WebSocket Collaboration Server stopped");
    }
}

// Stub classes (to be implemented in separate files)
class SessionManager {
    public function createSession(string sessionId, string userId) returns error? {
        return;
    }
    
    public function endSession(string sessionId) returns error? {
        return;
    }
}

class OperationalTransformEngine {
    public function transform(Operation op, Operation[] pending, int version) 
        returns TransformResult|error {
        return {
            transformedOperation: op,
            conflict: false
        };
    }
}

type TransformResult record {|
    Operation transformedOperation;
    boolean conflict;
    string? conflictType?;
|};

class PresenceManager {
    public function addUser(string documentId, ClientInfo client) returns error? {
        return;
    }
    
    public function removeUser(string documentId, string clientId) returns error? {
        return;
    }
    
    public function updateCursor(string documentId, string clientId, CursorPosition cursor) 
        returns error? {
        return;
    }
}