[![Build Status](https://semaphoreci.com/api/v1/garystafford/spring-music/branches/springmusic_v2/badge.svg)](https://semaphoreci.com/garystafford/spring-music) [![Build Status](https://travis-ci.org/garystafford/spring-music.svg?branch=springmusic_v2)](https://travis-ci.org/garystafford/spring-music)

## Spring Music Revisited: Java-Spring-MongoDB Web App with Docker 1.12
_Build, deploy, and monitor a multi-container, MongoDB-backed, Java Spring web application, using the new Docker 1.12._

![Project Architecture](https://programmaticponderings.files.wordpress.com/2016/08/spring-music-diagram2.png)

### Introduction
This post and the post’s example project represent an update to a previous post, <a href="https://programmaticponderings.wordpress.com/2015/09/07/building-and-deploying-a-multi-container-java-spring-mongodb-application-using-docker/">Build and Deploy a Java-Spring-MongoDB Application using Docker</a>. This new post incorporates many improvements made in Docker 1.12, including the use of Docker Compose’s v2 YAML format. The post’s project was also updated to use Filebeat with ELK, as opposed to Logspout, which was used previously.

In this post, we will demonstrate how to build, deploy, and manage a Java Spring web application, hosted on Apache Tomcat, load-balanced by NGINX, monitored with Filebeat and ELK, and all containerized with Docker.

We will use a sample Java Spring application, <a href="https://github.com/cloudfoundry-samples/spring-music">Spring Music</a>, available on GitHub from Cloud Foundry. The Spring Music sample record album collection application was originally designed to demonstrate the use of database services on <a href="http://www.cloudfoundry.com">Cloud Foundry</a>, using the <a href="http://www.springframework.org">Spring Framework</a>. Instead of Cloud Foundry, we will host the Spring Music application locally, using Docker on VirtualBox, and optionally on AWS.

All files necessary to build this project are stored on the <code>docker_v2</code> branch of the <a href="https://github.com/garystafford/spring-music-docker/tree/docker_v2">garystafford/spring-music-docker</a> repository on GitHub. The Spring Music source code is stored on the <code>springmusic_v2</code> branch of the <a href="https://github.com/garystafford/spring-music/tree/springmusic_v2">garystafford/spring-music</a> repository, also on GitHub.

![Spring Music Application](https://programmaticponderings.files.wordpress.com/2016/08/spring-music2.png)

A few changes were necessary to the original Spring Music application to make it work for this demonstration. At a high-level, the changes included:
* Modify MongoDB configuration class to work with non-local, containerized MongoDB instances
* Add Gradle `warNoStatic` task to build WAR file without the static assets, which will be host separately in NGINX
* Create new Gradle task, `zipStatic`, to ZIP up the application's static assets for deployment to NGINX
* Add versioning scheme for build artifacts
* Add `context.xml` file and `MANIFEST.MF` file to the WAR file
* Add log4j `syslog` appender to send log entries to Filebeat
* Update versions of several dependencies, including Gradle

### Application Architecture
The Java Spring Music application stack contains the following technologies: <a href="http://openjdk.java.net">Java</a>, <a href="http://projects.spring.io/spring-framework">Spring Framework</a>, <a href="http://nginx.org">NGINX</a>, <a href="http://tomcat.apache.org">Apache Tomcat</a>, <a href="http://mongoDB.com">MongoDB</a>, the <a href="https://www.elastic.co/products">ELK Stack</a>, and <a href="https://www.elastic.co/products/beats/filebeat">Filebeat</a>

##### NGINX
To increase performance, the Spring Music web application’s static content will be hosted by <a href="http://nginx.org">NGINX</a>. The application’s WAR file will be hosted by <a href="http://tomcat.apache.org">Apache Tomcat</a>. Requests for non-static content will be proxied through NGINX on the front-end, to a set of three load-balanced Tomcat instances on the back-end. To further increase application performance, NGINX will also be configured for browser caching of the static content.

Reverse proxying and caching are configured thought NGINX’s <code>default.conf</code> file, in the <code>server</code> configuration section:
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

The three Tomcat instances will be manually configured for load-balancing using NGINX’s default round-robin load-balancing algorithm. This is configured through the <code>default.conf</code> file, in the <code>upstream</code> configuration section:
```text
upstream backend {
  server music_app_1:8080;
  server music_app_2:8080;
  server music_app_3:8080;
}
```

##### MongoDB
The Spring Music application was designed to run with MySQL, Postgres, Oracle, MongoDB, Redis, or H2, an in-memory Java SQL database. Given the choice of both SQL and NoSQL databases, we will select MongoDB.

The Spring Music application, hosted by Tomcat, will store and modify record album data in a single instance of MongoDB. MongoDB will be populated with a collection of album data, from a JSON file, when the Spring Music application first creates the MongoDB database instance.

##### ELK
Lastly, the ELK Stack, with Filebeat, will aggregate both Docker and Java Log4j log entries, providing debugging and analytics to our demonstration. A similar method for aggregating logs, using Logspout instead of Filebeat, can be found in this previous <a href="https://programmaticponderings.wordpress.com/2015/08/02/log-aggregation-visualization-and-analysis-of-microservices-using-elk-stack-and-logspout/">post</a>.

![Kibana 4 Web Console](https://programmaticponderings.files.wordpress.com/2016/08/kibana4_output_filebeat1.png)

### Build and Publish Artifacts
We will use the following technologies, to build, publish, deploy, and host the Java Spring Music application: <a href="https://gradle.org">Gradle</a>, <a href="https://git-scm.com">git</a>, <a href="https://github.com">GitHub</a>, <a href="https://travis-ci.org">Travis CI</a>, <a href="https://www.virtualbox.org">Oracle VirtualBox</a>, <a href="https://www.docker.com">Docker</a>, <a href="https://www.docker.com/docker-compose">Docker Compose</a>, <a href="https://www.docker.com/docker-machine">Docker Machine</a>, <a href="https://hub.docker.com">Docker Hub</a>, and optionally, <a href="http://aws.amazon.com">Amazon Web Services (AWS)</a>

In this post's example, the two build artifacts, a WAR file for the app and ZIP file for the static web content, are built automatically by [Travis CI](https://travis-ci.org), whenever changes are pushed to the `springmusic_v2` branch of the [garystafford/spring-music](https://github.com/garystafford/spring-music) repository on GitHub.

![Travis CI Output](https://programmaticponderings.files.wordpress.com/2016/08/travisci1.png)

Following a successful build, Travis CI pushes the build artifacts to the `build-artifacts` branch on the same GitHub project. The `build-artifacts` branch acts as a pseudo [binary repository](https://en.wikipedia.org/wiki/Binary_repository_manager) for the project, much like JFrog's [Artifactory](https://www.jfrog.com/artifactory).

![Build Artifact Repository](https://programmaticponderings.files.wordpress.com/2016/08/build-artifacts.png)

Finally, Travis CI pushes build result notifications to a Slack channel, which eliminates the need to actively monitor the build.

![Slack](https://programmaticponderings.files.wordpress.com/2016/08/travisci_slack.png)

You can easily replicate this CI automation using your own continuous integration server, such as Travis CI, [Semaphore](https://semaphoreci.com), or [Jenkins](https://jenkins.io), coupled with a persistent chat application, such as  Glider Labs' [Slack](https://slack.com) or Atlassian's [HipChat](https://www.atlassian.com/software/hipchat). You could also simply push notifications to favorite IM app.

The Travis CI `.travis.yaml` file, custom `gradle.build` Gradle tasks, and the `deploy.sh` script handles the CI automation described, above.

Travis CI `.travis.yaml` file:
```yaml
language: java
jdk: oraclejdk8
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
  - secure: <your_secure_hash_here>
notifications:
  slack:
  - secure: <your_secure_hash_here>
```

Custom `gradle.build` tasks:
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

The `deploy.sh` file:
```bash
#!/bin/bash

# reference: https://gist.github.com/domenic/ec8b0fc8ab45f39403dd

set -e # exit with nonzero exit code if anything fails

cd build/distributions && git init

git config user.name "travis-ci"
git config user.email "auto-deploy@travis-ci.com"

git add .
git commit -m "Deploy Travis CI build #${TRAVIS_BUILD_NUMBER} artifacts to GitHub"
git push --force --quiet "https://${GH_TOKEN}@${GH_REF}" \
  master:build-artifacts > /dev/null 2>&1
```

### Docker
Docker Machine provisions a single VirtualBox VM to host the project’s containers. VirtualBox provides a quick and easy solution that can be run locally for initial development and testing of the application.

Next, the Docker data volume and project-specific Docker bridge network are built.

Next, using the project’s individual Dockerfiles, Docker Compose pulls base Docker images from Docker Hub for NGINX, Tomcat, ELK, and MongoDB. Project-specific Docker images are then built for NGINX, Tomcat, and MongoDB. While constructing the project-specific Docker images for NGINX and Tomcat, the latest Spring Music build artifacts are pulled and installed into the corresponding Docker images.

For example, the abridged NGINX `Dockerfile` looks like:
```text
FROM nginx

MAINTAINER Gary A. Stafford <garystafford@rochester.rr.com>
ENV REFRESHED_AT 2016-07-30

ENV GITHUB_REPO https://github.com/garystafford/spring-music/raw/build-artifacts
ENV STATIC_FILE spring-music-static.zip

RUN apt-get update -qq && \
  apt-get install -qqy curl wget unzip && \
  apt-get clean

RUN wget -O /tmp/${STATIC_FILE} ${GITHUB_REPO}/${STATIC_FILE} \
  && unzip /tmp/${STATIC_FILE} -d /usr/share/nginx/assets/

COPY default.conf /etc/nginx/conf.d/default.conf
```

Finally, Docker builds and deploys (1) NGINX container, (3) Tomcat containers, (1) MongoDB container, and (1) ELK container, onto the VirtualBox VM.

![Project Architecture](https://programmaticponderings.files.wordpress.com/2016/08/spring-music-diagram2.png)

##### Docker Compose v2 YAML
This post was recently updated for Docker 1.12.0, to use Docker Compose's v2 YAML file format. The post's example `docker-compose.yml` takes advantage of many of Docker 1.12 and Compose's v2 format improved functionality:
```yaml
version: '2'

services:
  proxy:
    build: nginx/
    ports:
    - 80:80
    networks:
    - net
    depends_on:
    - app
    hostname: proxy
    container_name: proxy

  app:
    build: tomcat/
    ports:
    - 8080
    networks:
    - net
    depends_on:
    - mongodb

  mongodb:
    build: mongodb/
    networks:
    - net
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
    - net
    hostname: elk
    container_name: elk

volumes:
  music_data:
    external: true

networks:
  net:
    driver: bridge
```

### Building Docker Environment Locally
Make sure VirtualBox, Docker, Docker Compose, and Docker Machine, are installed and running. At the time of this post, I have the following versions of software installed on my Mac, which is running OS X 10.11.6:
```text
VirtualBox 5.0.26
Docker 1.12.0
Docker Compose 1.8.0
Docker Machine 0.8.0
```

To build the project's VM, Images, and Containers, execute the following command, `sh ./build_project.sh`. This is useful for working with [Jenkins CI](https://jenkins-ci.org/), [ThoughtWorks go](http://www.thoughtworks.com/products/go-continuous-delivery), or similar CI tools. However, I suggest first running each command separately, locally, to understand the build process.
```bash
# clone project and rename project folder
git clone -b springmusic_v2 --single-branch \
  https://github.com/garystafford/spring-music-docker.git
mv spring-music-docker/ music/ && cd music/

# provision VirtualBox VM
docker-machine create --driver virtualbox springmusic

# set new environment
docker-machine env springmusic && \
eval "$(docker-machine env springmusic)"

# create directory to store mongo data on host
# ** assumes your project folder is 'music' **
docker volume create --name music_data

# create bridge network for project
# ** assumes your project folder is 'music' **
docker network create -d bridge music_net

# build images and orchestrate start-up of containers (in this order)
docker-compose -p music up -d elk && sleep 15 && \
docker-compose -p music up -d mongodb && sleep 15 && \
docker-compose -p music up -d app && \
docker-compose scale app=3 && sleep 15 && \
docker-compose -p music up -d proxy

# run a simple connectivity test of application
for i in {1..10}; do curl -I $(docker-machine ip springmusic); done
```

##### AWS
By simply changing the driver to AWS EC2 and providing your AWS credentials, the same environment can be built on AWS using a single EC2 instance. The `springmusic` environment has been fully tested both locally with VirtualBox, as well as on AWS.

### The Results
Resulting Docker Machine VirtualBox VM:
```text
$ docker-machine ls
NAME          ACTIVE   DRIVER       STATE     URL                         SWARM              DOCKER        ERRORS
springmusic   *        virtualbox   Running   tcp://192.168.99.100:2376                      v1.12.0-rc5
```

Resulting external volume:
```text
$ docker volume ls
DRIVER              VOLUME NAME
local               music_data
```

Resulting bridge network:
```text
$ docker network ls
NETWORK ID          NAME             DRIVER              SCOPE
f564dfa1b440        music_net        bridge              local
```

Resulting Docker images - (4) base images and (3) project images:
```text
$ docker images
REPOSITORY            TAG                 IMAGE ID            CREATED             SIZE
music_proxy           latest              54ffc068a492        31 minutes ago      248.1 MB
music_app             latest              5b22cefca2d9        6 hours ago         415.2 MB
music_mongodb         latest              73f93a7b8d71        26 hours ago        336.1 MB
sebp/elk              latest              7916c6886a65        5 days ago          883.1 MB
mongo                 latest              7f09d45df511        2 weeks ago         336.1 MB
tomcat                latest              25e98610c7d0        3 weeks ago         359.2 MB
nginx                 latest              0d409d33b27e        8 weeks ago         182.8 MB
```

Resulting (6) Docker containers:
```text
$ docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS                                                                                                      NAMES
e24f279bb249        music_proxy         "/usr/local/bin/start"   3 minutes ago       Up 3 minutes        0.0.0.0:80->80/tcp, 443/tcp                                                                                proxy
f77a67a6c907        music_app           "/usr/local/bin/start"   3 minutes ago       Up 3 minutes        0.0.0.0:32775->8080/tcp                                                                                    music_app_3
c2c210df38da        music_app           "/usr/local/bin/start"   3 minutes ago       Up 3 minutes        0.0.0.0:32776->8080/tcp                                                                                    music_app_2
80ee8c24f425        music_app           "/usr/local/bin/start"   3 minutes ago       Up 3 minutes        0.0.0.0:32774->8080/tcp                                                                                    music_app_1
a0d1c5336d6a        music_mongodb       "/entrypoint.sh mongo"   3 minutes ago       Up 3 minutes        27017/tcp                                                                                                  mongodb
ec47f6c0147d        sebp/elk:latest     "/usr/local/bin/start"   4 minutes ago       Up 4 minutes        0.0.0.0:5000->5000/tcp, 0.0.0.0:5044->5044/tcp, 0.0.0.0:5601->5601/tcp, 0.0.0.0:9200->9200/tcp, 9300/tcp   elk
```

### Testing the Application
Below are partial result of the curl test, hitting the NGINX endpoint. Note the different IP addresses in the `Upstream-Address` field between requests. This demonstrates NGINX's round-robin load-balancing is working across the three Tomcat application instances: `music_app_1`, `music_app_2`, and `music_app_3`.

Also, note the sharp decrease in the `Request-Time` between the first request, and subsequent requests. The `Upstream-Response-Time` to the Tomcat instances doesn't change, yet the total `Request-Time` is much shorter, due to caching of the application's static assets by NGINX.
```text
? for i in {1..10}; do curl -I $(docker-machine ip springmusic);done
HTTP/1.1 200 OK
Server: nginx/1.11.1
Date: Thu, 04 Aug 2016 01:18:07 GMT
Content-Type: text/html;charset=ISO-8859-1
Content-Length: 2090
Connection: keep-alive
Accept-Ranges: bytes
ETag: W/"2090-1469971406000"
Last-Modified: Sun, 31 Jul 2016 13:23:26 GMT
Content-Language: en
Request-Time: 1.433
Upstream-Address: 172.18.0.4:8080
Upstream-Response-Time: 1470273485.810

HTTP/1.1 200 OK
Server: nginx/1.11.1
Date: Thu, 04 Aug 2016 01:18:07 GMT
Content-Type: text/html;charset=ISO-8859-1
Content-Length: 2090
Connection: keep-alive
Accept-Ranges: bytes
ETag: W/"2090-1469971406000"
Last-Modified: Sun, 31 Jul 2016 13:23:26 GMT
Content-Language: en
Request-Time: 0.138
Upstream-Address: 172.18.0.6:8080
Upstream-Response-Time: 1470273487.479

HTTP/1.1 200 OK
Server: nginx/1.11.1
Date: Thu, 04 Aug 2016 01:18:08 GMT
Content-Type: text/html;charset=ISO-8859-1
Content-Length: 2090
Connection: keep-alive
Accept-Ranges: bytes
ETag: W/"2090-1469971406000"
Last-Modified: Sun, 31 Jul 2016 13:23:26 GMT
Content-Language: en
Request-Time: 0.253
Upstream-Address: 172.18.0.5:8080
Upstream-Response-Time: 1470273487.848

HTTP/1.1 200 OK
Server: nginx/1.11.1
Date: Thu, 04 Aug 2016 01:18:08 GMT
Content-Type: text/html;charset=ISO-8859-1
Content-Length: 2090
Connection: keep-alive
Accept-Ranges: bytes
ETag: W/"2090-1469971406000"
Last-Modified: Sun, 31 Jul 2016 13:23:26 GMT
Content-Language: en
Request-Time: 0.007
Upstream-Address: 172.18.0.4:8080
Upstream-Response-Time: 1470273488.329

HTTP/1.1 200 OK
Server: nginx/1.11.1
Date: Thu, 04 Aug 2016 01:18:08 GMT
Content-Type: text/html;charset=ISO-8859-1
Content-Length: 2090
Connection: keep-alive
Accept-Ranges: bytes
ETag: W/"2090-1469971406000"
Last-Modified: Sun, 31 Jul 2016 13:23:26 GMT
Content-Language: en
Request-Time: 0.007
Upstream-Address: 172.18.0.6:8080
Upstream-Response-Time: 1470273488.565
```

### Spring Music Application Links
Assuming `springmusic` VM is running at `192.168.99.100`:
* Spring Music Application: [192.168.99.100](http://192.168.99.100)
* NGINX Status: [192.168.99.100/nginx_status](http://192.168.99.100/nginx_status)
* Tomcat Console - music_app_1*: [192.168.99.100:32771/manager](http://192.168.99.100:32771/manager)
* Spring Environment - music_app_1: [192.168.99.100:32771/env](http://192.168.99.100:32771/env)
* Elasticsearch Info: [192.168.99.100:9200](http://192.168.99.100:8082)
* Elasticsearch Status: [192.168.99.100:9200/_status?pretty](http://192.168.99.100:8082/_status?pretty)
* Kibana Web Console: [192.168.99.100:5601](http://192.168.99.100:5601)

_* The Tomcat user name is `admin` and the password is `t0mcat53rv3r`._

### TODOs
* Automate the Docker image build and repository publish process
* Automate the Docker container build and deploy process
* Add Post-deployment Verification Testing to the project
* Update Spring Music with latest CF project revisions
* Add Docker Swarm multi-host capabilities
* Add scripting to stand-up project on AWS

### Helpful Links
* [Cloud Foundry's Spring Music Example](https://github.com/cloudfoundry-samples/spring-music)
* [Getting Started with Gradle for Java](https://gradle.org/getting-started-gradle-java)
* [Introduction to Gradle](https://semaphoreci.com/community/tutorials/introduction-to-gradle)
* [Spring Framework](http://projects.spring.io/spring-framework)
* [Understanding Nginx HTTP Proxying, Load Balancing, Buffering, and Caching](https://www.digitalocean.com/community/tutorials/understanding-nginx-http-proxying-load-balancing-buffering-and-caching)
* [Common conversion patterns for log4j's PatternLayout](http://www.codejava.net/coding/common-conversion-patterns-for-log4js-patternlayout)
* [Spring @PropertySource example](http://www.mkyong.com/spring/spring-propertysources-example)
* [Java log4j logging](http://help.papertrailapp.com/kb/configuration/java-log4j-logging/)
