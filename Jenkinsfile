pipeline {
  agent any
  environment {
    NEXUS_URL = 'http://127.0.0.1:8081' //local host nexu repo url
    NEXUS_MR_REPO = "${env.NEXUS_URL}/repository/mr" //path to the specific docker repo appended to nexus url
    NEXUS_MAIN_REPO = "${env.NEXUS_URL}/repository/main" //path to the specific docker repo appended to nexus url
    REGISTRY_CREDENTIALS_ID = 'nexus-credentials' //ID of nexus credentials specified in Jenkins
    DOCKER_IMAGE = 'spring-petclinic'
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
          docker.withRegistry("${env.NEXUS_MR_REPO}", "${env.REGISTRY_CREDENTIALS_ID}") {
            def app = docker.build("myapp:${env.GIT_COMMIT[0..7]}")
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
          docker.withRegistry("${env.NEXUS_MAIN_REPO}", "${env.REGISTRY_CREDENTIALS_ID}") {
            def app = docker.build("${env.DOCKER_IMAGE}:latest")
            app.push("latest")
          }
        }
      }
    }
    
  }
}
