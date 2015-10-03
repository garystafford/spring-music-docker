#!/bin/sh

########################################################################
#
# title:          Build Complete Single Cluster Weave Swarm Node Project
# author:         Gary A. Stafford (https://programmaticponderings.com)
# url:            https://github.com/garystafford/sprint-music-docker  
# description:    Clone and build complete Spring Music Docker project
#                 for single cluster weave swarm node
#
# to run:         sh ./build_project.sh
#
########################################################################

# install latest weave
curl -L git.io/weave -o /usr/local/bin/weave && 
chmod a+x /usr/local/bin/weave && 
weave version

# clone project
git clone -b swarm-weave \
  --single-branch --branch swarm-weave \
  https://github.com/garystafford/spring-music-docker.git && 
cd spring-music-docker

# build VM
docker-machine create --driver virtualbox springmusic --debug

# create directory to store mongo data on host
docker-machine ssh springmusic mkdir /opt/mongodb

# set new environment
docker-machine env springmusic && 
eval "$(docker-machine env springmusic)"

# launch weave and weaveproxy/weaveDNS containers
weave launch &&
tlsargs=$(docker-machine ssh springmusic \
  "cat /proc/\$(pgrep /usr/local/bin/docker)/cmdline | tr '\0' '\n' | grep ^--tls | tr '\n' ' '")
weave launch-proxy $tlsargs &&
eval "$(weave env)"

# test/confirm weave status
weave status &&
docker logs weaveproxy

# pull and build images and containers
# this step will take several minutes to pull images first time
docker-compose -f docker-compose.yml -p music up -d

# wait for container apps to fully start
sleep 15

# test weave (should list entries for all containers)
docker exec -it music_proxy_1 cat /etc/hosts 

# run quick test of Spring Music application
for i in {1..10}
do
  curl -I --url $(docker-machine ip springmusic)
done