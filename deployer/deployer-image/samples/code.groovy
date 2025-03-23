
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
        PIPELINE_LOG_LEVEL = 'FINEST'
    }

    stages {

        stage("Getting Azure CSF Landing Zone Foundations") {
            steps {
                script {
                    env.ORG_REPO_SPACE = REPOSITORY_CREDS_USR
                    env.GIT_REPO = REPOSITORY_CREDS_PSW
                }

                cleanWs()

                withCredentials([
    usernamePassword(credentialsId: 'REPOSITORY_INFO', 
                     usernameVariable: 'REPO_SPACE', 
                     passwordVariable: 'REPO_NAME')
]) {
    withCredentials([
        usernamePassword(credentialsId: 'BITBUCKET_COMMON_CREDS', 
                         usernameVariable: 'BITBUCKET_USER', 
                         passwordVariable: 'BITBUCKET_PASS')
    ]) {
        def gitUrl = "https://github.com/${env.REPO_SPACE}/${env.REPO_NAME}.git"
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

        stage("Extracting landing zone environment variables") {
            steps {
                script {
                    try {
                        def userInput = input(
                            message: 'Please enter landing zone code',
                            parameters: [string(
                                defaultValue: 'lz000',
                                description: 'The name of the assigned landing zone for this application',
                                name: 'lzCode'
                            )]
                        )
                        env.lzCode = userInput

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