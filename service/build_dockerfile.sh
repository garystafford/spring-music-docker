#!/bin/sh

jar_file_token="{{ jar_file }}"
jar_file=$(cd build-artifacts/ && ls *.jar)

echo "  ${jar_file_token} = ${jar_file}"

sed -e "s/${jar_file_token}/${jar_file}/g" \
  < Dockerfile-template \
  > Dockerfile