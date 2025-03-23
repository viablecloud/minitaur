#!/bin/bash
#simple demo deploy script

kubectl create namespace minitaur
kubectl delete -f deployer.yaml
kubectl delete configmap jenkins-casc-config -n minitaur

for i in `seq 1 12`
do
  kubectl get pods -n minitaur
  sleep 2
done
kubectl get services -n minitaur

#create the JSCASC definition for Jenkins
kubectl create configmap jenkins-casc-config --from-file=casc.yaml=./casc.yaml -n minitaur

kubectl apply -f quay-image-pull-secret.yaml
kubectl apply -f deployer.yaml

for i in `seq 1 12`
do
  kubectl get pods -n minitaur
  sleep 2
done
kubectl get services -n minitaur
