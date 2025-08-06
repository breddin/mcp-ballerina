// Test Suite for Template Manager
// Tests code generation templates

import ballerina/test;
import modules.refactoring;

// Test basic function template generation
@test:Config {
    groups: ["templates", "function"]
}
function testFunctionTemplateGeneration() returns error? {
    refactoring:TemplateManager manager = new();
    
    refactoring:GenerationRequest request = {
        templateType: refactoring:FUNCTION,
        templateName: "basic_function",
        variables: {
            "name": "processData",
            "visibility": "public",
            "parameters": "string input, int count",
            "returns": "returns string",
            "body": "return input.repeat(count);",
            "doc": "Process input data"
        }
    };
    
    refactoring:GenerationResult result = check manager.generate(request);
    
    test:assertTrue(result.success, "Function generation should succeed");
    test:assertNotEquals(result.generatedCode, "", "Should generate code");
    test:assertTrue(result.generatedCode.includes("processData"), "Should include function name");
}

// Test REST service template generation
@test:Config {
    groups: ["templates", "service"]
}
function testRestServiceTemplateGeneration() returns error? {
    refactoring:TemplateManager manager = new();
    
    refactoring:GenerationRequest request = {
        templateType: refactoring:SERVICE,
        templateName: "rest_service",
        variables: {
            "serviceName": "UserAPI",
            "basePath": "api/v1",
            "port": "9090",
            "resourceName": "User",
            "resourcePath": "users",
            "returnType": "User",
            "payloadType": "UserInput"
        }
    };
    
    refactoring:GenerationResult result = check manager.generate(request);
    
    test:assertTrue(result.success, "Service generation should succeed");
    test:assertNotEquals(result.generatedCode, "", "Should generate code");
    test:assertTrue(result.generatedCode.includes("service /api/v1"), "Should include service path");
    test:assertTrue(result.generatedCode.includes("resource function get users"), "Should include GET");
    test:assertTrue(result.generatedCode.includes("resource function post users"), "Should include POST");
    test:assertTrue(result.generatedCode.includes("resource function put users"), "Should include PUT");
    test:assertTrue(result.generatedCode.includes("resource function delete users"), "Should include DELETE");
    test:assertNotEquals(result.imports, (), "Should include imports");
}

// Test record type template generation
@test:Config {
    groups: ["templates", "record"]
}
function testRecordTemplateGeneration() returns error? {
    refactoring:TemplateManager manager = new();
    
    refactoring:GenerationRequest request = {
        templateType: refactoring:RECORD,
        templateName: "record_type",
        variables: {
            "name": "Person",
            "visibility": "public",
            "description": "Represents a person",
            "fields": "string firstName;\n    string lastName;\n    int age;"
        }
    };
    
    refactoring:GenerationResult result = check manager.generate(request);
    
    test:assertTrue(result.success, "Record generation should succeed");
    test:assertTrue(result.generatedCode.includes("type Person record"), "Should include record type");
    test:assertTrue(result.generatedCode.includes("firstName"), "Should include fields");
}

// Test class template generation
@test:Config {
    groups: ["templates", "class"]
}
function testClassTemplateGeneration() returns error? {
    refactoring:TemplateManager manager = new();
    
    refactoring:GenerationRequest request = {
        templateType: refactoring:CLASS,
        templateName: "basic_class",
        variables: {
            "className": "Calculator",
            "visibility": "public",
            "description": "Simple calculator class",
            "fields": "private decimal total = 0.0;",
            "initParams": "decimal initialValue = 0.0",
            "initBody": "self.total = initialValue;",
            "methods": string `public function add(decimal value) {
        self.total += value;
    }
    
    public function getTotal() returns decimal {
        return self.total;
    }`
        }
    };
    
    refactoring:GenerationResult result = check manager.generate(request);
    
    test:assertTrue(result.success, "Class generation should succeed");
    test:assertTrue(result.generatedCode.includes("class Calculator"), "Should include class name");
    test:assertTrue(result.generatedCode.includes("function init"), "Should include init function");
    test:assertTrue(result.generatedCode.includes("function add"), "Should include methods");
}

