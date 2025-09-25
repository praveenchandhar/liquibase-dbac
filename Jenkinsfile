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
        
        stage('Ensure Docker') {
            steps {
                echo "🐳 Checking Docker availability..."
                script {
                    sh "docker --version"
                    sh "docker-compose --version"
                }
                echo "✅ Docker is available"
            }
        }
        
        stage('Pre-Deployment Status') {
            steps {
                echo "🔍 Checking current deployment status..."
                script {
                    if (fileExists('scripts/run-liquibase-docker.sh')) {
                        sh "chmod +x scripts/run-liquibase-docker.sh"
                        sh "./scripts/run-liquibase-docker.sh status ${params.DATABASE} ${params.VERSION_OR_FILE} ${params.ENVIRONMENT}"
                    } else {
                        error "Docker Liquibase script not found!"
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
                    sh "./scripts/run-liquibase-docker.sh update ${params.DATABASE} ${params.VERSION_OR_FILE} ${params.ENVIRONMENT}"
                }
                echo "✅ Liquibase deployment completed"
            }
        }
        
        stage('Post-Deployment Status') {
            when {
                expression { params.COMMAND == 'update' }
            }
            steps {
                echo "📊 Checking post-deployment status..."
                script {
                    sh "./scripts/run-liquibase-docker.sh status ${params.DATABASE} ${params.VERSION_OR_FILE} ${params.ENVIRONMENT}"
                }
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
        }
    }
}
