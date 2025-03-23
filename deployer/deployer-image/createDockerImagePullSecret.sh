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
