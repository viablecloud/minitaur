# A Standalone Jenkins IaC Deployer for the Minitaur Project

* The entire cloud environment infrastructure code can be deployed using this standalone containerised Jenkins deployer.
* All the pipelines required to deploy, update and destroy the various components of the cloud architecture are contained in the deployer.
* Using this standalone tool as a starting point you can develop it into a more scalable and featureful solution for your business. 

# CASC

* The entire Jenkins configuration is defined using Jenkins "Configuration as Code". This means the contents and state of the Jenkins deployer is completely defined in code and therefore predictable and fully controlled by the user.
* Together with pipeline-as-code used to define each pipeline included in Jenkins, this provides a very stable, very deterministic platform for ci/cd automation.

* Use this as a starting point for developing your own Jenkins deployer, either based on Jenkins or your own choice of CI/CD automation technology!

