#!/bin/bash

# Liquibase Runner Script for YAML Changesets (Based on Working Jenkins Approach)
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

# Database context function (simplified approach)
get_database_context() {
    case "$1" in
        "liquibase_test") echo "liquibase_test" ;;
        "sample_mflix") echo "sample_mflix" ;;
        "liquibase_test_new") echo "liquibase_test_new" ;;
        *) echo "sample_mflix" ;;  # default
    esac
}

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

# Get database context
CONTEXT=$(get_database_context "$DATABASE")
print_info "Database context: $CONTEXT"

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
fi

print_status "Using changeset: $CHANGESET_FILE"

# Move to project root for relative paths
cd "$PROJECT_ROOT"

# Setup CLASSPATH - try different possible locations (like working version)
if [ -d "lib" ]; then
    JARS_DIR="lib"
elif [ -d "$HOME/liquibase-jars" ]; then
    JARS_DIR="$HOME/liquibase-jars"
elif [ -d "$(pwd)/liquibase-jars" ]; then
    JARS_DIR="$(pwd)/liquibase-jars"
elif [ -d "${WORKSPACE}/liquibase-jars" ]; then
    JARS_DIR="${WORKSPACE}/liquibase-jars"
else
    print_error "Could not find JAR directory (lib or liquibase-jars)"
    exit 1
fi

# Build classpath exactly like working version
CLASSPATH=$(find "$JARS_DIR" -name "*.jar" | tr '\n' ':')
export CLASSPATH

print_info "JAR directory: $JARS_DIR"
print_info "JAR count: $(find "$JARS_DIR" -name "*.jar" | wc -l | tr -d ' ')"

# Validate changeset file exists
if [ ! -f "$CHANGESET_FILE" ]; then
    print_error "Changeset file not found: $CHANGESET_FILE"
    exit 1
fi

# MongoDB connection string
MONGO_URL="${MONGO_BASE}/${DATABASE}?retryWrites=true&w=majority&tls=true"

print_info "Executing Liquibase using working Jenkins approach..."
print_info "MongoDB URL: ****/${DATABASE}?..."
print_info "Context: $CONTEXT"
print_info "Changeset: $CHANGESET_FILE"

# Execute Liquibase using the EXACT working approach (no complex module args)
java -cp "$CLASSPATH" liquibase.integration.commandline.Main \
    --url="$MONGO_URL" \
    --changeLogFile="$CHANGESET_FILE" \
    --contexts="$CONTEXT" \
    --logLevel="info" \
    "$COMMAND"

exit_code=$?

if [ $exit_code -eq 0 ]; then
    print_status "Liquibase $COMMAND completed successfully!"
else
    print_error "Liquibase $COMMAND failed with exit code: $exit_code"
fi

exit $exit_code
