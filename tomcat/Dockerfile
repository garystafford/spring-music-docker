# Apache Tomcat image with build artifact

FROM tomcat:latest

MAINTAINER Gary A. Stafford <garystafford@rochester.rr.com>
ENV REFRESHED_AT 2016-07-30

ENV GITHUB_REPO https://github.com/garystafford/spring-music/raw/build-artifacts
ENV APP_FILE spring-music.war

RUN apt-get update -qq && \
  apt-get install -qqy curl wget && \
  apt-get clean

RUN touch /var/log/spring-music.log

RUN wget -O /usr/local/tomcat/webapps/ROOT.war ${GITHUB_REPO}/${APP_FILE} && \
  mv /usr/local/tomcat/webapps/ROOT /usr/local/tomcat/webapps/_ROOT

COPY tomcat-users.xml /usr/local/tomcat/conf/tomcat-users.xml

#########################################################################################
# below from https://github.com/spujadas/elk-docker/blob/master/nginx-filebeat/Dockerfile
#########################################################################################

### install Filebeat
RUN curl -L -O https://download.elastic.co/beats/filebeat/filebeat_1.0.1_amd64.deb \
 && dpkg -i filebeat_1.0.1_amd64.deb \
 && rm filebeat_1.0.1_amd64.deb

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
