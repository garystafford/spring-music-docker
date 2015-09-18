##### New commands for v1.1.0
https://github.com/weaveworks/guides/blob/master/weave-and-docker-platform/1-machine.md

```bash
# install weave v1.1.0
curl -L git.io/weave -o /usr/local/bin/weave && 
chmod a+x /usr/local/bin/weave && 
weave version

# clone project
git clone https://github.com/garystafford/spring-music-docker.git && 
cd spring-music-docker

# build VM
docker-machine create --driver virtualbox springmusic --debug

# create diectory to store mongo data on host
docker ssh springmusic mkdir /opt/mongodb

# set new environment
docker-machine env springmusic && 
eval "$(docker-machine env springmusic)"

# launch weave and weaveproxy/weaveDNS containers
weave launch
tlsargs=$(docker-machine ssh springmusic \
  "cat /proc/\$(pgrep /usr/local/bin/docker)/cmdline | tr '\0' '\n' | grep ^--tls | tr '\n' ' '")
weave launch-proxy $tlsargs
eval "$(weave env)"

# test/confirm weave status
weave status 
docker logs weaveproxy

# pull build artifacts, built by Travis CI, 
# from source code repository
sh ./pull_build_artifacts.sh

# build images and containers
docker-compose -f docker-compose.yml -p music up -d

# wait for container apps to fully start
sleep 15

# test weaveDNS (should list entries for all containers)
docker exec -it music_proxy_1 cat /etc/hosts 

# run quick test of Spring Music application
for i in {1..10}
do
  curl -I --url $(docker-machine ip springmusic)
done
```

Links:
https://www.debian-administration.org/article/184/How_to_find_out_which_process_is_listening_upon_a_port
http://linux-ip.net/html/tools-ip-route.html
https://blog.abevoelker.com/why-i-dont-use-docker-much-anymore/
https://github.com/docker/compose/issues/235