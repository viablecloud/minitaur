#FROM jenkins/jenkins:2.426.1-lts-jdk11
#FROM jenkins/jenkins:2.426.3-lts-jdk11
#FROM jenkins/jenkins:jdk17
FROM jenkins/jenkins:latest-jdk21
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"
ENV CASC_JENKINS_CONFIG="/var/jenkins_home/casc.yaml"
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli -f /usr/share/jenkins/ref/plugins.txt
COPY casc.yaml /var/jenkins_home/casc.yaml
USER root
RUN apt-get clean && apt-get update && apt-get install -y gnupg software-properties-common
RUN apt-get clean && apt-get update
RUN apt-get -y install kubernetes-client
#RUN apt-get -y install netcat
RUN apt-get -y install jq
RUN apt-get -y install bash
RUN apt-get -y install unzip
RUN apt-get -y install curl
RUN apt-get -y install docker
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add -
RUN apt-get -y install ca-certificates curl apt-transport-https lsb-release gnupg
RUN curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null
RUN echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ focal main" | tee /etc/apt/sources.list.d/azure-cli.list
RUN apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com focal main"
#Install Packer for VM image build
RUN gpg --no-default-keyring --keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg --fingerprint
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add -
RUN apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
RUN apt-get update && apt-get install packer
RUN apt-get install wget
#BROKEN Upstream at microsoft.
#RUN apt-get update && apt-get install azure-cli
#So use this workaround:
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash
RUN apt install curl software-properties-common
#Install Terraform for Ubuntu from Hashicorp
RUN rm -f /usr/share/keyrings/hashicorp-archive-keyring.gpg   
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --no-tty --batch --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
RUN apt update && apt install terraform && terraform -version docker
RUN curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 && chmod 700 get_helm.sh && ./get_helm.sh
RUN apt-get -y install python3-pip
RUN apt-get -y install python3-requests
RUN apt-get -y install python3-jinja2
USER jenkins
#Now include the pipelines you want in the image:
COPY iac-deployer-nprd.groovy /usr/local/iac-deployer-nprd.groovy
COPY iac-deployer-test-nprd.groovy /usr/local/iac-deployer-test-nprd.groovy
COPY iac-state-bootstrap-nprd.groovy /usr/local/iac-state-bootstrap-nprd.groovy
COPY iac-destroyer-nprd.groovy /usr/local/iac-destroyer-nprd.groovy
COPY iac-destroyer-nprd-test.groovy /usr/local/iac-destroyer-nprd-test.groovy
