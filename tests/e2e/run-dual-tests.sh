#!/bin/bash

# Dual-Browser Test Runner for ShadowWhisper
# Runs Playwright tests locally with two browser contexts
#
# Usage:
#   ./run-dual-tests.sh                    # Run ALL tests
#   ./run-dual-tests.sh room-join          # Run tests matching "room-join"
#   ./run-dual-tests.sh --dir room         # Run tests in room/ directory
#   ./run-dual-tests.sh --list             # List all available tests
#   ./run-dual-tests.sh --help             # Show help

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_DIR="$SCRIPT_DIR/dual-browser"
RUNNER="$TEST_DIR/runner/test-runner.js"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Show help if requested
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     ShadowWhisper Dual-Browser Test Runner                 ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Usage:"
    echo "  ./run-dual-tests.sh                    Run ALL tests"
    echo "  ./run-dual-tests.sh <pattern>          Run tests matching pattern"
    echo "  ./run-dual-tests.sh --dir <dir>        Run tests in directory"
    echo "  ./run-dual-tests.sh --list             List all available tests"
    echo ""
    echo "Examples:"
    echo "  ./run-dual-tests.sh                    # Run full regression"
    echo "  ./run-dual-tests.sh room-join          # Run room-join tests"
    echo "  ./run-dual-tests.sh messaging          # Run messaging tests"
    echo "  ./run-dual-tests.sh --dir room         # Run all room/ tests"
    echo ""
    echo "Prerequisites:"
    echo "  Flutter app must be running:"
    echo "    flutter run -d chrome --web-port=8080"
    echo ""
    exit 0
fi

echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     ShadowWhisper Dual-Browser Test Runner                 ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Skip app check for --list mode
if [[ "$1" != "--list" && "$1" != "-l" ]]; then
    # Check if app is running
    echo -e "${YELLOW}Checking if app is running on http://localhost:8080...${NC}"
    if ! curl -s --max-time 5 http://localhost:8080 > /dev/null 2>&1; then
        echo -e "${RED}ERROR: App is not running on localhost:8080${NC}"
        echo -e "${YELLOW}Please start the Flutter app first:${NC}"
        echo "  cd $PROJECT_ROOT && flutter run -d chrome --web-port=8080"
        exit 1
    fi
    echo -e "${GREEN}✓ App is running${NC}"
    echo ""
fi

# Ensure output directories exist
mkdir -p "$TEST_DIR/output/screenshots"
mkdir -p "$TEST_DIR/output/logs"
mkdir -p "$TEST_DIR/output/reports"

# Run the test runner with all arguments passed through
echo -e "${YELLOW}Starting test runner...${NC}"
echo ""

cd "$TEST_DIR" && node "$RUNNER" "$@"

EXIT_CODE=$?

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  ALL TESTS PASSED${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
else
    echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}  TESTS FAILED (exit code: $EXIT_CODE)${NC}"
    echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
fi

echo ""
echo -e "${CYAN}Output directories:${NC}"
echo "  Screenshots: $TEST_DIR/output/screenshots/"
echo "  Logs:        $TEST_DIR/output/logs/"
echo "  Reports:     $TEST_DIR/output/reports/"
echo ""

exit $EXIT_CODE
