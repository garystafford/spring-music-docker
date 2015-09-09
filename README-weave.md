##### Old commands modified for v1.1.0
http://weave.works/guides/weave-and-docker-platform/chapter1/machine.html

```bash
curl -OL git.io/weave
chmod +x ./weave
export DOCKER_CLIENT_ARGS="$(docker-machine config springmusic)"
./weave launch
./weave launch 10.53.1.1/16
tlsargs=$(docker-machine ssh springmusic \
  "cat /proc/\$(pgrep /usr/local/bin/docker)/cmdline | tr '\0' '\n' | grep ^--tls | tr '\n' ' '")
./weave launch-proxy --with-dns $tlsargs
export DOCKER_CLIENT_ARGS="$(docker-machine config springmusic | sed 's|:2376|:12375|')"
docker $DOCKER_CLIENT_ARGS info
```

##### New commands for v1.1.0
https://github.com/weaveworks/guides/blob/master/weave-and-docker-platform/1-machine.md

```bash
curl -L git.io/weave -o /usr/local/bin/weave && \
chmod a+x /usr/local/bin/weave

#docker-machine create -d virtualbox springmusic
#eval "$(docker-machine config springmusic)"

weave launch
tlsargs=$(docker-machine ssh springmusic \
  "cat /proc/\$(pgrep /usr/local/bin/docker)/cmdline | tr '\0' '\n' | grep ^--tls | tr '\n' ' '")
weave launch-proxy $tlsargs
eval "$(weave env)"
```

#### To Remove Image and Containers During Development and Testing
```bash
# remove previous proxy/app/db images and containers
docker ps -a --no-trunc  | grep 'weave' | awk '{print $1}'   | xargs -r --no-run-if-empty docker stop && \
docker ps -a --no-trunc  | grep 'weave' | awk '{print $1}'   | xargs -r --no-run-if-empty docker rm && \
docker images --no-trunc | grep 'weave' | grep -v 'logspout' | awk '{print $3}' | xargs -r --no-run-if-empty docker rmi -f && \
docker images && echo && docker ps -a
```