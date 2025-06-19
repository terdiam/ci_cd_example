pipeline {
  agent any

  environment {
    IMAGE_NAME = 'example-cicd'
    NAME_DEPLOYMENT = "example-cicd"
    REGISTRY = credentials('registry-docker')
    GIT_TAG_NAME = ''
  }

  triggers {
    githubPush()
  }

  stages {
    stage('Git Checkout') {
        steps {
            checkout scm
        }
    }

    stage('Detect Tag') {
        steps {
            sh 'git fetch --tags'
            def tag = sh(script: "git describe --tags --exact-match || true", returnStdout: true).trim()
            env.GIT_TAG_NAME = tag
            echo "Tag Github: ${env.GIT_TAG_NAME}"
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

    stage('Build Docker Image') {
      steps {
        sh "docker build -t $REGISTRY/$IMAGE_NAME:$GIT_TAG_NAME ."
      }
    }

    stage('Push Docker Image') {
      steps {
        script {
          withDockerRegistry(credentialsId: 'bb6d4c11-0c95-4f28-90de-db262c4832f8') {
            sh "docker push $REGISTRY/$IMAGE_NAME:$GIT_TAG_NAME"
          }
        }
      }
    }

  }
}
