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

### Application Architecture
The Java Spring Music application stack contains the following technologies: <a href="http://openjdk.java.net">Java</a>, <a href="http://projects.spring.io/spring-framework">Spring Framework</a>, <a href="http://nginx.org">NGINX</a>, <a href="http://tomcat.apache.org">Apache Tomcat</a>, <a href="http://mongoDB.com">MongoDB</a>, the <a href="https://www.elastic.co/products">ELK Stack</a>, and <a href="https://www.elastic.co/products/beats/filebeat">Filebeat</a>.

A few changes were necessary to the original Spring Music application to make it work for this demonstration. At a high-level, the changes included:
* Modify MongoDB configuration class to work with non-local, containerized MongoDB instances
* Add Gradle `warNoStatic` task to build WAR file without the static assets, which will be host separately in NGINX
* Create new Gradle task, `zipStatic`, to ZIP up the application's static assets for deployment to NGINX
* Add versioning scheme for build artifacts
* Add `context.xml` file and `MANIFEST.MF` file to the WAR file
* Add log4j `syslog` appender to send log entries to Filebeat
* Update versions of several dependencies, including Gradle

We will use the following technologies to build, publish, deploy, and host the Java Spring Music application: <a href="https://gradle.org">Gradle</a>, <a href="https://git-scm.com">git</a>, <a href="https://github.com">GitHub</a>, <a href="https://travis-ci.org">Travis CI</a>, <a href="https://www.virtualbox.org">Oracle VirtualBox</a>, <a href="https://www.docker.com">Docker</a>, <a href="https://www.docker.com/docker-compose">Docker Compose</a>, <a href="https://www.docker.com/docker-machine">Docker Machine</a>, <a href="https://hub.docker.com">Docker Hub</a>, and optionally, <a href="http://aws.amazon.com">Amazon Web Services (AWS)</a>.

##### NGINX
To increase performance, the Spring Music web application’s static content will be hosted by <a href="http://nginx.org">NGINX</a>. The application’s WAR file will be hosted by <a href="http://tomcat.apache.org">Apache Tomcat</a>. Requests for non-static content will be proxied through NGINX on the front-end, to a set of three load-balanced Tomcat instances on the back-end. To further increase application performance, NGINX will also be configured for browser caching of the static content. In many enterprise environments, the use of a Java EE application server, like Tomcat, is still not uncommon.

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

### Continuous Integration
In this post’s example, two build artifacts, a WAR file for the application and ZIP file for the static web content, are built automatically by <a href="https://travis-ci.org">Travis CI</a>, whenever source code changes are pushed to the <code>springmusic_v2</code> branch of the <a href="https://github.com/garystafford/spring-music">garystafford/spring-music</a> repository on GitHub.

