#!/bin/bash

# Liquibase Runner Script for YAML Changesets (Jenkins Compatible)
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# MongoDB connection base - use environment variable or default
MONGO_BASE="${MONGO_CONNECTION_BASE:-mongodb+srv://praveenchandharts:kixIUsDWGd3n6w5S@praveen-mongodb-github.lhhwdqa.mongodb.net}"

# Valid databases
VALID_DATABASES="sample_mflix liquibase_test liquibase_test_new"

# Functions
print_status() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

usage() {
    echo "Usage: $0 <command> <database> [version_or_file_path] [environment]"
    echo ""
    echo "Commands:"
    echo "  status  - Check changeset status"
    echo "  update  - Apply changesets"
    echo ""
    echo "Databases:"
    echo "  sample_mflix, liquibase_test, liquibase_test_new"
    echo ""
    echo "Examples:"
    echo "  $0 status sample_mflix                                      # Latest changeset status"
    echo "  $0 update sample_mflix 24092025                            # Specific version"
    echo "  $0 update sample_mflix db/mongodb/weekly_release/24092025/testing.yaml  # Specific file"
    echo "  $0 update sample_mflix latest                              # Latest changeset"
    exit 1
}

# Validate arguments
if [ $# -lt 2 ]; then
    usage
fi

COMMAND="$1"
DATABASE="$2"
VERSION_OR_FILE="${3:-latest}"
ENVIRONMENT="${4:-weekly_release}"

# Validate command
if [[ "$COMMAND" != "status" && "$COMMAND" != "update" ]]; then
    print_error "Invalid command: $COMMAND"
    usage
fi

# Validate database
if [[ ! " $VALID_DATABASES " =~ " $DATABASE " ]]; then
    print_error "Invalid database: $DATABASE"
    echo "Valid databases: $VALID_DATABASES"
    exit 1
fi

print_info "Starting Liquibase execution..."
print_info "Command: $COMMAND"
print_info "Database: $DATABASE"
print_info "Version/File: $VERSION_OR_FILE"
print_info "Environment: $ENVIRONMENT"

# Change to project root first
cd "$PROJECT_ROOT"

# Determine changeset file
if [[ "$VERSION_OR_FILE" == *.yaml ]]; then
    # Direct file path provided
    CHANGESET_FILE="$VERSION_OR_FILE"
    print_info "Using direct file path: $CHANGESET_FILE"
else
    # Version provided, find the file
    CHANGESET_DIR="db/mongodb/$ENVIRONMENT"
    
    if [ ! -d "$CHANGESET_DIR" ]; then
        print_error "Changeset directory not found: $CHANGESET_DIR"
        exit 1
    fi
    
    # Find YAML files (relative paths)
    if [ "$VERSION_OR_FILE" = "latest" ]; then
        CHANGESET_FILE=$(find "$CHANGESET_DIR" -name "*.yaml" -type f | sort | tail -1)
    else
        CHANGESET_FILE=$(find "$CHANGESET_DIR" -path "*$VERSION_OR_FILE*" -name "*.yaml" -type f | head -1)
    fi
    
    if [ -z "$CHANGESET_FILE" ]; then
        print_error "No changeset file found for version: $VERSION_OR_FILE"
        print_info "Available changesets:"
        find "$CHANGESET_DIR" -name "*.yaml" -type f | sort
        exit 1
    fi
fi

print_status "Using changeset: $CHANGESET_FILE"

# Create dynamic properties file (using relative paths)
PROPS_FILE="liquibase-temp.properties"
MONGO_URL="${MONGO_BASE}/${DATABASE}?retryWrites=true&w=majority&tls=true"

cat > "$PROPS_FILE" << EOF
# Dynamic Liquibase Properties for MongoDB
url=$MONGO_URL
changeLogFile=$CHANGESET_FILE
contexts=$DATABASE
logLevel=INFO
classpath=lib/liquibase-core-4.24.0.jar:lib/liquibase-mongodb-4.24.0.jar:lib/mongodb-driver-sync-4.11.1.jar:lib/bson-4.11.1.jar:lib/mongodb-driver-core-4.11.1.jar:lib/picocli-4.6.3.jar:lib/snakeyaml-1.33.jar
EOF

print_info "MongoDB URL: ${MONGO_BASE}/${DATABASE}?..."
print_info "Context: $DATABASE"
print_info "Working directory: $(pwd)"
print_info "Changeset path: $CHANGESET_FILE"

# Verify file exists
if [ ! -f "$CHANGESET_FILE" ]; then
    print_error "Changeset file does not exist: $CHANGESET_FILE"
    print_info "Current directory contents:"
    ls -la
    exit 1
fi

# Preview changeset
print_info "Changeset preview:"
echo "===================="
head -20 "$CHANGESET_FILE"
echo "===================="

# Execute Liquibase using the WORKING approach
print_info "Executing Liquibase $COMMAND using properties file approach..."

# Use environment variable for Java options if available
JAVA_OPTS="${JAVA_OPTS:---add-opens java.base/java.lang=ALL-UNNAMED --add-opens java.base/java.util=ALL-UNNAMED --add-opens java.sql/java.sql=ALL-UNNAMED}"

java $JAVA_OPTS \
    -cp "lib/*" \
    liquibase.integration.commandline.Main \
    --defaultsFile="$PROPS_FILE" \
    "$COMMAND"

LIQUIBASE_EXIT_CODE=$?

# Cleanup
rm -f "$PROPS_FILE"

if [ $LIQUIBASE_EXIT_CODE -eq 0 ]; then
    print_status "Liquibase $COMMAND completed successfully!"
else
    print_error "Liquibase $COMMAND failed!"
    exit 1
fi

print_status "Operation completed!"
