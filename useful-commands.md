### Other Useful Commands

#### Stopping, Starting, Re-starting...
```bash
# starting after machine or VBox crash or restart
docker-machine start springmusic
docker-machine regenerate-certs springmusic

docker stop proxy music_app_1 music_app_2 music_app_3 mongodb elk
# or
docker rm -f proxy music_app_1 music_app_2 music_app_3 mongodb elk

# orchestrate start-up of containers
docker start elk && sleep 15 && \
docker start mongodb && sleep 15 && \
docker start music_app_1 music_app_2 music_app_3 && sleep 15 && \
docker start proxy

# inspect VM
docker-machine inspect springmusic
docker-machine ssh springmusic
```

#### Application Startup Issues
```bash
# stop / start Tomcat
docker exec -it music_app_1 sh /usr/local/tomcat/bin/startup.sh
docker exec -it music_app_1 sh /usr/local/tomcat/bin/shutdown.sh

# check logs for start-up issues...
docker exec -it music_app_1 cat /var/log/spring-music.log
docker exec -it music_app_1 ls -al /usr/local/tomcat/logs
docker exec -it music_app_1 cat /usr/local/tomcat/logs/catalina.out
docker logs music_app_1

# remove application containers and images
docker rm -f music_app_1 music_app_2 music_app_3
docker rmi music_app music_app

# remove dangling (unused) volumes
docker volume rm $(docker volume ls -qf dangling=true)
```

#### Useful Links
http://elk-docker.readthedocs.io/
http://pugnusferreus.github.io/blog/2016/01/03/integrating-logstash-with-your-java-application/
http://techfree.com.br/2016/07/dockerizando-aplicacoes-concorrencia/
