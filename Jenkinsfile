pipeline {
    agent any

    environment {
        AWS_REGION = 'us-east-1'
        DB_PASSWORD = credentials('db_password')
        DOCKERHUB_CREDENTIALS = credentials('docker-hub-credentials')
        DOCKER_IMAGE_NAME = 'ikobilynch/spring-petclinic'
        POSTGRES_URL = "ilynch-db.cma1xp5df2gi.us-east-1.rds.amazonaws.com"
        DB_NAME = "springAppDB"
        DB_HOST = "ilynch-db.cma1xp5df2gi.us-east-1.rds.amazonaws.com"
        DB_USERNAME = "myusername"
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

                sh "git clone 'https://github.com/IkobiLynch/GD_CP_infra.git'"
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
            steps {
              script {
                
                // Check if app code changed
                def hasCodeChanges = sh(
                  script: "git diff --name-only HEAD^ HEAD | grep src/ || echo 'no-changes'",
                  returnStdout: true
                )

                // Get latest tag in repo
                sh 'git fetch --tags'

                // Get previous tag or set default
                def previousTag = sh(
                  script: "git describe --tags --abbrev=0 || echo '0.0.0'",
                  returnStdout: true
                ).trim()

                // Remove v prefix
                if (previousTag.startsWith("v")) {
                  previousTag = previousTag.substring(1)
                }

                if (hasCodeChanges == 'no-changes') {
                  echo "No application code changes detected. Skipping version bump."
                  env.APP_VERSION = previousTag
                } else {
                  // Detmine version bump based on branch
                  def bumpType = 'bump_patch' // Default for non main branches

                  if (env.GIT_BRANCH == 'origin/main') {
                    bumpType = 'bump_minor'
                  } else if (env.GIT_BRANCH.startsWith('origin/release/')) {
                    bumpType = 'bump_major'
                  }

                  // Create new version tag & increment based on branch
                  def newVersion = sh(
                    script: "python3 -c 'import semver; print(semver.VersionInfo.parse(\"${previousTag}\").${bumpType}())'",
                    returnStdout: true
                  ).trim()

                  def tagExists = sh(
                    script: "git tag -l v${newVersion}", 
                    returnStdout: true
                  ).trim()
                  
                  // Create commit message var to be used in tag creation
                  def commitMessage = sh(
                    script: 'git log -1 --pretty=%B',
                    returnStdout: true
                  ).trim()
                  echo "Commit Message: ${commitMessage}"

                  def gitCommitterName = sh(
                    script: "echo ${GIT_COMMITTER_NAME:-'Ikobi Test'}",
                    returnStdout: true
                  )
                  echo "Committer name: ${gitCommitterName}"

                  def gitCommitterEmail = sh(
                    script: "echo ${GIT_COMMITTER_EMAIL:-'ikobi.lynch@macys.com'}",
                    returnStdout: true
                  )
                  echo "Committer Email: ${gitCommitterEmail}"

                  // Configure git with name & email
                  sh "git config --global user.email '${gitCommitterEmail}'"
                  sh "git config --global user.name '${gitCommitterName}'"

                  if (!tagExists) {
                    sh "git tag -a v${newVersion} -m '${commitMessage.replace("'", "\\'")}'"
                    withCredentials([usernamePassword(credentialsId: 'github_credentials', passwordVariable: 'GITHUB_TOKEN', usernameVariable: 'GITHUB_USERNAME')]) {
                        sh "git push https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.com/IkobiLynch/spring-petclinic.git v${newVersion}"
                    }
                  }
                  // Set env variable with new tag version
                  env.APP_VERSION = newVersion
                }
                
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
                    ansiblePlaybook inventory: 'GD_CP_infra/Ansible/inventory.ini',
                                    playbook: 'GD_CP_infra/Ansible/playbooks/deploy_app.yml',
                                    extras: "--private-key=${SSH_KEY} --extra-vars 'image_name=${DOCKER_IMAGE_NAME}:${imageTag} POSTGRES_USER=${POSTGRES_USER} POSTGRES_PASS=${POSTGRES_PASS} SPRING_PROFILES_ACTIVE=${SPRING_PROFILES_ACTIVE} DB_HOST=${DB_HOST} db_port=5432 DB_NAME=${DB_NAME}'"
                }
              }
            }
          }
    }

    post {
      cleanup {
        script {
          sh 'docker builder prune -f'
          sh 'docker image prune -f'
          sh 'docker container prune -f'
          // sleep(500)
          cleanWs()
        }
      }
        success {
            echo 'Pipeline completed successfully!'
        }
        failure {
            echo 'Pipeline failed. Check the logs for details.'
        }
    }
}

