#!/bin/sh

#docker-machine create --driver virtualbox springmusic --debug

# set new environment
docker-machine env springmusic && \
eval "$(docker-machine env springmusic)"

# remove previous proxy/app/db images and containers
docker ps -a --no-trunc  | grep 'music' | awk '{print $1}'   | xargs -r --no-run-if-empty docker stop && \
docker ps -a --no-trunc  | grep 'music' | awk '{print $1}'   | xargs -r --no-run-if-empty docker rm && \
docker images --no-trunc | grep 'music' | grep -v 'logspout' | awk '{print $3}' | xargs -r --no-run-if-empty docker rmi -f && \
docker images && echo && docker ps -a

# pull build artifacts from other repo, built by Travis CI
sh ./pull_build_artifacts.sh

# build Dockerfiles from templates
sh ./build_templates.sh

# build images and containers
docker-compose -f docker-compose.yml -p music up -d

# wait for containers and apps to start
sleep 15

# quick test of project
for i in {1..10}
do
  curl -I --url $(docker-machine ip springmusic)
done
