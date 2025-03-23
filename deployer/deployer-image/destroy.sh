#!/bin/bash
#simple demo deploy script for kubernetes (e.g Rancher Desktop)

kubectl delete -f deployer.yaml
kubectl delete -f quay-image-pull-secret.yaml


for i in `seq 1 6`
do
  kubectl get pods -n minitaur
  sleep 2
done
kubectl get services -n minitaur
