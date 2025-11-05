pipeline {
  agent any
  options { timestamps() }

  // parameters {
  //   string(name: 'NEXUS_URL', description: 'Optional custom PyPI/simple index URL')
  //   string(name: 'DEV_DIR',  description: 'Destination directory (absolute or relative)')
  //   string(name: 'NEXUS_CREDS_ID', description: 'Jenkins credentialsId (username+password). Leave empty to use params below.')
  //   string(name: 'NEXUS_USER', description: 'Only used if NEXUS_CREDS_ID is empty')
  //   password(name: 'NEXUS_PASS', description: 'Only used if NEXUS_CREDS_ID is empty')   
  //   string(name: 'REQUIREMENTS', description: 'requirements.txt') 
  //   string(name: 'CUSTOM_REQUIREMENTS', description: 'custom_requirements.txt') 
  // }

  environment {
    NEXUS_URL    = "${params.NEXUS_URL}"
    DEV_DIR_RAW  = "${params.DEV_DIR}"
    BUILD_NUMBER = "${params.BUILD_NUMBER}"
    REQUIREMENTS = "${params.REQUIREMENTS}"
    CUSTOM_REQUIREMENTS = "${params.CUSTOM_REQUIREMENTS}"
  }

  stages {

    stage('Checkout') {
      steps {
        script {
          echo "Cleaning and preparing workspace..."
          cleanWs()
          checkout scm
          echo "Branch: ${env.BRANCH_NAME ?: 'N/A'}"
          echo "Workspace: ${env.WORKSPACE}"
        }
      }
    }

    stage('Prepare') {
      steps {
        script {
          // Normalize DEV_DIR for OS
          env.DEV_DIR = isUnix()
            ? env.DEV_DIR_RAW.replace('\\', '/')
            : env.DEV_DIR_RAW.replace('/', '\\')

          // Use Jenkins credentials if provided, else fall back to params
     
          def prep = {
            if (isUnix()) {
              sh '''
              echo "Creating development directory..."
              if [ -d "$DEV_DIR_RAW" ]; then
                echo "Cleaning existing directory: $DEV_DIR_RAW"
                rm -rf "${DEV_DIR_RAW:?}/"*
              else
                echo "Creating directory: $DEV_DIR"
                mkdir -p "$DEV_DIR_RAW"
              fi
              echo "Development directory created"
              set -euo pipefail
              set -euo pipefail
              printf "%s" "${NEXUS_USER}" > "./nexus_user"
              printf "%s" "${NEXUS_PASS}" > "./nexus_pass"
              curl -fsSL -o "./requirements.txt" ${REQUIREMENTS}
              curl -fsSL -o "./custom_requirements.txt" ${CUSTOM_REQUIREMENTS}
              rm -rf ./.git
              cp -r ./* ${DEV_DIR_RAW}
              echo "Development env prepared."
              '''
            } else {
              bat '''
              echo Creating development directory...
              if exist "%DEV_DIR_RAW%" (
                  echo Cleaning existing directory: %DEV_DIR_RAW%
                  rmdir /s /q "%DEV_DIR_RAW%\\*"
              ) else (
                  echo Creating directory: %DEV_DIR_RAW%
                  mkdir "%DEV_DIR_RAW%"
              )
              echo Development directory created
              echo %NEXUS_USER% > ".\\nexus_user"
              echo %NEXUS_PASS% > ".\\nexus_pass"
              curl -L -o ".\\requirements.txt" %REQUIREMENTS%
              curl -L -o ".\\custom_requirements.txt" %CUSTOM_REQUIREMENTS%
              rmdir /s /q ".\\.git"
              xcopy * "%DEV_DIR_RAW%" /E /H /K /Y /I
              echo Development env prepared.
              '''
            }
          }

          if (params.NEXUS_CREDS_ID?.trim()) {
              withCredentials([usernamePassword(credentialsId: params.NEXUS_CREDS_ID, usernameVariable: 'NEXUS_USER', passwordVariable: 'NEXUS_PASS')]) {
              prep()
              }
          } else {
              withEnv(["NEXUS_USER=${params.NEXUS_USER}", "NEXUS_PASS=${params.NEXUS_PASS}"]) {
              prep()
              }
          }

          
        }
      }
    }

    stage('Build up services') {
      steps {
        script {

          def shell = { String cmd ->
            def dir = env.DEV_DIR
            if (isUnix()) {
                sh"""
                set -e
                cd "${env.DEV_DIR}"
                echo "" > README.md
                ${cmd}
                rm -rf nexus_user nexus_pass .env Dockerfile Jenkinsfile \
                docker-compose.yaml requirements.txt custom_requirements.txt
                """
            } else {
                bat"""
                cd /d "${env.DEV_DIR}"
                type "" > README.md
                ${cmd}
                del /F /Q "nexus_user" "nexus_pass" ".env" "Dockerfile" "Jenkinsfile" ^
                "docker-compose.yaml" "requirements.txt" "custom_requirements.txt" 2>nul
                """
            }
          }

          withEnv(["NEXUS_URL=${params.NEXUS_URL}"]) {
          shell("""
            docker compose version
            docker compose up -d
          """)
   
        }
      }
    }
  }

  }


  post {
    always {
      // Optional: keep logs/artifacts if you want
      echo "DEV_DIR resolved to: ${env.DEV_DIR}"
    }
  }
}

