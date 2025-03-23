#!/bin/bash
#Simple build script to create deployer image for Azure Landing Zone Foundations Terraform deployment pipelines
#
#Recommended: Use a semantic versioning scheme ...
#./build.sh <the semantic vesion id>

build_version=$1

#for Quay.io 
docker build  --platform linux/amd64 -t quay.io/twelcome/minitaur:"$build_version" .
docker push quay.io/twelcome/minitaur:"$build_version"
