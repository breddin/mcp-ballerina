// Tool Executor Module
// Implements actual execution logic for Ballerina MCP tools

import ballerina/io;
import ballerina/log;
import ballerina/os;
import ballerina/regex;
import ballerina/file;
import mcp_ballerina.mcp_protocol as mcp;
import mcp_ballerina.language_server as ls;

// Tool executor configuration
public type ExecutorConfig record {|
    string ballerinaHome?;
    string javaHome?;
    int timeout = 30000;
    boolean enableCache = true;
    int cacheSize = 100;
    int cacheTtl = 60000;
|};

// Execution result
public type ExecutionResult record {|
    boolean success;
    json|string content;
    string? errorMessage = ();
    int? exitCode = ();
    int duration = 0;
|};

// Tool executor class
public class ToolExecutor {
    private final ExecutorConfig config;
    private final map<ExecutionResult> cache = {};
    private final ls:ProcessManager? lspManager;
    private final ls:LSPClient? lspClient;

    public function init(ExecutorConfig config = {}) {
        self.config = config;
        
        // Initialize LSP if available
        ls:ProcessManagerConfig lspConfig = {
            command: "bal",
            args: ["start-language-server", "--stdio"],
            autoRestart: true,
            healthCheckInterval: 30000
        };
        
        self.lspManager = trap new ls:ProcessManager(lspConfig);
        if self.lspManager is ls:ProcessManager {
            error? startResult = self.lspManager.start();
            if startResult is () {
                self.lspClient = trap new ls:LSPClient("stdio://lsp");
            }
        }
    }

    // Execute a tool with given arguments
    public function execute(string toolName, json arguments) returns ExecutionResult|error {
        // Check cache first if enabled
        if self.config.enableCache {
            string cacheKey = self.getCacheKey(toolName, arguments);
            if self.cache.hasKey(cacheKey) {
                return self.cache.get(cacheKey);
            }
        }

        // Route to appropriate handler
        ExecutionResult result;
        match toolName {
            "mcp__ballerina__syntax_check" => {
                result = check self.executeSyntaxCheck(arguments);
            }
            "mcp__ballerina__complete" => {
                result = check self.executeCompletion(arguments);
            }
            "mcp__ballerina__package_info" => {
                result = check self.executePackageInfo(arguments);
            }
            "mcp__ballerina__deploy_lambda" => {
                result = check self.executeLambdaDeploy(arguments);
            }
            "mcp__ballerina__project_new" => {
                result = check self.executeProjectNew(arguments);
            }
            "mcp__ballerina__project_build" => {
                result = check self.executeProjectBuild(arguments);
            }
            "mcp__ballerina__project_test" => {
                result = check self.executeProjectTest(arguments);
            }
            "mcp__ballerina__project_run" => {
                result = check self.executeProjectRun(arguments);
            }
            "mcp__ballerina__hover" => {
                result = check self.executeHover(arguments);
            }
            "mcp__ballerina__definition" => {
                result = check self.executeDefinition(arguments);
            }
            "mcp__ballerina__format" => {
                result = check self.executeFormat(arguments);
            }
            _ => {
                return error(string `Unknown tool: ${toolName}`);
            }
        }

        // Cache successful results
        if self.config.enableCache && result.success {
            string cacheKey = self.getCacheKey(toolName, arguments);
            self.cache[cacheKey] = result;
        }

        return result;
    }

    // Execute syntax check
    private function executeSyntaxCheck(json arguments) returns ExecutionResult|error {
        string code = check arguments.code;
        string? uri = arguments.uri is string ? <string>arguments.uri : ();

        if self.lspClient is ls:LSPClient {
            // Use LSP for syntax checking
            ls:TextDocumentItem document = {
                uri: uri ?: "file:///temp.bal",
                languageId: "ballerina",
                version: 1,
                text: code
            };

            check self.lspClient.didOpen({textDocument: document});
            
            // Wait for diagnostics
            ls:Diagnostic[] diagnostics = [];
            int attempts = 0;
            while attempts < 10 {
                diagnostics = self.lspClient.getDiagnostics(document.uri);
                if diagnostics.length() > 0 || attempts > 5 {
                    break;
                }
                runtime:sleep(0.1);
                attempts += 1;
            }

            return {
                success: diagnostics.length() == 0,
                content: diagnostics.toJson(),
                errorMessage: diagnostics.length() > 0 ? "Code has syntax errors" : ()
            };
        }

        // Fallback to CLI
        string tempFile = check self.writeTempFile(code, "bal");
        os:Process process = check os:exec({
            value: "bal",
            arguments: ["build", "--compile-only", tempFile]
        }, (), self.getEnvironment());

        int exitCode = check process.waitForExit();
        byte[] output = check process.output(os:STDERR);

        check file:remove(tempFile);

        return {
            success: exitCode == 0,
            content: check string:fromBytes(output),
            exitCode: exitCode
        };
    }

