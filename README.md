```bash
# to pull and build project
git clone https://github.com/garystafford/spring-music-docker.git && \
cd spring-music-docker

docker-machine create --driver virtualbox springmusic --debug

docker-machine env springmusic && \
eval "$(docker-machine env springmusic)"

# mongo data will be stored on external host
# as opposed to within volitile contianer
docker ssh springmusic
mkdir /opt/mongodb
exit

# pulls build artifacts from other repo, built by Travis CI
sh ./pull_build_artifacts.sh

# builds Dockerfiles from templates
sh ./build_templates.sh

docker-compose -f docker-compose.yml -p music up -d

# quick test of project
curl -I --url $(docker-machine ip springmusic)
```

```bash
# to remove proxy/app/db images and containers
docker ps -a --no-trunc  | grep 'music' | awk '{print $1}'   | xargs -r --no-run-if-empty docker stop && \
docker ps -a --no-trunc  | grep 'music' | awk '{print $1}'   | xargs -r --no-run-if-empty docker rm && \
docker images --no-trunc | grep 'music' | grep -v 'logspout' | awk '{print $3}' | xargs -r --no-run-if-empty docker rmi -f && \
docker images && echo && docker ps -a
```

```text
gstafford@gstafford-X555LA:~/NetBeansProjects/spring-music-docker$ docker ps -a
CONTAINER ID        IMAGE               COMMAND                  CREATED              STATUS              PORTS                                                  NAMES
facb6eddfb96        music_proxy         "nginx -g 'daemon off"   46 seconds ago       Up 46 seconds       0.0.0.0:80->80/tcp, 443/tcp                            music_proxy_1
abf9bb0821e8        music_app01         "catalina.sh run"        About a minute ago   Up About a minute   0.0.0.0:8180->8080/tcp                                 music_app01_1
e4c43ed84bed        music_logspout      "/bin/logspout"          About a minute ago   Up About a minute   8000/tcp, 0.0.0.0:8083->80/tcp                         music_logspout_1
eca9a3cec52f        music_app02         "catalina.sh run"        2 minutes ago        Up 2 minutes        0.0.0.0:8280->8080/tcp                                 music_app02_1
b7a7fd54575f        mongo:latest        "/entrypoint.sh mongo"   2 minutes ago        Up 2 minutes        27017/tcp                                              music_nosqldb_1
cbfe43800f3e        music_elk           "/usr/bin/supervisord"   2 minutes ago        Up 2 minutes        5000/0, 0.0.0.0:8081->80/tcp, 0.0.0.0:8082->9200/tcp   music_elk_1

gstafford@gstafford-X555LA:~/NetBeansProjects/spring-music-docker$ docker images
REPOSITORY            TAG                 IMAGE ID            CREATED              VIRTUAL SIZE
music_proxy           latest              46af4c1ffee0        52 seconds ago       144.5 MB
music_logspout        latest              fe64597ab0c4        About a minute ago   24.36 MB
music_app02           latest              d935211139f6        2 minutes ago        370.1 MB
music_app01           latest              d935211139f6        2 minutes ago        370.1 MB
music_elk             latest              b03731595114        2 minutes ago        1.05 GB
gliderlabs/logspout   master              40a52d6ca462        14 hours ago         14.75 MB
willdurand/elk        latest              04cd7334eb5d        9 days ago           1.05 GB
tomcat                latest              6fe1972e6b08        10 days ago          347.7 MB
mongo                 latest              5c9464760d54        10 days ago          260.8 MB
nginx                 latest              cd3cf76a61ee        10 days ago          132.9 MB
```