// Security Reporter for Ballerina
// Generates security analysis reports and remediation guidance

import ballerina/io;
import ballerina/time;
import ballerina/log;

// Report format types
public enum ReportFormat {
    HTML,
    JSON,
    MARKDOWN,
    SARIF,
    XML,
    PDF
}

// Report configuration
public type ReportConfig record {|
    ReportFormat format = MARKDOWN;
    boolean includeRemediation = true;
    boolean includeCodeSnippets = true;
    boolean includeMetrics = true;
    boolean includeCompliance = true;
    boolean groupByCategory = true;
    string? templatePath?;
    string? outputPath?;
|};

// Security report
public type SecurityReport record {|
    string title;
    string projectName;
    time:Utc generatedAt;
    SecurityIssue[] issues;
    SecurityMetrics metrics;
    ComplianceStatus? compliance?;
    string[] recommendations;
    ExecutiveSummary summary;
|};

// Executive summary
public type ExecutiveSummary record {|
    string overview;
    int totalIssues;
    int criticalIssues;
    decimal riskScore;
    string[] keyFindings;
    string[] priorityActions;
|};

// Compliance status
public type ComplianceStatus record {|
    map<boolean> standards;
    decimal complianceScore;
    string[] violations;
    string[] recommendations;
|};

// Compliance standard
public enum ComplianceStandard {
    OWASP_TOP_10,
    CWE_TOP_25,
    PCI_DSS,
    HIPAA,
    GDPR,
    SOC2,
    ISO_27001,
    NIST
}

// Security Reporter
public class SecurityReporter {
    private ReportConfig config;
    private map<string> templates = {};
    
    public function init(ReportConfig? config = ()) {
        self.config = config ?: {};
        self.loadTemplates();
    }
    
    // Load report templates
    private function loadTemplates() {
        // Load default templates
        self.templates["markdown"] = self.getMarkdownTemplate();
        self.templates["html"] = self.getHtmlTemplate();
        self.templates["sarif"] = self.getSarifTemplate();
        
        // Load custom template if provided
        if self.config.templatePath is string {
            // Load from file
        }
    }
    
    // Generate security report
    public function generateReport(ScanResult scanResult, VulnerabilityScanResult? vulnResult = ()) 
        returns SecurityReport|error {
        
        // Combine issues from different scans
        SecurityIssue[] allIssues = scanResult.issues;
        
        // Add vulnerability issues if provided
        if vulnResult is VulnerabilityScanResult {
            SecurityIssue[] vulnIssues = self.convertVulnerabilities(vulnResult.vulnerabilities);
            allIssues.push(...vulnIssues);
        }
        
        // Group and sort issues
        if self.config.groupByCategory {
            allIssues = self.groupIssuesByCategory(allIssues);
        } else {
            allIssues = self.sortIssuesBySeverity(allIssues);
        }
        
        // Calculate metrics
        SecurityMetrics metrics = self.calculateCombinedMetrics(scanResult, vulnResult);
        
        // Check compliance
        ComplianceStatus? compliance = ();
        if self.config.includeCompliance {
            compliance = self.checkCompliance(allIssues);
        }
        
        // Generate recommendations
        string[] recommendations = self.generateRecommendations(allIssues, metrics);
        
        // Create executive summary
        ExecutiveSummary summary = self.createExecutiveSummary(allIssues, metrics);
        
        return {
            title: "Security Analysis Report",
            projectName: "Ballerina Project",
            generatedAt: time:utcNow(),
            issues: allIssues,
            metrics: metrics,
            compliance: compliance,
            recommendations: recommendations,
            summary: summary
        };
    }
    
    // Export report to file
    public function exportReport(SecurityReport report) returns error? {
        string content;
        
        match self.config.format {
            HTML => {
                content = self.generateHtmlReport(report);
            }
            JSON => {
                content = report.toJsonString();
            }
            MARKDOWN => {
                content = self.generateMarkdownReport(report);
            }
            SARIF => {
                content = self.generateSarifReport(report);
            }
            XML => {
                content = self.generateXmlReport(report);
            }
            PDF => {
                // Generate PDF (would require external library)
                content = self.generateMarkdownReport(report);
            }
        }
        
        // Write to file
        if self.config.outputPath is string {
            check io:fileWriteString(<string>self.config.outputPath, content);
            log:printInfo("Report exported to: " + <string>self.config.outputPath);
        } else {
            // Write to stdout
            io:println(content);
        }
        
        return;
    }
    