    // Execute code completion
    private function executeCompletion(json arguments) returns ExecutionResult|error {
        string code = check arguments.code;
        json position = check arguments.position;
        int line = check position.line;
        int character = check position.character;

        if self.lspClient is ls:LSPClient {
            ls:TextDocumentItem document = {
                uri: "file:///temp.bal",
                languageId: "ballerina",
                version: 1,
                text: code
            };

            check self.lspClient.didOpen({textDocument: document});

            ls:CompletionParams params = {
                textDocument: {uri: document.uri},
                position: {line: line, character: character}
            };

            ls:CompletionList|ls:CompletionItem[] completions = check self.lspClient.completion(params);
            
            return {
                success: true,
                content: completions.toJson()
            };
        }

        return {
            success: false,
            content: "LSP not available",
            errorMessage: "Language Server Protocol is not available for completion"
        };
    }

    // Execute package info retrieval
    private function executePackageInfo(json arguments) returns ExecutionResult|error {
        string packageName = check arguments.packageName;
        
        // Execute bal search command
        os:Process process = check os:exec({
            value: "bal",
            arguments: ["search", packageName, "--json"]
        }, (), self.getEnvironment());

        int exitCode = check process.waitForExit();
        byte[] output = check process.output(os:STDOUT);
        string outputStr = check string:fromBytes(output);

        if exitCode == 0 {
            json packageInfo = check outputStr.fromJsonString();
            return {
                success: true,
                content: packageInfo
            };
        }

        return {
            success: false,
            content: outputStr,
            exitCode: exitCode,
            errorMessage: "Failed to retrieve package information"
        };
    }

    // Execute Lambda deployment configuration
    private function executeLambdaDeploy(json arguments) returns ExecutionResult|error {
        string serviceName = check arguments.serviceName;
        string runtime = arguments.runtime is string ? <string>arguments.runtime : "java21";

        // Generate Lambda deployment configuration
        json deployConfig = {
            "service": serviceName,
            "runtime": runtime,
            "handler": string `${serviceName}.handler`,
            "memorySize": 512,
            "timeout": 30,
            "environment": {
                "JAVA_TOOL_OPTIONS": "-XX:+TieredCompilation -XX:TieredStopAtLevel=1"
            },
            "build": {
                "commands": [
                    "bal build --cloud=aws_lambda",
                    "zip -r function.zip target/bin/"
                ]
            },
            "cloudFormation": {
                "AWSTemplateFormatVersion": "2010-09-09",
                "Resources": {
                    "BallerinaLambdaFunction": {
                        "Type": "AWS::Lambda::Function",
                        "Properties": {
                            "FunctionName": serviceName,
                            "Runtime": runtime,
                            "Handler": string `${serviceName}.handler`,
                            "Code": {
                                "ZipFile": "function.zip"
                            },
                            "MemorySize": 512,
                            "Timeout": 30
                        }
                    }
                }
            }
        };

        return {
            success: true,
            content: deployConfig
        };
    }

    // Execute project creation
    private function executeProjectNew(json arguments) returns ExecutionResult|error {
        string projectName = check arguments.projectName;
        string projectType = arguments.projectType is string ? <string>arguments.projectType : "service";
        string? template = arguments.template is string ? <string>arguments.template : ();

        string[] args = ["new", projectName, "--type", projectType];
        if template is string {
            args.push("--template", template);
        }

        os:Process process = check os:exec({
            value: "bal",
            arguments: args
        }, (), self.getEnvironment());

        int exitCode = check process.waitForExit();
        byte[] output = check process.output(os:STDOUT);
        
        if exitCode == 0 {
            // List created files
            string projectPath = projectName;
            string[] files = [];
            file:MetaData[] entries = check file:readDir(projectPath);
            foreach file:MetaData entry in entries {
                files.push(entry.absPath);
            }

            return {
                success: true,
                content: {
                    "message": check string:fromBytes(output),
                    "projectPath": projectPath,
                    "files": files
                }
            };
        }

        return {
            success: false,
            content: check string:fromBytes(output),
            exitCode: exitCode,
            errorMessage: "Failed to create project"
        };
    }

