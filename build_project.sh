#!/bin/sh

########################################################################
# title:          Build Complete Project
# author:         Gary A. Stafford (https://programmaticponderings.com)
# url:            https://github.com/garystafford/sprint-music-docker
# description:    Clone and build complete Spring Music Docker project
# usage:          sh ./build_project.sh
########################################################################

# clone project
git clone -b master --single-branch \
  https://github.com/garystafford/spring-music-docker.git && \
cd spring-music-docker

# build VM
docker-machine create --driver virtualbox springmusic

# set new environment
docker-machine env springmusic && \
eval "$(docker-machine env springmusic)"

# create directory to store mongo data on host
docker volume create --name music_data

# build images and containers (sleep built in for sequencing startup times)
docker-compose -f docker-compose-v2.yml -p music up -d elk && sleep 5 && \
docker-compose -f docker-compose-v2.yml -p music up -d mongodb && sleep 5 && \
docker-compose -f docker-compose-v2.yml -p music up -d app01 app02 && sleep 10 && \
docker-compose -f docker-compose-v2.yml -p music up -d proxy && sleep 5

# optional: configure local DNS resolution for application URL
#echo "$(docker-machine ip springmusic)   springmusic.com" | sudo tee --append /etc/hosts

# run quick connectivity test of application
for i in {1..10}; do curl -I $(docker-machine ip springmusic);done