    // Generate Markdown report
    private function generateMarkdownReport(SecurityReport report) returns string {
        string md = "# " + report.title + "\n\n";
        md += "**Project:** " + report.projectName + "\n";
        md += "**Generated:** " + report.generatedAt.toString() + "\n\n";
        
        // Executive Summary
        md += "## Executive Summary\n\n";
        md += report.summary.overview + "\n\n";
        md += "### Key Findings\n\n";
        foreach string finding in report.summary.keyFindings {
            md += "- " + finding + "\n";
        }
        md += "\n";
        
        // Metrics
        if self.config.includeMetrics {
            md += "## Security Metrics\n\n";
            md += self.generateMetricsTable(report.metrics);
            md += "\n";
        }
        
        // Compliance
        if self.config.includeCompliance && report.compliance is ComplianceStatus {
            md += "## Compliance Status\n\n";
            md += self.generateComplianceSection(<ComplianceStatus>report.compliance);
            md += "\n";
        }
        
        // Issues by severity
        md += "## Security Issues\n\n";
        
        // Group issues by severity
        map<SecurityIssue[]> issuesBySeverity = self.groupBySeverity(report.issues);
        
        foreach Severity severity in [CRITICAL, HIGH, MEDIUM, LOW, INFO] {
            string sevStr = severity.toString();
            if issuesBySeverity.hasKey(sevStr) {
                SecurityIssue[] sevIssues = issuesBySeverity[sevStr];
                md += "### " + sevStr + " (" + sevIssues.length().toString() + ")\n\n";
                
                foreach SecurityIssue issue in sevIssues {
                    md += self.generateIssueMarkdown(issue);
                }
            }
        }
        
        // Recommendations
        md += "## Recommendations\n\n";
        foreach string rec in report.recommendations {
            md += "- " + rec + "\n";
        }
        md += "\n";
        
        // Priority Actions
        md += "## Priority Actions\n\n";
        foreach string action in report.summary.priorityActions {
            md += "1. " + action + "\n";
        }
        
        return md;
    }
    
    // Generate issue markdown
    private function generateIssueMarkdown(SecurityIssue issue) returns string {
        string md = "#### " + issue.title + "\n\n";
        md += "**ID:** " + issue.id + "\n";
        md += "**Category:** " + issue.category.toString() + "\n";
        md += "**File:** `" + issue.filePath + "`\n";
        md += "**Location:** Line " + issue.location.start.line.toString() + "\n\n";
        md += issue.description + "\n\n";
        
        if issue.cweId is string {
            md += "**CWE:** " + <string>issue.cweId + "\n";
        }
        
        if self.config.includeRemediation && issue.remediation is SecurityRemediation {
            SecurityRemediation rem = <SecurityRemediation>issue.remediation;
            md += "**Remediation:**\n";
            md += rem.description + "\n\n";
            
            if rem.codeExample is string && self.config.includeCodeSnippets {
                md += "```ballerina\n";
                md += <string>rem.codeExample + "\n";
                md += "```\n\n";
            }
            
            if rem.steps is string[] {
                md += "**Steps:**\n";
                foreach string step in <string[]>rem.steps {
                    md += "- " + step + "\n";
                }
                md += "\n";
            }
        }
        
        return md;
    }
    
    // Generate HTML report
    private function generateHtmlReport(SecurityReport report) returns string {
        string html = "<!DOCTYPE html>\n<html>\n<head>\n";
        html += "<title>" + report.title + "</title>\n";
        html += self.getHtmlStyles();
        html += "</head>\n<body>\n";
        
        html += "<div class='container'>\n";
        html += "<h1>" + report.title + "</h1>\n";
        html += "<div class='metadata'>\n";
        html += "<p><strong>Project:</strong> " + report.projectName + "</p>\n";
        html += "<p><strong>Generated:</strong> " + report.generatedAt.toString() + "</p>\n";
        html += "</div>\n";
        
        // Executive Summary
        html += "<section class='summary'>\n";
        html += "<h2>Executive Summary</h2>\n";
        html += "<p>" + report.summary.overview + "</p>\n";
        html += "<div class='metrics-grid'>\n";
        html += self.generateHtmlMetricsCards(report.metrics);
        html += "</div>\n";
        html += "</section>\n";
        
        // Issues
        html += "<section class='issues'>\n";
        html += "<h2>Security Issues</h2>\n";
        html += self.generateHtmlIssuesTable(report.issues);
        html += "</section>\n";
        
        // Recommendations
        html += "<section class='recommendations'>\n";
        html += "<h2>Recommendations</h2>\n";
        html += "<ul>\n";
        foreach string rec in report.recommendations {
            html += "<li>" + rec + "</li>\n";
        }
        html += "</ul>\n";
        html += "</section>\n";
        
        html += "</div>\n";
        html += "</body>\n</html>";
        
        return html;
    }
    
