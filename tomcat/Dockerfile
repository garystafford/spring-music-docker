# Apache Tomcat image with build artifact

FROM tomcat:latest

MAINTAINER Gary A. Stafford <garystafford@rochester.rr.com>

ENV REFRESHED_AT 2015-09-02

ENV appfile spring-music-1.9.war

LABEL version="1.0"

RUN mv /usr/local/tomcat/webapps/ROOT /usr/local/tomcat/webapps/_ROOT

COPY tomcat-users.xml /usr/local/tomcat/conf/tomcat-users.xml
COPY ./build-artifacts/${appfile} /usr/local/tomcat/webapps/ROOT.war