pipeline {
    agent any
    
    parameters {
        string(
            name: 'BRANCH',
            defaultValue: 'main',
            description: 'Git branch to deploy from (and commit back to)'
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
        booleanParam(
            name: 'COMMIT_RESULTS',
            defaultValue: false,
            description: 'Commit deployment results back to the same branch'
        )
    }
    
    environment {
        MONGO_CONNECTION_BASE = credentials('mongo-connection-string')
        JAVA_OPTS = '--add-opens java.base/java.lang=ALL-UNNAMED --add-opens java.base/java.util=ALL-UNNAMED --add-opens java.sql/java.sql=ALL-UNNAMED'
        DEPLOYMENT_TIMESTAMP = sh(script: 'date "+%Y-%m-%d_%H-%M-%S"', returnStdout: true).trim()
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo "🔄 Checking out branch: ${params.BRANCH}"
                
                // Checkout with credentials for push capability
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: params.BRANCH]],
                    userRemoteConfigs: [[
                        url: 'https://github.com/praveenchandhar/liquibase-dbac.git',
                        credentialsId: 'github-token'
                    ]]
                ])
                
                echo "✅ Repository checked out successfully"
                echo "📋 Current branch: ${params.BRANCH}"
                
                script {
                    // Store current commit for deployment tracking
                    env.CURRENT_COMMIT = sh(script: 'git rev-parse HEAD', returnStdout: true).trim()
                    env.CURRENT_COMMIT_SHORT = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                }
                
                echo "📝 Current commit: ${env.CURRENT_COMMIT_SHORT}"
                sh 'git log --oneline -3'
            }
        }
        
        stage('Setup Dependencies') {
            steps {
                echo "🔧 Setting up Liquibase dependencies..."
                
                script {
                    if (fileExists('scripts/setup-dependencies.sh')) {
                        sh 'chmod +x scripts/setup-dependencies.sh'
                        sh './scripts/setup-dependencies.sh'
                    } else {
                        sh '''
                            mkdir -p lib
                            cd lib
                            
                            echo "📥 Downloading Liquibase JARs..."
                            curl -L -O "https://github.com/liquibase/liquibase/releases/download/v4.24.0/liquibase-core-4.24.0.jar"
                            curl -L -O "https://github.com/liquibase/liquibase-mongodb/releases/download/v4.24.0/liquibase-mongodb-4.24.0.jar"
                            curl -L -O "https://repo1.maven.org/maven2/org/mongodb/mongodb-driver-sync/4.11.1/mongodb-driver-sync-4.11.1.jar"
                            curl -L -O "https://repo1.maven.org/maven2/org/mongodb/bson/4.11.1/bson-4.11.1.jar"
                            curl -L -O "https://repo1.maven.org/maven2/org/mongodb/mongodb-driver-core/4.11.1/mongodb-driver-core-4.11.1.jar"
                            curl -L -O "https://repo1.maven.org/maven2/info/picocli/picocli/4.6.3/picocli-4.6.3.jar"
                            curl -L -O "https://repo1.maven.org/maven2/org/yaml/snakeyaml/1.33/snakeyaml-1.33.jar"
                            cd ..
                        '''
                    }
                }
                
                echo "✅ Dependencies setup completed"
            }
        }
        
        stage('Pre-Deployment Status') {
            steps {
                echo "🔍 Checking current deployment status..."
                
                script {
                    if (fileExists('scripts/run-liquibase.sh')) {
                        sh 'chmod +x scripts/run-liquibase.sh'
                        sh "./scripts/run-liquibase.sh status ${params.DATABASE} '${params.VERSION_OR_FILE}'"
                    }
                }
            }
        }
        
        stage('Execute Liquibase') {
            steps {
                script {
                    def actualCommand = params.DRY_RUN ? 'status' : params.COMMAND
                    echo "🚀 Executing Liquibase ${actualCommand} on branch: ${params.BRANCH}"
                    
                    if (params.DRY_RUN && params.COMMAND == 'update') {
                        echo "⚠️  DRY_RUN enabled: Running status instead of update"
                    }
                    
                    if (fileExists('scripts/run-liquibase.sh')) {
                        sh 'chmod +x scripts/run-liquibase.sh'
                        sh "./scripts/run-liquibase.sh ${actualCommand} ${params.DATABASE} '${params.VERSION_OR_FILE}'"
                    } else {
                        error("scripts/run-liquibase.sh not found!")
                    }
                    
                    // Store deployment success flag
                    env.DEPLOYMENT_SUCCESS = 'true'
                }
                
                echo "✅ Liquibase execution completed successfully"
            }
        }
        
        stage('Create Deployment Record') {
            when {
                allOf {
                    expression { params.COMMIT_RESULTS == true }
                    expression { params.COMMAND == 'update' }
                    expression { params.DRY_RUN == false }
                    expression { env.DEPLOYMENT_SUCCESS == 'true' }
                }
            }
            steps {
                echo "📝 Creating deployment record..."
                
                script {
                    // Create deployment record directory
                    sh 'mkdir -p deployments'
                    
                    // Create deployment record file
                    def deploymentRecord = """
# Deployment Record

**Timestamp:** ${env.DEPLOYMENT_TIMESTAMP}
**Branch:** ${params.BRANCH}
**Commit:** ${env.CURRENT_COMMIT_SHORT}
**Database:** ${params.DATABASE}
**Environment:** ${params.ENVIRONMENT}
**Version/File:** ${params.VERSION_OR_FILE}
**Jenkins Build:** ${env.BUILD_NUMBER}
**Jenkins URL:** ${env.BUILD_URL}

## Status
✅ Successfully deployed to ${params.DATABASE}

## Changes Applied
- Applied changesets from: ${params.VERSION_OR_FILE}
- Environment: ${params.ENVIRONMENT}
- Execution time: ${env.DEPLOYMENT_TIMESTAMP}

---
*Auto-generated by Jenkins Pipeline*
""".trim()
                    
                    writeFile file: "deployments/deployment-${env.DEPLOYMENT_TIMESTAMP}.md", text: deploymentRecord
                    
                    // Also update latest deployment info
                    writeFile file: "deployments/LATEST_DEPLOYMENT.md", text: deploymentRecord
                    
                    echo "✅ Deployment record created"
                }
            }
        }
        
        stage('Commit Results to Same Branch') {
            when {
                allOf {
                    expression { params.COMMIT_RESULTS == true }
                    expression { params.COMMAND == 'update' }
                    expression { params.DRY_RUN == false }
                    expression { env.DEPLOYMENT_SUCCESS == 'true' }
                }
            }
            steps {
                echo "💾 Committing deployment results to branch: ${params.BRANCH}"
                
                withCredentials([usernamePassword(credentialsId: 'github-token', usernameVariable: 'GIT_USERNAME', passwordVariable: 'GIT_TOKEN')]) {
                    script {
                        sh '''
                            # Configure git
                            git config user.name "Jenkins Deployment Bot"
                            git config user.email "jenkins@yourcompany.com"
                            
                            # Set remote URL with token
                            git remote set-url origin https://${GIT_USERNAME}:${GIT_TOKEN}@github.com/praveenchandhar/liquibase-dbac.git
                            
                            # Add deployment files
                            git add deployments/
                            
                            # Check if there are changes to commit
                            if git diff --staged --quiet; then
                                echo "No changes to commit"
                            else
                                # Commit changes
                                git commit -m "🚀 Deployment Record: ${DEPLOYMENT_TIMESTAMP}
                                
                                - Database: ${DATABASE}
                                - Environment: ${ENVIRONMENT}  
                                - Version: ${VERSION_OR_FILE}
                                - Branch: ${BRANCH}
                                - Build: #${BUILD_NUMBER}"
                                
                                # Push to the same branch
                                git push origin ${BRANCH}
                                
                                echo "✅ Deployment record committed to ${BRANCH}"
                            fi
                        '''
                    }
                }
            }
        }
        
        stage('Post-Deployment Status') {
            when {
                allOf {
                    expression { params.COMMAND == 'update' }
                    expression { params.DRY_RUN == false }
                }
            }
            steps {
                echo "🔍 Verifying deployment status..."
                
                script {
                    if (fileExists('scripts/run-liquibase.sh')) {
                        sh "./scripts/run-liquibase.sh status ${params.DATABASE} '${params.VERSION_OR_FILE}'"
                    }
                }
            }
        }
        
        stage('Summary') {
            steps {
                script {
                    echo "📊 Deployment Summary:"
                    echo "   Branch: ${params.BRANCH}"
                    echo "   Command: ${params.COMMAND}"
                    echo "   Database: ${params.DATABASE}"
                    echo "   Environment: ${params.ENVIRONMENT}"
                    echo "   Version/File: ${params.VERSION_OR_FILE}"
                    echo "   Commit Results: ${params.COMMIT_RESULTS}"
                    echo "   Timestamp: ${env.DEPLOYMENT_TIMESTAMP}"
                    echo ""
                    
                    if (params.COMMAND == 'update' && !params.DRY_RUN) {
                        echo "✅ Changes applied to ${params.DATABASE} from branch ${params.BRANCH}"
                        if (params.COMMIT_RESULTS) {
                            echo "📝 Deployment record committed back to ${params.BRANCH}"
                        }
                    } else {
                        echo "ℹ️  Status check completed - no changes applied"
                    }
                }
            }
        }
    }
    
    post {
        always {
            echo "🏁 Pipeline execution completed"
        }
        
        success {
            echo "🎉 Pipeline completed successfully!"
            echo "📝 Branch ${params.BRANCH} processed successfully"
            
            script {
                if (params.COMMIT_RESULTS && params.COMMAND == 'update' && !params.DRY_RUN) {
                    echo "💾 Deployment record committed to ${params.BRANCH}"
                }
            }
        }
        
        failure {
            echo "❌ Pipeline failed!"
            echo "🔍 Check the logs for details"
        }
    }
}
