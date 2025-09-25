#!/bin/bash

# Liquibase Runner Script for YAML Changesets
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

# MongoDB connection base
MONGO_BASE="mongodb+srv://praveenchandharts:kixIUsDWGd3n6w5S@praveen-mongodb-github.lhhwdqa.mongodb.net"

# Valid databases
VALID_DATABASES="sample_mflix liquibase_test liquibase_test_new"

# Functions
print_status() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

usage() {
    echo "Usage: $0 <command> <database> [version] [environment]"
    echo ""
    echo "Commands:"
    echo "  status  - Check changeset status"
    echo "  update  - Apply changesets"
    echo ""
    echo "Databases:"
    echo "  sample_mflix, liquibase_test, liquibase_test_new"
    echo ""
    echo "Examples:"
    echo "  $0 status sample_mflix                    # Latest changeset status"
    echo "  $0 update sample_mflix 24092025          # Specific version"
    echo "  $0 update sample_mflix latest            # Latest changeset"
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

# Debug environment
print_info "Java version:"
java -version 2>&1 | head -3

print_info "Working directory: $(pwd)"
print_info "Script directory: $SCRIPT_DIR"
print_info "Project root: $PROJECT_ROOT"

# Find changeset file
if [[ "$VERSION_OR_FILE" == *.yaml ]]; then
    print_info "Using direct file path: $VERSION_OR_FILE"
    CHANGESET_FILE="$VERSION_OR_FILE"
else
    CHANGESET_DIR="$PROJECT_ROOT/db/mongodb/$ENVIRONMENT"
    
    if [ ! -d "$CHANGESET_DIR" ]; then
        print_error "Changeset directory not found: $CHANGESET_DIR"
        exit 1
    fi

    # Find YAML files
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
    
    # Convert to relative path from PROJECT_ROOT
    if command -v realpath >/dev/null 2>&1; then
        CHANGESET_FILE=$(realpath --relative-to="$PROJECT_ROOT" "$CHANGESET_FILE")
    else
        # Fallback for macOS/systems without realpath
        CHANGESET_FILE=$(python3 -c "import os; print(os.path.relpath('$CHANGESET_FILE', '$PROJECT_ROOT'))")
    fi
fi

print_status "Using changeset: $CHANGESET_FILE"

# Move to project root directory for relative paths
cd "$PROJECT_ROOT"

# Check lib directory and JARs
LIB_DIR="$PROJECT_ROOT/lib"
print_info "Checking lib directory: $LIB_DIR"

if [ ! -d "$LIB_DIR" ]; then
    print_error "lib directory not found: $LIB_DIR"
    exit 1
fi

JAR_COUNT=$(find "$LIB_DIR" -name "*.jar" | wc -l)
print_info "JAR files found: $JAR_COUNT"

if [ "$JAR_COUNT" -eq 0 ]; then
    print_error "No JAR files found in $LIB_DIR"
    exit 1
fi

# List JAR files for debugging
print_info "Available JARs:"
find "$LIB_DIR" -name "*.jar" -exec basename {} \; | sort

# MongoDB connection string
MONGO_URL="${MONGO_BASE}/${DATABASE}?retryWrites=true&w=majority&tls=true"
print_info "MongoDB URL: ****/${DATABASE}?..."
print_info "Context: $DATABASE"
print_info "Changeset path: $CHANGESET_FILE"

# Show changeset preview
print_info "Changeset preview:"
echo "===================="
head -20 "$CHANGESET_FILE" || echo "Could not read file"
echo "===================="

# Try multiple approaches for maximum compatibility
print_info "Executing Liquibase $COMMAND using enhanced JAR approach..."

# Approach 1: Java 21 compatible with explicit driver class
print_info "Trying Approach 1: Direct Java 21 with wildcard classpath..."
java \
    --add-opens java.base/java.lang=ALL-UNNAMED \
    --add-opens java.sql/java.sql=ALL-UNNAMED \
    -cp "lib/*" \
    liquibase.integration.commandline.Main \
    --driver=liquibase.ext.mongodb.database.MongoLiquibaseDatabase \
    --url="$MONGO_URL" \
    --changeLogFile="$CHANGESET_FILE" \
    --contexts="$DATABASE" \
    --logLevel="INFO" \
    "$COMMAND"

exit_code=$?

# If Approach 1 fails, try Approach 2
if [ $exit_code -ne 0 ]; then
    print_warning "Approach 1 failed, trying Approach 2: Simplified Java 21 approach..."
    
    java \
        --add-opens java.base/java.lang=ALL-UNNAMED \
        --add-opens java.sql/java.sql=ALL-UNNAMED \
        -cp "lib/*" \
        liquibase.integration.commandline.Main \
        --driver=liquibase.ext.mongodb.database.MongoLiquibaseDatabase \
        --url="$MONGO_URL" \
        --changeLogFile="$CHANGESET_FILE" \
        --contexts="$DATABASE" \
        --logLevel="INFO" \
        "$COMMAND"
    
    exit_code=$?
fi

# If Approach 2 fails, try Approach 3
if [ $exit_code -ne 0 ]; then
    print_warning "Approach 2 failed, trying Approach 3: Properties file approach..."
    
    # Create temporary properties file
    cat > liquibase-temp.properties << EOF
url=$MONGO_URL
changeLogFile=$CHANGESET_FILE
contexts=$DATABASE
logLevel=INFO
driver=liquibase.ext.mongodb.database.MongoLiquibaseDatabase
classpath=lib/*
EOF
    
    java \
        --add-opens java.base/java.lang=ALL-UNNAMED \
        --add-opens java.sql/java.sql=ALL-UNNAMED \
        -cp "lib/*" \
        liquibase.integration.commandline.Main \
        --defaultsFile=liquibase-temp.properties \
        "$COMMAND"
    
    exit_code=$?
    
    # Cleanup
    rm -f liquibase-temp.properties
fi

print_info "Liquibase execution completed with exit code: $exit_code"

if [ $exit_code -eq 0 ]; then
    print_status "Liquibase $COMMAND completed successfully!"
else
    print_error "All approaches failed. Liquibase $COMMAND failed with exit code: $exit_code"
    
    # Additional debugging info
    print_info "Additional debugging information:"
    print_info "Java classpath: lib/*"
    print_info "MongoDB URL format: mongodb+srv://.../${DATABASE}?..."
    print_info "Changeset file exists: $(test -f "$CHANGESET_FILE" && echo "YES" || echo "NO")"
    print_info "Lib directory contents:"
    ls -la "$LIB_DIR" || echo "Cannot list lib directory"
fi

exit $exit_code
