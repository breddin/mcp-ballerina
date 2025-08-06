// Security Analyzer for Ballerina Code
// Implements Static Application Security Testing (SAST)

import ballerina/log;
import ballerina/regex;
import ballerina/crypto;
import code_analysis.ast_parser;
import code_analysis.semantic_analyzer;

// Security issue severity levels
public enum Severity {
    CRITICAL,
    HIGH,
    MEDIUM,
    LOW,
    INFO
}

// Security issue categories
public enum SecurityCategory {
    INJECTION,
    AUTHENTICATION,
    AUTHORIZATION,
    CRYPTOGRAPHY,
    DATA_EXPOSURE,
    CONFIGURATION,
    INPUT_VALIDATION,
    OUTPUT_ENCODING,
    SESSION_MANAGEMENT,
    ERROR_HANDLING,
    LOGGING,
    DEPENDENCIES
}

// Security issue
public type SecurityIssue record {|
    string id;
    string title;
    string description;
    Severity severity;
    SecurityCategory category;
    ast_parser:Range location;
    string filePath;
    string? cweId?;
    string? owaspId?;
    string? cveId?;
    SecurityRemediation? remediation?;
    map<any> metadata = {};
|};

// Security remediation
public type SecurityRemediation record {|
    string description;
    string? codeExample?;
    string[] steps?;
    string[] references?;
|};

// Security scan configuration
public type ScanConfig record {|
    boolean enableTaintAnalysis = true;
    boolean enableCryptoAnalysis = true;
    boolean enableAuthAnalysis = true;
    boolean enableInjectionDetection = true;
    boolean enableDataFlowAnalysis = true;
    boolean scanDependencies = true;
    Severity minSeverity = LOW;
    string[] excludePaths = [];
    map<boolean> ruleSet = {};
|};

// Scan result
public type ScanResult record {|
    boolean success;
    SecurityIssue[] issues;
    SecurityMetrics metrics;
    time:Utc scanTime;
    decimal duration;
|};

// Security metrics
public type SecurityMetrics record {|
    int totalIssues;
    int criticalCount;
    int highCount;
    int mediumCount;
    int lowCount;
    int infoCount;
    map<int> categoryCount;
    decimal riskScore;
|};

// Taint source
public type TaintSource record {|
    string variable;
    string source; // "user_input", "network", "file", "database"
    ast_parser:Position position;
    boolean sanitized = false;
|};

// Data flow node
public type DataFlowNode record {|
    string variable;
    string operation;
    ast_parser:Position position;
    DataFlowNode[] predecessors = [];
    DataFlowNode[] successors = [];
    boolean tainted = false;
|};

// Security Analyzer
public class SecurityAnalyzer {
    private ast_parser:ASTParser parser;
    private semantic_analyzer:SemanticAnalyzer semanticAnalyzer;
    private ScanConfig config;
    private SecurityIssue[] issues = [];
    private map<SecurityRule> rules = {};
    private map<TaintSource> taintSources = {};
    private map<DataFlowNode> dataFlowGraph = {};
    
    public function init(ScanConfig? config = ()) {
        self.parser = new();
        self.semanticAnalyzer = new();
        self.config = config ?: {};
        self.loadSecurityRules();
    }
    
    // Load security rules
    private function loadSecurityRules() {
        // SQL Injection
        self.rules["SQL_INJECTION"] = new SqlInjectionRule();
        
        // Command Injection
        self.rules["COMMAND_INJECTION"] = new CommandInjectionRule();
        
        // Path Traversal
        self.rules["PATH_TRAVERSAL"] = new PathTraversalRule();
        
        // XXE Injection
        self.rules["XXE_INJECTION"] = new XxeInjectionRule();
        
        // Weak Cryptography
        self.rules["WEAK_CRYPTO"] = new WeakCryptoRule();
        
        // Hardcoded Secrets
        self.rules["HARDCODED_SECRETS"] = new HardcodedSecretsRule();
        
        // Insecure Random
        self.rules["INSECURE_RANDOM"] = new InsecureRandomRule();
        
        // Open Redirect
        self.rules["OPEN_REDIRECT"] = new OpenRedirectRule();
        
        // CORS Misconfiguration
        self.rules["CORS_MISCONFIG"] = new CorsMisconfigRule();
        
        // Missing Authentication
        self.rules["MISSING_AUTH"] = new MissingAuthRule();
        
        // Insufficient Logging
        self.rules["INSUFFICIENT_LOGGING"] = new InsufficientLoggingRule();
        
        // Error Information Leak
        self.rules["ERROR_INFO_LEAK"] = new ErrorInfoLeakRule();
    }
    
