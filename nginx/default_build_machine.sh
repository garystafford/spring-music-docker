#!/bin/sh

########################################################################
#
# title:          NGINX Configuration Template Variable Substitution Script
# author:         Gary A. Stafford (https://programmaticponderings.com)
# url:            https://github.com/garystafford/spring-music-docker  
# description:    Replaces tokens in template
#
# to run:         sh default_build_machien.sh
#
########################################################################

# reference: http://www.cyberciti.biz/faq/unix-linux-replace-string-words-in-many-files/
# http://www.cyberciti.biz/faq/howto-sed-substitute-find-replace-multiple-patterns/

# http://nginx.org/en/docs/http/load_balancing.html
# ip_hash;
lb_method_token="#{{ lb_method }}"
lb_method="" # round-robin by default

app_servers_token="#{{ app_servers }}"
app_servers="server music_app01_1:8080;\r\nserver music_app02_1:8080;"

echo "  ${lb_method_token} = ${lb_method}"
echo "  ${app_servers_token} = ${app_servers}"

sed -e "s/${lb_method_token}/${lb_method}/g" \
    -e "s/${app_servers_token}/${app_servers}/g" \
    < nginx/default-template.conf \
    > nginx/default.conf