    // Generate SARIF report
    private function generateSarifReport(SecurityReport report) returns string {
        // SARIF (Static Analysis Results Interchange Format)
        json sarif = {
            "$schema": "https://json.schemastore.org/sarif-2.1.0.json",
            "version": "2.1.0",
            "runs": [{
                "tool": {
                    "driver": {
                        "name": "Ballerina Security Analyzer",
                        "version": "1.0.0",
                        "rules": self.generateSarifRules(report.issues)
                    }
                },
                "results": self.generateSarifResults(report.issues)
            }]
        };
        
        return sarif.toJsonString();
    }
    
    // Generate XML report
    private function generateXmlReport(SecurityReport report) returns string {
        string xml = "<?xml version='1.0' encoding='UTF-8'?>\n";
        xml += "<SecurityReport>\n";
        xml += "  <Title>" + report.title + "</Title>\n";
        xml += "  <Project>" + report.projectName + "</Project>\n";
        xml += "  <GeneratedAt>" + report.generatedAt.toString() + "</GeneratedAt>\n";
        
        xml += "  <Summary>\n";
        xml += "    <TotalIssues>" + report.summary.totalIssues.toString() + "</TotalIssues>\n";
        xml += "    <CriticalIssues>" + report.summary.criticalIssues.toString() + "</CriticalIssues>\n";
        xml += "    <RiskScore>" + report.summary.riskScore.toString() + "</RiskScore>\n";
        xml += "  </Summary>\n";
        
        xml += "  <Issues>\n";
        foreach SecurityIssue issue in report.issues {
            xml += self.generateXmlIssue(issue);
        }
        xml += "  </Issues>\n";
        
        xml += "</SecurityReport>";
        
        return xml;
    }
    
    // Helper functions
    private function convertVulnerabilities(Vulnerability[] vulnerabilities) 
        returns SecurityIssue[] {
        
        SecurityIssue[] issues = [];
        
        foreach Vulnerability vuln in vulnerabilities {
            issues.push({
                id: vuln.id,
                title: vuln.title,
                description: vuln.description,
                severity: vuln.severity,
                category: DEPENDENCIES,
                location: {
                    start: {line: 0, column: 0},
                    end: {line: 0, column: 0}
                },
                filePath: "Ballerina.toml",
                cveId: vuln.id,
                remediation: {
                    description: "Update to version " + (vuln.fixedVersion ?: "latest"),
                    references: vuln.references
                }
            });
        }
        
        return issues;
    }
    
    private function groupIssuesByCategory(SecurityIssue[] issues) returns SecurityIssue[] {
        map<SecurityIssue[]> grouped = {};
        
        foreach SecurityIssue issue in issues {
            string cat = issue.category.toString();
            if !grouped.hasKey(cat) {
                grouped[cat] = [];
            }
            grouped[cat].push(issue);
        }
        
        SecurityIssue[] result = [];
        foreach SecurityIssue[] catIssues in grouped {
            result.push(...self.sortIssuesBySeverity(catIssues));
        }
        
        return result;
    }
    
    private function sortIssuesBySeverity(SecurityIssue[] issues) returns SecurityIssue[] {
        // Sort by severity (Critical -> Info)
        return issues.sort(function(SecurityIssue a, SecurityIssue b) returns int {
            return self.compareSeverity(b.severity, a.severity);
        });
    }
    
    private function groupBySeverity(SecurityIssue[] issues) returns map<SecurityIssue[]> {
        map<SecurityIssue[]> grouped = {};
        
        foreach SecurityIssue issue in issues {
            string sev = issue.severity.toString();
            if !grouped.hasKey(sev) {
                grouped[sev] = [];
            }
            grouped[sev].push(issue);
        }
        
        return grouped;
    }
    
    private function compareSeverity(Severity s1, Severity s2) returns int {
        int[] severityValues = [5, 4, 3, 2, 1]; // CRITICAL to INFO
        int v1 = severityValues[<int>s1];
        int v2 = severityValues[<int>s2];
        return v1 - v2;
    }
    
