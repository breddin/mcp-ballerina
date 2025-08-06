// Resource Content Loader Module
// Loads and manages MCP resource content from files and documentation

import ballerina/io;
import ballerina/file;
import ballerina/log;
import ballerina/http;
import ballerina/regex;
import mcp_ballerina.mcp_protocol as mcp;

// Resource loader configuration
public type LoaderConfig record {|
    string resourcePath = "./resources";
    boolean enableCache = true;
    int cacheSize = 50;
    boolean autoReload = false;
    int reloadInterval = 60000;
|};

// Resource content
public type ResourceContent record {|
    string uri;
    string mimeType;
    string|byte[] contents;
    json? metadata = ();
|};

// Resource loader class
public class ResourceLoader {
    private final LoaderConfig config;
    private final map<ResourceContent> cache = {};
    private final map<mcp:Resource> registry = {};
    
    public function init(LoaderConfig config = {}) {
        self.config = config;
        
        // Initialize resource directory if it doesn't exist
        error? mkdirResult = file:createDir(self.config.resourcePath, file:RECURSIVE);
        
        // Load initial resources
        error? loadResult = self.loadResources();
        if loadResult is error {
            log:printWarn("Failed to load initial resources", 'error = loadResult);
        }
        
        // Start auto-reload if enabled
        if self.config.autoReload {
            _ = start self.startAutoReload();
        }
    }

    // Register a resource
    public function registerResource(mcp:Resource 'resource) {
        self.registry['resource.uri] = 'resource;
        log:printInfo(string `Registered resource: ${'resource.uri}`);
    }

    // Get all registered resources
    public function getResources() returns mcp:Resource[] {
        return self.registry.toArray();
    }

    // Read resource content
    public function readResource(string uri) returns ResourceContent|error {
        // Check cache first
        if self.config.enableCache && self.cache.hasKey(uri) {
            return self.cache.get(uri);
        }

        // Find resource in registry
        mcp:Resource? 'resource = self.registry[uri];
        if 'resource is () {
            return error(string `Resource not found: ${uri}`);
        }

        // Load content based on URI scheme
        ResourceContent content;
        if uri.startsWith("ballerina://docs/") {
            content = check self.loadDocumentationResource(uri, 'resource);
        } else if uri.startsWith("ballerina://examples/") {
            content = check self.loadExampleResource(uri, 'resource);
        } else if uri.startsWith("ballerina://templates/") {
            content = check self.loadTemplateResource(uri, 'resource);
        } else if uri.startsWith("file://") {
            content = check self.loadFileResource(uri, 'resource);
        } else {
            content = check self.loadDefaultResource(uri, 'resource);
        }

        // Cache the content
        if self.config.enableCache {
            self.cache[uri] = content;
        }

        return content;
    }

    // Load documentation resources
    private function loadDocumentationResource(string uri, mcp:Resource 'resource) returns ResourceContent|error {
        string docType = self.extractResourceType(uri, "docs");
        
        string content = "";
        json metadata = {};
        
        match docType {
            "stdlib" => {
                content = check self.loadStdlibDocumentation();
                metadata = {
                    type: "stdlib",
                    modules: self.getStdlibModules()
                };
            }
            "lang-ref" => {
                content = check self.loadLanguageReference();
                metadata = {
                    type: "language-reference",
                    version: "2201.x"
                };
            }
            "lambda-optimization" => {
                content = check self.loadLambdaOptimizationGuide();
                metadata = {
                    type: "optimization-guide",
                    platform: "AWS Lambda"
                };
            }
            _ => {
                string filePath = file:joinPath(self.config.resourcePath, "docs", docType + ".md");
                if check file:test(filePath, file:EXISTS) {
                    content = check io:fileReadString(filePath);
                } else {
                    content = self.generateDefaultDocumentation(docType);
                }
            }
        }

        return {
            uri: uri,
            mimeType: 'resource.mimeType ?: "text/markdown",
            contents: content,
            metadata: metadata
        };
    }

    // Load example resources
    private function loadExampleResource(string uri, mcp:Resource 'resource) returns ResourceContent|error {
        string exampleType = self.extractResourceType(uri, "examples");
        
        string content = "";
        json metadata = {};
        
        match exampleType {
            "cloud-patterns" => {
                content = check self.loadCloudPatterns();
                metadata = {
                    type: "examples",
                    category: "cloud-deployment",
                    patterns: ["serverless", "microservices", "event-driven"]
                };
            }
            _ => {
                string filePath = file:joinPath(self.config.resourcePath, "examples", exampleType + ".bal");
                if check file:test(filePath, file:EXISTS) {
                    content = check io:fileReadString(filePath);
                } else {
                    content = self.generateExampleCode(exampleType);
                }
            }
        }

        return {
            uri: uri,
            mimeType: 'resource.mimeType ?: "text/x-ballerina",
            contents: content,
            metadata: metadata
        };
    }

    // Load template resources
    private function loadTemplateResource(string uri, mcp:Resource 'resource) returns ResourceContent|error {
        string templateType = self.extractResourceType(uri, "templates");
        
        string filePath = file:joinPath(self.config.resourcePath, "templates", templateType + ".template");
        string content;
        
        if check file:test(filePath, file:EXISTS) {
            content = check io:fileReadString(filePath);
        } else {
            content = self.generateTemplate(templateType);
        }

        return {
            uri: uri,
            mimeType: 'resource.mimeType ?: "text/plain",
            contents: content,
            metadata: {
                type: "template",
                variables: self.extractTemplateVariables(content)
            }
        };
    }

    // Load file resources
    private function loadFileResource(string uri, mcp:Resource 'resource) returns ResourceContent|error {
        string filePath = uri.substring(7); // Remove "file://" prefix
        
        if !check file:test(filePath, file:EXISTS) {
            return error(string `File not found: ${filePath}`);
        }

        string|byte[] content;
        string mimeType = self.detectMimeType(filePath);
        
        if mimeType.startsWith("text/") {
            content = check io:fileReadString(filePath);
        } else {
            content = check io:fileReadBytes(filePath);
        }

        file:MetaData metadata = check file:getMetaData(filePath);
        
        return {
            uri: uri,
            mimeType: mimeType,
            contents: content,
            metadata: {
                size: metadata.size,
                modified: metadata.modifiedTime.toString(),
                permissions: metadata.readable
            }
        };
    }

    // Load default resource
    private function loadDefaultResource(string uri, mcp:Resource 'resource) returns ResourceContent|error {
        // Try to load from resource directory
        string fileName = self.uriToFileName(uri);
        string filePath = file:joinPath(self.config.resourcePath, fileName);
        
        if check file:test(filePath, file:EXISTS) {
            string content = check io:fileReadString(filePath);
            return {
                uri: uri,
                mimeType: 'resource.mimeType ?: "text/plain",
                contents: content
            };
        }

        // Generate placeholder content
        return {
            uri: uri,
            mimeType: 'resource.mimeType ?: "text/plain",
            contents: string `Resource content for ${uri} is not yet available.`,
            metadata: {
                placeholder: true
            }
        };
    }

    // Load standard library documentation
    private function loadStdlibDocumentation() returns string|error {
        string content = "# Ballerina Standard Library Reference\n\n";
        content += "## Core Modules\n\n";
        
        string[] modules = [
            "io - Input/output operations",
            "http - HTTP client and server",
            "grpc - gRPC client and server",
            "sql - Database connectivity",
            "file - File system operations",
            "time - Date and time handling",
            "log - Logging framework",
            "crypto - Cryptographic functions",
            "regex - Regular expressions",
            "task - Task scheduling"
        ];
        
        foreach string module in modules {
            content += string `- ${module}\n`;
        }
        
        content += "\n## Usage Example\n\n";
        content += "```ballerina\n";
        content += "import ballerina/io;\n";
        content += "import ballerina/http;\n\n";
        content += "public function main() {\n";
        content += "    io:println(\"Hello, World!\");\n";
        content += "}\n";
        content += "```\n";
        
        return content;
    }

    // Load language reference
    private function loadLanguageReference() returns string|error {
        string content = "# Ballerina Language Reference\n\n";
        content += "## Language Fundamentals\n\n";
        
        content += "### Data Types\n";
        content += "- **Simple Types**: int, float, decimal, string, boolean, byte\n";
        content += "- **Structured Types**: array, tuple, map, record, table\n";
        content += "- **Behavioral Types**: object, function, future, stream\n";
        content += "- **Other Types**: json, xml, anydata, any, never\n\n";
        
        content += "### Control Flow\n";
        content += "- if/else statements\n";
        content += "- while loops\n";
        content += "- foreach loops\n";
        content += "- match expressions\n";
        content += "- check expressions\n\n";
        
        content += "### Concurrency\n";
        content += "- worker threads\n";
        content += "- fork/join\n";
        content += "- async/await\n";
        content += "- transactions\n\n";
        
        return content;
    }

    // Load Lambda optimization guide
    private function loadLambdaOptimizationGuide() returns string|error {
        string content = "# AWS Lambda Optimization Guide for Ballerina\n\n";
        
        content += "## Best Practices\n\n";
        content += "### 1. Cold Start Optimization\n";
        content += "- Use GraalVM native image compilation\n";
        content += "- Minimize dependencies\n";
        content += "- Lazy initialization of resources\n\n";
        
        content += "### 2. Memory Configuration\n";
        content += "```ballerina\n";
        content += "@cloud:Function {\n";
        content += "    memorySize: 512,\n";
        content += "    timeout: 30\n";
        content += "}\n";
        content += "```\n\n";
        
        content += "### 3. Connection Pooling\n";
        content += "- Reuse HTTP clients\n";
        content += "- Cache database connections\n";
        content += "- Use connection pools for external services\n\n";
        
        content += "### 4. Logging and Monitoring\n";
        content += "- Use structured logging\n";
        content += "- Implement custom CloudWatch metrics\n";
        content += "- Enable X-Ray tracing\n\n";
        
        return content;
    }

    // Load cloud patterns
    private function loadCloudPatterns() returns string|error {
        string content = "# Ballerina Cloud Deployment Patterns\n\n";
        
        content += "## Serverless Function Pattern\n\n";
        content += "```ballerina\n";
        content += "import ballerinax/aws.lambda;\n\n";
        content += "@lambda:Function\n";
        content += "public function handler(lambda:Context ctx, json input) returns json|error {\n";
        content += "    return {\"message\": \"Hello from Ballerina Lambda!\"};\n";
        content += "}\n";
        content += "```\n\n";
        
        content += "## Microservice Pattern\n\n";
        content += "```ballerina\n";
        content += "import ballerina/http;\n\n";
        content += "service / on new http:Listener(8080) {\n";
        content += "    resource function get health() returns json {\n";
        content += "        return {\"status\": \"healthy\"};\n";
        content += "    }\n";
        content += "}\n";
        content += "```\n\n";
        
        content += "## Event-Driven Pattern\n\n";
        content += "```ballerina\n";
        content += "import ballerinax/aws.sqs;\n\n";
        content += "public function processMessage(sqs:Message message) returns error? {\n";
        content += "    // Process SQS message\n";
        content += "}\n";
        content += "```\n\n";
        
        return content;
    }

    // Generate default documentation
    private function generateDefaultDocumentation(string docType) returns string {
        return string `# ${docType} Documentation\n\nDocumentation for ${docType} is being prepared.\n\nPlease check back later or visit https://ballerina.io/learn/ for more information.`;
    }

    // Generate example code
    private function generateExampleCode(string exampleType) returns string {
        return string `// Example: ${exampleType}\n\nimport ballerina/io;\n\npublic function main() {\n    io:println("Example code for ${exampleType}");\n}`;
    }

    // Generate template
    private function generateTemplate(string templateType) returns string {
        return string `# Template: ${templateType}\n\n{{variable1}}\n\n{{variable2}}\n\n# End of template`;
    }

    // Extract resource type from URI
    private function extractResourceType(string uri, string prefix) returns string {
        string pattern = string `ballerina://${prefix}/(.+)`;
        string? matched = regex:find(uri, pattern);
        
        if matched is string {
            string[] parts = regex:split(matched, "/");
            if parts.length() > 2 {
                return parts[parts.length() - 1];
            }
        }
        
        return "unknown";
    }

    // Convert URI to file name
    private function uriToFileName(string uri) returns string {
        string fileName = uri;
        fileName = regex:replaceAll(fileName, "ballerina://", "");
        fileName = regex:replaceAll(fileName, "/", "_");
        return fileName + ".resource";
    }

    // Detect MIME type from file extension
    private function detectMimeType(string filePath) returns string {
        if filePath.endsWith(".bal") {
            return "text/x-ballerina";
        } else if filePath.endsWith(".toml") {
            return "text/toml";
        } else if filePath.endsWith(".json") {
            return "application/json";
        } else if filePath.endsWith(".xml") {
            return "application/xml";
        } else if filePath.endsWith(".md") {
            return "text/markdown";
        } else if filePath.endsWith(".html") {
            return "text/html";
        } else if filePath.endsWith(".yaml") || filePath.endsWith(".yml") {
            return "text/yaml";
        } else if filePath.endsWith(".jar") {
            return "application/java-archive";
        } else {
            return "text/plain";
        }
    }

    // Extract template variables
    private function extractTemplateVariables(string template) returns string[] {
        string[] variables = [];
        string pattern = "\\{\\{([^}]+)\\}\\}";
        string[] matches = regex:findAll(template, pattern);
        
        foreach string match in matches {
            string variable = regex:replaceAll(match, "[{}]", "");
            if !variables.indexOf(variable) is int {
                variables.push(variable);
            }
        }
        
        return variables;
    }

    // Get standard library modules
    private function getStdlibModules() returns string[] {
        return [
            "io", "http", "grpc", "graphql", "websocket", "tcp", "udp",
            "sql", "file", "time", "task", "cache", "crypto", "jwt",
            "oauth2", "log", "os", "random", "regex", "runtime", "test",
            "lang.array", "lang.decimal", "lang.error", "lang.float",
            "lang.function", "lang.future", "lang.int", "lang.map",
            "lang.object", "lang.stream", "lang.string", "lang.table",
            "lang.transaction", "lang.typedesc", "lang.value", "lang.xml"
        ];
    }

    // Load resources from directory
    private function loadResources() returns error? {
        string docsPath = file:joinPath(self.config.resourcePath, "docs");
        string examplesPath = file:joinPath(self.config.resourcePath, "examples");
        string templatesPath = file:joinPath(self.config.resourcePath, "templates");
        
        // Create directories if they don't exist
        _ = file:createDir(docsPath, file:RECURSIVE);
        _ = file:createDir(examplesPath, file:RECURSIVE);
        _ = file:createDir(templatesPath, file:RECURSIVE);
        
        // Load any existing resource files
        if check file:test(docsPath, file:EXISTS) {
            file:MetaData[] docs = check file:readDir(docsPath);
            foreach file:MetaData doc in docs {
                if doc.absPath.endsWith(".md") {
                    string name = file:basename(doc.absPath);
                    string uri = string `ballerina://docs/${name.substring(0, name.length() - 3)}`;
                    self.registerResource({
                        uri: uri,
                        name: name,
                        mimeType: "text/markdown"
                    });
                }
            }
        }
        
        log:printInfo(string `Loaded ${self.registry.length()} resources`);
    }

    // Start auto-reload task
    private function startAutoReload() returns error? {
        while true {
            runtime:sleep(<decimal>self.config.reloadInterval / 1000);
            
            error? reloadResult = self.loadResources();
            if reloadResult is error {
                log:printWarn("Failed to reload resources", 'error = reloadResult);
            }
            
            // Clear cache on reload
            self.cache.removeAll();
        }
    }
}