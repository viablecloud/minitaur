pipelineJob('Infrastructure/NonProduction/landing-zone-destroyer-test-nprd') {
    definition {
        cps {
            sandbox(true)
            script('''
pipeline {
    agent any

    options {
        disableConcurrentBuilds()
        timeout(time: 1, unit: 'HOURS')
        skipDefaultCheckout()
    }

    environment {
        BITBUCKET_COMMON_CREDS = credentials('BITBUCKET_COMMON_CREDS')
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
                            defaultValue: 'minitaur',
                            description: 'The name of the GitHub repository',
                            name: 'repositoryName'
                        )]
                    )
                    env.REPOSITORY_NAME = repoInput

                    def repoSpaceInput = input(
                        message: 'Please enter the repository namespace',
                        parameters: [string(
                            defaultValue: 'viablecloud',
                            description: 'The name of the GitHub Namespace/Organisation Space',
                            name: 'repositoryNameSpace'
                        )]
                    )
                    env.REPOSITORY_NAMESPACE = repoSpaceInput

                    echo "Using repository: ${env.REPOSITORY_NAMESPACE}/${env.REPOSITORY_NAME}"
                }
            }
        }

        stage("Getting Azure CSF Landing Zone Foundations") {
            steps {
                cleanWs()

                withCredentials([usernamePassword(credentialsId: 'BITBUCKET_COMMON_CREDS', 
                                                usernameVariable: 'BITBUCKET_COMMON_CREDS_USR', 
                                                passwordVariable: 'BITBUCKET_COMMON_CREDS_PSW')]) {
                    script {
                        def gitUrl = "https://${BITBUCKET_COMMON_CREDS_USR}:${BITBUCKET_COMMON_CREDS_PSW}@github.com/${env.REPOSITORY_NAMESPACE}/${env.REPOSITORY_NAME}.git"
                        checkout([$class: 'GitSCM',
                                branches: [[name: "*/${CURRENT_BRANCH}"]],
                                userRemoteConfigs: [[url: gitUrl]]])
                    }
                }
            }
        }

        stage("Extracting landing zone environment variables") {
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
                        env.lzCode = "lz000" //userInput
                        
                        def props = readProperties(file: "${env.lzCode}.conf")
                        props.each { k, v -> 
                            env[k] = v
                        }
                    } catch (Exception e) {
                        error "Failed to process landing zone configuration"
                    }
                }
            }
        }

        stage("Configuring Azure Access") {
            steps {
                script {
                    sh 'chmod +x ./login.sh'
                    sh './login.sh'
                }
            }
        }

        stage("Validating Current Infrastructure Destroy") {
            steps {
                script {
                    sh 'pwd'
                    sh 'ls -l'
                    sh './destroy_azure_resources_test.sh exclude.txt'
                }
            }
        }
                
        stage("Deployment Summary") {
            steps {
                script {
                    sh 'echo "================== BEGIN VALIDATION ========="'
                    sh 'pwd'
                    sh 'ls -l'
                    sh 'echo "================== DONE VALIDATING =========="'
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
''')
        }
    }
}
