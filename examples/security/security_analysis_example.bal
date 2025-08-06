import ballerina/io;
import modules.security.security_analyzer;
import modules.security.vulnerability_scanner;
import modules.security.security_reporter;

public function main() returns error? {
    // Example 1: Basic Security Scan
    io:println("=== Basic Security Scan ===");
    
    string vulnerableCode = string `
        import ballerina/sql;
        import ballerina/http;
        
        service /api on new http:Listener(9090) {
            resource function get user(string id) returns json|error {
                // SQL Injection vulnerability
                string query = "SELECT * FROM users WHERE id = '" + id + "'";
                stream<record{}, error?> result = dbClient->query(query);
                
                return {"user": check result.next()};
            }
            
            resource function post login(@http:Payload json payload) returns json|error {
                string? password = check payload.password;
                
                // Hardcoded credentials vulnerability
                if password == "admin123" {
                    return {"token": "secret-token-123"};
                }
                
                // Weak cryptography
                string hashedPassword = simpleHash(password);
                
                return {"status": "failed"};
            }
        }
        
        function simpleHash(string input) returns string {
            // Weak hash function
            int hash = 0;
            foreach byte b in input.toBytes() {
                hash = hash + b;
            }
            return hash.toString();
        }
    `;
    
    security_analyzer:ScanConfig scanConfig = {
        enableTaintAnalysis: true,
        enableCryptoAnalysis: true,
        enableSecretDetection: true,
        minSeverity: security_analyzer:LOW,
        includeInfo: true
    };
    
    security_analyzer:SecurityAnalyzer analyzer = new(scanConfig);
    security_analyzer:ScanResult scanResult = analyzer.scan(vulnerableCode, "api_service.bal");
    
    io:println(string `Found ${scanResult.vulnerabilities.length()} vulnerabilities:`);
    
    foreach security_analyzer:Vulnerability vuln in scanResult.vulnerabilities {
        io:println(string `\n[${vuln.severity}] ${vuln.title}`);
        io:println(string `  Line ${vuln.location.start.line}: ${vuln.description}`);
        io:println(string `  CWE: ${vuln.cweId} | OWASP: ${vuln.owaspCategory}`);
        io:println(string `  Fix: ${vuln.remediation}`);
    }
    
    // Example 2: Taint Analysis
    io:println("\n\n=== Taint Analysis Example ===");
    
    string taintExample = string `
        function processUserInput(string userInput) returns string|error {
            // Tainted data flow
            string command = "echo " + userInput;  // Source of taint
            
            // Command injection vulnerability
            var result = exec(command);  // Sink - tainted data reaches dangerous function
            
            // Path traversal vulnerability
            string filePath = "/data/" + userInput;
            var fileContent = readFile(filePath);  // Another sink
            
            return result;
        }
        
        function safeProcessing(string userInput) returns string {
            // Proper sanitization
            string sanitized = sanitize(userInput);
            string command = "echo " + sanitized;  // Safe after sanitization
            
            return exec(command);
        }
    `;
    
    security_analyzer:TaintAnalysisResult taintResult = analyzer.analyzeTaintFlow(
        taintExample, "taint_example.bal"
    );
    
    io:println("Taint flow analysis:");
    io:println(string `  Sources found: ${taintResult.sources.length()}`);
    io:println(string `  Sinks found: ${taintResult.sinks.length()}`);
    io:println(string `  Tainted paths: ${taintResult.taintedPaths.length()}`);
    
    foreach security_analyzer:TaintPath path in taintResult.taintedPaths {
        io:println(string `\n  Tainted path from line ${path.source.line} to line ${path.sink.line}:`);
        foreach security_analyzer:TaintNode node in path.nodes {
            io:println(string `    -> ${node.type}: ${node.description}`);
        }
    }
    
    // Example 3: Dependency Vulnerability Scanning
    io:println("\n\n=== Dependency Vulnerability Scan ===");
    
    vulnerability_scanner:VulnerabilityScanConfig vulnConfig = {
        checkCVE: true,
        checkGHSA: true,
        includeTransitive: true,
        severityThreshold: vulnerability_scanner:MEDIUM
    };
    
    vulnerability_scanner:VulnerabilityScanner vulnScanner = new(vulnConfig);
    
    // Scan project dependencies
    vulnerability_scanner:VulnerabilityScanResult vulnScanResult = check vulnScanner.scanProject(".");
    
    io:println(string `Scanned ${vulnScanResult.totalDependencies} dependencies`);
    io:println(string `Found ${vulnScanResult.vulnerablePackages.length()} vulnerable packages:`);
    
    foreach vulnerability_scanner:VulnerablePackage pkg in vulnScanResult.vulnerablePackages {
        io:println(string `\n  📦 ${pkg.name} @ ${pkg.version}`);
        foreach vulnerability_scanner:CVE cve in pkg.vulnerabilities {
            io:println(string `    - ${cve.id}: ${cve.description}`);
            io:println(string `      Severity: ${cve.severity} | CVSS: ${cve.cvssScore}`);
            io:println(string `      Fixed in: ${cve.fixedVersion ?: "No fix available"}`);
        }
    }
    
    // Example 4: Security Report Generation
    io:println("\n\n=== Security Report Generation ===");
    
    security_reporter:ReportConfig reportConfig = {
        format: security_reporter:MARKDOWN,
        includeRemediation: true,
        includeCompliance: true,
        includeTrends: true,
        includeExecutiveSummary: true
    };
    
    security_reporter:SecurityReporter reporter = new(reportConfig);
    
    // Generate comprehensive report
    security_reporter:SecurityReport report = check reporter.generateReport(scanResult);
    
    io:println("Security Report Summary:");
    io:println(string `  Title: ${report.title}`);
    io:println(string `  Generated: ${report.timestamp}`);
    io:println(string `  Total Issues: ${report.summary.totalIssues}`);
    io:println(string `  Critical: ${report.summary.criticalCount}`);
    io:println(string `  High: ${report.summary.highCount}`);
    io:println(string `  Medium: ${report.summary.mediumCount}`);
    io:println(string `  Low: ${report.summary.lowCount}`);
    
    // Export report
    check reporter.exportReport(report, "./security-report.md");
    io:println("\n✅ Report exported to security-report.md");
    
    // Example 5: Custom Security Rules
    io:println("\n\n=== Custom Security Rules ===");
    
    // Add custom security rule
    security_analyzer:SecurityRule customRule = {
        id: "CUSTOM_001",
        name: "Avoid TODO Comments in Production",
        description: "TODO comments should not be present in production code",
        severity: security_analyzer:INFO,
        category: "Code Quality",
        pattern: "TODO|FIXME|HACK",
        cweId: "CWE-546"
    };
    
    analyzer.addCustomRule(customRule);
    
    string codeWithTodos = string `
        function processPayment(decimal amount) returns boolean {
            // TODO: Add proper validation
            // FIXME: Handle negative amounts
            
            if amount > 0 {
                // HACK: Temporary workaround
                return true;
            }
            return false;
        }
    `;
    
    security_analyzer:ScanResult customScan = analyzer.scan(codeWithTodos, "payment.bal");
    
    io:println("Custom rule violations found:");
    foreach security_analyzer:Vulnerability issue in customScan.vulnerabilities {
        if issue.ruleId == "CUSTOM_001" {
            io:println(string `  Line ${issue.location.start.line}: ${issue.title}`);
        }
    }
    
    // Example 6: Compliance Checking
    io:println("\n\n=== Compliance Checking ===");
    
    security_analyzer:ComplianceConfig complianceConfig = {
        frameworks: ["OWASP", "PCI-DSS", "GDPR"],
        strictMode: true
    };
    
    security_analyzer:ComplianceResult compliance = analyzer.checkCompliance(
        scanResult, complianceConfig
    );
    
    io:println("Compliance Status:");
    foreach security_analyzer:ComplianceFramework framework in compliance.frameworks {
        io:println(string `\n  ${framework.name}:`);
        io:println(string `    Compliant: ${framework.compliant}`);
        io:println(string `    Score: ${framework.score}%`);
        
        if framework.violations.length() > 0 {
            io:println("    Violations:");
            foreach string violation in framework.violations {
                io:println(string `      - ${violation}`);
            }
        }
    }
    
    // Example 7: Security Metrics
    io:println("\n\n=== Security Metrics ===");
    
    security_analyzer:SecurityMetrics metrics = analyzer.calculateMetrics(scanResult);
    
    io:println("Security Metrics:");
    io:println(string `  Security Score: ${metrics.securityScore}/100`);
    io:println(string `  Risk Level: ${metrics.riskLevel}`);
    io:println(string `  Vulnerability Density: ${metrics.vulnerabilityDensity} per KLOC`);
    io:println(string `  Mean Time to Remediate: ${metrics.mttr} hours`);
    io:println(string `  Coverage: ${metrics.coverage}%`);
    
    io:println("\nTop Security Risks:");
    foreach int i in 0 ..< math:minimum(3, metrics.topRisks.length()) {
        security_analyzer:Risk risk = metrics.topRisks[i];
        io:println(string `  ${i + 1}. ${risk.title} (Impact: ${risk.impact}, Likelihood: ${risk.likelihood})`);
    }
}

// Mock database client for examples
final sql:Client dbClient = check new ("jdbc:h2:mem:testdb");

// Mock exec function for examples
function exec(string command) returns string {
    return "executed: " + command;
}

// Mock readFile function for examples
function readFile(string path) returns string {
    return "content of: " + path;
}

// Mock sanitize function for examples
function sanitize(string input) returns string {
    // Simple sanitization for demonstration
    return input.replace("'", "").replace(";", "").replace("--", "");
}