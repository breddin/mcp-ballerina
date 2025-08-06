import ballerina/io;
import modules.refactoring.refactor_engine;
import modules.refactoring.code_templates;
import modules.refactoring.quick_fixes;

public function main() returns error? {
    // Example 1: Extract Method Refactoring
    io:println("=== Extract Method Example ===");
    
    string originalCode = string `
        function processOrder(Order order) returns decimal {
            // Calculate base price
            decimal basePrice = order.quantity * order.unitPrice;
            
            // Apply discount logic - candidate for extraction
            decimal discount = 0;
            if order.quantity > 100 {
                discount = basePrice * 0.15;
            } else if order.quantity > 50 {
                discount = basePrice * 0.10;
            } else if order.quantity > 20 {
                discount = basePrice * 0.05;
            }
            
            // Calculate tax
            decimal subtotal = basePrice - discount;
            decimal tax = subtotal * 0.08;
            
            return subtotal + tax;
        }
    `;
    
    refactor_engine:RefactorEngine engine = new();
    
    // Extract the discount calculation logic
    refactor_engine:RefactorRequest extractRequest = {
        type: refactor_engine:EXTRACT_METHOD,
        sourceCode: originalCode,
        selection: {
            start: {line: 6, column: 0},
            end: {line: 12, column: 0}
        },
        parameters: {
            "methodName": "calculateDiscount",
            "visibility": "private"
        }
    };
    
    refactor_engine:RefactorResult extractResult = check engine.refactor(extractRequest);
    
    if extractResult.success {
        io:println("✅ Method extracted successfully!");
        io:println("Refactored code:");
        io:println(extractResult.refactoredCode);
    }
    
    // Example 2: Rename Symbol with Dependency Tracking
    io:println("\n=== Rename Symbol Example ===");
    
    string codeWithSymbols = string `
        type Customer record {
            string custId;
            string custName;
            string custEmail;
        };
        
        function getCustomer(string custId) returns Customer? {
            // Fetch customer by custId
            return customerDB[custId];
        }
        
        function updateCustomer(Customer customer) {
            string id = customer.custId;
            customerDB[id] = customer;
        }
    `;
    
    refactor_engine:RefactorRequest renameRequest = {
        type: refactor_engine:RENAME_SYMBOL,
        sourceCode: codeWithSymbols,
        selection: {
            start: {line: 2, column: 12},  // Position of 'custId'
            end: {line: 2, column: 18}
        },
        parameters: {
            "newName": "customerId",
            "renameAll": "true"  // Rename all occurrences
        }
    };
    
    refactor_engine:RefactorResult renameResult = check engine.refactor(renameRequest);
    
    if renameResult.success {
        io:println("✅ Symbol renamed successfully!");
        io:println("Updated references: ", renameResult.metadata["updatedReferences"]);
    }
    
    // Example 3: Generate Code from Templates
    io:println("\n=== Code Template Generation ===");
    
    code_templates:TemplateManager templateManager = new();
    
    // Generate a REST service template
    code_templates:GenerationRequest serviceRequest = {
        templateType: code_templates:SERVICE,
        templateName: "rest_service",
        variables: {
            "serviceName": "ProductAPI",
            "port": "8080",
            "basePath": "/api/v1"
        }
    };
    
    code_templates:GenerationResult serviceResult = check templateManager.generate(serviceRequest);
    
    if serviceResult.success {
        io:println("✅ REST service template generated!");
        io:println("Generated code preview:");
        string preview = serviceResult.generatedCode.substring(0, 500) + "...";
        io:println(preview);
    }
    
    // Generate a database query template
    code_templates:GenerationRequest queryRequest = {
        templateType: code_templates:DATABASE_QUERY,
        templateName: "select_with_pagination",
        variables: {
            "tableName": "products",
            "columns": "id, name, price, stock",
            "orderBy": "created_at DESC"
        }
    };
    
    code_templates:GenerationResult queryResult = check templateManager.generate(queryRequest);
    
    if queryResult.success {
        io:println("\n✅ Database query template generated!");
        io:println(queryResult.generatedCode);
    }
    
    // Example 4: Quick Fixes
    io:println("\n=== Quick Fixes Example ===");
    
    string codeWithIssues = string `
        import ballerina/http;
        
        function processRequest(http:Request req) {
            json payload = req.getJsonPayload();  // Missing error handling
            
            string name = payload.name;  // Type mismatch
            
            io:println("Processing: " + name);  // Missing import
        }
    `;
    
    // Simulate diagnostics that would come from the parser
    anydata[] diagnostics = [
        {
            "code": "MISSING_ERROR_HANDLING",
            "message": "getJsonPayload() returns error|json",
            "range": {"start": {"line": 4}, "end": {"line": 4}}
        },
        {
            "code": "TYPE_MISMATCH",
            "message": "Cannot assign json to string",
            "range": {"start": {"line": 6}, "end": {"line": 6}}
        },
        {
            "code": "UNRESOLVED_REFERENCE",
            "message": "Undefined module 'io'",
            "range": {"start": {"line": 8}, "end": {"line": 8}}
        }
    ];
    
    quick_fixes:QuickFixProvider fixProvider = new();
    quick_fixes:QuickFix[] fixes = fixProvider.getQuickFixes(codeWithIssues, diagnostics);
    
    io:println("Available quick fixes:");
    foreach quick_fixes:QuickFix fix in fixes {
        io:println(string `  - ${fix.title} (${fix.kind})`);
        io:println(string `    Description: ${fix.description}`);
    }
    
    // Apply the first fix
    if fixes.length() > 0 {
        quick_fixes:QuickFix firstFix = fixes[0];
        quick_fixes:FixResult fixResult = check fixProvider.applyFix(codeWithIssues, firstFix);
        
        if fixResult.success {
            io:println("\n✅ Quick fix applied!");
            io:println("Fixed code:");
            io:println(fixResult.fixedCode);
        }
    }
    
    // Example 5: Inline Variable Refactoring
    io:println("\n=== Inline Variable Example ===");
    
    string codeWithVariable = string `
        function calculateTotal(decimal[] prices) returns decimal {
            decimal sum = 0;
            foreach decimal price in prices {
                decimal discountedPrice = price * 0.9;  // Variable to inline
                sum += discountedPrice;
            }
            return sum;
        }
    `;
    
    refactor_engine:RefactorRequest inlineRequest = {
        type: refactor_engine:INLINE_VARIABLE,
        sourceCode: codeWithVariable,
        selection: {
            start: {line: 4, column: 16},  // Position of 'discountedPrice'
            end: {line: 4, column: 31}
        },
        parameters: {}
    };
    
    refactor_engine:RefactorResult inlineResult = check engine.refactor(inlineRequest);
    
    if inlineResult.success {
        io:println("✅ Variable inlined successfully!");
        io:println("Refactored code:");
        io:println(inlineResult.refactoredCode);
    }
}

// Type definitions for the examples
type Order record {
    int quantity;
    decimal unitPrice;
};