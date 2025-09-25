pipeline {
    agent any
    
    parameters {
        string(
            name: 'BRANCH',
            defaultValue: 'main',
            description: 'Git branch to deploy from'
        )
        choice(
            name: 'COMMAND',
            choices: ['status', 'update'],
            description: 'Liquibase command to execute'
        )
        choice(
            name: 'DATABASE',
            choices: ['sample_mflix', 'liquibase_test', 'liquibase_test_new'],
            description: 'Target database'
        )
        choice(
            name: 'ENVIRONMENT',
            choices: ['weekly_release', 'monthly_release'],
            description: 'Release type'
        )
        string(
            name: 'VERSION_OR_FILE',
            defaultValue: 'latest',
            description: 'Version or file path'
        )
        booleanParam(
            name: 'DRY_RUN',
            defaultValue: false,
            description: 'Run status only'
        )
    }
    
    environment {
        MONGO_CONNECTION_BASE = credentials('mongo-connection-string')
        JAVA_OPTS = '--add-opens java.base/java.lang=ALL-UNNAMED --add-opens java.base/java.util=ALL-UNNAMED --add-opens java.sql/java.sql=ALL-UNNAMED'
    }
    
    stages {
        stage('Checkout') {
            steps {
                script {
                    echo "🔄 Checking out branch: ${params.BRANCH}"
                    git branch: params.BRANCH, url: 'https://github.com/praveenchandhar/liquibase-dbac.git'
                }
                echo "✅ Repository checked out successfully"
                sh 'ls -la'
            }
        }
        
        stage('Setup Dependencies') {
            steps {
                script {
                    echo "🔧 Setting up Liquibase dependencies..."
                    
                    // Check if setup script exists
                    if (fileExists('scripts/setup-dependencies.sh')) {
                        sh 'chmod +x scripts/setup-dependencies.sh'
                        sh './scripts/setup-dependencies.sh'
                    } else {
                        echo "⚠️  setup-dependencies.sh not found, creating lib directory manually"
                        sh 'mkdir -p lib'
                        // Download essential JARs manually
                        sh '''
                            cd lib
                            curl -L -O "https://github.com/liquibase/liquibase/releases/download/v4.24.0/liquibase-core-4.24.0.jar" || echo "Failed to download liquibase-core"
                            curl -L -O "https://github.com/liquibase/liquibase-mongodb/releases/download/v4.24.0/liquibase-mongodb-4.24.0.jar" || echo "Failed to download liquibase-mongodb"
                            curl -L -O "https://repo1.maven.org/maven2/org/mongodb/mongodb-driver-sync/4.11.1/mongodb-driver-sync-4.11.1.jar" || echo "Failed to download mongodb-driver-sync"
                            curl -L -O "https://repo1.maven.org/maven2/org/mongodb/bson/4.11.1/bson-4.11.1.jar" || echo "Failed to download bson"
                            curl -L -O "https://repo1.maven.org/maven2/org/mongodb/mongodb-driver-core/4.11.1/mongodb-driver-core-4.11.1.jar" || echo "Failed to download mongodb-driver-core"
                            curl -L -O "https://repo1.maven.org/maven2/info/picocli/picocli/4.6.3/picocli-4.6.3.jar" || echo "Failed to download picocli"
                            curl -L -O "https://repo1.maven.org/maven2/org/yaml/snakeyaml/1.33/snakeyaml-1.33.jar" || echo "Failed to download snakeyaml"
                            cd ..
                        '''
                    }
                    
                    echo "📦 Verifying JAR files:"
                    sh 'ls -la lib/ || echo "lib directory not found"'
                }
            }
        }
        
        stage('Validate Parameters') {
            steps {
                script {
                    echo "🔍 Validating parameters..."
                    echo "Branch: ${params.BRANCH}"
                    echo "Command: ${params.COMMAND}"
                    echo "Database: ${params.DATABASE}"
                    echo "Environment: ${params.ENVIRONMENT}"
                    echo "Version/File: ${params.VERSION_OR_FILE}"
                    echo "Dry Run: ${params.DRY_RUN}"
                    
                    echo "📁 Repository contents:"
                    sh 'find . -name "*.yaml" -type f | head -10 || echo "No YAML files found"'
                }
            }
        }
        
        stage('Execute Liquibase') {
            steps {
                script {
                    def actualCommand = params.DRY_RUN ? 'status' : params.COMMAND
                    echo "🚀 Executing Liquibase ${actualCommand}..."
                    
                    if (params.DRY_RUN && params.COMMAND == 'update') {
                        echo "⚠️  DRY_RUN enabled: Running status instead of update"
                    }
                    
                    // Check if run-liquibase.sh exists
                    if (fileExists('scripts/run-liquibase.sh')) {
                        sh 'chmod +x scripts/run-liquibase.sh'
                        sh """
                            ./scripts/run-liquibase.sh ${actualCommand} ${params.DATABASE} "${params.VERSION_OR_FILE}"
                        """
                    } else {
                        echo "❌ scripts/run-liquibase.sh not found!"
                        sh 'find . -name "*.sh" -type f || echo "No shell scripts found"'
                        error("Required script not found")
                    }
                }
            }
        }
    }
    
    post {
        always {
            script {
                echo "🏁 Pipeline execution completed"
                
                // Archive artifacts if they exist
                try {
                    archiveArtifacts artifacts: 'db/**/*.yaml', allowEmptyArchive: true
                } catch (Exception e) {
                    echo "⚠️  Could not archive YAML files: ${e.getMessage()}"
                }
                
                try {
                    archiveArtifacts artifacts: 'liquibase-output.sql', allowEmptyArchive: true
                } catch (Exception e) {
                    echo "⚠️  Could not archive liquibase-output.sql: ${e.getMessage()}"
                }
            }
        }
        
        success {
            echo "🎉 Pipeline completed successfully!"
        }
        
        failure {
            echo "❌ Pipeline failed!"
        }
    }
}
