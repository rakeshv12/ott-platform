pipeline {
    agent any

    triggers {
        pollSCM('H/5 * * * *')
    }

    environment {
        DOCKER_HUB_USER = 'rakeshv12'
        AUTH_IMAGE      = "rakeshv12/ott-auth-service"
        FRONTEND_IMAGE  = "rakeshv12/ott-frontend-web"
        IMAGE_TAG       = "${BUILD_NUMBER}"
        GITHUB_REPO     = 'https://github.com/rakeshv12/ott-platform.git'
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
                        authImage = docker.build("${AUTH_IMAGE}:${IMAGE_TAG}")
                    }
                }
            }
        }

        stage('Build Frontend') {
            steps {
                echo 'Building Frontend image...'
                dir('frontend/web') {
                    script {
                        frontendImage = docker.build("${FRONTEND_IMAGE}:${IMAGE_TAG}")
                    }
                }
            }
        }

        stage('Push to Docker Hub') {
            steps {
                echo 'Pushing images to Docker Hub...'
                script {
                    docker.withRegistry('https://index.docker.io/v1/', 'dockerhub-creds') {
                        authImage.push("${IMAGE_TAG}")
                        frontendImage.push("${IMAGE_TAG}")
                        authImage.push('latest')
                        frontendImage.push('latest')
                    }
                }
            }
        }

        stage('Update Manifests') {
            steps {
                echo 'Updating K8s image tags...'
                bat """
                    powershell -Command "(Get-Content k8s\\ott-backend\\auth-deployment.yaml) -replace 'rakeshv12/ott-auth-service:.*', 'rakeshv12/ott-auth-service:${IMAGE_TAG}' | Set-Content k8s\\ott-backend\\auth-deployment.yaml"
                """
                bat """
                    powershell -Command "(Get-Content k8s\\ott-frontend\\frontend-deployment.yaml) -replace 'rakeshv12/ott-frontend-web:.*', 'rakeshv12/ott-frontend-web:${IMAGE_TAG}' | Set-Content k8s\\ott-frontend\\frontend-deployment.yaml"
                """
            }
        }

        stage('Push Manifests to GitHub') {
            steps {
                echo 'Committing updated manifests...'
                bat """
                    git config user.email "jenkins@ott-platform.com"
                    git config user.name "Jenkins CI"
                    git add k8s/ott-backend/auth-deployment.yaml
                    git add k8s/ott-frontend/frontend-deployment.yaml
                    git commit -m "ci: update image tags to build ${IMAGE_TAG}"
                    git push origin main
                """
            }
        }
    }

    post {
        success {
            echo "SUCCESS - Build ${BUILD_NUMBER} deployed"
        }
        failure {
            echo 'FAILED - check stage logs above'
        }
        always {
            bat "docker rmi rakeshv12/ott-auth-service:${IMAGE_TAG} || exit 0"
            bat "docker rmi rakeshv12/ott-frontend-web:${IMAGE_TAG} || exit 0"
        }
    }
}
