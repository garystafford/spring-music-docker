# Apache Tomcat image with build artifact

FROM tomcat:latest

MAINTAINER Gary A. Stafford <garystafford@rochester.rr.com>

ENV appfile spring-music.war

RUN mv /usr/local/tomcat/webapps/ROOT /usr/local/tomcat/webapps/_ROOT

COPY tomcat-users.xml /usr/local/tomcat/conf/tomcat-users.xml
COPY ./build-artifacts/${appfile} /usr/local/tomcat/webapps/ROOT.war