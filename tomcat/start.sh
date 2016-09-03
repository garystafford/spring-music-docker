#!/bin/bash

curl -XPUT 'http://elk:9200/_template/filebeat?pretty' -d@/etc/filebeat/filebeat.template.json
/etc/init.d/filebeat start
sh ${CATALINA_HOME}/bin/startup.sh
tail -f ${CATALINA_HOME}/logs/catalina.out
