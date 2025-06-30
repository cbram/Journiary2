#!/bin/bash

# Performance Tests Runner Script
# Journiary Multi-User Performance Testing

set -e

echo "🚀 Journiary Performance Test Suite"
echo "===================================="

# Configuration
TEST_SCHEME="Journiary"
PROJECT_DIR="$(pwd)/Journiary"
TEST_CLASS="MultiUserPerformanceTests"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

function print_section() {
    echo -e "\n${BLUE}📋 $1${NC}"
    echo "----------------------------------------"
}

function print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

function print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

function print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if we're in the right directory
if [ ! -d "Journiary" ]; then
    print_error "Please run this script from the TravelCompanion root directory"
    exit 1
fi

print_section "Environment Check"

# Check Xcode installation
if ! command -v xcodebuild &> /dev/null; then
    print_error "Xcode command line tools not found. Please install Xcode."
    exit 1
fi
print_success "Xcode installation found"

# Check if project exists
if [ ! -f "Journiary/Journiary.xcodeproj/project.pbxproj" ]; then
    print_error "Journiary.xcodeproj not found"
    exit 1
fi
print_success "Journiary project found"

# Performance test options
QUICK_TEST=false
FULL_TEST=false
CUSTOM_CONFIG=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --quick)
            QUICK_TEST=true
            shift
            ;;
        --full)
            FULL_TEST=true
            shift
            ;;
        --custom)
            CUSTOM_CONFIG=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --quick     Run quick performance tests (smaller dataset)"
            echo "  --full      Run full performance tests (large dataset)"
            echo "  --custom    Use custom configuration"
            echo "  --help      Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 --quick    # Quick tests with 10 users, 10 trips each"
            echo "  $0 --full     # Full tests with 50 users, 25 trips each"
            echo "  $0 --custom   # Interactive configuration"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# If no options provided, ask user
if [ "$QUICK_TEST" = false ] && [ "$FULL_TEST" = false ] && [ "$CUSTOM_CONFIG" = false ]; then
    print_section "Test Configuration"
    echo "Please select test configuration:"
    echo "1) Quick Test (10 users, 10 trips each, ~100 memories) - ~30 seconds"
    echo "2) Full Test (50 users, 25 trips each, ~10,000 memories) - ~5-10 minutes"
    echo "3) Custom Configuration (interactive)"
    
    read -p "Select option (1-3): " choice
    
    case $choice in
        1)
            QUICK_TEST=true
            ;;
        2)
            FULL_TEST=true
            ;;
        3)
            CUSTOM_CONFIG=true
            ;;
        *)
            print_error "Invalid choice. Defaulting to Quick Test."
            QUICK_TEST=true
            ;;
    esac
fi

# Set test configuration based on choice
TEST_ARGS=""

if [ "$QUICK_TEST" = true ]; then
    print_section "Quick Performance Test Configuration"
    echo "📊 Users: 10"
    echo "🗺️  Trips per User: 10"
    echo "💭 Memories per Trip: 5"
    echo "🏷️  System Tags: 50"
    echo "⏱️  Estimated Duration: ~30 seconds"
    TEST_ARGS="-testQuickPerformance"
    
elif [ "$FULL_TEST" = true ]; then
    print_section "Full Performance Test Configuration"
    echo "📊 Users: 50"
    echo "🗺️  Trips per User: 25 (Total: 1,250+ trips)"
    echo "💭 Memories per Trip: 8 (Total: 10,000+ memories)"
    echo "🏷️  System Tags: 200"
    echo "⏱️  Estimated Duration: ~5-10 minutes"
    TEST_ARGS="-testFullPerformance"
    
elif [ "$CUSTOM_CONFIG" = true ]; then
    print_section "Custom Performance Test Configuration"
    
    read -p "Number of test users (default 25): " user_count
    user_count=${user_count:-25}
    
    read -p "Trips per user (default 15): " trips_per_user
    trips_per_user=${trips_per_user:-15}
    
    read -p "Memories per trip (default 6): " memories_per_trip
    memories_per_trip=${memories_per_trip:-6}
    
    read -p "Number of system tags (default 100): " tags_count
    tags_count=${tags_count:-100}
    
    total_trips=$((user_count * trips_per_user))
    total_memories=$((total_trips * memories_per_trip))
    
    echo ""
    print_warning "Custom Configuration Summary:"
    echo "📊 Users: $user_count"
    echo "🗺️  Trips per User: $trips_per_user (Total: $total_trips trips)"
    echo "💭 Memories per Trip: $memories_per_trip (Total: $total_memories memories)"
    echo "🏷️  System Tags: $tags_count"
    
    read -p "Continue with this configuration? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        print_warning "Test cancelled by user"
        exit 0
    fi
    
    TEST_ARGS="-testCustomPerformance:$user_count:$trips_per_user:$memories_per_trip:$tags_count"
fi

print_section "Preparing Test Environment"

# Build the project first
print_warning "Building project..."
cd Journiary

if xcodebuild -project Journiary.xcodeproj -scheme $TEST_SCHEME -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build-for-testing > /tmp/build.log 2>&1; then
    print_success "Project build completed"
else
    print_error "Project build failed. Check build log:"
    tail -20 /tmp/build.log
    exit 1
fi

print_section "Running Performance Tests"

# Create test results directory
TEST_RESULTS_DIR="../performance_test_results"
mkdir -p "$TEST_RESULTS_DIR"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
TEST_LOG="$TEST_RESULTS_DIR/performance_test_$TIMESTAMP.log"

print_warning "Starting performance tests..."
print_warning "Test output will be saved to: $TEST_LOG"

# Run the performance tests
if xcodebuild test -project Journiary.xcodeproj -scheme $TEST_SCHEME -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:JourniaryTests/$TEST_CLASS/testMultiUserPerformanceFullSuite > "$TEST_LOG" 2>&1; then
    print_success "Performance tests completed successfully!"
    
    # Extract key metrics from test log
    print_section "Performance Test Results Summary"
    
    if grep -q "PERFORMANCE TEST SUMMARY" "$TEST_LOG"; then
        echo "📊 Detailed results saved to: $TEST_LOG"
        echo ""
        
        # Extract summary section
        sed -n '/PERFORMANCE TEST SUMMARY/,/=====/p' "$TEST_LOG" | head -n -1
        
        # Check for any failures
        if grep -q "XCTAssertLessThan failed" "$TEST_LOG"; then
            print_warning "Some performance thresholds were exceeded!"
            echo "Check the detailed log for specific issues."
        else
            print_success "All performance thresholds met!"
        fi
        
    else
        print_warning "Summary not found in test output. Check full log for details."
    fi
    
else
    print_error "Performance tests failed!"
    echo "Check the test log for details: $TEST_LOG"
    
    # Show last few lines of log for immediate feedback
    echo ""
    print_warning "Last 20 lines of test output:"
    tail -20 "$TEST_LOG"
    exit 1
fi

print_section "Test Cleanup"

# Optional: Archive test results
read -p "Archive test results for future reference? (y/N): " archive
if [[ $archive =~ ^[Yy]$ ]]; then
    ARCHIVE_NAME="performance_results_$TIMESTAMP.tar.gz"
    tar -czf "$TEST_RESULTS_DIR/$ARCHIVE_NAME" "$TEST_LOG"
    print_success "Results archived as: $ARCHIVE_NAME"
fi

print_success "Performance testing completed!"
echo ""
echo "🎯 Next Steps:"
echo "   • Review detailed results in: $TEST_LOG"
echo "   • Compare with previous test runs"
echo "   • Address any performance issues identified"
echo "   • Run tests regularly to monitor performance regression"

cd .. 