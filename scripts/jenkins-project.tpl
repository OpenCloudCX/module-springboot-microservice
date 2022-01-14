<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job@2.42">
  <actions>
    <org.jenkinsci.plugins.pipeline.modeldefinition.actions.DeclarativeJobAction plugin="pipeline-model-definition@1.9.2"/>
    <org.jenkinsci.plugins.pipeline.modeldefinition.actions.DeclarativeJobPropertyTrackerAction plugin="pipeline-model-definition@1.9.2">
      <jobProperties/>
      <triggers/>
      <parameters/>
      <options/>
    </org.jenkinsci.plugins.pipeline.modeldefinition.actions.DeclarativeJobPropertyTrackerAction>
  </actions>
  <description></description>
  <keepDependencies>false</keepDependencies>
  <properties/>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition" plugin="workflow-cps@2.93">
    <script>pipeline {
  environment {
    PROJECT_GITHUB = &quot;https://github.com/ODOS-Technical-Challenge/springboot-microservice-template.git&quot;
	PROJECT_NAME   = &quot;springboot-microservice-template&quot;
	IMAGE_NAME     = &quot;springboot-microservice-template-app&quot;
	BUILD_NUMBER   = &quot;1.0&quot;
    REGISTRY       = &quot;index.docker.io&quot;
    REPOSITORY     = &quot;rivasolutionsinc&quot;
    BRANCH         = &quot;main&quot;
  }
  agent {
    kubernetes {
      label &apos;springboot-microservice-template-build&apos;
      yaml &quot;&quot;&quot;
kind: Pod
metadata:
  name: kaniko
spec:
  containers:
  - name: java-builder
    image: maven
    command:
      - sleep
    args:
      - 99d
  - name: crane
    workingDir: /home/jenkins
    image: gcr.io/go-containerregistry/crane:debug
    imagePullPolicy: Always
    command:
    - /busybox/cat
    tty: true
    volumeMounts:
      - name: jenkins-docker-cfg
        mountPath: /root/.docker/
  - name: alpine
    workingDir: /home/jenkins
    image: alpine:latest
    imagePullPolicy: Always
    command:
    - /bin/cat
    tty: true
  - name: alpine-builder
    workingDir: /home/jenkins
    image: openjdk:8-jdk-alpine
    imagePullPolicy: Always
    command:
    - /bin/cat
    tty: true
  - name: jnlp
    workingDir: /home/jenkins
  - name: kaniko
    workingDir: /home/jenkins
    image: gcr.io/kaniko-project/executor:debug
    imagePullPolicy: Always
    command:
    - /busybox/cat
    tty: true
    volumeMounts:
      - name: jenkins-docker-cfg
        mountPath: /kaniko/.docker
  volumes:
  - name: jenkins-docker-cfg
    projected:
      sources:
      - secret:
          name: riva-dockerhub
          items:
            - key: .dockerconfigjson
              path: config.json
&quot;&quot;&quot;
    }
  }
  stages {
    stage(&apos;Checkout&apos;) {
      steps {
        git branch: env.BRANCH, url: env.PROJECT_GITHUB
      }
    }
    stage(&apos;Prep container&apos;) {
        steps {
          container(name: &apos;alpine-builder&apos;) {
            sh &apos;apk update &amp;&amp; apk add git maven&apos;
          }
        }
    }
    stage(&apos;Create dependencies&apos;) {   
      steps {
        container(name: &apos;alpine-builder&apos;) {
            sh &apos;mvn compile dependency:copy-dependencies -DincludeScope=test&apos;
            sh &apos;mv target/dependency target/test-dependency&apos;
            sh &apos;mvn compile dependency:copy-dependencies -DincludeScope=runtime&apos;
        }
      }
    }
    stage(&apos;Run tests&apos;) {   
      steps {
        container(name: &apos;alpine-builder&apos;) {
            sh &apos;mvn test jacoco:report&apos;
        }
      }
    }
    stage(&apos;Sonarqube Code Scan&apos;) {
      steps {
        container(&apos;java-builder&apos;) {
          script {
            scannerHome = tool &apos;SonarScanner&apos;
            projectKey = env.PROJECT_NAME
            mainBranch = &quot;main&quot;
            appVersion = &apos;0.0.1&apos;
            withSonarQubeEnv(&apos;sonarqube&apos;) {
              sh &quot;$${scannerHome}/bin/sonar-scanner \
              -Dsonar.projectName=\&quot;$${projectKey}: ($${mainBranch})\&quot; \
              -Dsonar.projectVersion=\&quot;$${appVersion}\&quot; \
              -Dsonar.projectKey=$${projectKey}:$${mainBranch} \
              -Dsonar.exclusions=/src/test/** \
              -Dsonar.sources=src/main \
              -Dsonar.tests=src/test \
              -Dsonar.java.coveragePlugin=jacoco \
              -Dsonar.jacoco.reportPaths=target/jacoco.exec \
              -Dsonar.junit.reportPaths=target/surefire-reports/ \
              -Dsonar.java.binaries=target/classes \
              -Dsonar.java.libraries=target/dependency/*.jar \
              -Dsonar.java.test.binaries=target/test-classes \
              -Dsonar.java.test.libraries=target/test-dependency/*.jar&quot;
            }
          }
        }
      }
    }
    stage(&apos;Sonarqube Quality Gate&apos;) {
      options {
        timeout(time: 1, unit: &apos;HOURS&apos;)
      }
      steps {
        container(&apos;java-builder&apos;) {
          script {
            qg = waitForQualityGate()
            if (qg.status != &apos;OK&apos;) {
              error &quot;Pipeline aborted due to quality gate failure: $${qg.status}&quot;
            }
          }
        }
      }
    }
    stage(&apos;Build project&apos;) {   
      steps {
        container(name: &apos;alpine-builder&apos;) {
            sh &apos;mvn clean install&apos;
        }
      }
    }
    stage(&apos;Bake image and create tarball&apos;) {
      environment {
        PATH        = &quot;/busybox:/kaniko:$PATH&quot;
      }
      steps {
        container(name: &apos;kaniko&apos;, shell: &apos;/busybox/sh&apos;) {
            
          sh &apos;&apos;&apos;#!/busybox/sh
            /kaniko/executor --context `pwd` --verbosity debug --no-push --destination $${REGISTRY}/$${REPOSITORY}/$${IMAGE_NAME} --tarPath image.tar
          &apos;&apos;&apos;
        }
      }
    }
    stage(&quot;Grype scans of tarball&quot;) {
      steps { 
        container(name: &apos;alpine&apos;) {      
          sh &apos;apk add bash curl&apos;
          sh &apos;curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin&apos;
          sh &apos;grype image.tar --output table&apos;
        }
      }
    }
    stage(&quot;Push image to repository&quot;) {
      steps {
        container(name: &apos;crane&apos;) {
		  sh &apos;crane push image.tar $${REGISTRY}/$${REPOSITORY}/$${IMAGE_NAME}:$${BUILD_NUMBER}&apos;
        }
      } 
    }
  }
}</script>
    <sandbox>true</sandbox>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>