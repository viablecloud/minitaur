#!/bin/bash
#Set environment variables required for login
#and then log in ...
set -ex

#get the local variables for this level ...
source ./env.sh

printf "=====================BEGIN DUMPING ENV ===============================\n"
env
printf "=====================ENV DUMP COMPLETE ===============================\n"

printf "level-1 login to tenant ${TENANT_ID}\n"
az login --tenant ${TENANT_ID}
