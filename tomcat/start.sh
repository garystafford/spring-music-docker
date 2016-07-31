#!/bin/bash

curl -XPUT 'http://elk:9200/_template/filebeat?pretty' -d@/etc/filebeat/filebeat.template.json
/etc/init.d/filebeat start
sh /usr/local/tomcat/bin/startup.sh
tail -f /usr/local/tomcat/logs/catalina.out
