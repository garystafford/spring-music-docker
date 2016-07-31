### Other Useful Commands

#### Application Startup Issues
```bash
docker exec -it app01 sh /usr/local/tomcat/bin/startup.sh
docker exec -it app01 sh /usr/local/tomcat/bin/shutdown.sh

docker exec -it app01 cat /var/log/spring-music.log
docker exec -it app01 cat /usr/local/tomcat/logs/catalina.out

docker exec -it app01 ls -al /usr/local/tomcat/logs

docker rm -f app02 app01
docker rmi music_app01 music_app02

docker logs app01
```

#### Stopping, Starting, Re-starting...
```bash
docker rm -f proxy app01 app02 mongodb elk

docker-machine start springmusic

docker stop proxy app01 app02 mongodb elk
docker start elk && sleep 10 && \
docker start mongodb && sleep 10 && \
docker start app01 app02 && sleep 10 && \
docker start proxy
```

#### Useful Links
http://elk-docker.readthedocs.io/