    // Execute project build
    private function executeProjectBuild(json arguments) returns ExecutionResult|error {
        string projectPath = arguments.projectPath is string ? <string>arguments.projectPath : ".";
        boolean offline = arguments.offline is boolean ? <boolean>arguments.offline : false;
        boolean skipTests = arguments.skipTests is boolean ? <boolean>arguments.skipTests : false;
        boolean codeCoverage = arguments.codeCoverage is boolean ? <boolean>arguments.codeCoverage : false;

        string[] args = ["build"];
        if offline {
            args.push("--offline");
        }
        if skipTests {
            args.push("--skip-tests");
        }
        if codeCoverage {
            args.push("--code-coverage");
        }

        os:Process process = check os:exec({
            value: "bal",
            arguments: args
        }, projectPath, self.getEnvironment());

        int exitCode = check process.waitForExit();
        byte[] output = check process.output(os:STDOUT);
        byte[] errorOutput = check process.output(os:STDERR);

        string outputStr = check string:fromBytes(output);
        string errorStr = check string:fromBytes(errorOutput);

        if exitCode == 0 {
            // Find build artifacts
            string targetPath = file:joinPath(projectPath, "target");
            string[] artifacts = [];
            if check file:test(targetPath, file:EXISTS) {
                file:MetaData[] entries = check file:readDir(targetPath);
                foreach file:MetaData entry in entries {
                    if entry.absPath.endsWith(".jar") || entry.absPath.endsWith(".bala") {
                        artifacts.push(entry.absPath);
                    }
                }
            }

            return {
                success: true,
                content: {
                    "output": outputStr,
                    "artifacts": artifacts,
                    "codeCoverage": codeCoverage ? self.readCoverageReport(projectPath) : ()
                }
            };
        }

        return {
            success: false,
            content: outputStr + "\n" + errorStr,
            exitCode: exitCode,
            errorMessage: "Build failed"
        };
    }

    // Execute project tests
    private function executeProjectTest(json arguments) returns ExecutionResult|error {
        string projectPath = arguments.projectPath is string ? <string>arguments.projectPath : ".";
        boolean coverage = arguments.coverage is boolean ? <boolean>arguments.coverage : false;
        string? groups = arguments.groups is string ? <string>arguments.groups : ();
        string? tests = arguments.tests is string ? <string>arguments.tests : ();

        string[] args = ["test"];
        if coverage {
            args.push("--code-coverage");
        }
        if groups is string {
            args.push("--groups", groups);
        }
        if tests is string {
            args.push("--tests", tests);
        }

        os:Process process = check os:exec({
            value: "bal",
            arguments: args
        }, projectPath, self.getEnvironment());

        int exitCode = check process.waitForExit();
        byte[] output = check process.output(os:STDOUT);
        
        string outputStr = check string:fromBytes(output);
        
        // Parse test results
        json testResults = {
            "output": outputStr,
            "success": exitCode == 0,
            "coverage": coverage ? self.readCoverageReport(projectPath) : ()
        };

        return {
            success: exitCode == 0,
            content: testResults,
            exitCode: exitCode
        };
    }

    // Execute project run
    private function executeProjectRun(json arguments) returns ExecutionResult|error {
        string projectPath = arguments.projectPath is string ? <string>arguments.projectPath : ".";
        json programArgs = arguments.arguments ?: [];

        string[] args = ["run"];
        if programArgs is json[] {
            foreach json arg in <json[]>programArgs {
                args.push(arg.toString());
            }
        }

        os:Process process = check os:exec({
            value: "bal",
            arguments: args
        }, projectPath, self.getEnvironment());

        // For run command, we might want to capture output for a limited time
        byte[] output = [];
        byte[] errorOutput = [];
        
        // Read output for up to 5 seconds
        int elapsed = 0;
        while elapsed < 5000 {
            byte[]? stdout = process.output(os:STDOUT);
            byte[]? stderr = process.output(os:STDERR);
            
            if stdout is byte[] {
                output = [...output, ...stdout];
            }
            if stderr is byte[] {
                errorOutput = [...errorOutput, ...stderr];
            }
            
            runtime:sleep(0.1);
            elapsed += 100;
        }

        // Terminate process if still running
        _ = process.exit();

        return {
            success: true,
            content: {
                "output": check string:fromBytes(output),
                "error": check string:fromBytes(errorOutput)
            }
        };
    }

