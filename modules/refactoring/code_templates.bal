// Code Generation Templates for Ballerina
// Provides template-based code generation for common patterns

import ballerina/io;
import ballerina/regex;

// Template types
public enum TemplateType {
    FUNCTION,
    CLASS,
    SERVICE,
    RECORD,
    TEST,
    MODULE,
    REST_ENDPOINT,
    GRPC_SERVICE,
    WEBSOCKET,
    DATABASE_QUERY,
    ERROR_HANDLER
}

// Template definition
public type CodeTemplate record {|
    string name;
    TemplateType type;
    string description;
    string template;
    TemplateVariable[] variables;
    string[] imports?;
    map<string> metadata?;
|};

// Template variable
public type TemplateVariable record {|
    string name;
    string type;
    string defaultValue?;
    string description?;
    boolean required = true;
    string[] validValues?;
|};

// Generation request
public type GenerationRequest record {|
    TemplateType templateType;
    string templateName?;
    map<string> variables;
    GenerationOptions options?;
|};

// Generation options
public type GenerationOptions record {|
    boolean includeImports = true;
    boolean includeDocumentation = true;
    boolean includeTests = false;
    string indentation = "    ";
|};

// Generation result
public type GenerationResult record {|
    boolean success;
    string generatedCode;
    string[] imports?;
    string testCode?;
    string[] errors?;
|};

// Code Template Manager
public class TemplateManager {
    private map<string> templates;
    private map<CodeTemplate> templateDefinitions;
    
    public function init() {
        self.templates = {};
        self.templateDefinitions = {};
        self.loadBuiltInTemplates();
    }
    
