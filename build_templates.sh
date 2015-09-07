#!/bin/sh

########################################################################
#
# title:          Build Dockerfile Templates
# author:         Gary A. Stafford (https://programmaticponderings.com)
# url:            https://github.com/garystafford/sprint-music-docker  
# description:    Build Dockerfile templates
#
# to run:         sh ./build_templates.sh
#
########################################################################

echo "Executing Dockerfile template builds"

cd tomcat && sh build_dockerfile.sh && cd ..
cd nginx  && sh build_dockerfile.sh && cd ..

echo "Template building process complete"