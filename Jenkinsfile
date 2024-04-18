pipeline {
  agent any
  /*{ 
    dockerfile {
      additionalBuildArgs ''
      args '--cgroupns=host --entrypoint=' // Include additional required arguments for docker run here
    } 
  } */
  environment {
    NEXUS_URL = 'http://localhost:8084' //local host nexu repo url
    NEXUS_MR_REPO = "${env.NEXUS_URL}/repository/mr" //path to the specific docker repo appended to nexus url
    NEXUS_MAIN_REPO = "${env.NEXUS_URL}/repository/main" //path to the specific docker repo appended to nexus url
    REGISTRY_CREDENTIALS_ID = 'nexus-credentials' //ID of nexus credentials specified in Jenkins
    DOCKER_IMAGE = 'spring-petclinic'
    DOCKER_REGISTRY = 'https://registry.hub.docker.com' // Official DOcker Hub URL
    DOCKERHUB_NAME = 'ikobilynch'
    DOCKERHUB_CREDENTIALS = 'docker_login'
  }
  stages {
    stage('Checkstyle') {
      when {
        not {
          branch 'main'
        }
      }
      steps {
        script {
          sh './gradlew checkstyleMain'
          archiveArtifacts artifacts: 'build/reports/checkstyle/*.html', fingerprint: true
        }
      }
    }
    stage('Test') {
      when {
        not {
          branch 'main'
        }
      }
      steps {
        script {
          sh './gradlew test'
        }
      }
    }
    stage('Build') {
      when {
        not {
          branch 'main'
        }
      }
      steps {
        script {
          sh './gradlew assemble -x test'
        }
      }
    }
    stage('Create Docker Image and Push to MR') {
      when {
        not {
          branch 'main'
        }
      }
      steps {
        script {
          docker.withRegistry("https://${env.DOCKER_REGISTRY}", "${env.DOCKERHUB_CREDENTIALS}") {
            def app = docker.build("${env.DOCKERHUB_NAME}/myapp:${env.GIT_COMMIT[0..7]}")
            app.push()
          }
        }
      }
    }

    stage('Docker Build and Push (Main)') {
      when {
        branch 'main'
      }
      steps {
        script {
          sh 'echo "Test ====== $PATH"'
          withEnv(["PATH+DOCKER=/usr/local/bin/docker"]) {
            sh 'echo "TEST 2 ==== $PATH"'
            sh 'docker --version'
            def app = docker.build("${env.DOCKERHUB_NAME}/main:${env.GIT_COMMIT[0..7]}")
            app.push("latest")
          }
          sh 'echo "TEST AGAIN ==== $PATH"'
          
          
        }
      }
    }
    
  }
}