    // Scan code for security issues
    public function scan(string sourceCode, string filePath) returns ScanResult {
        time:Utc startTime = time:utcNow();
        self.issues = [];
        
        // Parse source code
        ast_parser:ParseResult parseResult = self.parser.parse(sourceCode, filePath);
        if !parseResult.success || parseResult.root is () {
            return {
                success: false,
                issues: [],
                metrics: self.calculateMetrics(),
                scanTime: startTime,
                duration: 0.0
            };
        }
        
        ast_parser:ASTNode ast = <ast_parser:ASTNode>parseResult.root;
        
        // Semantic analysis
        semantic_analyzer:SemanticContext semanticContext = self.semanticAnalyzer.analyze(ast);
        
        // Taint analysis
        if self.config.enableTaintAnalysis {
            self.performTaintAnalysis(ast, semanticContext);
        }
        
        // Data flow analysis
        if self.config.enableDataFlowAnalysis {
            self.performDataFlowAnalysis(ast, semanticContext);
        }
        
        // Apply security rules
        foreach [string, SecurityRule] [ruleName, rule] in self.rules.entries() {
            if self.isRuleEnabled(ruleName) {
                SecurityIssue[] ruleIssues = rule.check(ast, semanticContext, filePath);
                self.issues.push(...ruleIssues);
            }
        }
        
        // Cryptography analysis
        if self.config.enableCryptoAnalysis {
            self.analyzeCryptography(ast, filePath);
        }
        
        // Authentication/Authorization analysis
        if self.config.enableAuthAnalysis {
            self.analyzeAuthentication(ast, filePath);
        }
        
        // Filter by severity
        SecurityIssue[] filteredIssues = self.filterBySeverity(self.issues);
        
        time:Utc endTime = time:utcNow();
        decimal duration = <decimal>time:utcDiffSeconds(endTime, startTime);
        
        return {
            success: true,
            issues: filteredIssues,
            metrics: self.calculateMetrics(),
            scanTime: startTime,
            duration: duration
        };
    }
    
    // Perform taint analysis
    private function performTaintAnalysis(ast_parser:ASTNode ast, 
                                         semantic_analyzer:SemanticContext context) {
        // Identify taint sources
        self.identifyTaintSources(ast);
        
        // Track taint propagation
        self.trackTaintPropagation(ast, context);
        
        // Check for taint sinks
        self.checkTaintSinks(ast);
    }
    
    // Identify taint sources
    private function identifyTaintSources(ast_parser:ASTNode node) {
        if node.nodeType == "function_call" {
            string? funcName = node.value;
            if funcName is string {
                // Check for input sources
                if self.isInputSource(funcName) {
                    string? varName = self.getAssignedVariable(node);
                    if varName is string {
                        self.taintSources[varName] = {
                            variable: varName,
                            source: self.getTaintSourceType(funcName),
                            position: node.position
                        };
                    }
                }
            }
        }
        
        // Recurse through children
        foreach ast_parser:ASTNode child in node.children {
            self.identifyTaintSources(child);
        }
    }
    
    // Track taint propagation
    private function trackTaintPropagation(ast_parser:ASTNode node,
                                          semantic_analyzer:SemanticContext context) {
        if node.nodeType == "assignment" {
            string? target = node.children[0]?.value;
            string? source = node.children[1]?.value;
            
            if target is string && source is string {
                // Check if source is tainted
                if self.taintSources.hasKey(source) {
                    // Propagate taint
                    self.taintSources[target] = self.taintSources[source];
                }
            }
        }
        
        // Recurse
        foreach ast_parser:ASTNode child in node.children {
            self.trackTaintPropagation(child, context);
        }
    }
    
