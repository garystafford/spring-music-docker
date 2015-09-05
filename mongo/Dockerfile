#http://stackoverflow.com/a/26878915/580268

FROM mongo:latest

MAINTAINER Gary A. Stafford <garystafford@rochester.rr.com>

ENV REFRESHED_AT 2015-09-02

VOLUME ["/data/db"]
WORKDIR /data
CMD ["mongod", "--smallfiles"]