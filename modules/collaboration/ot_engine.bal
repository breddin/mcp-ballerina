// Operational Transform Engine for Ballerina
// Implements OT algorithm for real-time collaborative editing

import ballerina/log;

// Operation types
public type OperationType "insert"|"delete"|"format"|"move"|"retain";

// Text operation
public type TextOperation record {|
    OperationType opType;
    int position;
    string? text?;
    int? length?;
    map<any>? attributes?;
    string? moveToPosition?;
|};

// Compound operation (multiple ops)
public type CompoundOperation record {|
    TextOperation[] ops;
    int baseVersion;
    string authorId;
|};

// Transform result
public type TransformResult record {|
    TextOperation transformedOp;
    boolean conflict;
    string? conflictType?;
    ConflictResolution? resolution?;
|};

// Conflict resolution
public type ConflictResolution record {|
    string strategy; // "merge", "ours", "theirs", "manual"
    TextOperation? resolvedOp?;
    string? message?;
|};

// Document version info
public type VersionInfo record {|
    int version;
    string documentId;
    string? parentVersion?;
    string authorId;
    time:Utc timestamp;
|};

// Operational Transform Engine
public class OperationalTransformEngine {
    private map<CompoundOperation[]> operationHistory = {};
    private map<int> documentVersions = {};
    
    // Transform operation against concurrent operations
    public function transform(TextOperation op1, TextOperation op2, boolean priority = true) 
        returns TransformResult {
        
        // Check for conflicts
        boolean hasConflict = self.detectConflict(op1, op2);
        
        // Apply transformation based on operation types
        TextOperation transformedOp;
        string? conflictType = ();
        
        if op1.opType == "insert" && op2.opType == "insert" {
            transformedOp = self.transformInsertInsert(op1, op2, priority);
        } else if op1.opType == "insert" && op2.opType == "delete" {
            transformedOp = self.transformInsertDelete(op1, op2);
        } else if op1.opType == "delete" && op2.opType == "insert" {
            transformedOp = self.transformDeleteInsert(op1, op2);
        } else if op1.opType == "delete" && op2.opType == "delete" {
            transformedOp = self.transformDeleteDelete(op1, op2);
            if hasConflict {
                conflictType = "overlapping_delete";
            }
        } else if op1.opType == "format" {
            transformedOp = self.transformFormat(op1, op2);
        } else if op1.opType == "move" {
            transformedOp = self.transformMove(op1, op2);
        } else {
            transformedOp = op1; // Default: no transformation
        }
        
        return {
            transformedOp: transformedOp,
            conflict: hasConflict,
            conflictType: conflictType
        };
    }
    
    // Transform insert against insert
    private function transformInsertInsert(TextOperation op1, TextOperation op2, boolean priority) 
        returns TextOperation {
        
        TextOperation transformed = op1.clone();
        
        if op1.position < op2.position {
            // op1 comes before op2, no change needed
        } else if op1.position > op2.position {
            // op1 comes after op2, shift by op2's insert length
            transformed.position = op1.position + (op2.text?.length() ?: 0);
        } else {
            // Same position - use priority to determine order
            if priority {
                // op1 has priority, goes first
            } else {
                // op2 has priority, op1 shifts
                transformed.position = op1.position + (op2.text?.length() ?: 0);
            }
        }
        
        return transformed;
    }
    
    // Transform insert against delete
    private function transformInsertDelete(TextOperation op1, TextOperation op2) 
        returns TextOperation {
        
        TextOperation transformed = op1.clone();
        int deleteEnd = op2.position + (op2.length ?: 0);
        
        if op1.position <= op2.position {
            // Insert before delete, no change
        } else if op1.position >= deleteEnd {
            // Insert after delete, shift back
            transformed.position = op1.position - (op2.length ?: 0);
        } else {
            // Insert within delete range, move to delete position
            transformed.position = op2.position;
        }
        
        return transformed;
    }
    
    // Transform delete against insert
    private function transformDeleteInsert(TextOperation op1, TextOperation op2) 
        returns TextOperation {
        
        TextOperation transformed = op1.clone();
        int deleteEnd = op1.position + (op1.length ?: 0);
        
        if deleteEnd <= op2.position {
            // Delete before insert, no change
        } else if op1.position >= op2.position {
            // Delete after insert, shift forward
            transformed.position = op1.position + (op2.text?.length() ?: 0);
        } else {
            // Insert within delete range, split delete
            int insertLen = op2.text?.length() ?: 0;
            transformed.length = (op1.length ?: 0) + insertLen;
        }
        
        return transformed;
    }
    
