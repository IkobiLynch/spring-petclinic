pipeline {
    agent any

    environment {
        AWS_REGION = 'us-east-1'
        DB_PASSWORD = credentials('db_password')
        DOCKERHUB_CREDENTIALS = credentials('docker-hub-credentials')
        DOCKER_IMAGE_NAME = 'ikobilynch/spring-petclinic'
        POSTGRES_URL = "jdbc:postgresql://ilynch-db.cma1xp5df2gi.us-east-1.rds.amazonaws.com:5432/springAppDB"
        POSTGRES_USER = "myusername"
        POSTGRES_PASS  = credentials('db_password')
        SSH_CREDENTIALS_ID = 'ssh-key-id'  // Jenkins ID for the stored SSH private key
        SPRING_PROFILES_ACTIVE = 'postgres'
    }

    stages {
        stage('Checkout Code') {
            steps {
              script {
                echo "Branch name: ${env.BRANCH_NAME}"
                checkout([
                  $class: 'GitSCM',
                  branches: [[name: "${env.GIT_BRANCH}"]],
                  userRemoteConfigs: [[url: 'https://github.com/IkobiLynch/spring-petclinic.git']]
                ])
                echo "Branch name: ${env.BRANCH_NAME}"
              }
            }
        } 

        stage('Static Code Analysis') {
            when { 
              expression {
                return env.GIT_BRANCH != 'origin/main'
              } 
            }
            steps {
              echo "Current branch: ${env.GIT_BRANCH}"
              sh 'pwd'
              sh 'ls -al'
              echo 'Running static code analysis...'
              sh './gradlew check'
            }
        }

        stage('Run Tests') {
            when { 
              expression {
                return env.GIT_BRANCH != 'origin/main'
              }  
            }
            steps {
              echo 'Running tests...'
              sh './gradlew test'
            }
        }

        stage('Build Application') {
            steps {
              echo 'Building application...'
              sh './gradlew build'
            }
        }

        stage('Tagging and Versioning') {
            when { 
              expression {
                return env.GIT_BRANCH == 'origin/main'
              } 
             }
            steps {
              script {
              
                // Get previous tag or set default
                def previousTag = sh(
                  script: "git describe --tags --abbrev=0 || echo '0.0.0'",
                  returnStdout: true
                ).trim()

                // Remove v prefix
                if (previousTag.startsWith("v")) {
                  previousTag = previousTag.substring(1)
                }
                // Create new version tag
                def newVersion = sh(
                    script: "python3 -c 'import semver; print(semver.VersionInfo.parse(\"${previousTag}\").bump_minor())'",
                    returnStdout: true
                  ).trim()

                // Check if the tag already exists
                def tagExists = sh(
                    script: "git tag -l v${newVersion}",
                    returnStdout: true
                  ).trim()


                if (tagExists) {
                  echo "Tag v${newVersion} already exists. Skipping tag creation."
                } else {
                  // Create and push the new tag
                  sh "git tag ${newVersion}"
                  withCredentials([usernamePassword(credentialsId: 'github_credentials', passwordVariable: 'GITHUB_USERNAME', usernameVariable: 'GITHUB_TOKEN')]) {
                      sh "git push https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.com/IkobiLynch/spring-petclinic.git v${newVersion}"
                  }
                }
                
                // Set env variables
                env.APP_VERSION = newVersion
                currentBuild.displayName = "v${APP_VERSION}"
                }    
            }
        }

        stage('Create Docker Image') {
            steps {
              script {
                def imageTag = env.GIT_BRANCH == 'origin/main' ? env.APP_VERSION : env.GIT_COMMIT[0..6]
                sh "docker build -t ${DOCKER_IMAGE_NAME}:${imageTag} ."
              }    
            }
        }

        stage('Push Docker Image') {
            steps {
              script {
                def imageTag = env.GIT_BRANCH == 'origin/main' ? env.APP_VERSION : env.GIT_COMMIT[0..6]
                docker.withRegistry('https://index.docker.io/v1/', 'docker-hub-credentials') {
                  sh "docker push ${DOCKER_IMAGE_NAME}:${imageTag}"
                }  
              }
            }
        }

        stage('Deploy to AWS EC2 Instances') {
            when { 
              expression {
                return env.GIT_BRANCH == 'origin/main'
              } 
             }
            steps {
                input message: 'Deploy to production environment?'
                script {
                    // Define a variable for the image tag
                    def imageTag = env.APP_VERSION

                    // Use Ansible playbook in the infrastructure repo to deploy to EC2
                    withCredentials([sshUserPrivateKey(credentialsId: 'ssh-key-id', keyFileVariable: 'SSH_KEY')]) {
                        ansiblePlaybook inventory: 'GD_CP_infra/ansible/inventory.ini',
                                        playbook: 'GD_CP_infra/ansible/deploy_app.yml',
                                        extras: "--private-key=${SSH_KEY} --extra-vars 'image_name=${DOCKER_IMAGE_NAME}:${imageTag} POSTGRES_URL=${POSTGRES_URL} POSTGRES_USER=${POSTGRES_USER} POSTGRES_PASS=${POSTGRES_PASS} db_port=5432'"
                    }
                }
            }
        }
    }

    post {
      cleanup {
        // sleep(500)
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

