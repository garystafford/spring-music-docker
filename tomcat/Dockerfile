# Apache Tomcat image with build artifact

FROM tomcat:latest

MAINTAINER Gary A. Stafford <garystafford@rochester.rr.com>

ENV REFRESHED_AT 2015-09-20
ENV GITHUB_REPO https://github.com/garystafford/spring-music/blob/build-artifacts
ENV APP_FILE spring-music.war

RUN apt-get update -y && \
  apt-get install wget -y && \
  wget -O /usr/local/tomcat/webapps/ROOT.war ${GITHUB_REPO}/${APP_FILE} && \
  mv /usr/local/tomcat/webapps/ROOT /usr/local/tomcat/webapps/_ROOT

COPY tomcat-users.xml /usr/local/tomcat/conf/tomcat-users.xml