// Test unit test template generation
@test:Config {
    groups: ["templates", "test"]
}
function testUnitTestTemplateGeneration() returns error? {
    refactoring:TemplateManager manager = new();
    
    refactoring:GenerationRequest request = {
        templateType: refactoring:TEST,
        templateName: "unit_test",
        variables: {
            "testName": "CalculatorAdd",
            "testConfig": "groups: [\"unit\", \"calculator\"]",
            "throws": "",
            "arrange": "Calculator calc = new(10.0);",
            "act": "calc.add(5.0);\n    decimal result = calc.getTotal();",
            "assert": "test:assertEquals(result, 15.0);"
        }
    };
    
    refactoring:GenerationResult result = check manager.generate(request);
    
    test:assertTrue(result.success, "Test generation should succeed");
    test:assertTrue(result.generatedCode.includes("@test:Config"), "Should include test annotation");
    test:assertTrue(result.generatedCode.includes("function testCalculatorAdd"), "Should include test function");
    test:assertTrue(result.generatedCode.includes("// Arrange"), "Should include AAA pattern");
    test:assertTrue(result.generatedCode.includes("// Act"), "Should include AAA pattern");
    test:assertTrue(result.generatedCode.includes("// Assert"), "Should include AAA pattern");
}

// Test error handler template generation
@test:Config {
    groups: ["templates", "error-handler"]
}
function testErrorHandlerTemplateGeneration() returns error? {
    refactoring:TemplateManager manager = new();
    
    refactoring:GenerationRequest request = {
        templateType: refactoring:ERROR_HANDLER,
        templateName: "error_handler",
        variables: {
            "functionName": "safeOperation",
            "params": "string input",
            "returnType": "string",
            "tryBlock": "return processInput(input);",
            "errorMessage": "Failed to process input",
            "errorType": "ProcessingError",
            "specificHandling": "// Retry or fallback logic",
            "errorReturn": "return error(\"Operation failed: \" + e.message());"
        }
    };
    
    refactoring:GenerationResult result = check manager.generate(request);
    
    test:assertTrue(result.success, "Error handler generation should succeed");
    test:assertTrue(result.generatedCode.includes("do {"), "Should include do-catch block");
    test:assertTrue(result.generatedCode.includes("on fail error e"), "Should include error handling");
}

// Test database query template generation
@test:Config {
    groups: ["templates", "database"]
}
function testDatabaseQueryTemplateGeneration() returns error? {
    refactoring:TemplateManager manager = new();
    
    refactoring:GenerationRequest request = {
        templateType: refactoring:DATABASE_QUERY,
        templateName: "database_query",
        variables: {
            "functionName": "getUserById",
            "description": "Get user by ID",
            "params": "int userId",
            "returnType": "User",
            "sqlQuery": "SELECT * FROM users WHERE id = ${userId}",
            "executionType": "User",
            "clientVar": "dbClient",
            "operation": "queryRow",
            "errorMessage": "User not found",
            "resultHandling": "// Map to User type",
            "returnValue": "result"
        }
    };
    
    refactoring:GenerationResult result = check manager.generate(request);
    
    test:assertTrue(result.success, "Database query generation should succeed");
    test:assertTrue(result.generatedCode.includes("sql:ParameterizedQuery"), "Should include parameterized query");
    test:assertTrue(result.generatedCode.includes("SELECT * FROM users"), "Should include SQL");
}

// Test template with missing required variables
@test:Config {
    groups: ["templates", "negative"]
}
function testTemplateWithMissingVariables() {
    refactoring:TemplateManager manager = new();
    
    refactoring:GenerationRequest request = {
        templateType: refactoring:FUNCTION,
        templateName: "basic_function",
        variables: {
            // Missing required "name" variable
            "visibility": "public"
        }
    };
    
    refactoring:GenerationResult|error result = manager.generate(request);
    
    test:assertTrue(result is error, "Should fail for missing required variable");
}

