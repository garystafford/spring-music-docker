#!/bin/sh

########################################################################
#
# title:          Build Complete Project
# author:         Gary A. Stafford (https://programmaticponderings.com)
# url:            https://github.com/garystafford/sprint-music-docker  
# description:    Clone and build complete Spring Music Docker project
#
# to run:         sh ./build_project.sh
#
########################################################################

# clone project
git clone -b master \
  --single-branch https://github.com/garystafford/spring-music-docker.git && 
cd spring-music-docker

# build VM
docker-machine create --driver virtualbox springmusic --debug

# create directory to store mongo data on host
docker-machine ssh springmusic mkdir /opt/mongodb

# set new environment
docker-machine env springmusic && \
eval "$(docker-machine env springmusic)"

# build images and containers
docker-compose -f docker-compose.yml -p music up -d

# configure local DNS resolution for application URL
#echo "$(docker-machine ip springmusic)   springmusic.com" | sudo tee --append /etc/hosts

# wait for container apps to start
sleep 15

# run quick test of project
for i in {1..10}
do
  curl -I --url $(docker-machine ip springmusic)
done
