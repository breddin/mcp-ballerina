import ballerina/io;
import ballerina/websocket;
import modules.collaboration.websocket_server;
import modules.collaboration.ot_engine;
import modules.collaboration.presence_manager;

public function main() returns error? {
    // Example 1: Start Collaboration Server
    io:println("=== Starting Collaboration Server ===");
    
    websocket_server:ServerConfig config = {
        port: 8090,
        enableAuth: true,
        maxConnections: 100,
        heartbeatInterval: 30,
        documentTimeout: 3600
    };
    
    websocket_server:WebSocketCollaborationServer server = new(config);
    check server.start();
    
    io:println("✅ Collaboration server started on port 8090");
    
    // Example 2: Operational Transform Usage
    io:println("\n=== Operational Transform Example ===");
    
    ot_engine:OperationalTransformEngine otEngine = new();
    
    // Simulate concurrent edits from two users
    ot_engine:Operation op1 = {
        type: ot_engine:INSERT,
        position: 10,
        text: "Hello ",
        userId: "user1",
        revision: 5
    };
    
    ot_engine:Operation op2 = {
        type: ot_engine:INSERT,
        position: 10,
        text: "World ",
        userId: "user2",
        revision: 5
    };
    
    // Transform operations to handle concurrent edits
    ot_engine:TransformResult result = otEngine.transform(op1, op2);
    
    io:println("Original operations:");
    io:println(string `  User1: Insert "${op1.text}" at position ${op1.position}`);
    io:println(string `  User2: Insert "${op2.text}" at position ${op2.position}`);
    
    io:println("\nTransformed operations:");
    io:println(string `  Op1': Insert "${result.op1Prime.text}" at position ${result.op1Prime.position}`);
    io:println(string `  Op2': Insert "${result.op2Prime.text}" at position ${result.op2Prime.position}`);
    
    // Example 3: Complex OT Scenario
    io:println("\n=== Complex OT Scenario ===");
    
    // Document state: "The quick brown fox"
    string document = "The quick brown fox";
    io:println("Initial document: ", document);
    
    // User A deletes "quick " (positions 4-10)
    ot_engine:Operation deleteOp = {
        type: ot_engine:DELETE,
        position: 4,
        length: 6,
        userId: "userA",
        revision: 10
    };
    
    // User B inserts "very " before "quick" (position 4)
    ot_engine:Operation insertOp = {
        type: ot_engine:INSERT,
        position: 4,
        text: "very ",
        userId: "userB",
        revision: 10
    };
    
    // Transform for convergence
    ot_engine:TransformResult complexResult = otEngine.transform(deleteOp, insertOp);
    
    io:println("\nConcurrent operations:");
    io:println("  UserA: Delete 6 characters at position 4");
    io:println("  UserB: Insert 'very ' at position 4");
    
    io:println("\nAfter transformation:");
    io:println(string `  Delete operation moves to position ${complexResult.op1Prime.position}`);
    io:println(string `  Insert operation stays at position ${complexResult.op2Prime.position}`);
    
    // Example 4: Presence Management
    io:println("\n=== Presence Management Example ===");
    
    presence_manager:PresenceManager presenceManager = new();
    
    string documentId = "doc123";
    
    // Add users to document session
    presence_manager:UserPresence alice = check presenceManager.addUser(
        documentId, "alice", "client_001"
    );
    
    presence_manager:UserPresence bob = check presenceManager.addUser(
        documentId, "bob", "client_002"
    );
    
    io:println("Users joined document session:");
    io:println(string `  - ${alice.userId} (color: ${alice.color})`);
    io:println(string `  - ${bob.userId} (color: ${bob.color})`);
    
    // Update cursor positions
    check presenceManager.updateCursor(documentId, "alice", {line: 5, column: 10});
    check presenceManager.updateCursor(documentId, "bob", {line: 12, column: 0});
    
    // Update selections
    check presenceManager.updateSelection(documentId, "alice", {
        start: {line: 5, column: 10},
        end: {line: 5, column: 25}
    });
    
    // Update user status
    check presenceManager.updateStatus(documentId, "alice", presence_manager:TYPING);
    check presenceManager.updateStatus(documentId, "bob", presence_manager:IDLE);
    
    // Get all users in document
    presence_manager:UserPresence[] activeUsers = presenceManager.getDocumentUsers(documentId);
    
    io:println("\nActive users in document:");
    foreach presence_manager:UserPresence user in activeUsers {
        io:println(string `  - ${user.userId}: ${user.status} at line ${user.cursor.line}`);
    }
    
    // Example 5: WebSocket Client Simulation
    io:println("\n=== WebSocket Client Example ===");
    
    // Simulate client messages
    json connectMsg = {
        "type": "CONNECT",
        "payload": {
            "userId": "charlie",
            "clientId": "client_003"
        }
    };
    
    json authMsg = {
        "type": "AUTHENTICATE",
        "payload": {
            "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
        }
    };
    
    json joinDocMsg = {
        "type": "JOIN_DOCUMENT",
        "payload": {
            "documentId": "doc456",
            "mode": "write"
        }
    };
    
    json textOpMsg = {
        "type": "TEXT_OPERATION",
        "payload": {
            "documentId": "doc456",
            "operation": {
                "type": "insert",
                "position": 0,
                "text": "// New comment\n"
            }
        }
    };
    
    io:println("Client message flow:");
    io:println("1. Connect: ", connectMsg);
    io:println("2. Authenticate: ", authMsg.toJsonString().substring(0, 50), "...");
    io:println("3. Join Document: ", joinDocMsg);
    io:println("4. Text Operation: ", textOpMsg);
    
    // Example 6: Conflict Resolution
    io:println("\n=== Conflict Resolution Example ===");
    
    // Three-way merge scenario
    ot_engine:Operation[] operations = [
        {type: ot_engine:INSERT, position: 0, text: "Line 1\n", userId: "user1", revision: 1},
        {type: ot_engine:INSERT, position: 7, text: "Line 2\n", userId: "user2", revision: 1},
        {type: ot_engine:DELETE, position: 0, length: 7, userId: "user3", revision: 1}
    ];
    
    // Apply OT to resolve conflicts
    ot_engine:Operation[] resolved = check otEngine.resolveConflicts(operations);
    
    io:println("Conflicting operations: ", operations.length());
    io:println("Resolved operations: ", resolved.length());
    
    foreach int i in 0 ..< resolved.length() {
        ot_engine:Operation op = resolved[i];
        io:println(string `  ${i + 1}. ${op.type} by ${op.userId} at position ${op.position}`);
    }
    
    // Example 7: Activity Monitoring
    io:println("\n=== Activity Monitoring ===");
    
    // Track user activity
    presence_manager:ActivityStats stats = presenceManager.getActivityStats(documentId);
    
    io:println("Document activity statistics:");
    io:println("  Active users: ", stats.activeUsers);
    io:println("  Total edits: ", stats.totalEdits);
    io:println("  Last activity: ", stats.lastActivity);
    
    // Clean up
    check presenceManager.removeUser(documentId, "alice");
    check presenceManager.removeUser(documentId, "bob");
    
    io:println("\n✅ Collaboration examples completed!");
}

// Example WebSocket client handler
service class ClientHandler {
    private websocket:Caller caller;
    private string userId;
    private string documentId = "";
    
    function init(websocket:Caller caller, string userId) {
        self.caller = caller;
        self.userId = userId;
    }
    
    remote function onMessage(websocket:Caller caller, json message) returns error? {
        string msgType = check message.type;
        
        match msgType {
            "DOCUMENT_CHANGED" => {
                io:println("Document updated by another user");
                // Handle document change
            }
            "USER_JOINED" => {
                string newUser = check message.payload.userId;
                io:println(string `${newUser} joined the document`);
            }
            "CURSOR_MOVED" => {
                // Update other users' cursor positions
                json position = check message.payload.position;
                io:println("Cursor update received");
            }
        }
    }
    
    remote function onClose(websocket:Caller caller, int statusCode, string reason) {
        io:println(string `Connection closed: ${reason}`);
    }
}