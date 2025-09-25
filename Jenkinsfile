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
        string(
            name: 'VERSION_OR_FILE',
            defaultValue: 'latest',
            description: 'Version (e.g., 24092025) or specific file path (e.g., db/mongodb/weekly_release/24092025/testing.yaml)'
        )
        choice(
            name: 'ENVIRONMENT',
            choices: ['weekly_release', 'monthly_release'],
            description: 'Environment directory'
        )
    }
    
    environment {
        MONGO_CONNECTION_BASE = credentials('mongo-connection-string')
        BUILD_TIMESTAMP = sh(script: 'date +%Y-%m-%d_%H-%M-%S', returnStdout: true).trim()
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo "🔄 Checking out branch: ${params.BRANCH}"
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: "origin/${params.BRANCH}"]],
                    userRemoteConfigs: [[
                        url: 'https://github.com/praveenchandhar/liquibase-dbac.git',
                        credentialsId: 'github-token'
                    ]]
                ])
                echo "✅ Repository checked out successfully"
                echo "📋 Current branch: ${params.BRANCH}"
                script {
                    env.CURRENT_COMMIT = sh(script: 'git rev-parse HEAD', returnStdout: true).trim()
                    env.SHORT_COMMIT = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                }
                echo "📝 Current commit: ${env.SHORT_COMMIT}"
                sh "git log --oneline -3"
            }
        }
        
        stage('Setup Dependencies') {
            steps {
                echo "🔧 Setting up Liquibase dependencies..."
                script {
                    if (fileExists('scripts/setup-dependencies.sh')) {
                        sh "chmod +x scripts/setup-dependencies.sh"
                        sh "./scripts/setup-dependencies.sh"
                    } else {
                        error "setup-dependencies.sh script not found!"
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
                        sh "chmod +x scripts/run-liquibase.sh"
                        sh "./scripts/run-liquibase.sh status ${params.DATABASE} ${params.VERSION_OR_FILE} ${params.ENVIRONMENT}"
                    } else {
                        error "run-liquibase.sh script not found!"
                    }
                }
            }
        }
        
        stage('Execute Liquibase') {
            when {
                expression { params.COMMAND == 'update' }
            }
            steps {
                echo "🚀 Executing Liquibase deployment..."
                script {
                    sh "./scripts/run-liquibase.sh update ${params.DATABASE} ${params.VERSION_OR_FILE} ${params.ENVIRONMENT}"
                }
                echo "✅ Liquibase deployment completed"
            }
        }
        
        stage('Create Deployment Record') {
            when {
                expression { params.COMMAND == 'update' }
            }
            steps {
                echo "📝 Creating deployment record..."
                script {
                    def deploymentRecord = """
# Deployment Record
- **Date**: ${env.BUILD_TIMESTAMP}
- **Branch**: ${params.BRANCH}
- **Commit**: ${env.SHORT_COMMIT}
- **Command**: ${params.COMMAND}
- **Database**: ${params.DATABASE}
- **Version/File**: ${params.VERSION_OR_FILE}
- **Environment**: ${params.ENVIRONMENT}
- **Status**: SUCCESS
"""
                    writeFile file: "deployment-${env.BUILD_TIMESTAMP}.md", text: deploymentRecord
                    echo "📄 Deployment record created: deployment-${env.BUILD_TIMESTAMP}.md"
                }
            }
        }
        
        stage('Commit Results to Same Branch') {
            when {
                expression { params.COMMAND == 'update' }
            }
            steps {
                echo "📤 Committing deployment results back to branch: ${params.BRANCH}"
                script {
                    try {
                        sh """
                            git config --global user.email "jenkins@praveenchandhar.com"
                            git config --global user.name "Jenkins CI"
                            git add deployment-${env.BUILD_TIMESTAMP}.md
                            git commit -m "📈 Deployment completed: ${params.DATABASE} - ${env.BUILD_TIMESTAMP}
                            
                            - Command: ${params.COMMAND}
                            - Database: ${params.DATABASE}
                            - Version/File: ${params.VERSION_OR_FILE}
                            - Environment: ${params.ENVIRONMENT}
                            - Commit: ${env.SHORT_COMMIT}"
                            
                            git push origin HEAD:${params.BRANCH}
                        """
                        echo "✅ Deployment results committed to branch: ${params.BRANCH}"
                    } catch (Exception e) {
                        echo "⚠️ Could not commit deployment results: ${e.getMessage()}"
                        echo "This is not critical, deployment was successful"
                    }
                }
            }
        }
        
        stage('Post-Deployment Status') {
            when {
                expression { params.COMMAND == 'update' }
            }
            steps {
                echo "📊 Checking post-deployment status..."
                script {
                    sh "./scripts/run-liquibase.sh status ${params.DATABASE} ${params.VERSION_OR_FILE} ${params.ENVIRONMENT}"
                }
            }
        }
        
        stage('Summary') {
            steps {
                echo "📋 Deployment Summary:"
                echo "   • Command: ${params.COMMAND}"
                echo "   • Database: ${params.DATABASE}"
                echo "   • Version/File: ${params.VERSION_OR_FILE}"
                echo "   • Environment: ${params.ENVIRONMENT}"
                echo "   • Branch: ${params.BRANCH}"
                echo "   • Commit: ${env.SHORT_COMMIT}"
                echo "   • Status: ✅ SUCCESS"
            }
        }
    }
    
    post {
        always {
            echo "🏁 Pipeline execution completed"
        }
        
        failure {
            echo "❌ Pipeline failed!"
            echo "🔍 Check the logs for details"
        }
        
        success {
            echo "✅ Pipeline completed successfully!"
            echo "🎉 Liquibase ${params.COMMAND} executed for ${params.DATABASE}"
        }
    }
}