    // Check for taint sinks
    private function checkTaintSinks(ast_parser:ASTNode node) {
        if node.nodeType == "function_call" {
            string? funcName = node.value;
            if funcName is string && self.isTaintSink(funcName) {
                // Check arguments for tainted data
                foreach ast_parser:ASTNode arg in node.children {
                    string? argValue = arg.value;
                    if argValue is string && self.taintSources.hasKey(argValue) {
                        TaintSource taint = self.taintSources[argValue];
                        if !taint.sanitized {
                            self.reportTaintedDataFlow(funcName, taint, node);
                        }
                    }
                }
            }
        }
        
        // Recurse
        foreach ast_parser:ASTNode child in node.children {
            self.checkTaintSinks(child);
        }
    }
    
    // Report tainted data flow
    private function reportTaintedDataFlow(string sinkFunction, TaintSource taint, 
                                          ast_parser:ASTNode node) {
        SecurityCategory category = self.getSinkCategory(sinkFunction);
        Severity severity = self.getSinkSeverity(sinkFunction);
        
        self.issues.push({
            id: "TAINT_" + category.toString(),
            title: "Tainted Data Flow to " + sinkFunction,
            description: "User input from " + taint.source + " flows to " + sinkFunction + 
                        " without proper sanitization",
            severity: severity,
            category: category,
            location: {
                start: node.position,
                end: node.position
            },
            filePath: "",
            cweId: self.getCweForCategory(category),
            remediation: {
                description: "Sanitize user input before using in " + sinkFunction,
                steps: [
                    "Validate input format and content",
                    "Escape special characters",
                    "Use parameterized queries or prepared statements",
                    "Apply context-specific encoding"
                ]
            }
        });
    }
    
    // Perform data flow analysis
    private function performDataFlowAnalysis(ast_parser:ASTNode ast,
                                            semantic_analyzer:SemanticContext context) {
        // Build data flow graph
        self.buildDataFlowGraph(ast, context);
        
        // Analyze data flow paths
        self.analyzeDataFlowPaths();
    }
    
    // Build data flow graph
    private function buildDataFlowGraph(ast_parser:ASTNode node,
                                       semantic_analyzer:SemanticContext context) {
        // Implementation for building data flow graph
        // Track variable assignments and uses
    }
    
    // Analyze data flow paths
    private function analyzeDataFlowPaths() {
        // Implementation for analyzing paths in data flow graph
        // Detect vulnerable patterns
    }
    
    // Analyze cryptography usage
    private function analyzeCryptography(ast_parser:ASTNode ast, string filePath) {
        self.findCryptoUsage(ast, filePath);
    }
    
    // Find cryptography usage
    private function findCryptoUsage(ast_parser:ASTNode node, string filePath) {
        if node.nodeType == "import" && node.value == "ballerina/crypto" {
            // Check crypto module usage
            self.checkCryptoPatterns(node.parent ?: node, filePath);
        }
        
        if node.nodeType == "function_call" {
            string? funcName = node.value;
            if funcName is string {
                // Check for weak algorithms
                if self.isWeakCryptoAlgorithm(funcName) {
                    self.issues.push({
                        id: "WEAK_CRYPTO_ALGO",
                        title: "Weak Cryptographic Algorithm",
                        description: "Use of weak cryptographic algorithm: " + funcName,
                        severity: HIGH,
                        category: CRYPTOGRAPHY,
                        location: {
                            start: node.position,
                            end: node.position
                        },
                        filePath: filePath,
                        cweId: "CWE-327",
                        remediation: {
                            description: "Use strong cryptographic algorithms",
                            codeExample: "crypto:hashSha256(data)",
                            references: ["https://owasp.org/www-project-cryptographic-storage-cheat-sheet/"]
                        }
                    });
                }
                
                // Check for hardcoded keys
                self.checkHardcodedKeys(node, filePath);
            }
        }
        
        // Recurse
        foreach ast_parser:ASTNode child in node.children {
            self.findCryptoUsage(child, filePath);
        }
    }
    
    // Check crypto patterns
    private function checkCryptoPatterns(ast_parser:ASTNode node, string filePath) {
        // Check for insecure random number generation
        // Check for weak key sizes
        // Check for missing IV in encryption
    }
    
