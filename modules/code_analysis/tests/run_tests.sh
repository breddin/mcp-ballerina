#!/bin/bash

# Test Runner Script for Code Analysis Module
# Provides comprehensive testing with coverage and reporting

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
MODULE_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$(dirname "$MODULE_DIR")")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test categories
UNIT_TESTS="ast_parser_test,semantic_analyzer_test"
INTEGRATION_TESTS="integration_test,mcp_tool_test"
PERFORMANCE_TESTS="performance_test"
ALL_TESTS="$UNIT_TESTS,$INTEGRATION_TESTS,$PERFORMANCE_TESTS"

# Default options
RUN_COVERAGE=true
RUN_PERFORMANCE=false
TEST_FILTER=""
VERBOSE=false
GENERATE_REPORT=true

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to print test header
print_header() {
    local title=$1
    echo ""
    print_color "$BLUE" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_color "$BLUE" "  $title"
    print_color "$BLUE" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# Function to check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check Ballerina installation
    if ! command -v bal &> /dev/null; then
        print_color "$RED" "❌ Ballerina is not installed"
        echo "Please install Ballerina from https://ballerina.io/downloads/"
        exit 1
    fi
    
    local bal_version=$(bal version | head -n1)
    print_color "$GREEN" "✅ Ballerina: $bal_version"
    
    # Check if module exists
    if [ ! -f "$MODULE_DIR/Ballerina.toml" ]; then
        print_color "$RED" "❌ Module not found at $MODULE_DIR"
        exit 1
    fi
    
    print_color "$GREEN" "✅ Module found at $MODULE_DIR"
}

# Function to clean previous test results
clean_results() {
    print_header "Cleaning Previous Results"
    
    rm -rf "$MODULE_DIR/target/report"
    rm -f "$MODULE_DIR/target/test_results.json"
    rm -f "$MODULE_DIR/target/coverage.json"
    
    print_color "$GREEN" "✅ Cleaned previous test results"
}

# Function to build the module
build_module() {
    print_header "Building Module"
    
    cd "$MODULE_DIR"
    
    if $VERBOSE; then
        bal build
    else
        bal build 2>&1 | grep -E "(Compiling|Building|error)" || true
    fi
    
    if [ $? -eq 0 ]; then
        print_color "$GREEN" "✅ Module built successfully"
    else
        print_color "$RED" "❌ Build failed"
        exit 1
    fi
}

# Function to run unit tests
run_unit_tests() {
    print_header "Running Unit Tests"
    
    cd "$MODULE_DIR"
    
    local test_cmd="bal test --tests=$UNIT_TESTS"
    
    if $RUN_COVERAGE; then
        test_cmd="$test_cmd --code-coverage --coverage-format=xml"
    fi
    
    if $GENERATE_REPORT; then
        test_cmd="$test_cmd --test-report"
    fi
    
    if $VERBOSE; then
        $test_cmd
    else
        $test_cmd 2>&1 | grep -E "(PASSED|FAILED|error)" || true
    fi
    
    local status=$?
    
    if [ $status -eq 0 ]; then
        print_color "$GREEN" "✅ Unit tests passed"
    else
        print_color "$YELLOW" "⚠️  Some unit tests failed"
    fi
    
    return $status
}

# Function to run integration tests
run_integration_tests() {
    print_header "Running Integration Tests"
    
    cd "$MODULE_DIR"
    
    local test_cmd="bal test --tests=$INTEGRATION_TESTS"
    
    if $GENERATE_REPORT; then
        test_cmd="$test_cmd --test-report"
    fi
    
    if $VERBOSE; then
        $test_cmd
    else
        $test_cmd 2>&1 | grep -E "(PASSED|FAILED|error)" || true
    fi
    
    local status=$?
    
    if [ $status -eq 0 ]; then
        print_color "$GREEN" "✅ Integration tests passed"
    else
        print_color "$YELLOW" "⚠️  Some integration tests failed"
    fi
    
    return $status
}

# Function to run performance tests
run_performance_tests() {
    print_header "Running Performance Tests"
    
    cd "$MODULE_DIR"
    
    local test_cmd="bal test --tests=$PERFORMANCE_TESTS"
    
    if $GENERATE_REPORT; then
        test_cmd="$test_cmd --test-report"
    fi
    
    print_color "$YELLOW" "⏱️  Performance tests may take a while..."
    
    if $VERBOSE; then
        $test_cmd
    else
        $test_cmd 2>&1 | grep -E "(PASSED|FAILED|Performance|Avg=|error)" || true
    fi
    
    local status=$?
    
    if [ $status -eq 0 ]; then
        print_color "$GREEN" "✅ Performance tests completed"
    else
        print_color "$YELLOW" "⚠️  Some performance tests failed"
    fi
    
    return $status
}

