## Spring Music Application
[![Build Status](https://travis-ci.org/garystafford/spring-music.svg?branch=master)](https://travis-ci.org/garystafford/spring-music)

#### Built  with Docker Machine and Compose
<p>
  <a href="https://programmaticponderings.files.wordpress.com/2015/09/spring-music-machine.png" title="Spring Music Application with&nbsp;Docker" rel="attachment"><img width="620" height="213" src="https://programmaticponderings.files.wordpress.com/2015/09/spring-music-machine.png?w=620" alt="Spring Music Application with Docker"></a>
</p>

Complete set of commands to pull and build project:

```shell
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

# wait for container apps to start
sleep 15

# run quick test of project
for i in {1..10}
do
  curl -I --url $(docker-machine ip springmusic)
done
```

All of the above commands above can be executed with the following single script:
```shell
sh ./build_project.sh
```

#### Available Environment Links
Assumes `springmusic` VM is running at `192.168.99.100`
* Site: `192.168.99.100`
* NGINX: `192.168.99.100/nginx_status`
* Tomcat Node 1: `192.168.99.100:8180/manager`
* Tomcat Node 2: `192.168.99.100:8280/manager`
* Kibana: `192.168.99.100:8081`
* Elasticsearch: `192.168.99.100:8082`
* Elasticsearch: `192.168.99.100:8082/_status?pretty`
* Logspout: `192.168.99.100:8083/logs`

```bash
# remove previous proxy/app/db images and containers
docker ps -a --no-trunc  | grep 'music' | awk '{print $1}'   | xargs -r --no-run-if-empty docker stop && \
docker ps -a --no-trunc  | grep 'music' | awk '{print $1}'   | xargs -r --no-run-if-empty docker rm && \
docker images --no-trunc | grep 'music' | grep -v 'logspout' | awk '{print $3}' | xargs -r --no-run-if-empty docker rmi -f && \
docker images && echo && docker ps -a
``` 

Resulting containers and images:
```text
gstafford@gstafford-X555LA:$ docker ps -a
CONTAINER ID        IMAGE               COMMAND                  CREATED              STATUS              PORTS                                                  NAMES
facb6eddfb96        music_proxy         "nginx -g 'daemon off"   46 seconds ago       Up 46 seconds       0.0.0.0:80->80/tcp, 443/tcp                            music_proxy_1
abf9bb0821e8        music_app01         "catalina.sh run"        About a minute ago   Up About a minute   0.0.0.0:8180->8080/tcp                                 music_app01_1
e4c43ed84bed        music_logspout      "/bin/logspout"          About a minute ago   Up About a minute   8000/tcp, 0.0.0.0:8083->80/tcp                         music_logspout_1
eca9a3cec52f        music_app02         "catalina.sh run"        2 minutes ago        Up 2 minutes        0.0.0.0:8280->8080/tcp                                 music_app02_1
b7a7fd54575f        mongo:latest        "/entrypoint.sh mongo"   2 minutes ago        Up 2 minutes        27017/tcp                                              music_nosqldb_1
cbfe43800f3e        music_elk           "/usr/bin/supervisord"   2 minutes ago        Up 2 minutes        5000/0, 0.0.0.0:8081->80/tcp, 0.0.0.0:8082->9200/tcp   music_elk_1

gstafford@gstafford-X555LA:$ docker images
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