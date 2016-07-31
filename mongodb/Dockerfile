# MongoDB image with host-based data volume

FROM mongo:latest

MAINTAINER Gary A. Stafford <garystafford@rochester.rr.com>
ENV REFRESHED_AT 2016-07-30

VOLUME ["/data/db"]
WORKDIR /data
CMD ["mongod", "--smallfiles"]
