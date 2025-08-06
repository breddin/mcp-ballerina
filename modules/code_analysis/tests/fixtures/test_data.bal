// Test Data Fixtures for Code Analysis Tests

// Valid Ballerina code samples
public const string VALID_SIMPLE_FUNCTION = "
function greet(string name) returns string {
    return \"Hello, \" + name + \"!\";
}
";

public const string VALID_COMPLEX_MODULE = "
import ballerina/io;
import ballerina/http;
import ballerina/time;

# Configuration for the application
configurable string apiUrl = \"http://localhost:8080\";
configurable int timeout = 30;

# User record type
# + name - User's full name
# + email - User's email address
# + age - User's age
public type User record {|
    string name;
    string email;
    int age;
    time:Utc? lastLogin;
|};

# Service status enumeration
public enum ServiceStatus {
    ACTIVE,
    INACTIVE,
    MAINTENANCE
}

# Main service class
public class UserService {
    private map<User> users = {};
    private ServiceStatus status = ACTIVE;
    
    # Initialize the service
    public function init() {
        io:println(\"UserService initialized\");
    }
    
    # Add a new user
    # + user - User to add
    # + return - Error if user already exists
    public function addUser(User user) returns error? {
        if self.users.hasKey(user.email) {
            return error(\"User already exists: \" + user.email);
        }
        self.users[user.email] = user;
    }
    
    # Get user by email
    # + email - User's email
    # + return - User record or error
    public function getUser(string email) returns User|error {
        User? user = self.users[email];
        if user is () {
            return error(\"User not found: \" + email);
        }
        return user;
    }
}

# REST API service
service /api/v1 on new http:Listener(8080) {
    private final UserService userService = new();
    
    # Get all users endpoint
    resource function get users() returns User[]|error {
        return self.userService.users.toArray();
    }
    
    # Get specific user endpoint
    resource function get users/[string email]() returns User|http:NotFound {
        User|error result = self.userService.getUser(email);
        if result is error {
            return <http:NotFound>{};
        }
        return result;
    }
    
    # Create new user endpoint
    resource function post users(@http:Payload User user) returns http:Created|http:BadRequest {
        error? result = self.userService.addUser(user);
        if result is error {
            return <http:BadRequest>{body: result.message()};
        }
        return <http:Created>{};
    }
}

# Main function
public function main() returns error? {
    UserService service = new();
    
    User testUser = {
        name: \"John Doe\",
        email: \"john@example.com\",
        age: 30,
        lastLogin: time:utcNow()
    };
    
    check service.addUser(testUser);
    io:println(\"User added successfully\");
    
    User retrievedUser = check service.getUser(\"john@example.com\");
    io:println(\"Retrieved user: \" + retrievedUser.toString());
}
";

// Invalid code samples for error testing
public const string INVALID_SYNTAX = "
function broken( {  // Missing closing parenthesis
    return 42;
}
";

public const string DUPLICATE_DECLARATIONS = "
function duplicate() returns int {
    return 1;
}

function duplicate() returns int {  // Duplicate function
    return 2;
}

type MyType string;
type MyType int;  // Duplicate type
";

public const string TYPE_ERRORS = "
function typeError() {
    int x = \"not an int\";  // Type mismatch
    string s = 123;  // Type mismatch
    boolean b = 1.5;  // Type mismatch
}
";

public const string UNDEFINED_REFERENCES = "
function useUndefined() {
    int x = undefinedVar;  // Undefined variable
    undefinedFunction();  // Undefined function
    UndefinedType t = {};  // Undefined type
}
";

// Edge case samples
public const string DEEPLY_NESTED = "
function deeplyNested() {
    if true {
        while true {
            foreach int i in 0...10 {
                match i {
                    0 => {
                        do {
                            if i == 0 {
                                lock {
                                    transaction {
                                        io:println(\"Deep\");
                                    }
                                }
                            }
                        } on fail error e {
                            io:println(e);
                        }
                    }
                }
            }
        }
    }
}
";

public const string UNICODE_IDENTIFIERS = "
function 你好() {
    string μεταβλητή = \"Greek\";
    int число = 42;
    boolean 本当 = true;
}
";

public const string LARGE_FUNCTION = generateLargeFunction();

function generateLargeFunction() returns string {
    string[] lines = ["function largeFunc() {"];
    foreach int i in 0...1000 {
        lines.push("    int var" + i.toString() + " = " + i.toString() + ";");
    }
    lines.push("}");
    return string:'join("\n", ...lines);
}

// Special constructs
public const string ANNOTATIONS = "
@http:ServiceConfig {
    cors: {
        allowOrigins: [\"*\"],
        allowCredentials: false
    }
}
service /api on new http:Listener(9090) {
    @http:ResourceConfig {
        methods: [\"GET\"],
        path: \"/health\"
    }
    resource function get health() returns json {
        return {\"status\": \"healthy\"};
    }
}
";

public const string ASYNC_PATTERNS = "
function asyncPatterns() returns error? {
    worker w1 {
        int x = 10;
        x -> w2;
    }
    
    worker w2 {
        int y = <- w1;
        io:println(y);
    }
    
    future<int> f1 = start calculateAsync();
    int result = check wait f1;
}

function calculateAsync() returns int {
    return 42;
}
";

public const string QUERY_EXPRESSIONS = "
function queryExpressions() {
    int[] numbers = [1, 2, 3, 4, 5];
    
    int[] evens = from int n in numbers
                  where n % 2 == 0
                  select n;
    
    var result = from var {name, age} in getPersons()
                 where age > 18
                 order by name ascending
                 limit 10
                 select {name, age};
}

function getPersons() returns record {|string name; int age;|}[] {
    return [{name: \"Alice\", age: 25}, {name: \"Bob\", age: 30}];
}
";

public const string ERROR_HANDLING = "
function errorHandling() returns error? {
    int|error result = divide(10, 0);
    
    if result is error {
        io:println(\"Error: \" + result.message());
        return result;
    }
    
    int x = check divide(10, 2);
    
    int y = divide(10, 3) ?: 0;
    
    do {
        check riskyOperation();
    } on fail error e {
        io:println(\"Operation failed: \" + e.message());
    }
}

function divide(int a, int b) returns int|error {
    if b == 0 {
        return error(\"Division by zero\");
    }
    return a / b;
}

function riskyOperation() returns error? {
    return error(\"Something went wrong\");
}
";

// Test result expectations
public type TestExpectation record {|
    string testName;
    string input;
    boolean shouldPass;
    int expectedErrors?;
    int expectedWarnings?;
    string[] expectedSymbols?;
|};

public final TestExpectation[] TEST_EXPECTATIONS = [
    {
        testName: "Valid simple function",
        input: VALID_SIMPLE_FUNCTION,
        shouldPass: true,
        expectedErrors: 0,
        expectedSymbols: ["greet"]
    },
    {
        testName: "Invalid syntax",
        input: INVALID_SYNTAX,
        shouldPass: false,
        expectedErrors: 1
    },
    {
        testName: "Duplicate declarations",
        input: DUPLICATE_DECLARATIONS,
        shouldPass: false,
        expectedErrors: 2,
        expectedSymbols: ["duplicate", "MyType"]
    },
    {
        testName: "Type errors",
        input: TYPE_ERRORS,
        shouldPass: false,
        expectedErrors: 3
    }
];