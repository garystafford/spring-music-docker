#!/bin/sh

zip_file_token="{{ zip_file }}"
zip_file=$(cd build-artifacts/ && ls *.zip)

echo "  ${zip_file_token} = ${zip_file}"

sed -e "s/${zip_file_token}/${zip_file}/g" \
    < Dockerfile-template \
    > Dockerfile