def GIT_TAG_NAME = ''
def GIT_COMMIT = ''
def IS_TAG = ''
def GIT_BRANCH = ''
def IS_BUILD_BRANCH_MASTER = false
def IS_BUILD_BRANCH_DEVELOPMENT = false

pipeline {
  agent any

  environment {
    IMAGE_NAME = 'example-cicd'
    NAME_DEPLOYMENT = "example-cicd"
    REGISTRY = credentials('registry-docker')
  }

  triggers {
    githubPush()
  }  

  options {
    skipDefaultCheckout(true)
  }
  
  stages {
    stage('Git Checkout') {
        steps {
            checkout scm
        }
    }

    stage('Branch Main check') {
      when {
        branch 'main'
      }
      steps {
        script {
          GIT_BRANCH = 'main'
          IS_TAG = sh(script: "git describe --exact-match --tags || echo ''", returnStdout: true).trim()
          echo "IS_TAG: $IS_TAG"
          if (IS_TAG) {
            IS_BUILD_BRANCH_MASTER = true
            GIT_TAG_NAME = IS_TAG
          } else {
            IS_BUILD_BRANCH_MASTER = false
          }
        }
      }
    }

    stage('Branch Development check') {
      when {
        branch 'development'
      }
      steps {
        script {
          GIT_BRANCH = 'development'
          IS_TAG = sh(script: "git describe --exact-match --tags || echo ''", returnStdout: true).trim()
          echo "IS_TAG: $IS_TAG"
          if (IS_TAG) {
            IS_BUILD_BRANCH_DEVELOPMENT = true
            GIT_TAG_NAME = IS_TAG
          } else {
            IS_BUILD_BRANCH_DEVELOPMENT = false
          }
        }
      }
    }         

    stage('Sonarcube Analisys') {
      environment {
        scannerHome = tool 'sonar-scanner';
      }
      steps {
        withSonarQubeEnv(credentialsId: 'sonarcube', installationName: 'sonar-scanner') {
          sh "${scannerHome}/bin/sonar-scanner -Dsonar.projectName=cicd-example -Dsonar.projectKey=cicd-example"
        }
      }
    }

    stage('OWASP SCAN') {
        steps {
            dependencyCheck additionalArguments: ' --scan ./', nvdCredentialsId: '7225b970-460c-4b83-ad2f-89f58888ca0f', odcInstallation: 'dp'
            dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
        }
    }

    stage('Security Scan: Trivy') {
      steps {
        sh 'trivy fs --exit-code 1 . || echo "Vulnerabilities found"'
      }
    }

    stage('Build Docker Image development') {
      when {
        expression {
          IS_BUILD_BRANCH_DEVELOPMENT
        }
      }
      steps {
        sh "docker build -t $REGISTRY/$IMAGE_NAME:$GIT_TAG_NAME ."
      }
    }

    stage('Build Docker Image Main') {
      when {
        expression {
          IS_BUILD_BRANCH_MASTER
        }
      }
      steps {
        sh "docker build -t $REGISTRY/$IMAGE_NAME:$GIT_TAG_NAME ."
      }
    }

    stage('Push Docker Image development') {
      when {
        expression {
          IS_BUILD_BRANCH_DEVELOPMENT
        }
      }
      steps {
        script {
          withDockerRegistry(credentialsId: 'bb6d4c11-0c95-4f28-90de-db262c4832f8') {
            sh "docker push $REGISTRY/$IMAGE_NAME-dev:$GIT_TAG_NAME"
          }
        }
      }
    }

    stage('Push Docker Image master') {
      when {
        expression {
          IS_BUILD_BRANCH_MASTER
        }
      }
      steps {
        script {
          withDockerRegistry(credentialsId: 'bb6d4c11-0c95-4f28-90de-db262c4832f8') {
            sh "docker push $REGISTRY/$IMAGE_NAME:$GIT_TAG_NAME"
          }
        }
      }
    }
  }

  post {
    always {
        sh 'rm -f dependency-check-report.xml'
    }
  }

}