    // Transform delete against delete
    private function transformDeleteDelete(TextOperation op1, TextOperation op2) 
        returns TextOperation {
        
        TextOperation transformed = op1.clone();
        int end1 = op1.position + (op1.length ?: 0);
        int end2 = op2.position + (op2.length ?: 0);
        
        if end1 <= op2.position {
            // op1 before op2, no change
        } else if op1.position >= end2 {
            // op1 after op2, shift back
            transformed.position = op1.position - (op2.length ?: 0);
        } else if op1.position >= op2.position && end1 <= end2 {
            // op1 entirely within op2, nullify
            transformed.length = 0;
        } else if op2.position >= op1.position && end2 <= end1 {
            // op2 entirely within op1, reduce length
            transformed.length = (op1.length ?: 0) - (op2.length ?: 0);
        } else if op1.position < op2.position && end1 > op2.position && end1 <= end2 {
            // op1 overlaps start of op2
            transformed.length = op2.position - op1.position;
        } else if op2.position < op1.position && end2 > op1.position && end2 <= end1 {
            // op2 overlaps start of op1
            transformed.position = op2.position;
            transformed.length = end1 - end2;
        }
        
        return transformed;
    }
    
    // Transform format operation
    private function transformFormat(TextOperation op1, TextOperation op2) 
        returns TextOperation {
        
        TextOperation transformed = op1.clone();
        
        if op2.opType == "insert" {
            if op1.position >= op2.position {
                transformed.position = op1.position + (op2.text?.length() ?: 0);
            }
        } else if op2.opType == "delete" {
            int deleteEnd = op2.position + (op2.length ?: 0);
            if op1.position >= deleteEnd {
                transformed.position = op1.position - (op2.length ?: 0);
            } else if op1.position > op2.position {
                transformed.position = op2.position;
            }
        }
        
        return transformed;
    }
    
    // Transform move operation
    private function transformMove(TextOperation op1, TextOperation op2) 
        returns TextOperation {
        
        TextOperation transformed = op1.clone();
        
        // Adjust source position
        if op2.opType == "insert" && op1.position >= op2.position {
            transformed.position = op1.position + (op2.text?.length() ?: 0);
        } else if op2.opType == "delete" {
            int deleteEnd = op2.position + (op2.length ?: 0);
            if op1.position >= deleteEnd {
                transformed.position = op1.position - (op2.length ?: 0);
            }
        }
        
        // Adjust target position
        if transformed.moveToPosition is string {
            int targetPos = int:fromString(transformed.moveToPosition) ?: 0;
            if op2.opType == "insert" && targetPos >= op2.position {
                transformed.moveToPosition = (targetPos + (op2.text?.length() ?: 0)).toString();
            } else if op2.opType == "delete" {
                int deleteEnd = op2.position + (op2.length ?: 0);
                if targetPos >= deleteEnd {
                    transformed.moveToPosition = (targetPos - (op2.length ?: 0)).toString();
                }
            }
        }
        
        return transformed;
    }
    
    // Detect conflicts between operations
    private function detectConflict(TextOperation op1, TextOperation op2) returns boolean {
        // Check for overlapping regions
        if op1.opType == "delete" && op2.opType == "delete" {
            int end1 = op1.position + (op1.length ?: 0);
            int end2 = op2.position + (op2.length ?: 0);
            
            // Overlapping deletes are conflicts
            return (op1.position < end2 && end1 > op2.position);
        }
        
        // Format conflicts
        if op1.opType == "format" && op2.opType == "format" {
            int end1 = op1.position + (op1.length ?: 0);
            int end2 = op2.position + (op2.length ?: 0);
            
            // Overlapping format operations with different attributes
            if op1.position < end2 && end1 > op2.position {
                return !self.attributesEqual(op1.attributes, op2.attributes);
            }
        }
        
        return false;
    }
    
    // Check if attributes are equal
    private function attributesEqual(map<any>? attrs1, map<any>? attrs2) returns boolean {
        if attrs1 is () && attrs2 is () {
            return true;
        }
        if attrs1 is () || attrs2 is () {
            return false;
        }
        
        // Compare attribute maps
        if attrs1.keys().length() != attrs2.keys().length() {
            return false;
        }
        
        foreach string key in attrs1.keys() {
            if !attrs2.hasKey(key) || attrs1[key] != attrs2[key] {
                return false;
            }
        }
        
        return true;
    }
    
    // Transform compound operation
    public function transformCompound(CompoundOperation op1, CompoundOperation op2) 
        returns CompoundOperation {
        
        TextOperation[] transformedOps = [];
        
        foreach TextOperation op in op1.ops {
            TextOperation current = op;
            foreach TextOperation otherOp in op2.ops {
                TransformResult result = self.transform(current, otherOp);
                current = result.transformedOp;
            }
            transformedOps.push(current);
        }
        
        return {
            ops: transformedOps,
            baseVersion: op1.baseVersion,
            authorId: op1.authorId
        };
    }
    
