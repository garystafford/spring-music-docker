# NGINX image with build artifact

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

#########################################################################################
# below from https://github.com/spujadas/elk-docker/blob/master/nginx-filebeat/Dockerfile
#########################################################################################

### install Filebeat
RUN curl -L -O https://download.elastic.co/beats/filebeat/filebeat_1.2.3_amd64.deb \
 && dpkg -i filebeat_1.2.3_amd64.deb \
 && rm filebeat_1.2.3_amd64.deb

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
