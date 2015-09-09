##### New commands for v1.1.0
https://github.com/weaveworks/guides/blob/master/weave-and-docker-platform/1-machine.md

```bash

# install weave v1.1.0
curl -L git.io/weave -o /usr/local/bin/weave && \
chmod a+x /usr/local/bin/weave && \
weave version

# create VM - see other script
#docker-machine create -d virtualbox springmusic
#eval "$(docker-machine config springmusic)"

# launch weave and weaveproxy containers
weave launch
tlsargs=$(docker-machine ssh springmusic \
  "cat /proc/\$(pgrep /usr/local/bin/docker)/cmdline | tr '\0' '\n' | grep ^--tls | tr '\n' ' '")
weave launch-proxy $tlsargs
eval "$(weave env)"

# test weave
weave status 
docker logs weaveproxy
docker exec -it music_proxy_1 cat /etc/hosts # should see all containers!
```