pipeline {
  agent any

  environment {
    IMAGE_NAME = 'example-cicd'
    NAME_DEPLOYMENT = "example-cicd"
    REGISTRY = credentials('registry-docker')
    RANCHER_URL = credentials('rancher-url')
    CLUSTER_ID = 'local'
    PROJECT_ID = credentials('project-id')
    NAMESPACE = 'example'
    RANCHER_ACCESS_KEY = credentials('rancher-access-key')
    RANCHER_SCREET_KEY = credentials('rancher-screet-key')
  }

  triggers {
    githubPush()
  }

  stages {
    stage('Git Checkout') {
        steps {
            checkout scm
            // git branch: 'main', changelog: false, poll: false, url: 'https://github.com/terdiam/ci_cd_example.git' // if using cred git "credentialsId: ''"
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
        sh "docker build -t $REGISTRY/$IMAGE_NAME:latest ."
      }
    }

    stage('Push Docker Image') {
      steps {
        script {
          withDockerRegistry(credentialsId: 'bb6d4c11-0c95-4f28-90de-db262c4832f8') {
            sh "docker push $REGISTRY/$IMAGE_NAME:latest"
          }
        }
      }
    }

    stage('Deploy to Rancher') {
      steps {
        script {
          // Send deployment request to Rancher
          def response = sh(
            script: """
              curl -s -X POST "${RANCHER_URL}/project/${CLUSTER_ID}:${PROJECT_ID}/workloads/deployment:${NAMESPACE}:${NAME_DEPLOYMENT}?action=redeploy" \\
                -H "Authorization: Bearer ${RANCHER_ACCESS_KEY}:${RANCHER_SCREET_KEY}" \\
                -H "Content-Type: application/json" \\
            """,
            returnStdout: true
          ).trim()

          echo "Rancher API Response: ${response}"
        }
      }
    }    

  }
}
