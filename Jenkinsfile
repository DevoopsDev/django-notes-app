pipeline {
    agent { label 'jenkins-agent-1' }

    environment {
        IMAGE_NAME = "notes-app"
        IMAGE_TAG = "${BUILD_NUMBER}"

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
      kubectl set image deployment/django-app \
        django=azuredevdevops/notes-app:${BUILD_NUMBER} \
        -n notes-app

      kubectl rollout status deployment/django-app -n notes-app
    '''
  }
}


    }

    post {
        success {
            echo "✅ Pipeline completed successfully"
        }
        failure {
            echo "❌ Pipeline failed"
        }
    }
}
