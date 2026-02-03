def IS_TAG = ''
def BUILD_TYPE = ''
def IMAGE_VERSION = ''
def NAME_SPACE = ''

pipeline {
  agent any

  environment {
    IMAGE_NAME = 'ci-cd-example'
    PROJECT_NAME = 'ci-cd-example'
    REGISTRY = 'quantumteknologi'
    GIT_REPO = 'github.com/terdiam/ci_cd_example.git'

    REGISTRY_CRED = 'registry-docker'
    REGISTRY_URL = 'https://index.docker.io/v2/'
    SONAR_CRED = 'sonarcube'
    SONAR_INSTALLATION = 'sonar-scanner'
    SONAR_SCANNER_TOOL = 'sonar-scanner'
    SLACK_BOT_WEBHOOK_URL = credentials('SLACK_BOT_WEBHOOK_URL')
    GROUP_TELEGRAM = credentials('group-telegram')
    BOT_TOKEN = credentials('TELEGRAM_BOT_TOKEN')

    KUBECONFIG_CREDENTIAL = 'rancher-prod'
  }

  triggers {
    githubPush()
  }

  options {
    skipDefaultCheckout(true)
    timestamps()
    disableConcurrentBuilds()
  }

  stages {

    /* =============================
     * Checkout
     * ============================= */
    stage('Checkout') {
      when {
        anyOf {
          branch 'master'
          branch 'stagging'
          branch 'development'
        }
      }
      steps {
        checkout scm
        echo "Branch: ${env.BRANCH_NAME}"
      }
    }

    /* =============================
     * Tag & Branch Validation
     * ============================= */
    stage('Branch & Tag Validation') {
      steps {
        script {
          sh 'git fetch --tags'

          IS_TAG = sh(
            script: "git describe --exact-match --tags || echo ''",
            returnStdout: true
          ).trim()

          if (!IS_TAG) {
            error("❌ Build must be triggered by TAG")
          }

          if (IS_TAG.startsWith('dev-') && env.BRANCH_NAME == 'development') {
            BUILD_TYPE = 'development'
            NAME_SPACE = 'dev'
          } else if (IS_TAG.startsWith('stag-') && env.BRANCH_NAME == 'stagging') {
            BUILD_TYPE = 'stagging'
            NAME_SPACE = 'stagging'
          } else if (IS_TAG.startsWith('prod-') && env.BRANCH_NAME == 'master') {
            BUILD_TYPE = 'production'
            NAME_SPACE = 'production'
          } else {
            error("❌ Tag prefix & branch mismatch")
          }

          IMAGE_VERSION = IS_TAG

          sendTelegram("🚀 *Pipeline Triggered*\nProject: *$PROJECT_NAME*\nBranch: *${env.BRANCH_NAME}*\nTag: *$IS_TAG*\nEnv: *$BUILD_TYPE*")
          sendSlack("🚀 Pipeline Triggered", PROJECT_NAME, env.BRANCH_NAME, IS_TAG, BUILD_TYPE, IMAGE_VERSION)
        }
      }
    }

    /* =============================
     * SonarQube
     * ============================= */
    stage('SonarQube Analysis') {
      steps {
        script {
          def scannerHome = tool name: SONAR_SCANNER_TOOL, type: 'hudson.plugins.sonar.SonarRunnerInstallation'
          withSonarQubeEnv(installationName: SONAR_INSTALLATION, credentialsId: SONAR_CRED) {
            sh """
              export PATH="${scannerHome}/bin:\${PATH}"
              sonar-scanner \
                -Dsonar.projectKey=${PROJECT_NAME} \
                -Dsonar.projectName=${PROJECT_NAME} \
                -Dsonar.exclusions=**/.nuxt/**,**/node_modules/**,**/dist/**
            """
          }
        }
      }
    }

    stage('Sonar Quality Gate') {
      steps {
        timeout(time: 20, unit: 'MINUTES') {
          waitForQualityGate abortPipeline: false
        }
      }
    }

    /* =============================
     * OWASP Dependency Check
     * ============================= */
    stage('OWASP Scan') {
      steps {
        dependencyCheck additionalArguments: '--scan ./', odcInstallation: 'dp'
        dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
      }
    }

    /* =============================
     * Trivy Security Scan
     * ============================= */
    stage('Trivy Security Scan') {
      steps {
        script {
            def severity = env.BRANCH_NAME == 'development'
                ? 'CRITICAL'
                : 'HIGH,CRITICAL'

            sh """
                trivy fs \
                --severity ${severity} \
                --ignore-unfixed \
                --exit-code 1 .
            """
            }
      }
    }

    /* =============================
     * Prepare Environment
     * ============================= */
    // stage('Prepare Environment') {
    //   steps {
    //     script {
    //       def envCred = BUILD_TYPE == 'production'
    //         ? 'env-prod'
    //         : BUILD_TYPE == 'stagging'
    //           ? 'env-stag'
    //           : 'env-dev'

    //       withCredentials([file(credentialsId: envCred, variable: 'ENV_FILE')]) {
    //         sh 'cp $ENV_FILE .env'
    //       }
    //     }
    //   }
    // }

    /* =============================
     * Unit Test
     * ============================= */
    stage('Unit Test') {
      steps {
        sh '''
          corepack enable
          pnpm install --frozen-lockfile
          pnpm test
        '''
      }
    }

    /* =============================
     * Docker Build
     * ============================= */
    stage('Docker Build') {
      steps {
        sh """
          docker build -t ${REGISTRY}/${IMAGE_NAME}:${IMAGE_VERSION} .
        """
      }
    }

    /* =============================
     * Trivy Image Scan
     * ============================= */
    stage('Trivy Image Scan') {
      steps {
        sh """
          trivy image --exit-code 1 --severity HIGH,CRITICAL \
          ${REGISTRY}/${IMAGE_NAME}:${IMAGE_VERSION}
        """
      }
    }

    /* =============================
     * Docker Push
     * ============================= */
    stage('Docker Push') {
      steps {
        withDockerRegistry(url: REGISTRY_URL, credentialsId: REGISTRY_CRED) {
          sh "docker push ${REGISTRY}/${IMAGE_NAME}:${IMAGE_VERSION}"
        }
      }
    }

    /* =============================
     * Deploy
     * ============================= */
    stage('Deploy to Kubernetes') {
      steps {
        withCredentials([file(credentialsId: KUBECONFIG_CREDENTIAL, variable: 'KUBECONFIG')]) {
          sh """
            export KUBECONFIG=${KUBECONFIG}
            kubectl set image deployment/${IMAGE_NAME} \
              ${IMAGE_NAME}=${REGISTRY}/${IMAGE_NAME}:${IMAGE_VERSION} \
              -n ${NAME_SPACE}
          """
        }
      }
    }
  }

  post {
    success {
      sendTelegram("✅ *DEPLOY SUCCESS*\nProject: $PROJECT_NAME\nEnv: $BUILD_TYPE\nTag: $IMAGE_VERSION")
      sendSlack("✅ Build Success", PROJECT_NAME, env.BRANCH_NAME, IS_TAG, BUILD_TYPE, IMAGE_VERSION)
    }
    failure {
      sendTelegram("❌ *DEPLOY FAILED*\nProject: $PROJECT_NAME\nEnv: $BUILD_TYPE\nTag: $IMAGE_VERSION")
      sendSlack("❌ Build Failed", PROJECT_NAME, env.BRANCH_NAME, IS_TAG, BUILD_TYPE, IMAGE_VERSION)
    }
    always {
      sh '''
        rm -f .env || true
        docker image prune -f || true
      '''
    }
  }
}

/* =============================
 * Notification Helpers
 * ============================= */
def sendTelegram(String message) {
  sh """
    curl -s -X POST https://api.telegram.org/bot${BOT_TOKEN}/sendMessage \
      -d chat_id=${GROUP_TELEGRAM} \
      -d text="${message}" \
      -d parse_mode=Markdown
  """
}

def sendSlack(String status, String project, String branch, String tag, String type, String version) {
  def payload = """
  {
    "text": "*${status}*\\n📦 Project: ${project}\\n🌿 Branch: ${branch}\\n🏷 Tag: ${tag}\\n🚀 Env: ${type}"
  }
  """
  sh """
    curl -X POST ${SLACK_BOT_WEBHOOK_URL} \
      -H 'Content-Type: application/json' \
      -d '${payload}'
  """
}
