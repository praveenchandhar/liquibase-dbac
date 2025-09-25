#!/bin/bash

# Setup Dependencies Script for Jenkins
set -e

echo "🔧 Setting up Liquibase dependencies..."

# Create lib directory
mkdir -p lib
cd lib

# Download JARs if they don't exist
download_if_missing() {
    local file=$1
    local url=$2
    
    if [ ! -f "$file" ]; then
        echo "📥 Downloading $file..."
        curl -L -O "$url"
        echo "✅ Downloaded $file"
    else
        echo "✅ $file already exists"
    fi
}

# Download all required JARs
download_if_missing "liquibase-core-4.24.0.jar" \
    "https://github.com/liquibase/liquibase/releases/download/v4.24.0/liquibase-core-4.24.0.jar"

download_if_missing "liquibase-mongodb-4.24.0.jar" \
    "https://github.com/liquibase/liquibase-mongodb/releases/download/v4.24.0/liquibase-mongodb-4.24.0.jar"

download_if_missing "mongodb-driver-sync-4.11.1.jar" \
    "https://repo1.maven.org/maven2/org/mongodb/mongodb-driver-sync/4.11.1/mongodb-driver-sync-4.11.1.jar"

download_if_missing "bson-4.11.1.jar" \
    "https://repo1.maven.org/maven2/org/mongodb/bson/4.11.1/bson-4.11.1.jar"

download_if_missing "mongodb-driver-core-4.11.1.jar" \
    "https://repo1.maven.org/maven2/org/mongodb/mongodb-driver-core/4.11.1/mongodb-driver-core-4.11.1.jar"

download_if_missing "picocli-4.6.3.jar" \
    "https://repo1.maven.org/maven2/info/picocli/picocli/4.6.3/picocli-4.6.3.jar"

download_if_missing "snakeyaml-1.33.jar" \
    "https://repo1.maven.org/maven2/org/yaml/snakeyaml/1.33/snakeyaml-1.33.jar"

cd ..

echo "🎉 All dependencies ready!"
echo "📦 JAR count: $(ls -1 lib/*.jar 2>/dev/null | wc -l)"