    // Execute hover information
    private function executeHover(json arguments) returns ExecutionResult|error {
        if self.lspClient is ls:LSPClient {
            string uri = check arguments.uri;
            json position = check arguments.position;
            
            ls:HoverParams params = {
                textDocument: {uri: uri},
                position: {
                    line: check position.line,
                    character: check position.character
                }
            };

            ls:Hover? hover = check self.lspClient.hover(params);
            
            return {
                success: true,
                content: hover?.toJson() ?: null
            };
        }

        return {
            success: false,
            content: "LSP not available",
            errorMessage: "Language Server Protocol is not available for hover"
        };
    }

    // Execute go to definition
    private function executeDefinition(json arguments) returns ExecutionResult|error {
        if self.lspClient is ls:LSPClient {
            string uri = check arguments.uri;
            json position = check arguments.position;
            
            ls:DefinitionParams params = {
                textDocument: {uri: uri},
                position: {
                    line: check position.line,
                    character: check position.character
                }
            };

            ls:Location|ls:Location[]? definition = check self.lspClient.definition(params);
            
            return {
                success: true,
                content: definition?.toJson() ?: null
            };
        }

        return {
            success: false,
            content: "LSP not available",
            errorMessage: "Language Server Protocol is not available for definition"
        };
    }

    // Execute code formatting
    private function executeFormat(json arguments) returns ExecutionResult|error {
        string code = check arguments.code;
        string? filePath = arguments.filePath is string ? <string>arguments.filePath : ();

        if filePath is string {
            // Format existing file
            os:Process process = check os:exec({
                value: "bal",
                arguments: ["format", filePath]
            }, (), self.getEnvironment());

            int exitCode = check process.waitForExit();
            
            if exitCode == 0 {
                string formattedCode = check io:fileReadString(filePath);
                return {
                    success: true,
                    content: formattedCode
                };
            }
        } else {
            // Format code snippet
            string tempFile = check self.writeTempFile(code, "bal");
            
            os:Process process = check os:exec({
                value: "bal",
                arguments: ["format", tempFile]
            }, (), self.getEnvironment());

            int exitCode = check process.waitForExit();
            
            if exitCode == 0 {
                string formattedCode = check io:fileReadString(tempFile);
                check file:remove(tempFile);
                return {
                    success: true,
                    content: formattedCode
                };
            }
            
            check file:remove(tempFile);
        }

        return {
            success: false,
            content: code,
            errorMessage: "Failed to format code"
        };
    }

    // Helper: Get environment variables
    private function getEnvironment() returns map<string> {
        map<string> env = os:environ();
        
        if self.config.ballerinaHome is string {
            env["BAL_HOME"] = <string>self.config.ballerinaHome;
        }
        if self.config.javaHome is string {
            env["JAVA_HOME"] = <string>self.config.javaHome;
        }
        
        return env;
    }

    // Helper: Write temporary file
    private function writeTempFile(string content, string extension) returns string|error {
        string tempDir = os:tmpDir();
        string fileName = string `temp_${uuid:createType1AsString()}.${extension}`;
        string filePath = file:joinPath(tempDir, fileName);
        
        check io:fileWriteString(filePath, content);
        return filePath;
    }

    // Helper: Read coverage report
    private function readCoverageReport(string projectPath) returns json? {
        string coveragePath = file:joinPath(projectPath, "target", "report", "coverage", "index.html");
        if check file:test(coveragePath, file:EXISTS) {
            // Parse coverage summary (simplified)
            return {
                "reportPath": coveragePath,
                "available": true
            };
        }
        return ();
    }

    // Helper: Generate cache key
    private function getCacheKey(string toolName, json arguments) returns string {
        return string `${toolName}:${arguments.toString()}`;
    }

    // Cleanup resources
    public function close() returns error? {
        if self.lspManager is ls:ProcessManager {
            check self.lspManager.stop();
        }
        if self.lspClient is ls:LSPClient {
            check self.lspClient.shutdown();
        }
    }
}