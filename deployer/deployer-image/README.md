# Deployer Image

* This directory contains the configuration and scripts for a Jenkins-based Infrastructure as Code (IaC) deployment container. 
* The container is designed to run Jenkins with pre-configured pipelines for managing Azure infrastructure through Terraform.

## Image build workflow:

- Ensure Rancher Desktop or docker Desktop is installed on your workstation (or equivalent small kubernetes cluster)
- Edit casc.yaml and customise jenkins login credentials as required
- Edit build.sh and add the details of your image registry if you intend to store the jenkins image in a registry
- Build the docker image for the jenkins deployer using `build.sh <image version number>`
- Edit `deployer.yaml` amd update the version number of the jenkins deployer image
- Kybernetes install: Run ./deploy.sh to deploy the deployer image to kubernetes
- Browse to jenkins deployer u.i on localhost, login with the password set in casc.yaml and run the test pipelines

* Detailed getting started steps for deploying infrastructure as code is provided on the wiki: https://github.com/viablecloud/minitaur/wiki

## Detailed File Overview

* This section provides an itemised description of each file in this directory. It may not be completely up to date at all times.

### Docker Configuration Files

#### Dockerfile
The Dockerfile defines a multi-stage build process that creates a Jenkins container with:
- Base Jenkins LTS image
- Additional tools installation:
  - Azure CLI
  - Terraform
  - kubectl
  - Required system packages
- Jenkins plugin installation
- Configuration as Code setup
- Security hardening measures
- Custom entrypoint configuration

#### plugins.txt
* Contains a curated list of Jenkins plugins required for:

- Pipeline execution (workflow-aggregator, pipeline-stage-view)
- Azure integration (azure-credentials, azure-cli)
- Terraform integration (terraform)
- Git integration (git, github)
- Authentication and authorization
- UI improvements and utilities

* `plugins.txt` is consumed by CASC to ensure only allowed plugins are included in the final Jenkins Docker image

#### casc.yaml

Jenkins Configuration as Code (JCasC) file that defines the entire Jenkins server image, providing:

- Security configurations:
  - Authentication settings
  - Authorization strategies
  - CSRF protection

- Pipeline configurations:
  - Shared libraries
  - Global pipeline settings

- Tool configurations:
  - Terraform installation
  - Azure CLI setup
  - Git configurations

- Credential management:
  - Azure service principal
  - Git credentials
  - Container registry credentials

* NOTE: You can include *bootstrap* credentials in the casc.yaml definition of the jenkins image but you should first consider the security implications of this. For example:

```
credentials:
  system:
    domainCredentials:
    - credentials:
      - usernamePassword:
          id: "BITBUCKET_COMMON_CREDS"
          username: "your_github_username"
          password: "your_github_repo_access_key"
          description: "GitHub Repo Access Key"
          scope: GLOBAL
```

### Build and Deployment Scripts

#### build.sh

* Run `./build.sh x.y.z` to build the deployer image and push it to the docker image registry of your choice.

```bash
#!/bin/bash
# Script for building the Docker image
# Features:
# - Version tagging
# - Multi-architecture support
# - Build argument handling
# - Error checking
# - Build caching
```

#### deploy.sh

* Usage: edit `deployment.yaml` to update the Jenkins deployer image version you want to use, then run `deploy.sh`
* Use this script to deploy the image to a local kubernetes installation on your workstation.
* Here we assume you are running Rancher Desktop, which provides a local kubernetes cluster on your computer. 

```bash
#!/bin/bash
# Kubernetes deployment script
# Features:
# - Namespace creation/verification
# - Secret management
# - Deployment application
# - Health checks
# - Rollback capabilities
```

#### destroy.sh

* This will delete the jenkins deployer image from your local kubernetes cluster.

```bash
#!/bin/bash
# Cleanup script
# Features:
# - Resource removal
# - State cleanup
# - Verification steps
# - Error handling
```

#### rundocker.sh

```bash
#!/bin/bash
# Local testing script
# Features:
# - Volume mounting
# - Port forwarding
# - Environment variable handling
# - Debug mode support
```

#### createDockerImagePullSecret.sh

```bash
#!/bin/bash
# Registry authentication script
# Features:
# - Secret creation
# - Registry authentication
# - Namespace management
# - Credential rotation
```

### Kubernetes Resources

#### deployer.yaml
Comprehensive Kubernetes deployment manifest including:
- Deployment configuration:
  - Resource requests and limits
  - Node selection
  - Security contexts
  - Volume mounts
- Service definition:
  - Port mappings
  - Load balancer configuration
- ConfigMap settings:
  - Environment variables
  - Configuration files
- PersistentVolumeClaim:
  - Storage requirements
  - Access modes

#### quay-image-pull-secret.yaml
Container registry authentication template:
- Secret type definition
- Registry URL configuration
- Authentication data structure
- Namespace settings

### Jenkins Pipeline Definitions

#### iac-deployer-nprd.groovy
Non-production infrastructure deployment pipeline:
```groovy
// Pipeline stages:
// 1. Checkout - Source code retrieval
// 2. Validation - Syntax and security checks
// 3. Init - Terraform initialization
// 4. Plan - Infrastructure plan generation
// 5. Approval - Manual intervention point
// 6. Apply - Infrastructure deployment
// 7. Verification - Deployment testing
// 8. Documentation - Update system records
```

#### iac-destroyer-nprd.groovy
Non-production infrastructure destruction pipeline:
```groovy
// Pipeline stages:
// 1. Preparation - Environment validation
// 2. Backup - State and configuration backup
// 3. Validation - Destruction plan review
// 4. Approval - Manual confirmation
// 5. Destruction - Resource removal
// 6. Verification - Cleanup confirmation
// 7. Notification - Status updates
```

