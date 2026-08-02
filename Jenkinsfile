pipeline {
    agent any

    triggers {
        pollSCM('H/5 * * * *')
    }

    environment {
        AUTH_IMAGE  = "rakeshv12/ott-auth-service"
        IMAGE_TAG   = "${BUILD_NUMBER}"
        GITHUB_REPO = 'https://github.com/rakeshv12/ott-platform.git'
    }

    stages {

        stage('Checkout') {
            steps {
                echo 'Pulling latest code from GitHub...'
                git branch: 'main', url: "${GITHUB_REPO}"
            }
        }

        stage('Build Auth Service') {
            steps {
                echo 'Building Auth Service image...'
                dir('backend/auth') {
                    script {
                        def authImage = docker.build("${AUTH_IMAGE}:${IMAGE_TAG}")
                        docker.withRegistry('https://index.docker.io/v1/', 'Docker') {
                            authImage.push("${IMAGE_TAG}")
                            authImage.push('latest')
                        }
                    }
                }
            }
        }

        stage('Update Manifests') {
            steps {
                echo 'Updating K8s image tag...'
                bat """
                    powershell -Command "(Get-Content k8s\\ott-backend\\auth-deployment.yaml) -replace 'ott-auth-service:.*', 'ott-auth-service:${IMAGE_TAG}' | Set-Content k8s\\ott-backend\\auth-deployment.yaml"
                """
            }
        }

        stage('Push Manifests to GitHub') {
            steps {
                echo 'Committing updated manifests...'
                script {
                    withCredentials([usernamePassword(
                        credentialsId: 'gitcred',
                        usernameVariable: 'GIT_USER',
                        passwordVariable: 'GIT_PASS'
                    )]) {
                        bat """
                            git config user.email "jenkins@ott-platform.com"
                            git config user.name "Jenkins CI"
                            git add k8s/ott-backend/auth-deployment.yaml
                            git diff --cached --quiet || git commit -m "ci: update auth image tag to build ${IMAGE_TAG}"
                            git push https://%GIT_USER%:%GIT_PASS%@github.com/rakeshv12/ott-platform.git main
                        """
                    }
                }
            }
        }
    }

    post {
        success {
            echo "SUCCESS - Auth Service Build ${IMAGE_TAG} pushed to Docker Hub and manifests updated"
        }
        failure {
            echo 'FAILED - check stage logs above'
        }
        always {
            bat "docker rmi ${AUTH_IMAGE}:${IMAGE_TAG} || exit 0"
        }
    }
}
