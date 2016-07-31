_Build a multi-container, MongoDB-backed, Java Spring web application, and deploy to a test environment using Docker._

![Project Architecture](https://programmaticponderings.files.wordpress.com/2015/09/spring-music-diagram.png)

[Introduction](#introduction)  
[Application Architecture](#application-architecture)  
[Spring Music Environment](#spring-music-environment)  
[Building the Environment](#building-the-environment)  
[Spring Music Application Links](#building-the-environment)  
[Helpful Links](#spring-music-application-links)

### Introduction
In this post, we will demonstrate how to build, deploy, and host a multi-tier Java application using Docker. For the demonstration, we will use a sample Java Spring application, available on GitHub from Cloud Foundry. Cloud Foundry's [Spring Music](https://github.com/cloudfoundry-samples/spring-music) sample record album collection application was originally designed to demonstrate the use of database services on [Cloud Foundry](http://www.cloudfoundry.com) and [Spring Framework](http://www.springframework.org). Instead of Cloud Foundry, we will host the Spring Music application using Docker with VirtualBox and optionally, AWS.

All files required to build this post's demonstration are located in the `master` branch of this [GitHub](https://github.com/garystafford/spring-music-docker/tree/docker_v2) repository. Instructions to clone the repository are below. The Java Spring Music application's source code, used in this post's demonstration, is located in the `master` branch of this [GitHub](https://github.com/garystafford/spring-music/tree/master) repository.

![Spring Music Application](https://programmaticponderings.files.wordpress.com/2015/09/spring-music.png)

A few changes were necessary to the original Spring Music application to make it work for the this demonstration. At a high-level, the changes included:

* Modify MongoDB configuration class to work with non-local MongoDB instances
* Add Gradle `warNoStatic` task to build WAR file without the static assets, which will be host separately in NGINX
* Create new Gradle task, `zipStatic`, to ZIP up the application's static assets for deployment to NGINX
* Add versioning scheme for build artifacts
* Add `context.xml` file and `MANIFEST.MF` file to the WAR file
* Add log4j `syslog` appender to send log entries to Logstash
* Update versions of several dependencies, including Gradle to 2.6

### Application Architecture
The Java Spring Music application stack contains the following technologies:

* [Java](http://openjdk.java.net)
* [Spring Framework](http://projects.spring.io/spring-framework)
* [NGINX](http://nginx.org)
* [Apache Tomcat](http://tomcat.apache.org)
* [MongoDB](http://mongoDB.com)
* [ELK Stack](https://www.elastic.co/products)
* [Logspout](https://github.com/gliderlabs/logspout)
* [Logspout-Logstash Adapter](https://github.com/looplab/logspout-logstash)

The Spring Music web application's static content will be hosted by [NGINX](http://nginx.org) for increased performance. The application's WAR file will be hosted by [Apache Tomcat](http://tomcat.apache.org). Requests for non-static content will be proxied through a single instance of NGINX on the front-end, to one of two load-balanced Tomcat instances on the back-end. NGINX will also be configured to allow for browser caching of the static content, to further increase application performance. Reverse proxying and caching are configured thought NGINX's `default.conf` file's `server` configuration section:
```text
server {
  listen        80;
  server_name   proxy;

  location ~* \/assets\/(css|images|js|template)\/* {
    root          /usr/share/nginx/;
    expires       max;
    add_header    Pragma public;
    add_header    Cache-Control "public, must-revalidate, proxy-revalidate";
    add_header    Vary Accept-Encoding;
    access_log    off;
  }
```

The two Tomcat instances will be configured on NGINX, in a load-balancing pool, using NGINX's default round-robin load-balancing algorithm. This is configured through NGINX's `default.conf` file's `upstream` configuration section:
```text
upstream backend {
  server app01:8080;
  server app02:8080;
}
```

The Spring Music application can be run with MySQL, Postgres, Oracle, MongoDB, Redis, or H2, an in-memory Java SQL database. Given the choice of both SQL and NoSQL databases available for use with the Spring Music application, we will select MongoDB.

The Spring Music application, hosted by Tomcat, will store and modify record album data in a single instance of MongoDB. MongoDB will be populated with a collection of album data when the Spring Music application first creates the MongoDB database instance.

Lastly, the ELK Stack with Logspout, will aggregate both Docker and Java Log4j log entries, providing debugging and analytics to our demonstration. I've used the same method for Docker and Java Log4j log entries, as detailed in this previous [post](https://programmaticponderings.wordpress.com/2015/08/02/log-aggregation-visualization-and-analysis-of-microservices-using-elk-stack-and-logspout/).

![Kibana 4 Web Console](https://programmaticponderings.files.wordpress.com/2016/07/kibana4_output.png)

### Spring Music Environment
To build, deploy, and host the Java Spring Music application, we will use the following technologies:

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

All files necessary to build this project are stored in the [garystafford/spring-music-docker](https://github.com/garystafford/spring-music-docker/docker_v2) repository on GitHub. The Spring Music source code and build artifacts are stored in a separate [garystafford/spring-music](https://github.com/garystafford/spring-music) repository, also on GitHub.

Build artifacts are automatically built by [Travis CI](https://travis-ci.org) when changes are checked into the [garystafford/spring-music](https://github.com/garystafford/spring-music) repository on GitHub. Travis CI then overwrites the build artifacts back to a [build artifact](https://github.com/garystafford/spring-music/tree/build-artifacts) branch of that same project. The build artifact branch acts as a pseudo [binary repository](https://en.wikipedia.org/wiki/Binary_repository_manager) for the project. The `.travis.yaml` file`gradle.build` file, and `deploy.sh` script handles these functions.

.travis.yaml file:
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

gradle.build file snippet:
```groovy
// new Gradle build tasks

task warNoStatic(type: War) {
  // omit the version from the war file name
  version = ''
  exclude '**/assets/**'
  manifest {
    attributes
      'Manifest-Version': '1.0',
      'Created-By': currentJvm,
      'Gradle-Version': GradleVersion.current().getVersion(),
      'Implementation-Title': archivesBaseName + '.war',
      'Implementation-Version': artifact_version,
      'Implementation-Vendor': 'Gary A. Stafford'
  }
}

task warCopy(type: Copy) {
  from 'build/libs'
  into 'build/distributions'
  include '**/*.war'
}

task zipGetVersion (type: Task) {
  ext.versionfile =
    new File("${projectDir}/src/main/webapp/assets/buildinfo.properties")
  versionfile.text = 'build.version=' + artifact_version
}

task zipStatic(type: Zip) {
  from 'src/main/webapp/assets'
  appendix = 'static'
  version = ''
}
```

deploy.sh file:
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
# /dev/null to hide any sensitive credential data that might otherwise be exposed.
# Environment variables pre-configured on Travis CI.
git push --force --quiet "https://${GH_TOKEN}@${GH_REF}" master:build-artifacts > /dev/null 2>&1
```
Base Docker images, such as NGINX, Tomcat, and MongoDB, used to build the project's images and subsequently the containers, are all pulled from Docker Hub.

This NGINX and Tomcat Dockerfiles pull the latest build artifacts down to build the project-specific versions of the NGINX and Tomcat Docker images used for this project. For example, the NGINX `Dockerfile` looks like:
```text
# NGINX image with build artifact

FROM nginx:latest

MAINTAINER Gary A. Stafford <garystafford@rochester.rr.com>

ENV GITHUB_REPO https://github.com/garystafford/spring-music/raw/build-artifacts
ENV STATIC_FILE spring-music-static.zip

RUN apt-get update -y && \
  apt-get install wget unzip nano -y && \
  wget -O /tmp/${STATIC_FILE} ${GITHUB_REPO}/${STATIC_FILE} && \
  unzip /tmp/${STATIC_FILE} -d /usr/share/nginx/assets/

COPY default.conf /etc/nginx/conf.d/default.conf
```

Docker Machine builds a single VirtualBox VM. After building the VM, Docker Compose then builds and deploys (1) NGINX container, (2) load-balanced Tomcat containers, (1) MongoDB container, (1) ELK container, and (1) Logspout container, onto the VM. Docker Machine's VirtualBox driver provides a basic solution that can be run locally for testing and development.

This post was recently updated for Docker 1.12.0, to use Docker Compose's v2 yaml file format. The `docker-compose-v2.yml` for the project is as follows:
```yaml
version: '2'
services:

  proxy:
    build: nginx/
    ports:
     - "80:80"
    depends_on:
     - app01
     - app02
    hostname: "proxy"
    container_name: "proxy"

  app01:
    build: tomcat/
    ports:
     - "8180:8080"
    depends_on:
     - nosqldb
    hostname: "app01"
    container_name: "app01"

  app02:
    build: tomcat/
    ports:
     - "8280:8080"
    depends_on:
     - nosqldb
    hostname: "app02"
    container_name: "app02"

  nosqldb:
    build: mongo/
    depends_on:
     - logspout
    hostname: "nosqldb"
    container_name: "nosqldb"
    volumes:
     - "music_data:/data/db"
     - "music_data:/data/configdb"

  logspout:
    build: logspout/
    volumes:
     - "/var/run/docker.sock:/var/run/docker.sock"
    ports:
     - "8083:80"
    depends_on:
     - elk
    hostname: "logspout"
    container_name: "logspout"
    environment:
      - ROUTE_URIS=logstash://elk:5000

  elk:
    build: elk/
    ports:
     - "8081:80"
     - "8082:9200"
     - "5000:5000/udp"
     - "5001:5001/udp"
    hostname: "elk"
    container_name: "elk"

volumes:
  music_data:
    external: true
```

### Building the Environment
Make sure VirtualBox, Docker, Docker Compose, and Docker Machine, are all installed and running. At the time of this post, I have the following versions of software installed:
```text
VirtualBox 5.0.24
Docker version 1.12.0 (Mac version 1.12.0-beta21)
docker-compose version 1.8.0
docker-machine version 0.8.0
```

All of the below commands may be executed with the following single command (`sh ./build_project.sh`). This is useful for working with [Jenkins CI](https://jenkins-ci.org/), [ThoughtWorks go](http://www.thoughtworks.com/products/go-continuous-delivery), or similar CI tools. However, I suggest building the project step-by-step, as shown below, to better understand the process.
```bash
# clone project
git clone -b master --single-branch \
  https://github.com/garystafford/spring-music-docker.git &&
cd spring-music-docker

# build VM
docker-machine create --driver virtualbox springmusic

# set new environment
docker-machine env springmusic && \
eval "$(docker-machine env springmusic)"

# create directory to store mongo data on host
docker volume create --name music_data

# build images and containers (sleep built in for sequencing startup times)
docker-compose -f docker-compose-v2.yml -p music up -d elk && sleep 5 && \
docker-compose -f docker-compose-v2.yml -p music up -d logspout && sleep 5 && \
docker-compose -f docker-compose-v2.yml -p music up -d nosqldb && sleep 5 && \
docker-compose -f docker-compose-v2.yml -p music up -d app01 app02 && sleep 10 && \
docker-compose -f docker-compose-v2.yml -p music up -d proxy && sleep 5

# optional: configure local DNS resolution for application URL
#echo "$(docker-machine ip springmusic)   springmusic.com" | sudo tee --append /etc/hosts

# run quick connectivity test of application
for i in {1..10}; do curl -I $(docker-machine ip springmusic);done
```

By simply changing the driver to AWS EC2 and providing your AWS credentials, the same environment can be built on AWS within a single EC2 instance. The 'springmusic' environment has been fully tested both locally with VirtualBox, as well as on AWS.

**Results**
Resulting Docker images and containers:
```text
$ docker-machine ls
NAME          ACTIVE   DRIVER       STATE     URL                         SWARM              DOCKER        ERRORS
springmusic   *        virtualbox   Running   tcp://192.168.99.100:2376                      v1.12.0-rc5
```

```text
$ docker images
REPOSITORY            TAG                 IMAGE ID            CREATED             SIZE
music_proxy           latest              8e000d4646cd        5 days ago          228.8 MB
music_app01           latest              c1bb4b5e8b3b        5 days ago          401.4 MB
music_app02           latest              c1bb4b5e8b3b        5 days ago          401.4 MB
music_nosqldb         latest              8b91389f1bc2        5 days ago          336.1 MB
music_logspout        latest              7d017d97a9d7        5 days ago          25.68 MB
music_elk             latest              b6018a1e8a13        5 days ago          878.3 MB
mongo                 latest              7f09d45df511        2 weeks ago         336.1 MB
tomcat                latest              25e98610c7d0        3 weeks ago         359.2 MB
willdurand/elk        latest              26bad05fb77c        7 weeks ago         878.3 MB
nginx                 latest              0d409d33b27e        8 weeks ago         182.8 MB
gliderlabs/logspout   latest              6c7afda380b2        9 weeks ago         15.27 MB
```

```text
$ docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS                                                                  NAMES
4bd306c5788d        music_proxy         "nginx -g 'daemon off"   10 seconds ago      Up 10 seconds       0.0.0.0:80->80/tcp, 443/tcp                                            proxy
94b27bcf7bb6        music_app01         "catalina.sh run"        21 seconds ago      Up 21 seconds       0.0.0.0:8180->8080/tcp                                                 app01
0250016345d1        music_app02         "catalina.sh run"        21 seconds ago      Up 21 seconds       0.0.0.0:8280->8080/tcp                                                 app02
1a0dc3c7a7a3        music_logspout      "/bin/logspout"          2 days ago          Up 21 seconds       0.0.0.0:8083->80/tcp                                                   logspout
bb2f9f446104        music_elk           "/usr/bin/supervisord"   2 days ago          Up 2 days           0.0.0.0:5000->5000/udp, 0.0.0.0:8081->80/tcp, 0.0.0.0:8082->9200/tcp   elk
c38a29713647        music_nosqldb       "/entrypoint.sh mongo"   2 days ago          Up 2 days           27017/tcp                                                              nosqldb
```

Partial result of the curl test, calling NGINX. Note the two different 'Upstream-Address' IPs for Tomcat application instances (app01 and app02). Also, note the sharp decrease in 'Request-Time', due to caching, for both Tomcat application instances.
```text
? for i in {1..10}; do curl -I $(docker-machine ip springmusic);done
HTTP/1.1 200 OK
Server: nginx/1.11.1
Date: Sat, 30 Jul 2016 18:34:08 GMT
Content-Type: text/html;charset=ISO-8859-1
Content-Length: 2090
Connection: keep-alive
Accept-Ranges: bytes
ETag: W/"2090-1444826112000"
Last-Modified: Wed, 14 Oct 2015 12:35:12 GMT
Content-Language: en
Request-Time: 0.157
Upstream-Address: 172.18.0.6:8080
Upstream-Response-Time: 1469903648.409

HTTP/1.1 200 OK
Server: nginx/1.11.1
Date: Sat, 30 Jul 2016 18:34:08 GMT
Content-Type: text/html;charset=ISO-8859-1
Content-Length: 2090
Connection: keep-alive
Accept-Ranges: bytes
ETag: W/"2090-1444826112000"
Last-Modified: Wed, 14 Oct 2015 12:35:12 GMT
Content-Language: en
Request-Time: 0.170
Upstream-Address: 172.18.0.5:8080
Upstream-Response-Time: 1469903648.822

HTTP/1.1 200 OK
Server: nginx/1.11.1
Date: Sat, 30 Jul 2016 18:34:09 GMT
Content-Type: text/html;charset=ISO-8859-1
Content-Length: 2090
Connection: keep-alive
Accept-Ranges: bytes
ETag: W/"2090-1444826112000"
Last-Modified: Wed, 14 Oct 2015 12:35:12 GMT
Content-Language: en
Request-Time: 0.010
Upstream-Address: 172.18.0.6:8080
Upstream-Response-Time: 1469903649.226

HTTP/1.1 200 OK
Server: nginx/1.11.1
Date: Sat, 30 Jul 2016 18:34:09 GMT
Content-Type: text/html;charset=ISO-8859-1
Content-Length: 2090
Connection: keep-alive
Accept-Ranges: bytes
ETag: W/"2090-1444826112000"
Last-Modified: Wed, 14 Oct 2015 12:35:12 GMT
Content-Language: en
Request-Time: 0.004
Upstream-Address: 172.18.0.5:8080
Upstream-Response-Time: 1469903649.465
```

### Spring Music Application Links
Assuming `springmusic` VM is running at `192.168.99.100`:
* Spring Music Application: [192.168.99.100](http://192.168.99.100)
* NGINX Status: [192.168.99.100/nginx_status](http://192.168.99.100/nginx_status)
* Tomcat Console - app01*: [192.168.99.100:8180/manager](http://192.168.99.100:8180/manager)
* Tomcat Console - app02*: [192.168.99.100:8280/manager](http://192.168.99.100:8280/manager)
* Spring Environment Endpoint - app01: [192.168.99.100:8180/env](http://192.168.99.100:8180/env)
* Spring Environment Endpoint - app01: [192.168.99.100:8280/env](http://192.168.99.100:8180/env)

* Kibana Console: [192.168.99.100:8081](http://192.168.99.100:8281)
* Elasticsearch Info: [192.168.99.100:8082](http://192.168.99.100:8082)
* Elasticsearch Status: [192.168.99.100:8082/_status?pretty](http://192.168.99.100:8082/_status?pretty)
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
* [Java log4j logging](http://help.papertrailapp.com/kb/configuration/java-log4j-logging/)
