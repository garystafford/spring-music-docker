# NGINX image with build artifact

FROM nginx:latest

MAINTAINER Gary A. Stafford <garystafford@rochester.rr.com>

ENV REFRESHED_AT 2015-09-02

ENV staticfile spring-music-static.zip

COPY build-artifacts/${staticfile} /tmp/${staticfile}

RUN apt-get update -y && \
  apt-get install unzip nano -y && \
  unzip /tmp/${staticfile} -d /usr/share/nginx/assets/

COPY default.conf /etc/nginx/conf.d/default.conf