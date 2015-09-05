#!/bin/sh

war_file_token="{{ war_file }}"
war_file=$(cd build-artifacts/ && ls *.war)

echo "  ${war_file_token} = ${war_file}"

sed -e "s/${war_file_token}/${war_file}/g" \
    < Dockerfile-template \
    > Dockerfile