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
docker-machine create --driver virtualbox springmusic

# set new environment
docker-machine env springmusic && \
eval "$(docker-machine env springmusic)"

# create directory to store mongo data on host
docker volume create --name data

# create overlay network
# docker network create --driver overlay --subnet=10.0.11.0/24 music_overlay_net

# build images and containers
docker-compose -f docker-compose-v2.yml -p music up -d elk && sleep 2 && \
docker-compose -f docker-compose-v2.yml -p music up -d logspout && sleep 2 && \
docker-compose -f docker-compose-v2.yml -p music up -d nosqldb && sleep 5 && \
docker-compose -f docker-compose-v2.yml -p music up -d app01 app02 && sleep 5 && \
docker-compose -f docker-compose-v2.yml -p music up -d proxy

# configure local DNS resolution for application URL
#echo "$(docker-machine ip springmusic)   springmusic.com" | sudo tee --append /etc/hosts

# wait for container apps to start
sleep 15

# run quick test of project
for i in {1..10}
do
  curl -I --url $(docker-machine ip springmusic)
done

# useful commands
# docker rm -f proxy app01 app02 nosqldb elk logspout
# docker restart elk && sleep 5 && docker restart logspout && sleep 5 && docker restart nosqldb && sleep 10
# docker restart app01 app02 && sleep 10 && docker restart proxy
