## Build and Deploy a Java-Spring-MongoDB Application using Docker

_Build a multi-container, MongoDB-backed, Java Spring web application, and deploy to a test environment using Docker._

[![Spring Music Application Environment](https://programmaticponderings.files.wordpress.com/2015/09/spring-music-machine.png)](https://programmaticponderings.files.wordpress.com/2015/09/spring-music-machine.png "Spring Music Application Environment")

### Introduction
In this post, we will demonstrate how to build, deploy, and host a multi-tier Java application using Docker. For the demonstration, we will use a sample Java Spring application, available on GitHub from Cloud Foundry. Cloud Foundry's [Spring Music](https://github.com/cloudfoundry-samples/spring-music) sample record album collection application was originally designed to demonstrate the use of database services on [Cloud Foundry](http://www.cloudfoundry.com) and [Spring Framework](http://www.springframework.org). Instead of Cloud Foundry, we will host the Spring Music application using Docker with VirtualBox and optionally, AWS.

[![Spring Music Application](https://programmaticponderings.files.wordpress.com/2015/09/spring-music.png)](https://programmaticponderings.files.wordpress.com/2015/09/spring-music.png "Spring Music Application")

A few changes were necessary to the original Spring Music application to make it work for the this demonstration. At a high-level, the changes included:

* Modify MongoDB configuration class to work with non-local MongoDB instances
* Add Gradle 'warNoStatic' task to build WAR file without the static assets, which will be host separately in NGINX
* Create new Gradle task, 'zipStatic', to ZIP up the application's static assets for deployment to NGINX
* Add versioning scheme for build artifacts
* Add context.xml file and MANIFEST.MF file to the WAR file
* Add log4j syslog appender to send long entries to Logstash
* Update versions of several dependencies, including Gradle to 2.6

### Application Architecture
The Spring Music web application's static content will be hosted by [NGINX](http://nginx.org) for increased performance. The application's WAR file will be hosted by [Apache Tomcat](http://tomcat.apache.org). Requests for non-static content will be proxied through a single instance of NGINX on the front-end, to one of two load-balanced Tomcat instances on the back-end. NGINX will also be configured to allow for browser caching of the static content, to further increase application performance. Reverse proxying and caching are configured thought NGINX's `default.conf` file's `server` configuration section:
```bash
server {
  listen        80;
  server_name   localhost;

  location ~* \/assets\/(css|images|js|template)\/* {
    root          /usr/share/nginx/;
    expires       max;
    add_header    Pragma public;
    add_header    Cache-Control "public, must-revalidate, proxy-revalidate";
    add_header    Vary Accept-Encoding;
    access_log    off;
  }
```

The two Tomcat instances will be configured on NGINX, in a load-balancing pool, using the default round-robin load-balancing algorithm. This is configured thought NGINX's `default.conf` file's `upstream` configuration section:
```bash
upstream backend {
  server app01:8080;
  server app02:8080;
}
```

The Spring Music application can be run with MySQL, Postgres, Oracle, MongoDB, Redis, or H2, an in-memory Java SQL database. Given the choice of both SQL and NoSQL databases available for use with the Spring Music application, we will select MongoDB. The Spring Music application, hosted by Tomcat, will store and modify record album data in a single instance of MongoDB. MongoDB will be populated with a collection of album data when the Spring Music application first creates the MongoDB database instance.

Lastly, the ELK Stack with Logspout, will aggregate both Docker and Java Log4j log entries, providing debugging and analytics to our demonstration. I've used the same method for Docker and Java Log4j log entries, as detailed in this previous [post](https://programmaticponderings.wordpress.com/2015/08/02/log-aggregation-visualization-and-analysis-of-microservices-using-elk-stack-and-logspout/).

[![Kibana](https://programmaticponderings.files.wordpress.com/2015/09/kibana-spring-music.png)](https://programmaticponderings.files.wordpress.com/2015/09/kibana-spring-music.png "Kibana")

**Application Technology Stack**

* [Java](http://openjdk.java.net)
* [Spring Framework](http://projects.spring.io/spring-framework)
* [NGINX](http://nginx.org)
* [Apache Tomcat](http://tomcat.apache.org)
* [MongoDB](http://mongoDB.com)
* [ELK Stack](https://www.elastic.co/products)
* [Logspout](https://github.com/gliderlabs/logspout)
* [Logspout-Logstash Adapter](https://github.com/looplab/logspout-logstash)

### Spring Music Environment
All files necessary to build this project are stored in the [garystafford/spring-music-docker](https://github.com/garystafford/spring-music-docker) repository on GitHub. The Spring Music source code and build artifacts are stored in a seperate [garystafford/spring-music](https://github.com/garystafford/spring-music) repository, also on GitHub.

Build artifacts are automatically built by [Travis CI](https://travis-ci.org) when changes are checked into the [garystafford/spring-music](https://github.com/garystafford/spring-music) repository on GitHub. Travis CI then overwrites the build artifacts back to a [build artifact](https://github.com/garystafford/spring-music/tree/build-artifacts) branch of that same project. The build artifact branch acts as a pseudo [binary repository](https://en.wikipedia.org/wiki/Binary_repository_manager) for the project. The `.travis.yaml` file and `deploy.sh` script handles these functions:

```yaml
language: java
jdk: oraclejdk7
before_install:
- chmod +x gradlew
before_deploy:
- chmod ugo+x deploy.sh
script:
- bash ./gradlew clean warNoStatic warCopy zipGetVersion zipStatic
- bash ./deploy.sh
env:
  global:
  - GH_REF: github.com/garystafford/spring-music.git
  - secure: <secure hash here>
```


```bash
#!/bin/bash
# reference: https://gist.github.com/domenic/ec8b0fc8ab45f39403dd

set -e # exit with nonzero exit code if anything fails

# go to the distributions directory and create a *new* Git repo
cd build/distributions && git init

# inside this git repo we'll pretend to be a new user
git config user.name "travis-ci"
git config user.email "auto-deploy@travis-ci.com"

# The first and only commit to this new Git repo contains all the
# files present with the commit message.
git add .
git commit -m "Deploy Travis CI build #${TRAVIS_BUILD_NUMBER} artifacts to GitHub"

# Force push from the current repo's master branch to the remote
# repo's build-artifacts branch. (All previous history on the gh-pages branch
# will be lost, since we are overwriting it.) We redirect any output to
# /dev/null to hide any sensitive credential data that might otherwise be exposed. Environment variables pre-configured on Travis CI.
git push --force --quiet "https://${GH_TOKEN}@${GH_REF}" master:build-artifacts > /dev/null 2>&1
```

This project then pulls the latest build artifacts down, to build the project-specific versions of the NGINX and Tomcat Docker images used for this project. For this we use the `pull_build_artifacts.sh` script:
```bash
#!/bin/sh

echo "Removing all existing build artifacts"
rm -rf build-artifacts
rm -rf nginx/build-artifacts/
rm -rf tomcat/build-artifacts/

mkdir nginx/build-artifacts
mkdir tomcat/build-artifacts

echo "Pulling latest build artficats"
git clone https://github.com/garystafford/spring-music.git \
  --branch build-artifacts \
  --single-branch build-artifacts

echo "Moving build artifacts to each microservice directory"
mv build-artifacts/*.war tomcat/build-artifacts/
mv build-artifacts/*.zip nginx/build-artifacts/

echo "Removing local clone of build artifacts repo"
rm -rf build-artifacts

echo "Pulling build artifacts complete"
```

Docker Images, such as NGINX, Tomcat, and MongoDB, used to build the project's images, and subsequently the containers, are all pulled from Docker Hub.

Docker Machine builds a single VirtualBox VM. After building the VM, Docker Compose then builds and deploys (1) NGINX container, (2) load-balanced Tomcat containers, (1) MongoDB container, (1) ELK container, and (1) Logspout container, onto the VM. Docker Machine's VirtualBox driver provides a basic solution that can be run locally for testing and development. The Docker Compose YAML file reads as follows:
```yaml
proxy:
  build: nginx/
  ports: "80:80"
  links:
   - app01
   - app02
  hostname: "proxy"

app01:
  build: tomcat/
  expose: "8080"
  ports: "8180:8080"
  links:
   - nosqldb
   - elk
  hostname: "app01"

app02:
  build: tomcat/
  expose: "8080"
  ports: "8280:8080"
  links:
   - nosqldb
   - elk
  hostname: "app01"

nosqldb:
  build: mongo/
  hostname: "nosqldb"
  volumes: "/opt/mongodb:/data/db"

elk:
  build: elk/
  ports:
   - "8081:80"
   - "8082:9200"
  expose: "5000/upd"

logspout:
  build: logspout/
  volumes: "/var/run/docker.sock:/tmp/docker.sock"
  links: elk
  ports: "8083:80"
  environment: ROUTE_URIS=logstash://elk:5000
```

[![Spring Music Application Environment](https://programmaticponderings.files.wordpress.com/2015/09/spring-music-machine.png)](https://programmaticponderings.files.wordpress.com/2015/09/spring-music-machine.png "Spring Music Application Environment")

**Build, Deploy, Host Technology Stack**

* [Gradle](https://gradle.org)
* [GitHub](https://github.com)
* [Travis CI](https://travis-ci.org)
* [git](https://git-scm.com)
* [Oracle VirtualBox](https://www.virtualbox.org)
* [Docker](https://www.docker.com)
* [Docker Compose](https://www.docker.com/docker-compose)
* [Docker Machine](https://www.docker.com/docker-machine)
* [Docker Hub](https://hub.docker.com)
* _optional:_ [Amazon Web Services (AWS)](http://aws.amazon.com)

### Building the Environment
Before continuing, ensure you have nothing running on ports `80`, `8080`, `8081`, `8082`, and `8083`. Also, make sure VirtualBox, Docker, Docker Compose, Docker Machine, VirtualBox, cURL, and git are all pre-installed and running.
```bash
docker --version && 
docker-compose --version && 
docker-machine --version && 
echo "VirtualBox $(vboxmanage --version)" && 
curl --version && git --version
```

All of the below commands may be executed with the following single command (`sh ./build_project.sh`). This is useful for working with Jenkins CI, ThoughtWorks go, or similar CI tools. However, I suggest building the project step-by-step, as shown below, to better understand the process.
```bash
git clone https://github.com/garystafford/spring-music-docker.git && 
cd spring-music-docker

# build VM
docker-machine create --driver virtualbox springmusic --debug

# create diectory to store mongo data on host
docker ssh springmusic mkdir /opt/mongodb

# set new environment
docker-machine env springmusic && 
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

By simply changing the driver to AWS EC2 and providing your AWS credentials, the same environment can be built on AWS within a single EC2 instance. The 'springmusic' environment has been fully tested both locally with VirtualBox, as well as on AWS.

**Results**
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

Partial result of the curl test, calling NGINX. Note the two different upstream addresses for Tomcat. Also, note the sharp decrease in request times, due to caching.
```text
HTTP/1.1 200 OK
Server: nginx/1.9.4
Date: Mon, 07 Sep 2015 17:56:11 GMT
Content-Type: text/html;charset=ISO-8859-1
Content-Length: 2090
Connection: keep-alive
Accept-Ranges: bytes
ETag: W/"2090-1441648256000"
Last-Modified: Mon, 07 Sep 2015 17:50:56 GMT
Content-Language: en
Request-Time: 0.521
Upstream-Address: 172.17.0.121:8080
Upstream-Response-Time: 1441648570.774

HTTP/1.1 200 OK
Server: nginx/1.9.4
Date: Mon, 07 Sep 2015 17:56:11 GMT
Content-Type: text/html;charset=ISO-8859-1
Content-Length: 2090
Connection: keep-alive
Accept-Ranges: bytes
ETag: W/"2090-1441648256000"
Last-Modified: Mon, 07 Sep 2015 17:50:56 GMT
Content-Language: en
Request-Time: 0.326
Upstream-Address: 172.17.0.123:8080
Upstream-Response-Time: 1441648571.506

HTTP/1.1 200 OK
Server: nginx/1.9.4
Date: Mon, 07 Sep 2015 17:56:12 GMT
Content-Type: text/html;charset=ISO-8859-1
Content-Length: 2090
Connection: keep-alive
Accept-Ranges: bytes
ETag: W/"2090-1441648256000"
Last-Modified: Mon, 07 Sep 2015 17:50:56 GMT
Content-Language: en
Request-Time: 0.006
Upstream-Address: 172.17.0.121:8080
Upstream-Response-Time: 1441648572.050

HTTP/1.1 200 OK
Server: nginx/1.9.4
Date: Mon, 07 Sep 2015 17:56:12 GMT
Content-Type: text/html;charset=ISO-8859-1
Content-Length: 2090
Connection: keep-alive
Accept-Ranges: bytes
ETag: W/"2090-1441648256000"
Last-Modified: Mon, 07 Sep 2015 17:50:56 GMT
Content-Language: en
Request-Time: 0.006
Upstream-Address: 172.17.0.123:8080
Upstream-Response-Time: 1441648572.266
```

### Spring Music Application Links
Assuming `springmusic` VM is running at `192.168.99.100`:

* Spring Music: [192.168.99.100](http://192.168.99.100)
* NGINX: [192.168.99.100/nginx_status](http://192.168.99.100/nginx_status)
* Tomcat Node 1*: [192.168.99.100:8180/manager](http://192.168.99.100:8180/manager)
* Tomcat Node 2*: [192.168.99.100:8280/manager](http://192.168.99.100:8280/manager)
* Kibana: [192.168.99.100:8081](http://192.168.99.100:8081)
* Elasticsearch: [192.168.99.100:8082](http://192.168.99.100:8082)
* Elasticsearch: [192.168.99.100:8082/_status?pretty](http://192.168.99.100:8082/_status?pretty)
* Logspout: [192.168.99.100:8083/logs](http://192.168.99.100:8083/logs)

_* The Tomcat user name is `admin` and the password is `t0mcat53rv3r`._

### Helpful Links
* [Cloud Foundry's Spring Music Example](https://github.com/cloudfoundry-samples/spring-music)
* [Getting Started with Gradle for Java](https://gradle.org/getting-started-gradle-java)
* [Introduction to Gradle](https://semaphoreci.com/community/tutorials/introduction-to-gradle)
* [Spring Framework](http://projects.spring.io/spring-framework)
* [Understanding Nginx HTTP Proxying, Load Balancing, Buffering, and Caching](https://www.digitalocean.com/community/tutorials/understanding-nginx-http-proxying-load-balancing-buffering-and-caching)
[Common conversion patterns for log4j's PatternLayout](http://www.codejava.net/coding/common-conversion-patterns-for-log4js-patternlayout)
* [Spring @PropertySource example](http://www.mkyong.com/spring/spring-propertysources-example)


#### To Remove Image and Containers During Development and Testing
```bash
# remove previous proxy/app/db images and containers
docker ps -a --no-trunc  | grep 'music' | awk '{print $1}'   | xargs -r --no-run-if-empty docker stop && \
docker ps -a --no-trunc  | grep 'music' | awk '{print $1}'   | xargs -r --no-run-if-empty docker rm && \
docker images --no-trunc | grep 'music' | grep -v 'logspout' | awk '{print $3}' | xargs -r --no-run-if-empty docker rmi -f && \
docker images && echo && docker ps -a
```