#!/bin/bash

# Liquibase Runner Script for YAML Changesets
set -e  # Exit on error (removed 'u' to avoid unbound variable issues)

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

# Valid databases (using simple approach instead of associative array)
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
VERSION="${3:-latest}"
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
print_info "Version: $VERSION"
print_info "Environment: $ENVIRONMENT"

# Find changeset file
CHANGESET_DIR="$PROJECT_ROOT/db/mongodb/$ENVIRONMENT"

if [ ! -d "$CHANGESET_DIR" ]; then
    print_error "Changeset directory not found: $CHANGESET_DIR"
    exit 1
fi

# Find YAML files
if [ "$VERSION" = "latest" ]; then
    CHANGESET_FILE=$(find "$CHANGESET_DIR" -name "*.yaml" -type f | sort | tail -1)
else
    CHANGESET_FILE=$(find "$CHANGESET_DIR" -path "*$VERSION*" -name "*.yaml" -type f | head -1)
fi

if [ -z "$CHANGESET_FILE" ]; then
    print_error "No changeset file found for version: $VERSION"
    print_info "Available changesets:"
    find "$CHANGESET_DIR" -name "*.yaml" -type f | sort
    exit 1
fi

print_status "Using changeset: $CHANGESET_FILE"

# Setup classpath
LIB_DIR="$PROJECT_ROOT/lib"
CLASSPATH=""

if [ -d "$LIB_DIR" ]; then
    # Add all JARs from lib directory
    for jar in "$LIB_DIR"/*.jar; do
        if [ -f "$jar" ]; then
            if [ -z "$CLASSPATH" ]; then
                CLASSPATH="$jar"
            else
                CLASSPATH="$CLASSPATH:$jar"
            fi
        fi
    done
fi

# Check if we have Liquibase installed
if command -v liquibase &> /dev/null; then
    print_info "Using system Liquibase installation"
    LIQUIBASE_CMD="liquibase"
elif [ -n "$CLASSPATH" ]; then
    print_info "Using JAR-based Liquibase"
    LIQUIBASE_CMD="java -cp $CLASSPATH liquibase.integration.commandline.Main"
else
    print_error "Neither system Liquibase nor required JARs found!"
    print_info "Please either:"
    print_info "1. Install Liquibase system-wide, or"
    print_info "2. Download JARs to $LIB_DIR/"
    exit 1
fi

# Build MongoDB URL
MONGO_URL="${MONGO_BASE}/${DATABASE}?retryWrites=true&w=majority&tls=true"

print_info "MongoDB URL: ${MONGO_BASE}/${DATABASE}?..."
print_info "Context: $DATABASE"

# Preview changeset
print_info "Changeset preview:"
echo "===================="
head -20 "$CHANGESET_FILE"
echo "===================="

# Execute Liquibase
print_info "Executing Liquibase $COMMAND..."

$LIQUIBASE_CMD \
    --url="$MONGO_URL" \
    --changeLogFile="$CHANGESET_FILE" \
    --contexts="$DATABASE" \
    --logLevel="INFO" \
    "$COMMAND"

if [ $? -eq 0 ]; then
    print_status "Liquibase $COMMAND completed successfully!"
else
    print_error "Liquibase $COMMAND failed!"
    exit 1
fi

print_status "Operation completed!"
