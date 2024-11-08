pipeline {
    agent any

    environment {
        AWS_REGION = 'us-east-1'
        db_password = credentials('db_password')
        DOCKERHUB_CREDENTIALS = credentials('docker-hub-credentials')
        DOCKER_IMAGE_NAME = 'ikobilynch/spring-petclinic'
        DB_URL = "terraform-20241102004139871700000001.cma1xp5df2gi.us-east-1.rds.amazonaws.com" 
        SSH_CREDENTIALS_ID = 'ssh-key-id'  // Jenkins ID for the stored SSH private key
    }

    stages {
        stage('Clone Repositories') {
            steps {
              //git url: 'https://github.com/IkobiLynch/spring-petclinic.git', branch: "${env.BRANCH_NAME}"
              dir('GD_CP_infra'){
                git url: 'https://github.com/IkobiLynch/GD_CP_infra.git', branch: 'main'
                sh 'pwd'
                sh 'ls -al'
              }

              sh 'pwd'
              sh 'ls -al'
            }
        }

        stage('Static Code Analysis') {
            when { not { branch 'main' } }
            steps {
              sh 'pwd'
              sh 'ls -al'
              echo 'Running static code analysis...'
              sh './gradlew check'
            }
        }

        stage('Run Tests') {
            when { not { branch 'main' } }
            steps {
                dir('spring-petclinic') {
                    echo 'Running tests...'
                    sh './gradlew test'
                }
            }
        }

        stage('Build Application') {
            steps {
                dir('spring-petclinic') {
                    echo 'Building application...'
                    sh './gradlew build'
                }
            }
        }

        stage('Tagging and Versioning') {
            when { branch 'main' }
            steps {
                dir('spring-petclinic') {
                    echo 'Updating version tag...'
                    sh './gradlew release'
                    script {
                        def version = readFile('version.txt').trim()
                        env.APP_VERSION = version
                        currentBuild.displayName = "v${APP_VERSION}"
                    }
                }
            }
        }

        stage('Create Docker Image') {
            steps {
                dir('spring-petclinic') {
                    script {
                        def imageTag = env.BRANCH_NAME == 'main' ? env.APP_VERSION : env.GIT_COMMIT[0..6]
                        sh "docker build -t ${DOCKER_IMAGE_NAME}:${imageTag} ."
                    }
                }
            }
        }

        stage('Push Docker Image') {
            steps {
                dir('spring-petclinic') {
                    script {
                        def imageTag = env.BRANCH_NAME == 'main' ? env.APP_VERSION : env.GIT_COMMIT[0..6]
                        docker.withRegistry('https://index.docker.io/v1/', 'docker-hub-credentials') {
                            sh "docker push ${DOCKER_IMAGE_NAME}:${imageTag}"
                        }
                    }
                }
            }
        }

        stage('Deploy to AWS EC2 Instances') {
            when { branch 'main' }
            steps {
                input message: 'Deploy to production environment?'
                script {
                    // Define a variable for the image tag
                    def imageTag = env.APP_VERSION

                    // Use Ansible playbook in the infrastructure repo to deploy to EC2
                    withCredentials([sshUserPrivateKey(credentialsId: 'ssh-key-id', keyFileVariable: 'SSH_KEY')]) {
                        ansiblePlaybook inventory: 'GD_CP_infra/ansible/inventory.ini',
                                        playbook: 'GD_CP_infra/ansible/deploy_app.yml',
                                        extras: "--private-key=${SSH_KEY} --extra-vars 'docker_image=${DOCKER_IMAGE_NAME}:${imageTag} db_url=${DB_URL}'"
                    }
                }
            }
        }
    }

    post {
      cleanup {
        cleanWs()
      }
        success {
            echo 'Pipeline completed successfully!'
        }
        failure {
            echo 'Pipeline failed. Check the logs for details.'
        }
    }
}
