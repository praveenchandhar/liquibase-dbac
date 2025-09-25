#!/bin/bash

# MongoDB Atlas connection base
MONGO_CONNECTION_BASE="mongodb+srv://praveenchandharts:kixIUsDWGd3n6w5S@praveen-mongodb-github.lhhwdqa.mongodb.net"

# Define database contexts using simple variables instead of associative arrays
get_database_context() {
    case "$1" in
        "liquibase_test") echo "liquibase_test" ;;
        "sample_mflix") echo "sample_mflix" ;;
        "liquibase_test_new") echo "liquibase_test_new" ;;
        *) echo "sample_mflix" ;;  # default
    esac
}

# Validate input arguments
if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <command> <database> <changeset_file>"
    echo ""
    echo "Commands: status, update"
    echo "Examples:"
    echo "  $0 status sample_mflix db/mongodb/weekly_release/25092025/data.yaml"
    echo "  $0 update sample_mflix db/mongodb/weekly_release/25092025/data.yaml"
    exit 1
fi

command="$1"
database="$2"
changeset_file="$3"

# Validate command
if [ "$command" != "status" ] && [ "$command" != "update" ]; then
    echo "❌ Invalid command: $command"
    echo "Valid commands: status, update"
    exit 1
fi

# Get database context
context=$(get_database_context "$database")
echo "🎯 Using database context: $context"

# Validate changeset file
if [ ! -f "$changeset_file" ]; then
    echo "❌ Changeset file not found: $changeset_file"
    exit 1
fi

# Setup CLASSPATH - EXACT working code logic
if [ -d "$HOME/liquibase-jars" ]; then
    JARS_DIR="$HOME/liquibase-jars"
elif [ -d "$(pwd)/liquibase-jars" ]; then
    JARS_DIR="$(pwd)/liquibase-jars"
elif [ -d "${WORKSPACE}/liquibase-jars" ]; then
    JARS_DIR="${WORKSPACE}/liquibase-jars"
else
    echo "❌ Could not find liquibase-jars directory"
    exit 1
fi

CLASSPATH=$(find "$JARS_DIR" -name "*.jar" | tr '\n' ':')
export CLASSPATH

echo "🚀 Executing Liquibase command..."
echo "   Command: $command"
echo "   Database: $database"
echo "   Context: $context"
echo "   Changeset: $changeset_file"
echo "   JAR Directory: $JARS_DIR"

# Execute EXACTLY like working code - no module arguments!
java \
    --add-opens=java.base/java.lang=ALL-UNNAMED \
    --add-opens=java.sql/java.sql=ALL-UNNAMED \
    --add-exports=java.base/sun.nio.ch=ALL-UNNAMED \
    --add-exports=java.sql/java.sql=ALL-UNNAMED \
    -Djava.security.manager=allow \
    -cp "$CLASSPATH" \
    liquibase.integration.commandline.Main \
    --url="${MONGO_CONNECTION_BASE}/${database}?retryWrites=true&w=majority&tls=true" \
    --changeLogFile="$changeset_file" \
    --contexts="$context" \
    --logLevel="info" \
    "$command"

# Check exit code
if [ $? -eq 0 ]; then
    echo "✅ Liquibase $command completed successfully"
else
    echo "❌ Liquibase $command failed"
    exit 1
fi

exit 0
