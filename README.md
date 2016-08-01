_Build a multi-container, MongoDB-backed, Java Spring web application, and deploy to a test environment using Docker._

![Project Architecture](https://programmaticponderings.files.wordpress.com/2015/09/spring-music-diagram.png)

[Introduction](#introduction)  
[Application Architecture](#application-architecture)  
[Spring Music Environment](#spring-music-environment)  
[Building the Environment](#building-the-environment)  
[Spring Music Application Links](#building-the-environment)  
[Helpful Links](#spring-music-application-links)

### Docker 1.12 and Filebeat
This post was updated in July, 2016, to reflect changes in Docker 1.12, including the use of Docker Compose's v2 yaml format and scale feature. This post does make use Docker Swarm for scaling. The post's example project was also updated to use Filebeat with ELK, as opposed to Logstash and Logspout.

### Introduction
In this post, we will demonstrate how to build, deploy, and host a multi-tier Java application using Docker. For the demonstration, we will use a sample Java Spring application, available on GitHub from Cloud Foundry. Cloud Foundry's [Spring Music](https://github.com/cloudfoundry-samples/spring-music) sample record album collection application was originally designed to demonstrate the use of database services on [Cloud Foundry](http://www.cloudfoundry.com) and [Spring Framework](http://www.springframework.org). Instead of Cloud Foundry, we will host the Spring Music application using Docker with VirtualBox and optionally, AWS.

All files required to build this post's demonstration are located in the `docker_v2` branch of the [garystafford/spring-music-docker](https://github.com/garystafford/spring-music-docker/tree/docker_v2) repository. Instructions to clone the repository are below. The Java Spring Music application's source code, used in this post's demonstration, are located in the `docker_v2` branch of the [garystafford/spring-music](https://github.com/garystafford/spring-music/tree/docker_v2) repository.

![Spring Music Application](https://programmaticponderings.files.wordpress.com/2015/09/spring-music.png)

A few changes were necessary to the original Spring Music application to make it work for the this demonstration. At a high-level, the changes included:

* Modify MongoDB configuration class to work with non-local MongoDB instances
* Add Gradle `warNoStatic` task to build WAR file without the static assets, which will be host separately in NGINX
* Create new Gradle task, `zipStatic`, to ZIP up the application's static assets for deployment to NGINX
* Add versioning scheme for build artifacts
* Add `context.xml` file and `MANIFEST.MF` file to the WAR file
* Add log4j `syslog` appender to send log entries to Filebeat
* Update versions of several dependencies, including Gradle to 2.6

### Application Architecture
The Java Spring Music application stack contains the following technologies:

* [Java](http://openjdk.java.net)
* [Spring Framework](http://projects.spring.io/spring-framework)
* [NGINX](http://nginx.org)
* [Apache Tomcat](http://tomcat.apache.org)
* [MongoDB](http://mongoDB.com)
* [ELK Stack](https://www.elastic.co/products)
* [Filebeat](https://www.elastic.co/products/beats/filebeat)

The Spring Music web application's static content will be hosted by [NGINX](http://nginx.org) for increased performance. The application's WAR file will be hosted by [Apache Tomcat](http://tomcat.apache.org). Requests for non-static content will be proxied through a single instance of NGINX on the front-end, a set of load-balanced Tomcat instances on the back-end. NGINX will also be configured to allow for browser caching of the static content, to further increase application performance. Reverse proxying and caching are configured thought NGINX's `default.conf` file's `server` configuration section:
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

The multiple Tomcat instances will be configured on NGINX, in a load-balancing pool, using NGINX's default round-robin load-balancing algorithm. This is configured through NGINX's `default.conf` file's `upstream` configuration section:
```text
upstream backend {
  server music_app_1:8080;
  server music_app_2:8080;
  server music_app_3:8080;
}
```

The Spring Music application can be run with MySQL, Postgres, Oracle, MongoDB, Redis, or H2, an in-memory Java SQL database. Given the choice of both SQL and NoSQL databases available for use with the Spring Music application, we will select MongoDB.

The Spring Music application, hosted by Tomcat, will store and modify record album data in a single instance of MongoDB. MongoDB will be populated with a collection of album data when the Spring Music application first creates the MongoDB database instance.

Lastly, the ELK Stack with Filebeat, will aggregate both Docker and Java Log4j log entries, providing debugging and analytics to our demonstration. I've used the same method for Docker and Java Log4j log entries, as detailed in this previous [post](https://programmaticponderings.wordpress.com/2015/08/02/log-aggregation-visualization-and-analysis-of-microservices-using-elk-stack-and-logspout/).

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

All files necessary to build this project are stored in the `docker_v2` branch of the [garystafford/spring-music-docker](https://github.com/garystafford/spring-music-docker/docker_v2) repository on GitHub. The Spring Music source code and build artifacts are stored in a separate [garystafford/spring-music](https://github.com/garystafford/spring-music) repository, also on GitHub.

Build artifacts are automatically built by [Travis CI](https://travis-ci.org) when changes are checked into the `docker_v2` branch of the [garystafford/spring-music](https://github.com/garystafford/spring-music) repository on GitHub. Travis CI then overwrites the build artifacts back to a [build artifact](https://github.com/garystafford/spring-music/tree/build-artifacts) branch of that same project. The build artifact branch acts as a pseudo [binary repository](https://en.wikipedia.org/wiki/Binary_repository_manager) for the project. The `.travis.yaml` file`gradle.build` file, and `deploy.sh` script handles these functions.

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

cd build/distributions && git init

git config user.name "travis-ci"
git config user.email "auto-deploy@travis-ci.com"

git add .
git commit -m "Deploy Travis CI build #${TRAVIS_BUILD_NUMBER} artifacts to GitHub"

git push --force --quiet "https://${GH_TOKEN}@${GH_REF}" master:build-artifacts > /dev/null 2>&1
```
Base Docker images, such as NGINX, Tomcat, and MongoDB, used to build the project's images and subsequently the containers, are all pulled from Docker Hub.

This NGINX and Tomcat Dockerfiles pull the latest build artifacts down to build the project-specific versions of the NGINX and Tomcat Docker images used for this project. For example, the abridged NGINX `Dockerfile` looks like:
```text
FROM nginx

MAINTAINER Gary A. Stafford <garystafford@rochester.rr.com>
ENV REFRESHED_AT 2016-07-30

ENV GITHUB_REPO https://github.com/garystafford/spring-music/raw/build-artifacts
ENV STATIC_FILE spring-music-static.zip

RUN apt-get update -qq && \
  apt-get install -qqy curl wget unzip nano && \
  apt-get clean

RUN wget -O /tmp/${STATIC_FILE} ${GITHUB_REPO}/${STATIC_FILE} \
  && unzip /tmp/${STATIC_FILE} -d /usr/share/nginx/assets/

COPY default.conf /etc/nginx/conf.d/default.conf
```

Docker Machine builds a single VirtualBox VM. After building the VM, Docker Compose then builds and deploys (1) NGINX container, (3) load-balanced Tomcat containers, (1) MongoDB container, and (1) ELK container, onto the VM. Docker Machine's VirtualBox driver provides a basic solution that can be run locally for testing and development.

This post was recently updated for Docker 1.12.0, to use Docker Compose's v2 yaml file format. The `docker-compose-v2.yml` for the project is as follows:
```yaml
version: '2'

services:
  proxy:
    build: nginx/
    ports:
    - 80:80
    networks:
    - app-net
    depends_on:
    - app
    hostname: proxy
    container_name: proxy

  app:
    build: tomcat/
    ports:
    - 8080
    networks:
    - app-net
    depends_on:
    - mongodb

  mongodb:
    build: mongodb/
    networks:
    - app-net
    depends_on:
    - elk
    hostname: mongodb
    container_name: mongodb
    volumes:
    - music_data:/data/db:rw
    - music_data:/data/configdb:rw

  elk:
    image: sebp/elk:latest
    ports:
    - 5601:5601
    - 9200:9200
    - 5044:5044
    - 5000:5000
    networks:
    - app-net
    hostname: elk
    container_name: elk

volumes:
  music_data:
    external: true

networks:
  app-net:
    driver: bridge
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
  https://github.com/garystafford/spring-music-docker.git && \
cd spring-music-docker

# build VM
docker-machine create --driver virtualbox springmusic

# set new environment
docker-machine env springmusic && \
eval "$(docker-machine env springmusic)"

# create directory to store mongo data on host
docker volume create --name music_data

# create bridge network for project
docker network create -d bridge music_app-net

# build images and containers
docker-compose -p music up -d elk
docker-compose -p music up -d mongodb
docker-compose -p music up -d app
docker-compose scale app=3
docker-compose -p music up -d proxy

# run quick connectivity test of application
for i in {1..10}; do curl -I $(docker-machine ip springmusic); done
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
REPOSITORY            TAG                 IMAGE ID            CREATED             SIZE
music_proxy           latest              54ffc068a492        31 minutes ago      248.1 MB
music_app             latest              5b22cefca2d9        6 hours ago         415.2 MB
music_mongodb         latest              73f93a7b8d71        26 hours ago        336.1 MB
sebp/elk              latest              7916c6886a65        5 days ago          883.1 MB
mongo                 latest              7f09d45df511        2 weeks ago         336.1 MB
tomcat                latest              25e98610c7d0        3 weeks ago         359.2 MB
nginx                 latest              0d409d33b27e        8 weeks ago         182.8 MB

```text
$ docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS                                                                                                      NAMES
9eb1c1adc7c8        music_proxy         "/usr/local/bin/start"   24 minutes ago      Up 24 minutes       0.0.0.0:80->80/tcp, 443/tcp                                                                                proxy
0af162888365        music_app           "/usr/local/bin/start"   25 minutes ago      Up 25 minutes       0.0.0.0:32773->8080/tcp                                                                                    music_app_2
1da3ef56032e        music_app           "/usr/local/bin/start"   25 minutes ago      Up 25 minutes       0.0.0.0:32772->8080/tcp                                                                                    music_app_3
16671ce6701e        music_app           "/usr/local/bin/start"   25 minutes ago      Up 25 minutes       0.0.0.0:32771->8080/tcp                                                                                    music_app_1
591fdd06fcd4        music_mongodb       "/entrypoint.sh mongo"   25 minutes ago      Up 25 minutes       27017/tcp                                                                                                  mongodb
32fe86944432        sebp/elk:latest     "/usr/local/bin/start"   25 minutes ago      Up 25 minutes       0.0.0.0:5000->5000/tcp, 0.0.0.0:5044->5044/tcp, 0.0.0.0:5601->5601/tcp, 0.0.0.0:9200->9200/tcp, 9300/tcp   elk
```

Partial result of the curl test, calling NGINX. Note the difference of the 'Upstream-Address', for Tomcat application instances (`music_app_1`, `music_app_2`, `music_app_3`). Also, note the sharp decrease in the 'Request-Time', for the same Tomcat application instance, due to caching.
```text
? for i in {1..10}; do curl -I $(docker-machine ip springmusic);done
HTTP/1.1 200 OK
Server: nginx/1.11.1
Date: Mon, 01 Aug 2016 03:56:34 GMT
Content-Type: text/html;charset=ISO-8859-1
Content-Length: 2090
Connection: keep-alive
Accept-Ranges: bytes
ETag: W/"2090-1469971406000"
Last-Modified: Sun, 31 Jul 2016 13:23:26 GMT
Content-Language: en
Request-Time: 0.081
Upstream-Address: 172.18.0.4:8080
Upstream-Response-Time: 1470023794.838

HTTP/1.1 200 OK
Server: nginx/1.11.1
Date: Mon, 01 Aug 2016 03:56:35 GMT
Content-Type: text/html;charset=ISO-8859-1
Content-Length: 2090
Connection: keep-alive
Accept-Ranges: bytes
ETag: W/"2090-1469971406000"
Last-Modified: Sun, 31 Jul 2016 13:23:26 GMT
Content-Language: en
Request-Time: 0.144
Upstream-Address: 172.18.0.6:8080
Upstream-Response-Time: 1470023795.160

HTTP/1.1 200 OK
Server: nginx/1.11.1
Date: Mon, 01 Aug 2016 03:56:35 GMT
Content-Type: text/html;charset=ISO-8859-1
Content-Length: 2090
Connection: keep-alive
Accept-Ranges: bytes
ETag: W/"2090-1469971406000"
Last-Modified: Sun, 31 Jul 2016 13:23:26 GMT
Content-Language: en
Request-Time: 0.103
Upstream-Address: 172.18.0.5:8080
Upstream-Response-Time: 1470023795.538

HTTP/1.1 200 OK
Server: nginx/1.11.1
Date: Mon, 01 Aug 2016 03:56:35 GMT
Content-Type: text/html;charset=ISO-8859-1
Content-Length: 2090
Connection: keep-alive
Accept-Ranges: bytes
ETag: W/"2090-1469971406000"
Last-Modified: Sun, 31 Jul 2016 13:23:26 GMT
Content-Language: en
Request-Time: 0.008
Upstream-Address: 172.18.0.4:8080
Upstream-Response-Time: 1470023795.863
```

### Spring Music Application Links
Assuming `springmusic` VM is running at `192.168.99.100`:
* Spring Music Application: [192.168.99.100](http://192.168.99.100)
* NGINX Status: [192.168.99.100/nginx_status](http://192.168.99.100/nginx_status)
* Tomcat Console - music_app_1*: [192.168.99.100:32771/manager](http://192.168.99.100:32771/manager)
* Spring Environment - music_app_1: [192.168.99.100:32771/env](http://192.168.99.100:32771/env)

* Kibana Console: [192.168.99.100:5601](http://192.168.99.100:5601)
* Elasticsearch Info: [192.168.99.100:9200](http://192.168.99.100:8082)
* Elasticsearch Status: [192.168.99.100:9200/_status?pretty](http://192.168.99.100:8082/_status?pretty)

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
