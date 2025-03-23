#!/bin/bash
#little management script for docker container
docker stop `docker ps | egrep "engeneon" | awk -s '{print $1}'`
docker run -d -p 8080:8080 quay.io/twelcome/engeneon:0.1.5
for i in `seq 1 5`
do
	printf $i
        ${docker ps}
done