    // Check for hardcoded keys
    private function checkHardcodedKeys(ast_parser:ASTNode node, string filePath) {
        foreach ast_parser:ASTNode child in node.children {
            if child.nodeType == "literal" {
                string? value = child.value;
                if value is string && self.looksLikeKey(value) {
                    self.issues.push({
                        id: "HARDCODED_KEY",
                        title: "Hardcoded Cryptographic Key",
                        description: "Possible hardcoded cryptographic key detected",
                        severity: CRITICAL,
                        category: CRYPTOGRAPHY,
                        location: {
                            start: child.position,
                            end: child.position
                        },
                        filePath: filePath,
                        cweId: "CWE-798",
                        remediation: {
                            description: "Store keys in secure configuration or key management system",
                            steps: [
                                "Use environment variables for keys",
                                "Implement key rotation",
                                "Use a key management service",
                                "Never commit keys to version control"
                            ]
                        }
                    });
                }
            }
        }
    }
    
    // Analyze authentication
    private function analyzeAuthentication(ast_parser:ASTNode ast, string filePath) {
        // Check for missing authentication
        self.checkMissingAuth(ast, filePath);
        
        // Check for weak authentication
        self.checkWeakAuth(ast, filePath);
        
        // Check session management
        self.checkSessionManagement(ast, filePath);
    }
    
    // Check for missing authentication
    private function checkMissingAuth(ast_parser:ASTNode node, string filePath) {
        if node.nodeType == "resource_function" {
            boolean hasAuth = self.hasAuthenticationCheck(node);
            if !hasAuth && self.isSensitiveEndpoint(node) {
                self.issues.push({
                    id: "MISSING_AUTH",
                    title: "Missing Authentication",
                    description: "Sensitive endpoint lacks authentication check",
                    severity: HIGH,
                    category: AUTHENTICATION,
                    location: {
                        start: node.position,
                        end: node.position
                    },
                    filePath: filePath,
                    cweId: "CWE-306",
                    remediation: {
                        description: "Add authentication check to sensitive endpoints",
                        codeExample: "check auth:authenticate(request);"
                    }
                });
            }
        }
        
        // Recurse
        foreach ast_parser:ASTNode child in node.children {
            self.checkMissingAuth(child, filePath);
        }
    }
    
    // Check for weak authentication
    private function checkWeakAuth(ast_parser:ASTNode node, string filePath) {
        // Check for basic auth over HTTP
        // Check for weak password policies
        // Check for missing MFA
    }
    
    // Check session management
    private function checkSessionManagement(ast_parser:ASTNode node, string filePath) {
        // Check for session fixation
        // Check for missing session timeout
        // Check for insecure session storage
    }
    
    // Helper functions
    private function isInputSource(string funcName) returns boolean {
        string[] inputSources = [
            "http:getQueryParam",
            "http:getHeader",
            "http:getPayload",
            "io:readln",
            "file:read",
            "sql:queryRow"
        ];
        return inputSources.indexOf(funcName) != ();
    }
    
    private function getTaintSourceType(string funcName) returns string {
        if funcName.startsWith("http:") {
            return "network";
        } else if funcName.startsWith("io:") {
            return "user_input";
        } else if funcName.startsWith("file:") {
            return "file";
        } else if funcName.startsWith("sql:") {
            return "database";
        }
        return "unknown";
    }
    
    private function isTaintSink(string funcName) returns boolean {
        string[] sinks = [
            "sql:execute",
            "sql:queryRow",
            "os:exec",
            "file:create",
            "file:write",
            "http:redirect",
            "xml:parse"
        ];
        return sinks.indexOf(funcName) != ();
    }
    
    private function getSinkCategory(string sinkFunction) returns SecurityCategory {
        if sinkFunction.startsWith("sql:") {
            return INJECTION;
        } else if sinkFunction.startsWith("os:") {
            return INJECTION;
        } else if sinkFunction.startsWith("file:") {
            return DATA_EXPOSURE;
        }
        return INPUT_VALIDATION;
    }
    
    private function getSinkSeverity(string sinkFunction) returns Severity {
        if sinkFunction.startsWith("sql:") || sinkFunction.startsWith("os:") {
            return CRITICAL;
        }
        return HIGH;
    }
    