// Test template with default values
@test:Config {
    groups: ["templates", "defaults"]
}
function testTemplateWithDefaults() returns error? {
    refactoring:TemplateManager manager = new();
    
    refactoring:GenerationRequest request = {
        templateType: refactoring:FUNCTION,
        templateName: "basic_function",
        variables: {
            "name": "simpleFunc"
            // Other variables should use defaults
        }
    };
    
    refactoring:GenerationResult result = check manager.generate(request);
    
    test:assertTrue(result.success, "Should succeed with defaults");
    test:assertTrue(result.generatedCode.includes("public function"), "Should use default visibility");
    test:assertTrue(result.generatedCode.includes("// TODO: Implement"), "Should use default body");
}

// Test template with test code generation
@test:Config {
    groups: ["templates", "with-tests"]
}
function testTemplateWithTestGeneration() returns error? {
    refactoring:TemplateManager manager = new();
    
    refactoring:GenerationRequest request = {
        templateType: refactoring:FUNCTION,
        templateName: "basic_function",
        variables: {
            "name": "calculate"
        },
        options: {
            includeTests: true
        }
    };
    
    refactoring:GenerationResult result = check manager.generate(request);
    
    test:assertTrue(result.success, "Should succeed");
    test:assertNotEquals(result.testCode, (), "Should generate test code");
    test:assertTrue(result.testCode?.includes("@test:Config") ?: false, "Test should have annotation");
}

// Test getting available templates
@test:Config {
    groups: ["templates", "listing"]
}
function testGetAvailableTemplates() {
    refactoring:TemplateManager manager = new();
    
    // Get all templates
    refactoring:CodeTemplate[] allTemplates = manager.getAvailableTemplates();
    test:assertTrue(allTemplates.length() > 0, "Should have templates");
    
    // Get templates by type
    refactoring:CodeTemplate[] functionTemplates = manager.getAvailableTemplates(refactoring:FUNCTION);
    test:assertTrue(functionTemplates.length() > 0, "Should have function templates");
    
    foreach refactoring:CodeTemplate template in functionTemplates {
        test:assertEquals(template.type, refactoring:FUNCTION, "Should only return function templates");
    }
}

// Test getting template by name
@test:Config {
    groups: ["templates", "lookup"]
}
function testGetTemplateByName() {
    refactoring:TemplateManager manager = new();
    
    refactoring:CodeTemplate? template = manager.getTemplate("basic_function");
    test:assertNotEquals(template, (), "Should find template");
    
    if template is refactoring:CodeTemplate {
        test:assertEquals(template.name, "basic_function", "Should return correct template");
        test:assertEquals(template.type, refactoring:FUNCTION, "Should be function template");
    }
    
    // Test non-existent template
    refactoring:CodeTemplate? notFound = manager.getTemplate("non_existent");
    test:assertEquals(notFound, (), "Should return nil for non-existent template");
}

// Test custom template registration
@test:Config {
    groups: ["templates", "custom"]
}
function testCustomTemplateRegistration() returns error? {
    refactoring:TemplateManager manager = new();
    
    // Register custom template
    manager.registerTemplate({
        name: "custom_template",
        type: refactoring:FUNCTION,
        description: "Custom template for testing",
        template: "// Custom: ${name}",
        variables: [
            {name: "name", type: "string", required: true}
        ]
    });
    
    // Use custom template
    refactoring:GenerationRequest request = {
        templateType: refactoring:FUNCTION,
        templateName: "custom_template",
        variables: {
            "name": "TestFunction"
        }
    };
    
    refactoring:GenerationResult result = check manager.generate(request);
    
    test:assertTrue(result.success, "Custom template should work");
    test:assertEquals(result.generatedCode, "// Custom: TestFunction", "Should use custom template");
}