# Function to generate coverage report
generate_coverage_report() {
    print_header "Coverage Report"
    
    if [ -f "$MODULE_DIR/target/report/coverage.xml" ]; then
        # Parse coverage XML (simplified)
        local coverage=$(grep -oP 'line-rate="\K[^"]*' "$MODULE_DIR/target/report/coverage.xml" 2>/dev/null | head -1)
        
        if [ -n "$coverage" ]; then
            local percentage=$(echo "$coverage * 100" | bc -l | cut -d. -f1)
            
            if [ "$percentage" -ge 80 ]; then
                print_color "$GREEN" "✅ Code Coverage: ${percentage}%"
            elif [ "$percentage" -ge 60 ]; then
                print_color "$YELLOW" "⚠️  Code Coverage: ${percentage}%"
            else
                print_color "$RED" "❌ Code Coverage: ${percentage}%"
            fi
        fi
        
        echo ""
        echo "Detailed coverage report: $MODULE_DIR/target/report/coverage/index.html"
    else
        print_color "$YELLOW" "No coverage report generated"
    fi
}

# Function to show test summary
show_summary() {
    print_header "Test Summary"
    
    if [ -f "$MODULE_DIR/target/test_results.json" ]; then
        # Parse test results (simplified)
        local total=$(grep -o '"total":[0-9]*' "$MODULE_DIR/target/test_results.json" | cut -d: -f2)
        local passed=$(grep -o '"passed":[0-9]*' "$MODULE_DIR/target/test_results.json" | cut -d: -f2)
        local failed=$(grep -o '"failed":[0-9]*' "$MODULE_DIR/target/test_results.json" | cut -d: -f2)
        local skipped=$(grep -o '"skipped":[0-9]*' "$MODULE_DIR/target/test_results.json" | cut -d: -f2)
        
        echo "Tests Run: ${total:-0}"
        print_color "$GREEN" "  Passed: ${passed:-0}"
        
        if [ "${failed:-0}" -gt 0 ]; then
            print_color "$RED" "  Failed: $failed"
        fi
        
        if [ "${skipped:-0}" -gt 0 ]; then
            print_color "$YELLOW" "  Skipped: $skipped"
        fi
    fi
    
    echo ""
    echo "Full test report: $MODULE_DIR/target/report/index.html"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -u, --unit          Run only unit tests"
    echo "  -i, --integration   Run only integration tests"
    echo "  -p, --performance   Include performance tests"
    echo "  -a, --all          Run all tests including performance"
    echo "  -c, --no-coverage  Skip code coverage"
    echo "  -v, --verbose      Verbose output"
    echo "  -h, --help         Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0              # Run unit and integration tests with coverage"
    echo "  $0 -u           # Run only unit tests"
    echo "  $0 -a           # Run all tests including performance"
    echo "  $0 -p -v        # Run with performance tests and verbose output"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--unit)
            TEST_FILTER="unit"
            shift
            ;;
        -i|--integration)
            TEST_FILTER="integration"
            shift
            ;;
        -p|--performance)
            RUN_PERFORMANCE=true
            shift
            ;;
        -a|--all)
            TEST_FILTER=""
            RUN_PERFORMANCE=true
            shift
            ;;
        -c|--no-coverage)
            RUN_COVERAGE=false
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    print_color "$BLUE" "🧪 Ballerina Code Analysis Test Suite"
    echo ""
    
    check_prerequisites
    clean_results
    build_module
    
    local test_failed=false
    
    # Run tests based on filter
    if [ "$TEST_FILTER" == "unit" ] || [ -z "$TEST_FILTER" ]; then
        run_unit_tests || test_failed=true
    fi
    
    if [ "$TEST_FILTER" == "integration" ] || [ -z "$TEST_FILTER" ]; then
        run_integration_tests || test_failed=true
    fi
    
    if $RUN_PERFORMANCE; then
        run_performance_tests || test_failed=true
    fi
    
    # Generate reports
    if $RUN_COVERAGE; then
        generate_coverage_report
    fi
    
    show_summary
    
    # Exit with appropriate code
    if $test_failed; then
        print_color "$YELLOW" "⚠️  Some tests failed. Check the report for details."
        exit 1
    else
        print_color "$GREEN" "✅ All tests passed successfully!"
        exit 0
    fi
}

# Run main function
main