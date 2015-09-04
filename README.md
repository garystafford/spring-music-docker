```bash
docker-machine create --driver virtualbox springmusic --debug

docker ps -a --no-trunc | grep 'music' | awk '{print $1}' | xargs -r --no-run-if-empty docker stop && \
docker ps -a --no-trunc | grep 'music' | awk '{print $1}' | xargs -r --no-run-if-empty docker rm && \
docker images --no-trunc | grep 'music' | grep -v 'logspout' | awk '{print $3}' | xargs -r --no-run-if-empty docker rmi -f && \
docker images && echo && docker ps -a
```