### Other Useful Commands

#### Application Startup Issues
```bash
docker exec -it music_app_1 sh /usr/local/tomcat/bin/startup.sh
docker exec -it music_app_1 sh /usr/local/tomcat/bin/shutdown.sh

docker exec -it music_app_1 cat /var/log/spring-music.log
docker exec -it music_app_1 cat /usr/local/tomcat/logs/catalina.out

docker exec -it music_app_1 ls -al /usr/local/tomcat/logs

docker rm -f music_app_1 music_app_2 music_app_3
docker rmi music_app music_app

docker logs music_app_1
```

#### Stopping, Starting, Re-starting...
```bash
docker rm -f proxy music_app_1 music_app_2 music_app_3 mongodb elk

docker-machine start springmusic

docker stop proxy music_app_1 music_app_2 music_app_3 mongodb elk

docker start elk && sleep 10 && \
docker start mongodb && sleep 10 && \
docker start music_app_1 music_app_2 music_app_3 && sleep 10 && \
docker start proxy
```

#### Useful Links
http://elk-docker.readthedocs.io/