#### iac-destroyer-nprd-test.groovy
Test version of destroyer pipeline with additional features:
```groovy
// Additional stages:
// - Mock resource creation
// - Destruction testing
// - Recovery testing
// - Performance metrics
// - Test result reporting
```

#### iac-state-bootstrap-nprd.groovy
Terraform state infrastructure setup:
```groovy
// Bootstrap stages:
// 1. Prerequisites - Environment checking
// 2. Storage - Backend storage creation
// 3. Access - Permission configuration
// 4. State - Initial state setup
// 5. Locking - State locking mechanism
// 6. Monitoring - Monitoring setup
```

#### iac-test-deployer-nprd.groovy

* Enhanced testing pipeline: Run this pipeline before running the actual deployment pipeline - just to make sure all is well with the terraform state and cloud infrastructure.

```groovy
// Test stages:
// 1. Unit Testing
// 2. Integration Testing
// 3. Security Scanning
// 4. Compliance Checking
// 5. Performance Testing
// 6. Rollback Testing
```

## Detailed Usage Instructions

### Prerequisites
- Docker 20.10 or higher
- Kubernetes 1.21 or higher
- Azure CLI 2.30 or higher
- Terraform 1.0 or higher
- Access to required Azure resources:
  - Subscription
  - Resource groups
  - Service principal
- Quay.io registry access
- Required permissions:
  - Kubernetes cluster admin
  - Azure resource management
  - Registry push/pull

### Building the Image

1. Configure build arguments:

* Edit `build.sh` and configure the path to your docker image registry based on the example in the file. Then run: 

2. Build the image:
```bash
./build.sh x.y.z 
```

* This should push the Jenkins deployer image to your own docker image registry

3. Verify the build:
```bash
docker images | grep deployer
```

### Kubernetes Deployment

* Use the provided scripts and manifests to deploy the Jenkins deployer to a kubernetes cluster:

1. Create namespace and secrets:

* Create the namespace and also create an image pull secret to allow kubernetes to pull the jenkins docker image from your image registry:
 
```bash
kubectl create namespace deployer
./createDockerImagePullSecret.sh
```

NOTE: You will have to edit createDockerImagePullSecret.sh to provide the details of your docker image registry. Here we assume Quay.io:

```
#!/bin/bash
#Example for Quay.io

#modify the values below to match your requirements
USERNAME="engeneon"
PASSWORD="YOUR_QUAY_IO_PASSWORD"
NAMESPACE="deployer"

kubectl create secret docker-registry \
  engeneon-pull-secret \
  --docker-server=quay.io \
  --docker-username="${USERNAME}"\
  --docker-password="${PASSWORD}" \
  --docker-email=tgw@viablecloud.io \
  -n "${NAMESPACE}"
```

2. Deploy the jenkins deployer:
```bash
./deploy.sh
```

3. Verify deployment:
```bash
kubectl get pods -n deployer
kubectl get services -n deployer
```

### Local Testing

* You can run and test the deployer with docker alone on your local machine instead of kubernetes:

1. Configure local environment:
```bash
export JENKINS_HOME="/path/to/jenkins/home"
```

2. Run container:
```bash
./rundocker.sh
```

3. Access Jenkins:
```bash
browse to http://localhost:8080
```

## Configuration Details

### Security Considerations

* The current codebase takes into account the following security areas:

- RBAC configuration
- Network policies
- Secret management
- Pod security policies
- Container security
- Jenkins security

### Resource Requirements

* Hosting the Jenkins deployer in a business environment requires minimal resources:

- CPU: 2 cores minimum
- Memory: 4GB minimum
- Storage: 20GB minimum
- Network: Load balancer access

### Monitoring and Logging
- Prometheus metrics
- Grafana dashboards
- Log aggregation
- Alert configuration
- Audit logging

### Backup and Recovery
- Jenkins configuration backup
- Pipeline backup
- State file backup
- Disaster recovery procedures

## Troubleshooting

### Common Issues

* These are the issues you're likely to face with infrastructure as code on the cloud in general:

1. Image Pull Errors
2. Resource Constraints
3. Permission Issues
4. Pipeline Failures
5. State Lock Issues

* Currently we recommend relying on ChatGPT or Cursor.com's a.i coding environment to assist with the debugging and resolution of these issues.

### Regular Tasks

* As with any new technology adoption, to develop and maintain this image deployer codebase you'll need to add the following to your list of DevOps tasks:

- Image updates
- Plugin updates
- Security patches
- Configuration reviews
- Performance optimization

### Version Control

- Image versioning: `deploy.sh` accepts a semantic versioning standard (semver) or any other version tag you want
- Configuration versioning: Use git - we insist :-)
- Pipeline versioning: We recommend you establish a versioning system for your individual groovy pipelines

## Support and Contributing

### Getting Help

* For any issues you encounter please feel free to log an issue on the github repository for this codebase: https://github.com/viablecloud/minitaur/issues
* Aside from this , the component technologies used to build the minitaur project have the following additional documentation available:

- Internal documentation: This repo
- Community resources: The Jenkins, Kubernetes, Terraform and Azure communities on stackoverflow
- Support channels: You may opt to make heavy use of the Azure Cloud Support plan that comes with your subscription
- Issue tracking: https://github.com/viablecloud/minitaur/issues
- A.I Agents: Cursor.com and ChatGPT offer excellent A.I assistance for resolving issues with the minitaur project codebase