    // Load built-in templates
    private function loadBuiltInTemplates() {
        // Function template
        self.registerTemplate({
            name: "basic_function",
            type: FUNCTION,
            description: "Basic function template",
            template: string `# ${doc}
${visibility} function ${name}(${parameters}) ${returns} {
    ${body}
}`,
            variables: [
                {name: "name", type: "string", required: true},
                {name: "visibility", type: "string", defaultValue: "public"},
                {name: "parameters", type: "string", defaultValue: ""},
                {name: "returns", type: "string", defaultValue: ""},
                {name: "body", type: "string", defaultValue: "// TODO: Implement"},
                {name: "doc", type: "string", defaultValue: "Function description"}
            ]
        });
        
        // REST Service template
        self.registerTemplate({
            name: "rest_service",
            type: SERVICE,
            description: "REST API service template",
            template: string `import ballerina/http;

# ${serviceName} REST API Service
service /${basePath} on new http:Listener(${port}) {
    
    # Get ${resourceName}
    # + return - ${resourceName} data or error
    resource function get ${resourcePath}() returns ${returnType}|http:Error {
        // TODO: Implement GET logic
        return {message: "GET ${resourceName} not implemented"};
    }
    
    # Create ${resourceName}
    # + payload - ${resourceName} data
    # + return - Created response or error
    resource function post ${resourcePath}(@http:Payload ${payloadType} payload) 
        returns http:Created|http:Error {
        // TODO: Implement POST logic
        return <http:Created>{body: {message: "Created"}};
    }
    
    # Update ${resourceName}
    # + id - Resource ID
    # + payload - Updated data
    # + return - Updated response or error
    resource function put ${resourcePath}/[string id](@http:Payload ${payloadType} payload) 
        returns ${returnType}|http:Error {
        // TODO: Implement PUT logic
        return {message: "PUT ${resourceName} not implemented"};
    }
    
    # Delete ${resourceName}
    # + id - Resource ID
    # + return - Success response or error
    resource function delete ${resourcePath}/[string id]() 
        returns http:NoContent|http:Error {
        // TODO: Implement DELETE logic
        return <http:NoContent>{};
    }
}`,
            variables: [
                {name: "serviceName", type: "string", required: true},
                {name: "basePath", type: "string", defaultValue: "api/v1"},
                {name: "port", type: "string", defaultValue: "8080"},
                {name: "resourceName", type: "string", required: true},
                {name: "resourcePath", type: "string", required: true},
                {name: "returnType", type: "string", defaultValue: "json"},
                {name: "payloadType", type: "string", defaultValue: "json"}
            ],
            imports: ["ballerina/http"]
        });
        
        // Record type template
        self.registerTemplate({
            name: "record_type",
            type: RECORD,
            description: "Record type definition template",
            template: string `# ${description}
${visibility} type ${name} record {|
    ${fields}
|};`,
            variables: [
                {name: "name", type: "string", required: true},
                {name: "visibility", type: "string", defaultValue: "public"},
                {name: "description", type: "string", defaultValue: "Record type description"},
                {name: "fields", type: "string", required: true}
            ]
        });
        
        // Class template
        self.registerTemplate({
            name: "basic_class",
            type: CLASS,
            description: "Basic class template",
            template: string `# ${description}
${visibility} class ${className} {
    ${fields}
    
    # Initialize ${className}
    public function init(${initParams}) {
        ${initBody}
    }
    
    ${methods}
}`,
            variables: [
                {name: "className", type: "string", required: true},
                {name: "visibility", type: "string", defaultValue: "public"},
                {name: "description", type: "string", defaultValue: "Class description"},
                {name: "fields", type: "string", defaultValue: "// Add fields here"},
                {name: "initParams", type: "string", defaultValue: ""},
                {name: "initBody", type: "string", defaultValue: "// Initialize fields"},
                {name: "methods", type: "string", defaultValue: "// Add methods here"}
            ]
        });
        
        // Test template
        self.registerTemplate({
            name: "unit_test",
            type: TEST,
            description: "Unit test template",
            template: string `import ballerina/test;

# Test ${testName}
@test:Config {
    ${testConfig}
}
function test${testName}() ${throws} {
    // Arrange
    ${arrange}
    
    // Act
    ${act}
    
    // Assert
    ${assert}
}`,
            variables: [
                {name: "testName", type: "string", required: true},
                {name: "testConfig", type: "string", defaultValue: ""},
                {name: "throws", type: "string", defaultValue: ""},
                {name: "arrange", type: "string", defaultValue: "// Setup test data"},
                {name: "act", type: "string", defaultValue: "// Execute test action"},
                {name: "assert", type: "string", defaultValue: "test:assertEquals(actual, expected);"}
            ],
            imports: ["ballerina/test"]
        });
        
        // Error handler template
        self.registerTemplate({
            name: "error_handler",
            type: ERROR_HANDLER,
            description: "Error handling pattern",
            template: string `function ${functionName}(${params}) returns ${returnType}|error {
    do {
        ${tryBlock}
    } on fail error e {
        // Log error
        log:printError("${errorMessage}", 'error = e);
        
        // Handle specific error types
        if e is ${errorType} {
            ${specificHandling}
        }
        
        // Return or rethrow
        ${errorReturn}
    }
}`,
            variables: [
                {name: "functionName", type: "string", required: true},
                {name: "params", type: "string", defaultValue: ""},
                {name: "returnType", type: "string", defaultValue: "()"},
                {name: "tryBlock", type: "string", defaultValue: "// Code that might fail"},
                {name: "errorMessage", type: "string", defaultValue: "Operation failed"},
                {name: "errorType", type: "string", defaultValue: "ApplicationError"},
                {name: "specificHandling", type: "string", defaultValue: "// Handle specific error"},
                {name: "errorReturn", type: "string", defaultValue: "return e;"}
            ]
        });
        
        // Database query template
        self.registerTemplate({
            name: "database_query",
            type: DATABASE_QUERY,
            description: "Database query template",
            template: string `import ballerinax/mysql;
import ballerina/sql;

# ${description}
public function ${functionName}(${params}) returns ${returnType}|error {
    sql:ParameterizedQuery query = `${sqlQuery}`;
    
    ${executionType} result = ${clientVar}->${operation}(query);
    
    if result is sql:Error {
        log:printError("Database error", 'error = result);
        return error("${errorMessage}");
    }
    
    ${resultHandling}
    
    return ${returnValue};
}`,
            variables: [
                {name: "functionName", type: "string", required: true},
                {name: "description", type: "string", defaultValue: "Execute database query"},
                {name: "params", type: "string", defaultValue: ""},
                {name: "returnType", type: "string", defaultValue: "()"},
                {name: "sqlQuery", type: "string", required: true},
                {name: "executionType", type: "string", defaultValue: "stream<record {}, error?>"},
                {name: "clientVar", type: "string", defaultValue: "dbClient"},
                {name: "operation", type: "string", defaultValue: "query"},
                {name: "errorMessage", type: "string", defaultValue: "Database operation failed"},
                {name: "resultHandling", type: "string", defaultValue: "// Process results"},
                {name: "returnValue", type: "string", defaultValue: "()"}
            ],
            imports: ["ballerinax/mysql", "ballerina/sql"]
        });
    }
    
