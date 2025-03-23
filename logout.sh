#!/bin/bash
#Set environment variables required for login
#and then log out
set -ex

printf "===================== logging out ===============================\n"
printf "level-1 logout of tenant ${TENANT_ID}\n"
az logout
printf "===================== START dumping env  ===============================\n"
env
printf "===================== DONE dumping env  ===============================\n"

