pipeline {
    agent { label 'jenkins-agent-1' }

    environment {
        IMAGE_NAME = "notes-app"
        DOCKER_REPO = "azuredevdevops"
        IMAGE_TAG  = "${BUILD_NUMBER}"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                  echo "Building image: $IMAGE_NAME:$IMAGE_TAG"
                  docker build -t $IMAGE_NAME:$IMAGE_TAG .
                '''
            }
        }

        stage('Push to DockerHub') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerHubCreds',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh '''
                      echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                      docker tag $IMAGE_NAME:$IMAGE_TAG $DOCKER_USER/$IMAGE_NAME:$IMAGE_TAG
                      docker push $DOCKER_USER/$IMAGE_NAME:$IMAGE_TAG
                    '''
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                sh '''
                  echo "Deploying image to Kubernetes"
                  sed -i "s|notes-app:BUILD_TAG|$DOCKER_REPO/$IMAGE_NAME:$IMAGE_TAG|g" k8s/deployment.yaml
                  kubectl apply -f k8s/
                  kubectl rollout status deployment/django-app -n notes-app
                '''
            }
        }
    }

    post {
        failure {
            echo "❌ Deployment failed — rolling back"
            sh 'kubectl rollout undo deployment/django-app -n notes-app || true'
        }
        success {
            echo "✅ Deployment successful"
        }
    }
}