    // Register a template
    public function registerTemplate(CodeTemplate template) {
        self.templateDefinitions[template.name] = template;
    }
    
    // Generate code from template
    public function generate(GenerationRequest request) returns GenerationResult|error {
        // Find template
        CodeTemplate? template = self.findTemplate(request);
        if template is () {
            return error("Template not found: " + request.templateType.toString());
        }
        
        // Validate variables
        check self.validateVariables(template, request.variables);
        
        // Prepare variables with defaults
        map<string> finalVars = self.prepareVariables(template, request.variables);
        
        // Generate code
        string generatedCode = self.processTemplate(template.template, finalVars);
        
        // Add imports if requested
        if request.options?.includeImports ?: true {
            generatedCode = self.addImports(template.imports ?: [], generatedCode);
        }
        
        // Generate test code if requested
        string? testCode = ();
        if request.options?.includeTests ?: false {
            testCode = self.generateTestCode(template, finalVars);
        }
        
        return {
            success: true,
            generatedCode: generatedCode,
            imports: template.imports,
            testCode: testCode
        };
    }
    
    // Find matching template
    private function findTemplate(GenerationRequest request) returns CodeTemplate? {
        if request.templateName is string {
            return self.templateDefinitions[request.templateName];
        }
        
        // Find first template of requested type
        foreach CodeTemplate template in self.templateDefinitions {
            if template.type == request.templateType {
                return template;
            }
        }
        
        return ();
    }
    
    // Validate provided variables
    private function validateVariables(CodeTemplate template, map<string> provided) returns error? {
        foreach TemplateVariable var in template.variables {
            if var.required && !provided.hasKey(var.name) && var.defaultValue is () {
                return error("Required variable missing: " + var.name);
            }
            
            // Validate against allowed values
            if var.validValues is string[] && provided.hasKey(var.name) {
                string value = provided[var.name];
                boolean valid = false;
                foreach string validValue in var.validValues {
                    if value == validValue {
                        valid = true;
                        break;
                    }
                }
                if !valid {
                    return error("Invalid value for " + var.name + ": " + value);
                }
            }
        }
        
        return;
    }
    
    // Prepare variables with defaults
    private function prepareVariables(CodeTemplate template, map<string> provided) returns map<string> {
        map<string> result = {};
        
        foreach TemplateVariable var in template.variables {
            if provided.hasKey(var.name) {
                result[var.name] = provided[var.name];
            } else if var.defaultValue is string {
                result[var.name] = var.defaultValue;
            }
        }
        
        // Add any extra provided variables
        foreach [string, string] [key, value] in provided.entries() {
            if !result.hasKey(key) {
                result[key] = value;
            }
        }
        
        return result;
    }
    
    // Process template with variables
    private function processTemplate(string template, map<string> variables) returns string {
        string result = template;
        
        foreach [string, string] [key, value] in variables.entries() {
            string placeholder = "${" + key + "}";
            result = regex:replaceAll(result, placeholder, value);
        }
        
        return result;
    }
    
    // Add imports to generated code
    private function addImports(string[] imports, string code) returns string {
        if imports.length() == 0 {
            return code;
        }
        
        string importSection = "";
        foreach string imp in imports {
            importSection += "import " + imp + ";\n";
        }
        
        return importSection + "\n" + code;
    }
    
    // Generate test code for template
    private function generateTestCode(CodeTemplate template, map<string> variables) returns string {
        // Generate corresponding test code
        return string `import ballerina/test;

@test:Config {}
function test${variables["name"] ?: "Generated"}() {
    // Test generated code
    test:assertTrue(true, "Generated code test");
}`;
    }
    
    // Get available templates
    public function getAvailableTemplates(TemplateType? type = ()) returns CodeTemplate[] {
        CodeTemplate[] templates = [];
        
        foreach CodeTemplate template in self.templateDefinitions {
            if type is () || template.type == type {
                templates.push(template);
            }
        }
        
        return templates;
    }
    
    // Get template by name
    public function getTemplate(string name) returns CodeTemplate? {
        return self.templateDefinitions[name];
    }
}