    private function getCweForCategory(SecurityCategory category) returns string {
        match category {
            INJECTION => { return "CWE-89"; }
            AUTHENTICATION => { return "CWE-287"; }
            AUTHORIZATION => { return "CWE-285"; }
            CRYPTOGRAPHY => { return "CWE-310"; }
            DATA_EXPOSURE => { return "CWE-200"; }
            _ => { return "CWE-20"; }
        }
    }
    
    private function getAssignedVariable(ast_parser:ASTNode node) returns string? {
        // Get variable being assigned from function call
        ast_parser:ASTNode? parent = node.parent;
        if parent is ast_parser:ASTNode && parent.nodeType == "assignment" {
            return parent.children[0]?.value;
        }
        return ();
    }
    
    private function isWeakCryptoAlgorithm(string algo) returns boolean {
        string[] weakAlgos = ["MD5", "SHA1", "DES", "RC4"];
        foreach string weak in weakAlgos {
            if algo.toLowerAscii().includes(weak.toLowerAscii()) {
                return true;
            }
        }
        return false;
    }
    
    private function looksLikeKey(string value) returns boolean {
        // Check if string looks like a cryptographic key
        if value.length() < 16 {
            return false;
        }
        
        // Check for base64 or hex patterns
        boolean isBase64 = regex:matches(value, "^[A-Za-z0-9+/]+=*$");
        boolean isHex = regex:matches(value, "^[0-9a-fA-F]+$");
        
        return (isBase64 || isHex) && value.length() >= 32;
    }
    
    private function hasAuthenticationCheck(ast_parser:ASTNode node) returns boolean {
        // Check if function has authentication checks
        foreach ast_parser:ASTNode child in node.children {
            if child.nodeType == "function_call" {
                string? funcName = child.value;
                if funcName is string && 
                   (funcName.includes("auth") || funcName.includes("authenticate")) {
                    return true;
                }
            }
        }
        return false;
    }
    
    private function isSensitiveEndpoint(ast_parser:ASTNode node) returns boolean {
        // Check if endpoint handles sensitive operations
        string? funcName = node.value;
        if funcName is string {
            string[] sensitiveOps = ["delete", "update", "admin", "config", "user"];
            foreach string op in sensitiveOps {
                if funcName.toLowerAscii().includes(op) {
                    return true;
                }
            }
        }
        return false;
    }
    
    private function isRuleEnabled(string ruleName) returns boolean {
        if self.config.ruleSet.hasKey(ruleName) {
            return self.config.ruleSet[ruleName];
        }
        return true; // Default: enabled
    }
    
    private function filterBySeverity(SecurityIssue[] issues) returns SecurityIssue[] {
        SecurityIssue[] filtered = [];
        foreach SecurityIssue issue in issues {
            if self.compareSeverity(issue.severity, self.config.minSeverity) >= 0 {
                filtered.push(issue);
            }
        }
        return filtered;
    }
    
    private function compareSeverity(Severity s1, Severity s2) returns int {
        int[] severityValues = [5, 4, 3, 2, 1]; // CRITICAL to INFO
        int v1 = severityValues[<int>s1];
        int v2 = severityValues[<int>s2];
        return v1 - v2;
    }
    
    private function calculateMetrics() returns SecurityMetrics {
        int critical = 0, high = 0, medium = 0, low = 0, info = 0;
        map<int> categoryCount = {};
        
        foreach SecurityIssue issue in self.issues {
            match issue.severity {
                CRITICAL => { critical += 1; }
                HIGH => { high += 1; }
                MEDIUM => { medium += 1; }
                LOW => { low += 1; }
                INFO => { info += 1; }
            }
            
            string cat = issue.category.toString();
            categoryCount[cat] = (categoryCount[cat] ?: 0) + 1;
        }
        
        // Calculate risk score (CVSS-like)
        decimal riskScore = <decimal>(critical * 10 + high * 7 + medium * 4 + low * 1);
        
        return {
            totalIssues: self.issues.length(),
            criticalCount: critical,
            highCount: high,
            mediumCount: medium,
            lowCount: low,
            infoCount: info,
            categoryCount: categoryCount,
            riskScore: riskScore
        };
    }
}

