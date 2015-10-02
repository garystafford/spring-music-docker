# NGINX image with build artifact

FROM nginx:latest

MAINTAINER Gary A. Stafford <garystafford@rochester.rr.com>

ENV REFRESHED_AT 2015-09-20
ENV GITHUB_REPO https://github.com/garystafford/spring-music/raw/build-artifacts
ENV STATIC_FILE spring-music-static.zip

RUN apt-get update -y && \
  apt-get install wget unzip nano -y && \
  wget -O /tmp/${STATIC_FILE} ${GITHUB_REPO}/${STATIC_FILE} && \
  unzip /tmp/${STATIC_FILE} -d /usr/share/nginx/assets/

#COPY default.conf /etc/nginx/conf.d/default.conf
COPY default* /tmp