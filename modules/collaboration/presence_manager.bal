// Presence Manager for Real-time Collaboration
// Manages user presence, cursor positions, and activity tracking

import ballerina/time;
import ballerina/log;

// User presence status
public enum PresenceStatus {
    ONLINE,
    IDLE,
    TYPING,
    SELECTING,
    AWAY,
    OFFLINE
}

// User presence info
public type UserPresence record {|
    string userId;
    string clientId;
    string documentId;
    PresenceStatus status;
    CursorInfo? cursor?;
    SelectionInfo? selection?;
    string? color;
    string? displayName;
    time:Utc lastActivity;
    map<any> metadata = {};
|};

// Cursor information
public type CursorInfo record {|
    int line;
    int column;
    int offset?;
    string? fileName?;
|};

// Selection information
public type SelectionInfo record {|
    CursorInfo 'start;
    CursorInfo end;
    string? text?;
|};

// Activity type
public enum ActivityType {
    CURSOR_MOVE,
    TEXT_EDIT,
    SELECTION,
    SCROLL,
    FILE_OPEN,
    FILE_CLOSE
}

// User activity
public type UserActivity record {|
    string userId;
    string documentId;
    ActivityType activityType;
    json? data?;
    time:Utc timestamp;
|};

// Presence update event
public type PresenceUpdate record {|
    string updateType; // "join", "leave", "status", "cursor", "selection"
    UserPresence presence;
    time:Utc timestamp;
|};

// Presence Manager
public class PresenceManager {
    private map<map<UserPresence>> documentPresence = {}; // documentId -> userId -> presence
    private map<UserPresence> userPresence = {}; // userId -> presence
    private map<string> userColors = {}; // userId -> color
    private string[] availableColors = [
        "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFEAA7",
        "#D63031", "#74B9FF", "#A29BFE", "#6C5CE7", "#FD79A8",
        "#FDCB6E", "#E17055", "#00B894", "#00CEC9", "#0984E3"
    ];
    private int colorIndex = 0;
    private int idleTimeout = 60000; // 1 minute
    private int awayTimeout = 300000; // 5 minutes
    
    // Add user to document
    public function addUser(string documentId, string userId, string clientId, 
                           string? displayName = ()) returns UserPresence|error {
        
        // Assign color if not exists
        if !self.userColors.hasKey(userId) {
            self.userColors[userId] = self.getNextColor();
        }
        
        // Create presence info
        UserPresence presence = {
            userId: userId,
            clientId: clientId,
            documentId: documentId,
            status: ONLINE,
            color: self.userColors[userId],
            displayName: displayName,
            lastActivity: time:utcNow()
        };
        
        // Add to document presence
        lock {
            if !self.documentPresence.hasKey(documentId) {
                self.documentPresence[documentId] = {};
            }
            self.documentPresence[documentId][userId] = presence;
            self.userPresence[userId] = presence;
        }
        
        log:printInfo("User " + userId + " joined document " + documentId);
        
        return presence;
    }
    
    // Remove user from document
    public function removeUser(string documentId, string userId) returns error? {
        lock {
            map<UserPresence>? docPresence = self.documentPresence[documentId];
            if docPresence is map<UserPresence> {
                _ = docPresence.remove(userId);
                
                // Clean up empty document
                if docPresence.keys().length() == 0 {
                    _ = self.documentPresence.remove(documentId);
                }
            }
            
            // Update user presence
            UserPresence? presence = self.userPresence[userId];
            if presence is UserPresence {
                presence.status = OFFLINE;
                presence.cursor = ();
                presence.selection = ();
            }
        }
        
        log:printInfo("User " + userId + " left document " + documentId);
        
        return;
    }
    
    // Update user status
    public function updateStatus(string userId, PresenceStatus status) returns error? {
        lock {
            UserPresence? presence = self.userPresence[userId];
            if presence is UserPresence {
                presence.status = status;
                presence.lastActivity = time:utcNow();
            } else {
                return error("User not found: " + userId);
            }
        }
        
        return;
    }
    
    // Update cursor position
    public function updateCursor(string userId, string documentId, CursorInfo cursor) 
        returns PresenceUpdate|error {
        
        UserPresence? presence;
        lock {
            map<UserPresence>? docPresence = self.documentPresence[documentId];
            if docPresence is map<UserPresence> {
                presence = docPresence[userId];
                if presence is UserPresence {
                    presence.cursor = cursor;
                    presence.lastActivity = time:utcNow();
                    
                    // Update status if idle
                    if presence.status == IDLE || presence.status == AWAY {
                        presence.status = ONLINE;
                    }
                }
            }
        }
        
        if presence is () {
            return error("User not in document: " + userId);
        }
        
        return {
            updateType: "cursor",
            presence: presence,
            timestamp: time:utcNow()
        };
    }
    