![Travis CI Output](https://programmaticponderings.files.wordpress.com/2016/08/travisci1.png)

Following a successful build, Travis CI pushes the build artifacts to the <code>build-artifacts</code> branch on the same GitHub project. The <code>build-artifacts</code> branch acts as a pseudo <a href="https://en.wikipedia.org/wiki/Binary_repository_manager">binary repository</a> for the project, much like JFrog’s <a href="https://www.jfrog.com/artifactory">Artifactory</a>. These artifacts are used later by Docker to build the project’s immutable Docker images and containers.

![Build Artifact Repository](https://programmaticponderings.files.wordpress.com/2016/08/build-artifacts.png)

##### Build Notifications
Travis CI pushes build notifications to a <a href="https://slack.com">Slack</a> channel, which eliminates the need to actively monitor Travis CI.

![Slack](https://programmaticponderings.files.wordpress.com/2016/08/travisci_slack.png)

##### Automation Scripting
The Travis CI <code>.travis.yaml</code> file, custom <code>gradle.build</code> Gradle tasks, and the <code>deploy.sh</code> script handles the CI automation described, above.

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
You can easily replicate the project’s CI automation using your choice of toolchains. <a href="https://github.com">GitHub</a> or <a href="https://bitbucket.org">BitBucket</a> are good choices for distributed version control. For continuous integration and deployment, I recommend Travis CI, <a href="https://semaphoreci.com">Semaphore</a>, <a href="https://codeship.com">Codeship</a>, or <a href="https://jenkins.io">Jenkins</a>. Couple this with a good persistent chat application, such as Glider Labs’ <a href="https://slack.com">Slack</a> or Atlassian’s <a href="https://www.atlassian.com/software/hipchat">HipChat</a>.

### Building the Docker Environment
Make sure VirtualBox, Docker, Docker Compose, and Docker Machine, are installed and running. At the time of this post, I have the following versions of software installed on my Mac:
```text
Mac OS X 10.11.6
VirtualBox 5.0.26
Docker 1.12.1
Docker Compose 1.8.0
Docker Machine 0.8.1
```

To build the project’s host VM, Docker images, and containers, run the build script, using the following command: <code>sh ./build_project.sh</code>. This script is useful when working with CI/CD automation tools, such as <a href="https://jenkins-ci.org/">Jenkins CI </a>or <a href="http://www.thoughtworks.com/products/go-continuous-delivery">ThoughtWorks go</a>. However, I suggest first running each command, locally, to understand the build process.
```bash
#!/bin/sh

# clone project
git clone -b docker_v2 --single-branch \
  https://github.com/garystafford/spring-music-docker.git \
  music && cd "$_"

# provision VirtualBox VM
docker-machine create --driver virtualbox springmusic

# set new environment
docker-machine env springmusic && \
eval "$(docker-machine env springmusic)"

# mount a named volume on host to store mongo and elk data
# ** assumes your project folder is 'music' **
docker volume create --name music_data
docker volume create --name music_elk

# create bridge network for project
# ** assumes your project folder is 'music' **
docker network create -d bridge music_net

# build images and orchestrate start-up of containers (in this order)
docker-compose -p music up -d elk && sleep 15 && \
docker-compose -p music up -d mongodb && sleep 15 && \
docker-compose -p music up -d app && \
docker-compose scale app=3 && sleep 15 && \
docker-compose -p music up -d proxy

# optional: configure local DNS resolution for application URL
#echo "$(docker-machine ip springmusic)   springmusic.com" | sudo tee --append /etc/hosts

# run a simple connectivity test of application
for i in {1..10}; do curl -I $(docker-machine ip springmusic); done
```

##### Deploying to AWS
By simply changing the Docker Machine driver to AWS EC2 from VirtualBox, and providing your AWS credentials, the <code>springmusic</code> environment can also be built on AWS.

##### Build Process
Docker Machine provisions a single VirtualBox <code>springmusic</code> VM on which host the project’s containers. VirtualBox provides a quick and easy solution that can be run locally for initial development and testing of the application.

Next, the Docker data volume and project-specific Docker bridge network are built.

Next, using the project’s individual Dockerfiles, Docker Compose pulls base Docker images from Docker Hub for NGINX, Tomcat, ELK, and MongoDB. Project-specific immutable Docker images are then built for NGINX, Tomcat, and MongoDB. While constructing the project-specific Docker images for NGINX and Tomcat, the latest Spring Music build artifacts are pulled and installed into the corresponding Docker images.

The NGINX `Dockerfile`:
```text
# NGINX image with build artifact

FROM nginx:latest

MAINTAINER Gary A. Stafford <garystafford@rochester.rr.com>
ENV REFRESHED_AT 2016-09-02

ENV GITHUB_REPO https://github.com/garystafford/spring-music/raw/build-artifacts
ENV STATIC_FILE spring-music-static.zip

RUN apt-get update -qq && \
  apt-get install -qqy curl wget unzip nano && \
  apt-get clean

RUN wget -O /tmp/${STATIC_FILE} ${GITHUB_REPO}/${STATIC_FILE} \
  && unzip /tmp/${STATIC_FILE} -d /usr/share/nginx/assets/

COPY default.conf /etc/nginx/conf.d/default.conf

#########################################################################################
# below from https://github.com/spujadas/elk-docker/blob/master/nginx-filebeat/Dockerfile
#########################################################################################

### install Filebeat
ENV FILEBEAT_VERSION=filebeat_1.2.3_amd64.deb
RUN curl -L -O https://download.elastic.co/beats/filebeat/${FILEBEAT_VERSION} \
 && dpkg -i ${FILEBEAT_VERSION} \
 && rm ${FILEBEAT_VERSION}

### tweak nginx image set-up
# remove log symlinks
RUN rm /var/log/nginx/access.log /var/log/nginx/error.log

### configure Filebeat
# config file
ADD filebeat.yml /etc/filebeat/filebeat.yml

# CA cert
RUN mkdir -p /etc/pki/tls/certs
ADD logstash-beats.crt /etc/pki/tls/certs/logstash-beats.crt

### start Filebeat
ADD ./start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh
CMD [ "/usr/local/bin/start.sh" ]
```

The Tomcat `Dockerfile`:
```text
# Apache Tomcat image with build artifact

FROM tomcat:8.5.4-jre8

MAINTAINER Gary A. Stafford <garystafford@rochester.rr.com>
ENV REFRESHED_AT 2016-09-02

ENV GITHUB_REPO https://github.com/garystafford/spring-music/raw/build-artifacts
ENV APP_FILE spring-music.war
ENV TERM xterm
ENV JAVA_OPTS -Djava.security.egd=file:/dev/./urandom

RUN apt-get update -qq && \
  apt-get install -qqy curl wget && \
  apt-get clean

RUN touch /var/log/spring-music.log && \
  chmod 666 /var/log/spring-music.log

RUN wget -q -O /usr/local/tomcat/webapps/ROOT.war ${GITHUB_REPO}/${APP_FILE} && \
  mv /usr/local/tomcat/webapps/ROOT /usr/local/tomcat/webapps/_ROOT

COPY tomcat-users.xml /usr/local/tomcat/conf/tomcat-users.xml

#########################################################################################
# below from https://github.com/spujadas/elk-docker/blob/master/nginx-filebeat/Dockerfile
#########################################################################################

### install Filebeat
ENV FILEBEAT_VERSION=filebeat_1.2.3_amd64.deb
RUN curl -L -O https://download.elastic.co/beats/filebeat/${FILEBEAT_VERSION} \
 && dpkg -i ${FILEBEAT_VERSION} \
 && rm ${FILEBEAT_VERSION}

### configure Filebeat
# config file
ADD filebeat.yml /etc/filebeat/filebeat.yml

# CA cert
RUN mkdir -p /etc/pki/tls/certs
ADD logstash-beats.crt /etc/pki/tls/certs/logstash-beats.crt

### start Filebeat
ADD ./start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh
CMD [ "/usr/local/bin/start.sh" ]
```

Finally, Docker Compose builds and deploys (6) containers onto the VirtualBox VM: (1) NGINX, (3) Tomcat, (1) MongoDB, and (1) ELK.

![Project Architecture](https://programmaticponderings.files.wordpress.com/2016/08/spring-music-diagram2.png)

##### Docker Compose v2 YAML
This post was recently updated for Docker 1.12 to use Docker Compose’s v2 YAML file format. The post’s example <code>docker-compose.yml</code> takes advantage of many of Docker 1.12 and Compose’s v2 format improved functionality:
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
    ports:
    - 27017:27017
    networks:
    - net
    depends_on:
    - elk
    hostname: mongodb
    container_name: mongodb
    volumes:
    - music_data:/data/db
    - music_data:/data/configdb

  elk:
    image: sebp/elk:latest
    ports:
    - 5601:5601
    - 9200:9200
    - 5044:5044
    - 5000:5000
    networks:
    - net
    volumes:
    - music_elk:/var/lib/elasticsearch
    hostname: elk
    container_name: elk

volumes:
  music_data:
    external: true
  music_elk:
    external: true

networks:
  net:
    driver: bridge
```

### The Results
Below are the results of building the project.
```text
# Resulting Docker Machine VirtualBox VM:
$ docker-machine ls
NAME          ACTIVE   DRIVER       STATE     URL                         SWARM              DOCKER        ERRORS
springmusic   *        virtualbox   Running   tcp://192.168.99.100:2376                      v1.12.1

# Resulting external volume:
$ docker volume ls
DRIVER              VOLUME NAME
local               music_data
local               music_elk

# Resulting bridge network:
$ docker network ls
NETWORK ID          NAME             DRIVER              SCOPE
f564dfa1b440        music_net        bridge              local

# Resulting Docker images - (4) base images and (3) project images:
$ docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
music_proxy         latest              7a8dd90bcf32        About an hour ago   250.2 MB
music_app           latest              c93c713d03b8        About an hour ago   393 MB
music_mongodb       latest              fbcbbe9d4485        25 hours ago        366.4 MB

tomcat              8.5.4-jre8          98cc750770ba        2 days ago          334.5 MB
mongo               latest              48b8b08dca4d        2 days ago          366.4 MB
nginx               latest              4efb2fcdb1ab        10 days ago         183.4 MB
sebp/elk            latest              07a3e78b01f5        13 days ago         884.5 MB

# Resulting (6) Docker containers
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
Below are partial results of the curl test, hitting the NGINX endpoint. Note the different IP addresses in the <code>Upstream-Address</code> field between requests. This proves NGINX’s round-robin load-balancing is working across the three Tomcat application instances: <code>music_app_1</code>, <code>music_app_2</code>, and <code>music_app_3</code>.

Also, note the sharp decrease in the <code>Request-Time</code> between the first request, and subsequent requests. The <code>Upstream-Response-Time</code> to the Tomcat instances doesn’t change, yet the total <code>Request-Time</code> is much shorter, due to caching of the application’s static assets by NGINX.
```text
$ for i in {1..10}; do curl -I $(docker-machine ip springmusic);done

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
Assuming the <code>springmusic</code> VM is running at <code>192.168.99.100</code>, the following links can be used to access various project endpoints. Note the (3) Tomcat instances each map to randomly exposed ports. These ports are not required by NGINX, which maps to port 8080 for each instance. The port is only required if you want access to the Tomcat Web Console. The port shown below, 32771, is merely used as an example.

* Spring Music Application: [192.168.99.100](http://192.168.99.100)
* NGINX Status: [192.168.99.100/nginx_status](http://192.168.99.100/nginx_status)
* Tomcat Web Console - music_app_1*: [192.168.99.100:32771/manager](http://192.168.99.100:32771/manager)
* Environment Variables - music_app_1: [192.168.99.100:32771/env](http://192.168.99.100:32771/env)
* Album List (RESTful endpoint) - music_app_1: [192.168.99.100:32771/albums](http://192.168.99.100:32771/albums)
* Elasticsearch Info: [192.168.99.100:9200](http://192.168.99.100:8082)
* Elasticsearch Status: [192.168.99.100:9200/_status?pretty](http://192.168.99.100:9200/_status?pretty)
* Kibana Web Console: [192.168.99.100:5601](http://192.168.99.100:5601)

_* The Tomcat user name is `admin` and the password is `t0mcat53rv3r`._

### TODOs
* Automate the Docker image build and publish processes
* Automate the Docker container build and deploy processes
* Automate post-deployment verification testing of project infrastructure
* Add Docker Swarm multi-host capabilities with overlay networking
* Update Spring Music with latest CF project revisions
* Include scripting example to stand-up project on AWS
* Add Consul and Consul Template for NGINX configuration

### Helpful Links
* [Cloud Foundry's Spring Music Example](https://github.com/cloudfoundry-samples/spring-music)
* [Getting Started with Gradle for Java](https://gradle.org/getting-started-gradle-java)
* [Introduction to Gradle](https://semaphoreci.com/community/tutorials/introduction-to-gradle)
* [Spring Framework](http://projects.spring.io/spring-framework)
* [Understanding Nginx HTTP Proxying, Load Balancing, Buffering, and Caching](https://www.digitalocean.com/community/tutorials/understanding-nginx-http-proxying-load-balancing-buffering-and-caching)
* [Common conversion patterns for log4j's PatternLayout](http://www.codejava.net/coding/common-conversion-patterns-for-log4js-patternlayout)
* [Spring @PropertySource example](http://www.mkyong.com/spring/spring-propertysources-example)
* [Java log4j logging](http://help.papertrailapp.com/kb/configuration/java-log4j-logging/)