// Base security rule interface
type SecurityRule object {
    public function check(ast_parser:ASTNode ast, semantic_analyzer:SemanticContext context,
                         string filePath) returns SecurityIssue[];
};

// SQL Injection Rule
class SqlInjectionRule {
    *SecurityRule;
    
    public function check(ast_parser:ASTNode ast, semantic_analyzer:SemanticContext context,
                         string filePath) returns SecurityIssue[] {
        SecurityIssue[] issues = [];
        // Implementation for SQL injection detection
        return issues;
    }
}

// Command Injection Rule
class CommandInjectionRule {
    *SecurityRule;
    
    public function check(ast_parser:ASTNode ast, semantic_analyzer:SemanticContext context,
                         string filePath) returns SecurityIssue[] {
        SecurityIssue[] issues = [];
        // Implementation for command injection detection
        return issues;
    }
}

// Path Traversal Rule
class PathTraversalRule {
    *SecurityRule;
    
    public function check(ast_parser:ASTNode ast, semantic_analyzer:SemanticContext context,
                         string filePath) returns SecurityIssue[] {
        SecurityIssue[] issues = [];
        // Implementation for path traversal detection
        return issues;
    }
}

// XXE Injection Rule
class XxeInjectionRule {
    *SecurityRule;
    
    public function check(ast_parser:ASTNode ast, semantic_analyzer:SemanticContext context,
                         string filePath) returns SecurityIssue[] {
        SecurityIssue[] issues = [];
        // Implementation for XXE injection detection
        return issues;
    }
}

// Weak Crypto Rule
class WeakCryptoRule {
    *SecurityRule;
    
    public function check(ast_parser:ASTNode ast, semantic_analyzer:SemanticContext context,
                         string filePath) returns SecurityIssue[] {
        SecurityIssue[] issues = [];
        // Implementation for weak crypto detection
        return issues;
    }
}

// Hardcoded Secrets Rule
class HardcodedSecretsRule {
    *SecurityRule;
    
    public function check(ast_parser:ASTNode ast, semantic_analyzer:SemanticContext context,
                         string filePath) returns SecurityIssue[] {
        SecurityIssue[] issues = [];
        // Implementation for hardcoded secrets detection
        return issues;
    }
}

// Insecure Random Rule
class InsecureRandomRule {
    *SecurityRule;
    
    public function check(ast_parser:ASTNode ast, semantic_analyzer:SemanticContext context,
                         string filePath) returns SecurityIssue[] {
        SecurityIssue[] issues = [];
        // Implementation for insecure random detection
        return issues;
    }
}

// Open Redirect Rule
class OpenRedirectRule {
    *SecurityRule;
    
    public function check(ast_parser:ASTNode ast, semantic_analyzer:SemanticContext context,
                         string filePath) returns SecurityIssue[] {
        SecurityIssue[] issues = [];
        // Implementation for open redirect detection
        return issues;
    }
}

// CORS Misconfiguration Rule
class CorsMisconfigRule {
    *SecurityRule;
    
    public function check(ast_parser:ASTNode ast, semantic_analyzer:SemanticContext context,
                         string filePath) returns SecurityIssue[] {
        SecurityIssue[] issues = [];
        // Implementation for CORS misconfiguration detection
        return issues;
    }
}

// Missing Auth Rule
class MissingAuthRule {
    *SecurityRule;
    
    public function check(ast_parser:ASTNode ast, semantic_analyzer:SemanticContext context,
                         string filePath) returns SecurityIssue[] {
        SecurityIssue[] issues = [];
        // Implementation for missing authentication detection
        return issues;
    }
}

// Insufficient Logging Rule
class InsufficientLoggingRule {
    *SecurityRule;
    
    public function check(ast_parser:ASTNode ast, semantic_analyzer:SemanticContext context,
                         string filePath) returns SecurityIssue[] {
        SecurityIssue[] issues = [];
        // Implementation for insufficient logging detection
        return issues;
    }
}

// Error Info Leak Rule
class ErrorInfoLeakRule {
    *SecurityRule;
    
    public function check(ast_parser:ASTNode ast, semantic_analyzer:SemanticContext context,
                         string filePath) returns SecurityIssue[] {
        SecurityIssue[] issues = [];
        // Implementation for error information leak detection
        return issues;
    }
}