    private function calculateCombinedMetrics(ScanResult scanResult, 
                                             VulnerabilityScanResult? vulnResult) 
        returns SecurityMetrics {
        
        SecurityMetrics metrics = scanResult.metrics;
        
        if vulnResult is VulnerabilityScanResult {
            // Combine vulnerability metrics
            metrics.totalIssues += vulnResult.metrics.totalVulnerabilities;
            metrics.criticalCount += vulnResult.metrics.criticalCount;
            metrics.highCount += vulnResult.metrics.highCount;
            metrics.mediumCount += vulnResult.metrics.mediumCount;
            metrics.lowCount += vulnResult.metrics.lowCount;
            
            // Recalculate risk score
            metrics.riskScore = <decimal>(
                metrics.criticalCount * 10 + 
                metrics.highCount * 7 + 
                metrics.mediumCount * 4 + 
                metrics.lowCount * 1
            );
        }
        
        return metrics;
    }
    
    private function checkCompliance(SecurityIssue[] issues) returns ComplianceStatus {
        map<boolean> standards = {};
        string[] violations = [];
        
        // Check OWASP Top 10
        standards["OWASP_TOP_10"] = self.checkOwaspCompliance(issues, violations);
        
        // Check CWE Top 25
        standards["CWE_TOP_25"] = self.checkCweCompliance(issues, violations);
        
        // Calculate compliance score
        int compliant = 0;
        int total = 0;
        foreach boolean isCompliant in standards {
            total += 1;
            if isCompliant {
                compliant += 1;
            }
        }
        
        decimal complianceScore = total > 0 ? <decimal>compliant / <decimal>total * 100 : 0.0;
        
        return {
            standards: standards,
            complianceScore: complianceScore,
            violations: violations,
            recommendations: self.getComplianceRecommendations(violations)
        };
    }
    
    private function checkOwaspCompliance(SecurityIssue[] issues, string[] violations) 
        returns boolean {
        
        // Check for OWASP Top 10 violations
        foreach SecurityIssue issue in issues {
            if issue.severity == CRITICAL || issue.severity == HIGH {
                if issue.category == INJECTION {
                    violations.push("OWASP A03: Injection vulnerability found");
                } else if issue.category == AUTHENTICATION {
                    violations.push("OWASP A07: Authentication failure found");
                }
            }
        }
        
        return violations.length() == 0;
    }
    
    private function checkCweCompliance(SecurityIssue[] issues, string[] violations) 
        returns boolean {
        
        // Check for CWE Top 25 violations
        string[] cweTop25 = ["CWE-79", "CWE-89", "CWE-20", "CWE-125", "CWE-119"];
        
        foreach SecurityIssue issue in issues {
            if issue.cweId is string {
                string cwe = <string>issue.cweId;
                if cweTop25.indexOf(cwe) != () {
                    violations.push("CWE Top 25: " + cwe + " violation found");
                }
            }
        }
        
        return violations.length() == 0;
    }
    
    private function getComplianceRecommendations(string[] violations) returns string[] {
        string[] recommendations = [];
        
        foreach string violation in violations {
            if violation.includes("Injection") {
                recommendations.push("Implement input validation and parameterized queries");
            } else if violation.includes("Authentication") {
                recommendations.push("Strengthen authentication mechanisms and implement MFA");
            }
        }
        
        return recommendations;
    }
    
    private function generateRecommendations(SecurityIssue[] issues, SecurityMetrics metrics) 
        returns string[] {
        
        string[] recommendations = [];
        
        if metrics.criticalCount > 0 {
            recommendations.push("Address all critical security issues immediately");
        }
        
        if metrics.highCount > 5 {
            recommendations.push("Prioritize fixing high-severity issues within this sprint");
        }
        
        // Category-specific recommendations
        map<int> categoryCount = metrics.categoryCount;
        if categoryCount["INJECTION"] > 0 {
            recommendations.push("Implement comprehensive input validation across all endpoints");
        }
        
        if categoryCount["CRYPTOGRAPHY"] > 0 {
            recommendations.push("Review and update cryptographic implementations");
        }
        
        if categoryCount["DEPENDENCIES"] > 0 {
            recommendations.push("Update vulnerable dependencies to latest secure versions");
        }
        
        return recommendations;
    }
    
