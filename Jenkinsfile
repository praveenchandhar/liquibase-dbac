pipeline {
    agent any
    
    parameters {
        gitParameter(
            name: 'BRANCH',
            type: 'PT_BRANCH',
            branchFilter: 'origin/(.*)',
            defaultValue: 'main',
            description: 'Select branch to deploy from',
            selectedValue: 'DEFAULT'
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
            description: 'Version (e.g., 24092025) or specific file path (e.g., db/mongodb/weekly_release/24092025/testing.yaml)'
        )
        booleanParam(
            name: 'DRY_RUN',
            defaultValue: false,
            description: 'Run status only (even if update is selected)'
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
                    checkout([
                        $class: 'GitSCM',
                        branches: [[name: params.BRANCH]],
                        userRemoteConfigs: [[
                            url: scm.userRemoteConfigs[0].url,
                            credentialsId: scm.userRemoteConfigs[0].credentialsId
                        ]]
                    ])
                }
                
                echo "✅ Repository checked out successfully"
                sh 'git log --oneline -5'
            }
        }
        
        stage('Setup Dependencies') {
            steps {
                script {
                    echo "🔧 Setting up Liquibase dependencies..."
                    sh 'chmod +x scripts/setup-dependencies.sh'
                    sh './scripts/setup-dependencies.sh'
                    
                    echo "📦 Verifying JAR files:"
                    sh 'ls -la lib/'
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
                    
                    // Determine if VERSION_OR_FILE is a file path or version
                    if (params.VERSION_OR_FILE.contains('/')) {
                        env.CHANGESET_FILE = params.VERSION_OR_FILE
                        echo "📄 Using specific file: ${env.CHANGESET_FILE}"
                    } else {
                        env.VERSION = params.VERSION_OR_FILE
                        echo "📅 Using version: ${env.VERSION}"
                    }
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
                    
                    sh """
                        chmod +x scripts/run-liquibase.sh
                        ./scripts/run-liquibase.sh ${actualCommand} ${params.DATABASE} "${params.VERSION_OR_FILE}"
                    """
                }
            }
        }
    }
    
    post {
        always {
            echo "🏁 Pipeline execution completed"
            archiveArtifacts artifacts: 'db/**/*.yaml', allowEmptyArchive: true
            archiveArtifacts artifacts: 'liquibase-output.sql', allowEmptyArchive: true
        }
        
        success {
            echo "🎉 Pipeline completed successfully!"
        }
        
        failure {
            echo "❌ Pipeline failed!"
        }
        
        cleanup {
            cleanWs(cleanWhenNotBuilt: false,
                    deleteDirs: true,
                    disableDeferredWipeout: true,
                    notFailBuild: true)
        }
    }
}
