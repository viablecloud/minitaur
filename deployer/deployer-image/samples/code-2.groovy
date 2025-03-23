pipeline {
    agent any

    options {
        disableConcurrentBuilds()
        timeout(time: 1, unit: 'HOURS')
        skipDefaultCheckout()
    }

    environment {
        BITBUCKET_COMMON_CREDS = credentials('BITBUCKET_COMMON_CREDS')
        REPOSITORY_CREDS = credentials('REPOSITORY_INFO')
        CURRENT_BRANCH = "main"
        PIPELINE_LOG_LEVEL = 'INFO'
    }

    stages {
        
        stage("Input Repository Name") {
            steps {
                script {
                    def repoInput = input(
                        message: 'Please enter the repository name',
                        parameters: [string(
                            defaultValue: 'my-repository',
                            description: 'The name of the GitHub repository',
                            name: 'repositoryName'
                        )]
                    )
                    env.REPOSITORY_NAME = repoInput
                }
            }
        }

        stage("Checkout Repository") {
            steps {
                cleanWs()
                script {
                    withCredentials([
                        usernamePassword(credentialsId: 'BITBUCKET_COMMON_CREDS', 
                                         usernameVariable: 'BITBUCKET_USER', 
                                         passwordVariable: 'BITBUCKET_PASS'),
                        usernamePassword(credentialsId: 'REPOSITORY_INFO', 
                                         usernameVariable: 'REPO_USER', 
                                         passwordVariable: 'REPO_PASS')
                    ]) {
                        def gitUrl = "https://github.com/${env.REPO_USER}/${env.REPOSITORY_NAME}.git"
                        checkout([$class: 'GitSCM',
                                  branches: [[name: "*/${CURRENT_BRANCH}"]],
                                  userRemoteConfigs: [[
                                      url: gitUrl,
                                      credentialsId: 'BITBUCKET_COMMON_CREDS'
                                  ]]])
                    }
                }
            }
        }

        stage("Input Step") {
            steps {
                script {
                    try {
                        /*
                        def userInput = input(
                            message: 'Please enter landing zone code',
                            parameters: [string(
                                defaultValue: 'lz000',
                                description: 'The name of the assigned landing zone for this application',
                                name: 'lzCode'
                            )]
                        )
                        */
                        env.lzCode = "lz000"

                        // Test with minimal property reading
                        def props = []  // Stubbed for simplified testing
                    } catch (Exception e) {
                        error "Failed to process landing zone configuration"
                    }
                }
            }
        }
    }

    post {
        always {
            cleanWs()
        }
        failure {
            script {
                echo "Pipeline failed. Cleaning up..."
            }
        }
    }
}
