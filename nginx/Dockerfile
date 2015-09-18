# NGINX image with build artifact

FROM nginx:latest

MAINTAINER Gary A. Stafford <garystafford@rochester.rr.com>

ENV REFRESHED_AT 2015-09-02

ENV STATIC_FILE spring-music-static.zip

COPY build-artifacts/${STATIC_FILE} /tmp/${STATIC_FILE}

RUN apt-get update -y && \
  apt-get install unzip nano -y && \
  unzip /tmp/${STATIC_FILE} -d /usr/share/nginx/assets/

COPY default.conf /etc/nginx/conf.d/default.conf