# Other Useful Commands

## Stopping, Starting, Restarting...

```bash
# starting after machine or VBox crash or restart
eval "$(docker-machine env springmusic)"
docker-machine start springmusic
docker-machine regenerate-certs springmusic

# orchestrate start-up of containers, tailing the logs...
docker-compose -p music up -d elk && docker logs elk --follow # ^C to break
docker-compose -p music up -d mongodb && docker logs mongodb --follow
docker-compose -p music up -d app && docker logs music_app_1 --follow
docker-compose scale app=3 && sleep 15
docker-compose -p music up -d proxy && docker logs proxy --follow

# orchestrate start-up of containers
docker start elk && sleep 15 \
  && docker start mongodb && sleep 15 \
  && docker start music_app_1 music_app_2 music_app_3 && sleep 15 \
  && docker start proxy

# update images
docker pull mongo:latest \
  && docker pull nginx:latest \
  && docker pull sebp/elk:latest \
  && docker pull tomcat:8.5.4-jre8

# stopping containers
docker-compose stop
# removing containers
docker-compose rm

# inspect VM
docker-machine inspect springmusic
docker-machine ssh springmusic
```

## Application Startup Issues

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
docker rmi music_app

# remove dangling (unused) volumes
docker volume rm $(docker volume ls -qf dangling=true)

# remove <none> images
docker rmi $(docker images -a | grep "^<none>" | awk "{print $3}")
```

## Useful Links

- <http://elk-docker.readthedocs.io/>
- <http://pugnusferreus.github.io/blog/2016/01/03/integrating-logstash-with-your-java-application/>
- <http://techfree.com.br/2016/07/dockerizando-aplicacoes-concorrencia/>
