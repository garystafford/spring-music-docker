#!/bin/sh

########################################################################
#
# title:          Pull Build Artifacts
# author:         Gary A. Stafford (https://programmaticponderings.com)
# url:            https://github.com/garystafford/sprint-music-docker  
# description:    Pulls latest build artifacts from sprint-music-docker repo
#
# to run:         sh ./pull_build_artifacts.sh
#
########################################################################

echo "Removing all existing build artifacts"
rm -rf build-artifacts

rm -rf nginx/build-artifacts/
rm -rf tomcat/build-artifacts/

mkdir nginx/build-artifacts
mkdir tomcat/build-artifacts

echo "Pulling latest build artficats"
git clone https://github.com/garystafford/spring-music.git \
  --branch build-artifacts \
  --single-branch build-artifacts

echo "Moving build artifacts to each microservice directory"
mv build-artifacts/*.war tomcat/build-artifacts/
mv build-artifacts/*.zip nginx/build-artifacts/

echo "Removing local clone of build artifacts repo"
rm -rf build-artifacts

echo "Pulling build artifacts complete"