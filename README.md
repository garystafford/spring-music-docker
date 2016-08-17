_Build, deploy, and monitor a multi-container, MongoDB-backed, Java Spring web application, using the new Docker 1.12._  

![Spring Music Infrastruture](https://programmaticponderings.files.wordpress.com/2016/08/spring-music-diagram2.png)

### Introduction
This post and the post’s example project represent an update to a previous post, [Build and Deploy a Java-Spring-MongoDB Application using Docker](https://programmaticponderings.wordpress.com/2015/09/07/building-and-deploying-a-multi-container-java-spring-mongodb-application-using-docker/). This new post incorporates many improvements made in Docker 1.12, including the use of Docker Compose’s v2 YAML format. The post’s project was also updated to use Filebeat with ELK, as opposed to Logspout, which was used previously.  

In this post, we will demonstrate how to build, deploy, and manage a Java Spring web application, hosted on Apache Tomcat, load-balanced by NGINX, monitored with Filebeat and ELK, and all containerized with Docker.  

We will use a sample Java Spring application, [Spring Music](https://github.com/cloudfoundry-samples/spring-music), available on GitHub from Cloud Foundry. The Spring Music sample record album collection application was originally designed to demonstrate the use of database services on [Cloud Foundry](http://www.cloudfoundry.com), using the [Spring Framework](http://www.springframework.org). Instead of Cloud Foundry, we will host the Spring Music application locally, using Docker on VirtualBox, and optionally on AWS.  
All files necessary to build this project are stored on the `docker_v2` branch of the [garystafford/spring-music-docker](https://github.com/garystafford/spring-music-docker/tree/docker_v2) repository on GitHub. The Spring Music source code is stored on the `springmusic_v2` branch of the [garystafford/spring-music](https://github.com/garystafford/spring-music/tree/springmusic_v2) repository, also on GitHub.  

![Spring Music Application](https://programmaticponderings.files.wordpress.com/2016/08/spring-music2.png)

### Application Architecture
The Java Spring Music application stack contains the following technologies: [Java](http://openjdk.java.net), [Spring Framework](http://projects.spring.io/spring-framework), [AngularJS](https://angularjs.org/), [Bootstrap](http://getbootstrap.com/), [jQuery](https://jquery.com/), [NGINX](http://nginx.org), [Apache Tomcat](http://tomcat.apache.org), [MongoDB](http://mongoDB.com), the [ELK Stack](https://www.elastic.co/products), and [Filebeat](https://www.elastic.co/products/beats/filebeat). A few changes were made to the original Spring Music application to make it work for this demonstration, including:
* Move from Java 1.7 to 1.8
* Modify MongoDB data configuration classes to work with configurable MongoDB instances
* Add Gradle `warNoStatic` task to build WAR file without the static assets, which will be host separately in NGINX
* Create new Gradle task, `zipStatic`, to ZIP up the application’s static assets for deployment to NGINX
* Add versioning scheme for build artifacts
* Add `context.xml` file and `MANIFEST.MF` file to the WAR file
* Add log4j `syslog` appender to send log entries to Filebeat
* Update versions of several dependencies, including Gradle

We will use the following technologies to build, publish, deploy, and host the Java Spring Music application: [Gradle](https://gradle.org), [git](https://git-scm.com), [GitHub](https://github.com), [Travis CI](https://travis-ci.org), [Oracle VirtualBox](https://www.virtualbox.org), [Docker](https://www.docker.com), [Docker Compose](https://www.docker.com/docker-compose), [Docker Machine](https://www.docker.com/docker-machine), [Docker Hub](https://hub.docker.com), and optionally, [Amazon Web Services (AWS)](http://aws.amazon.com).

##### NGINX
To increase performance, the Spring Music web application’s static content will be hosted by [NGINX](http://nginx.org). The application’s WAR file will be hosted by [Apache Tomcat](http://tomcat.apache.org). Requests for non-static content will be proxied through NGINX on the front-end, to a set of three load-balanced Tomcat instances on the back-end. To further increase application performance, NGINX will also be configured for browser caching of the static content.  

Reverse proxying and caching are configured thought NGINX’s `default.conf` file, in the `server` configuration section: [gist]1084830c9e0ba63e62b620f6ff5e7a2b[/gist]  
The three Tomcat instances will be manually configured for load-balancing using NGINX’s default round-robin load-balancing algorithm. This is configured through the `default.conf` file, in the `upstream` configuration section: [gist]71bc2da68d605c187dab818c7332a2fb[/gist]

##### MongoDB
The Spring Music application was designed to run with MySQL, Postgres, Oracle, MongoDB, Redis, or H2, an in-memory Java SQL database. Given the choice of both SQL and NoSQL databases, we will select MongoDB.  

The Spring Music application, hosted by Tomcat, will store and modify record album data in a single instance of MongoDB. MongoDB will be populated with a collection of album data, from a JSON file, when the Spring Music application first creates the MongoDB database instance.

##### ELK
Lastly, the ELK Stack, with Filebeat, will aggregate both Docker and Java Log4j log entries, providing debugging and analytics to our demonstration. A similar method for aggregating logs, using Logspout instead of Filebeat, can be found in this previous [post](https://programmaticponderings.wordpress.com/2015/08/02/log-aggregation-visualization-and-analysis-of-microservices-using-elk-stack-and-logspout/).  

![Kibana 4 Web Console](https://programmaticponderings.files.wordpress.com/2016/08/kibana4_output_filebeat1.png)

##### Continuous Integration
In this post’s example, two build artifacts, a WAR file for the application and ZIP file for the static web content, are built automatically by [Travis CI](https://travis-ci.org), whenever source code changes are pushed to the `springmusic_v2` branch of the [garystafford/spring-music](https://github.com/garystafford/spring-music) repository on GitHub.  

![Travis CI Output](https://programmaticponderings.files.wordpress.com/2016/08/travisci1.png)

Following a successful build, Travis CI pushes the build artifacts to the `build-artifacts` branch on the same GitHub project. The `build-artifacts` branch acts as a pseudo [binary repository](https://en.wikipedia.org/wiki/Binary_repository_manager) for the project, much like JFrog’s [Artifactory](https://www.jfrog.com/artifactory). These artifacts are used later by Docker to build the project’s immutable Docker images and containers.  

![Build Artifact Respository](https://programmaticponderings.files.wordpress.com/2016/08/build-artifacts.png)

##### Build Notifications
Travis CI pushes build notifications to a [Slack](https://slack.com) channel, which eliminates the need to actively monitor Travis CI.  

![Travis CI Slack Notifications](https://programmaticponderings.files.wordpress.com/2016/08/travisci_slack.png)

##### Automation Scripting
The Travis CI `.travis.yaml` file, custom `gradle.build` Gradle tasks, and the `deploy.sh` script handles the CI automation described, above.

Travis CI `.travis.yaml` file:
[gist]45c45be7806a4b50316aa8fae49efa03[/gist]

Custom `gradle.build` tasks:
[gist]850dcf9b51fe90e8b59198566806072b[/gist]

The `deploy.sh` file:
[gist]00036478163e0f405b58430ad061e304[/gist]

You can easily replicate the project’s CI automation using your choice of toolchains. [GitHub](https://github.com) or [BitBucket](https://bitbucket.org) are good choices for distributed version control. For continuous integration and deployment, I recommend Travis CI, [Semaphore](https://semaphoreci.com), [Codeship](https://codeship.com), or [Jenkins](https://jenkins.io). Couple those with a good persistent chat application, such as Glider Labs’ [Slack](https://slack.com) or Atlassian’s [HipChat](https://www.atlassian.com/software/hipchat).

### Building the Docker Environment
Make sure VirtualBox, Docker, Docker Compose, and Docker Machine, are installed and running. At the time of this post, I have the following versions of software installed on my Mac:
* Mac OS X 10.11.6
* VirtualBox 5.0.26
* Docker 1.12.0
* Docker Compose 1.8.0
* Docker Machine 0.8.0

To build the project’s VirtualBox VM, Docker images, and Docker containers, execute the build script, using the following command: `sh ./build_project.sh`. A build script is useful when working with CI/CD automation tools, such as [Jenkins CI](https://jenkins-ci.org/) or [ThoughtWorks go](http://www.thoughtworks.com/products/go-continuous-delivery). However, to understand the build process, I suggest first running the individual commands, locally.
[gist]af817d4033d488100d8eb74c676f6ec3[/gist]

##### Deploying to AWS
By simply changing the Docker Machine driver to AWS EC2 from VirtualBox, and providing your AWS credentials, the `springmusic` environment may also be built on AWS.

##### Build Process
Docker Machine provisions a single VirtualBox `springmusic` VM on which host the project’s containers. VirtualBox provides a quick and easy solution that can be run locally for initial development and testing of the application.  
Next, the script creates a Docker data volume and project-specific Docker bridge network.  
Next, using the project’s individual Dockerfiles, Docker Compose pulls base Docker images from Docker Hub for NGINX, Tomcat, ELK, and MongoDB. Project-specific immutable Docker images are then built for NGINX, Tomcat, and MongoDB. While constructing the project-specific Docker images for NGINX and Tomcat, the latest Spring Music build artifacts are pulled and installed into the corresponding Docker images.  

For example, the NGINX `Dockerfile` looks like: [gist]07e9bb17e0a253df518039af3bda9243[/gist]  

Finally, Docker Compose builds and deploys (6) containers onto the VirtualBox VM: (1) NGINX, (3) Tomcat, (1) MongoDB, and (1) ELK.  

![Spring Music Infrastruture](https://programmaticponderings.files.wordpress.com/2016/08/spring-music-diagram2.png)

##### Docker Compose v2 YAML
This post was recently updated for Docker 1.12 to use Docker Compose’s v2 YAML file format. The post’s example `docker-compose.yml` takes advantage of many of Docker 1.12 and Compose’s v2 format improved functionality: [gist]77c7dd2b9612e714b7033b357672ed31[/gist]

### The Results
Below are the results of building the project. [gist]c89075469f9f6ca65261add3c7c552cc[/gist]

### Testing the Application
Below are partial results of the curl test, hitting the NGINX endpoint. Note the different IP addresses in the `Upstream-Address` field between requests. This proves NGINX’s round-robin load-balancing is working across the three Tomcat application instances: `music_app_1`, `music_app_2`, and `music_app_3`.  

Also, note the sharp decrease in the `Request-Time` between the first request, and subsequent requests. The `Upstream-Response-Time` to the Tomcat instances doesn’t change, yet the total `Request-Time` is much shorter, due to caching of the application’s static assets by NGINX.
[gist]0da4980511f6acab8473c5b930964275[/gist]

### Spring Music Application Links
Assuming the `springmusic` VM is running at `192.168.99.100`, the following links can be used to access various project endpoints. Note the (3) Tomcat instances each map to randomly exposed ports. These ports are not required by NGINX, which maps to port 8080 for each instance. The port is only required if you want access to the Tomcat Web Console. The port, shown below, 32771, is merely used as an example.

* Spring Music Application: [192.168.99.100](http://192.168.99.100)
* NGINX Status: [192.168.99.100/nginx_status](http://192.168.99.100/nginx_status)
* Tomcat Web Console - music_app_1*: [192.168.99.100:32771/manager](http://192.168.99.100:32771/manager)
* Environment Variables - music_app_1: [192.168.99.100:32771/env](http://192.168.99.100:32771/env)
* Album List (RESTful endpoint) - music_app_1: [192.168.99.100:32771/albums](http://192.168.99.100:32771/albums)
* Elasticsearch Info: [192.168.99.100:9200](http://192.168.99.100:9200)
* Elasticsearch Status: [192.168.99.100:9200/_status?pretty](http://192.168.99.100:9200/_status?pretty)
* Kibana Web Console: [192.168.99.100:5601](http://192.168.99.100:5601)

_* The Tomcat user name is `admin` and the password is `t0mcat53rv3r`._

### Helpful Links
* [Cloud Foundry’s Spring Music Example](https://github.com/cloudfoundry-samples/spring-music)
* [Getting Started with Gradle for Java](https://gradle.org/getting-started-gradle-java)
* [Introduction to Gradle](https://semaphoreci.com/community/tutorials/introduction-to-gradle)
* [Spring Framework](http://projects.spring.io/spring-framework)
* [Understanding Nginx HTTP Proxying, Load Balancing, Buffering, and Caching](https://www.digitalocean.com/community/tutorials/understanding-nginx-http-proxying-load-balancing-buffering-and-caching)
* [Common conversion patterns for log4j’s PatternLayout](http://www.codejava.net/coding/common-conversion-patterns-for-log4js-patternlayout)
* [Spring @PropertySource example](http://www.mkyong.com/spring/spring-propertysources-example)
* [Java log4j logging](http://help.papertrailapp.com/kb/configuration/java-log4j-logging/)

### TODOs
* Automate the Docker image build and publish processes
* Automate the Docker container build and deploy processes
* Automate post-deployment verification testing of project infrastructure
* Add Docker Swarm multi-host capabilities with overlay networking
* Update Spring Music with latest CF project revisions
* Include scripting example to stand-up project on AWS
* Add Consul and Consul Template for NGINX configuration