    // Compose operations
    public function compose(TextOperation op1, TextOperation op2) returns TextOperation? {
        // Compose consecutive operations
        if op1.opType == "insert" && op2.opType == "insert" {
            if op1.position + (op1.text?.length() ?: 0) == op2.position {
                // Adjacent inserts
                return {
                    opType: "insert",
                    position: op1.position,
                    text: (op1.text ?: "") + (op2.text ?: "")
                };
            }
        } else if op1.opType == "delete" && op2.opType == "delete" {
            if op1.position == op2.position {
                // Consecutive deletes at same position
                return {
                    opType: "delete",
                    position: op1.position,
                    length: (op1.length ?: 0) + (op2.length ?: 0)
                };
            }
        }
        
        return (); // Cannot compose
    }
    
    // Invert operation (for undo)
    public function invert(TextOperation op, string? originalText = ()) returns TextOperation {
        match op.opType {
            "insert" => {
                return {
                    opType: "delete",
                    position: op.position,
                    length: op.text?.length() ?: 0
                };
            }
            "delete" => {
                return {
                    opType: "insert",
                    position: op.position,
                    text: originalText ?: ""
                };
            }
            "format" => {
                // Invert format by reversing attributes
                return {
                    opType: "format",
                    position: op.position,
                    length: op.length,
                    attributes: {} // Should store original attributes
                };
            }
            "move" => {
                // Invert move by swapping positions
                return {
                    opType: "move",
                    position: int:fromString(op.moveToPosition ?: "0") ?: 0,
                    moveToPosition: op.position.toString()
                };
            }
            _ => {
                return op; // Default: return as-is
            }
        }
    }
    
    // Apply operation to text
    public function applyToText(string text, TextOperation op) returns string|error {
        match op.opType {
            "insert" => {
                string insertText = op.text ?: "";
                return text.substring(0, op.position) + insertText + 
                       text.substring(op.position);
            }
            "delete" => {
                int deleteLength = op.length ?: 0;
                return text.substring(0, op.position) + 
                       text.substring(op.position + deleteLength);
            }
            "format" => {
                // Format doesn't change text content
                return text;
            }
            "move" => {
                int moveLength = op.length ?: 1;
                int targetPos = int:fromString(op.moveToPosition ?: "0") ?: 0;
                string movedText = text.substring(op.position, op.position + moveLength);
                string withoutMoved = text.substring(0, op.position) + 
                                     text.substring(op.position + moveLength);
                
                if targetPos <= op.position {
                    return withoutMoved.substring(0, targetPos) + movedText + 
                           withoutMoved.substring(targetPos);
                } else {
                    int adjustedTarget = targetPos - moveLength;
                    return withoutMoved.substring(0, adjustedTarget) + movedText + 
                           withoutMoved.substring(adjustedTarget);
                }
            }
            _ => {
                return text;
            }
        }
    }
    
    // Validate operation
    public function validateOperation(TextOperation op, string text) returns boolean {
        if op.position < 0 || op.position > text.length() {
            return false;
        }
        
        if op.opType == "delete" {
            int deleteLength = op.length ?: 0;
            if op.position + deleteLength > text.length() {
                return false;
            }
        }
        
        if op.opType == "move" {
            int moveLength = op.length ?: 1;
            if op.position + moveLength > text.length() {
                return false;
            }
            int targetPos = int:fromString(op.moveToPosition ?: "0") ?: 0;
            if targetPos < 0 || targetPos > text.length() {
                return false;
            }
        }
        
        return true;
    }
    
    // Store operation in history
    public function addToHistory(string documentId, CompoundOperation op) {
        if !self.operationHistory.hasKey(documentId) {
            self.operationHistory[documentId] = [];
        }
        self.operationHistory[documentId].push(op);
    }
    
    // Get operation history
    public function getHistory(string documentId, int? fromVersion = ()) 
        returns CompoundOperation[] {
        
        CompoundOperation[] history = self.operationHistory[documentId] ?: [];
        
        if fromVersion is int {
            CompoundOperation[] filtered = [];
            foreach CompoundOperation op in history {
                if op.baseVersion >= fromVersion {
                    filtered.push(op);
                }
            }
            return filtered;
        }
        
        return history;
    }
    
    // Clear history for document
    public function clearHistory(string documentId) {
        _ = self.operationHistory.remove(documentId);
        _ = self.documentVersions.remove(documentId);
    }
}