    // Update selection
    public function updateSelection(string userId, string documentId, SelectionInfo? selection) 
        returns PresenceUpdate|error {
        
        UserPresence? presence;
        lock {
            map<UserPresence>? docPresence = self.documentPresence[documentId];
            if docPresence is map<UserPresence> {
                presence = docPresence[userId];
                if presence is UserPresence {
                    presence.selection = selection;
                    presence.lastActivity = time:utcNow();
                    
                    // Update status
                    if selection is SelectionInfo {
                        presence.status = SELECTING;
                    } else if presence.status == SELECTING {
                        presence.status = ONLINE;
                    }
                }
            }
        }
        
        if presence is () {
            return error("User not in document: " + userId);
        }
        
        return {
            updateType: "selection",
            presence: presence,
            timestamp: time:utcNow()
        };
    }
    
    // Record user activity
    public function recordActivity(string userId, string documentId, ActivityType activityType, 
                                  json? data = ()) returns error? {
        
        UserActivity activity = {
            userId: userId,
            documentId: documentId,
            activityType: activityType,
            data: data,
            timestamp: time:utcNow()
        };
        
        // Update last activity
        lock {
            UserPresence? presence = self.userPresence[userId];
            if presence is UserPresence {
                presence.lastActivity = activity.timestamp;
                
                // Update status based on activity
                match activityType {
                    TEXT_EDIT => {
                        presence.status = TYPING;
                    }
                    SELECTION => {
                        presence.status = SELECTING;
                    }
                    _ => {
                        if presence.status == TYPING || presence.status == SELECTING {
                            presence.status = ONLINE;
                        }
                    }
                }
            }
        }
        
        return;
    }
    
    // Get document presence
    public function getDocumentPresence(string documentId) returns UserPresence[] {
        lock {
            map<UserPresence>? docPresence = self.documentPresence[documentId];
            if docPresence is map<UserPresence> {
                return docPresence.toArray();
            }
        }
        return [];
    }
    
    // Get user presence
    public function getUserPresence(string userId) returns UserPresence? {
        lock {
            return self.userPresence[userId];
        }
    }
    
    // Get all active users
    public function getActiveUsers(string documentId) returns UserPresence[] {
        UserPresence[] active = [];
        lock {
            map<UserPresence>? docPresence = self.documentPresence[documentId];
            if docPresence is map<UserPresence> {
                foreach UserPresence presence in docPresence {
                    if presence.status != OFFLINE && presence.status != AWAY {
                        active.push(presence);
                    }
                }
            }
        }
        return active;
    }
    
    // Check for idle users
    public function checkIdleUsers() returns string[] {
        string[] idleUsers = [];
        time:Utc now = time:utcNow();
        
        lock {
            foreach [string, UserPresence] [userId, presence] in self.userPresence.entries() {
                time:Seconds elapsed = time:utcDiffSeconds(now, presence.lastActivity);
                int elapsedMs = <int>(elapsed * 1000);
                
                if presence.status == ONLINE && elapsedMs > self.idleTimeout {
                    presence.status = IDLE;
                    idleUsers.push(userId);
                } else if presence.status == IDLE && elapsedMs > self.awayTimeout {
                    presence.status = AWAY;
                    idleUsers.push(userId);
                }
            }
        }
        
        return idleUsers;
    }
    
    // Get next available color
    private function getNextColor() returns string {
        string color = self.availableColors[self.colorIndex];
        self.colorIndex = (self.colorIndex + 1) % self.availableColors.length();
        return color;
    }
    
    // Get presence statistics
    public function getStatistics(string documentId) returns map<int> {
        map<int> stats = {
            "total": 0,
            "online": 0,
            "idle": 0,
            "away": 0,
            "typing": 0,
            "selecting": 0
        };
        
        lock {
            map<UserPresence>? docPresence = self.documentPresence[documentId];
            if docPresence is map<UserPresence> {
                foreach UserPresence presence in docPresence {
                    stats["total"] = <int>stats["total"] + 1;
                    
                    match presence.status {
                        ONLINE => stats["online"] = <int>stats["online"] + 1;
                        IDLE => stats["idle"] = <int>stats["idle"] + 1;
                        AWAY => stats["away"] = <int>stats["away"] + 1;
                        TYPING => {
                            stats["typing"] = <int>stats["typing"] + 1;
                            stats["online"] = <int>stats["online"] + 1;
                        }
                        SELECTING => {
                            stats["selecting"] = <int>stats["selecting"] + 1;
                            stats["online"] = <int>stats["online"] + 1;
                        }
                    }
                }
            }
        }
        
        return stats;
    }
    
    // Clear presence for document
    public function clearDocumentPresence(string documentId) {
        lock {
            map<UserPresence>? docPresence = self.documentPresence[documentId];
            if docPresence is map<UserPresence> {
                foreach UserPresence presence in docPresence {
                    presence.status = OFFLINE;
                    presence.cursor = ();
                    presence.selection = ();
                }
                _ = self.documentPresence.remove(documentId);
            }
        }
    }
    
    // Monitor presence (background task)
    public function startMonitoring() returns error? {
        _ = @strand {thread: "any"} start self.monitorPresence();
        return;
    }
    
    private function monitorPresence() {
        while true {
            runtime:sleep(30); // Check every 30 seconds
            string[] idleUsers = self.checkIdleUsers();
            
            if idleUsers.length() > 0 {
                log:printInfo("Users marked as idle/away: " + idleUsers.toString());
            }
        }
    }
}