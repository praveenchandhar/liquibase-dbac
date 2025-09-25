#!/bin/bash

# Setup Dependencies Script - Fixed to match working code
set -e

echo "🔧 Setting up Liquibase dependencies..."

# Create liquibase-jars directory (NOT lib) to match working code
mkdir -p liquibase-jars
cd liquibase-jars

# Clean up any existing JARs to avoid version conflicts
echo "🧹 Cleaning up existing JARs to avoid conflicts..."
rm -f *.jar

# Function to download with retries
download_if_missing() {
    local file=$1
    local url=$2
    
    if [ ! -f "$file" ]; then
        echo "📥 Downloading $file..."
        if command -v curl >/dev/null 2>&1; then
            curl -L -f -o "$file" "$url" || {
                echo "❌ Failed to download $file with curl"
                return 1
            }
        elif command -v wget >/dev/null 2>&1; then
            wget -O "$file" "$url" || {
                echo "❌ Failed to download $file with wget"
                return 1
            }
        else
            echo "❌ Neither curl nor wget available"
            return 1
        fi
        echo "✅ Downloaded $file"
    else
        echo "✅ $file already exists"
    fi
}

# Download SAME versions as working code
download_if_missing "liquibase-core-4.20.0.jar" "https://repo1.maven.org/maven2/org/liquibase/liquibase-core/4.20.0/liquibase-core-4.20.0.jar"
download_if_missing "liquibase-mongodb-4.20.0.jar" "https://repo1.maven.org/maven2/org/liquibase/ext/liquibase-mongodb/4.20.0/liquibase-mongodb-4.20.0.jar"
download_if_missing "mongodb-driver-sync-4.8.2.jar" "https://repo1.maven.org/maven2/org/mongodb/mongodb-driver-sync/4.8.2/mongodb-driver-sync-4.8.2.jar"
download_if_missing "bson-4.8.2.jar" "https://repo1.maven.org/maven2/org/mongodb/bson/4.8.2/bson-4.8.2.jar"
download_if_missing "mongodb-driver-core-4.8.2.jar" "https://repo1.maven.org/maven2/org/mongodb/mongodb-driver-core/4.8.2/mongodb-driver-core-4.8.2.jar"
download_if_missing "picocli-4.6.3.jar" "https://repo1.maven.org/maven2/info/picocli/picocli/4.6.3/picocli-4.6.3.jar"
download_if_missing "snakeyaml-1.33.jar" "https://repo1.maven.org/maven2/org/yaml/snakeyaml/1.33/snakeyaml-1.33.jar"

echo "🎉 All dependencies ready!"
echo "📦 JAR count: $(find . -name "*.jar" | wc -l | tr -d ' ')"

# List all JARs for verification
echo "📋 Downloaded JARs:"
find . -name "*.jar" -exec basename {} \; | sort