    private function createExecutiveSummary(SecurityIssue[] issues, SecurityMetrics metrics) 
        returns ExecutiveSummary {
        
        string overview = "Security analysis identified " + metrics.totalIssues.toString() + 
                         " issues across the codebase. ";
        
        if metrics.criticalCount > 0 {
            overview += "URGENT: " + metrics.criticalCount.toString() + 
                       " critical issues require immediate attention.";
        } else if metrics.highCount > 0 {
            overview += metrics.highCount.toString() + 
                       " high-severity issues should be prioritized.";
        } else {
            overview += "No critical or high-severity issues found.";
        }
        
        string[] keyFindings = [];
        if metrics.criticalCount > 0 {
            keyFindings.push(metrics.criticalCount.toString() + " critical security vulnerabilities");
        }
        if metrics.categoryCount["INJECTION"] > 0 {
            keyFindings.push("Injection vulnerabilities detected");
        }
        if metrics.categoryCount["DEPENDENCIES"] > 0 {
            keyFindings.push("Vulnerable dependencies identified");
        }
        
        string[] priorityActions = [];
        if metrics.criticalCount > 0 {
            priorityActions.push("Fix all critical vulnerabilities immediately");
        }
        if metrics.highCount > 0 {
            priorityActions.push("Address high-severity issues within 7 days");
        }
        priorityActions.push("Implement security testing in CI/CD pipeline");
        priorityActions.push("Schedule security training for development team");
        
        return {
            overview: overview,
            totalIssues: metrics.totalIssues,
            criticalIssues: metrics.criticalCount,
            riskScore: metrics.riskScore,
            keyFindings: keyFindings,
            priorityActions: priorityActions
        };
    }
    
    // Template helper functions
    private function getMarkdownTemplate() returns string {
        return "";
    }
    
    private function getHtmlTemplate() returns string {
        return "";
    }
    
    private function getSarifTemplate() returns string {
        return "";
    }
    
    private function getHtmlStyles() returns string {
        return "<style>\n" +
               "body { font-family: Arial, sans-serif; margin: 20px; }\n" +
               ".container { max-width: 1200px; margin: 0 auto; }\n" +
               ".summary { background: #f5f5f5; padding: 20px; border-radius: 5px; }\n" +
               ".metrics-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 15px; }\n" +
               ".metric-card { background: white; padding: 15px; border-radius: 5px; }\n" +
               ".critical { color: #d32f2f; }\n" +
               ".high { color: #f57c00; }\n" +
               ".medium { color: #fbc02d; }\n" +
               ".low { color: #388e3c; }\n" +
               "table { width: 100%; border-collapse: collapse; }\n" +
               "th, td { padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }\n" +
               "</style>\n";
    }
    
    private function generateMetricsTable(SecurityMetrics metrics) returns string {
        string table = "| Metric | Value |\n";
        table += "|--------|-------|\n";
        table += "| Total Issues | " + metrics.totalIssues.toString() + " |\n";
        table += "| Critical | " + metrics.criticalCount.toString() + " |\n";
        table += "| High | " + metrics.highCount.toString() + " |\n";
        table += "| Medium | " + metrics.mediumCount.toString() + " |\n";
        table += "| Low | " + metrics.lowCount.toString() + " |\n";
        table += "| Risk Score | " + metrics.riskScore.toString() + " |\n";
        return table;
    }
    
    private function generateComplianceSection(ComplianceStatus compliance) returns string {
        string section = "**Compliance Score:** " + compliance.complianceScore.toString() + "%\n\n";
        
        section += "### Standards\n\n";
        foreach [string, boolean] [standard, compliant] in compliance.standards.entries() {
            string status = compliant ? "✅ Compliant" : "❌ Non-compliant";
            section += "- " + standard + ": " + status + "\n";
        }
        
        if compliance.violations.length() > 0 {
            section += "\n### Violations\n\n";
            foreach string violation in compliance.violations {
                section += "- " + violation + "\n";
            }
        }
        
        return section;
    }
    
    private function generateHtmlMetricsCards(SecurityMetrics metrics) returns string {
        // Generate HTML metric cards
        return "";
    }
    
    private function generateHtmlIssuesTable(SecurityIssue[] issues) returns string {
        // Generate HTML issues table
        return "";
    }
    
    private function generateSarifRules(SecurityIssue[] issues) returns json[] {
        // Generate SARIF rules
        return [];
    }
    
    private function generateSarifResults(SecurityIssue[] issues) returns json[] {
        // Generate SARIF results
        return [];
    }
    
    private function generateXmlIssue(SecurityIssue issue) returns string {
        // Generate XML for single issue
        return "";
    }
}