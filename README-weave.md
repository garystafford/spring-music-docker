##### New commands for v1.1.0
https://github.com/weaveworks/guides/blob/master/weave-and-docker-platform/1-machine.md

```bash
# install weave v1.1.0
curl -L git.io/weave -o /usr/local/bin/weave && \
chmod a+x /usr/local/bin/weave && \
weave version

# clone project
git clone https://github.com/garystafford/spring-music-docker.git && \
cd spring-music-docker

# build VM
docker-machine create --driver virtualbox springmusic --debug

# create diectory to store mongo data on host
docker ssh springmusic mkdir /opt/mongodb

# set new environment
docker-machine env springmusic && \
eval "$(docker-machine env springmusic)"

# pull build artifacts from other repo, built by Travis CI
sh ./pull_build_artifacts.sh

# build images and containers
docker-compose -f docker-compose.yml -p music up -d

# configure local DNS resolution for application URL
#echo "$(docker-machine ip springmusic)   springmusic.com" | sudo tee --append /etc/hosts

# launch weave and weaveproxy containers
weave launch
tlsargs=$(docker-machine ssh springmusic \
  "cat /proc/\$(pgrep /usr/local/bin/docker)/cmdline | tr '\0' '\n' | grep ^--tls | tr '\n' ' '")
weave launch-proxy $tlsargs
eval "$(weave env)"

# test weave
weave status 
docker logs weaveproxy

# wait for container apps to start
sleep 15

# run quick test of project
for i in {1..10}
do
  curl -I --url $(docker-machine ip springmusic)
done

# test weave
docker exec -it music_proxy_1 cat /etc/hosts # should see all containers!
```