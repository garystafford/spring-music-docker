## Using Weave to Network a Docker Multi-Container Java Application

_Use the latest version of Weaveworks' Weave Net to network a multi-container, Dockerized Java Spring web application._ [![Introduction Weave Image](https://programmaticponderings.files.wordpress.com/2015/09/introduction-weave-image.png)](https://programmaticponderings.files.wordpress.com/2015/09/introduction-weave-image.png)

### Introduction

The last [post](https://programmaticponderings.wordpress.com/2015/09/07/building-and-deploying-a-multi-container-java-spring-mongodb-application-using-docker) demonstrated how to build and deploy the [Java Spring Music](https://github.com/cloudfoundry-samples/spring-music) application to a VirtualBox, multi-container test environment. The environment contained (1) NGINX container, (2) load-balanced Tomcat containers, (1) MongoDB container, (1) ELK Stack container, and (1) Logspout container, all on one VM. [![Spring Music](https://programmaticponderings.files.wordpress.com/2015/09/spring-music.png)](https://programmaticponderings.files.wordpress.com/2015/09/spring-music.png) In that post, we used Docker's [`links`](https://docs.docker.com/compose/yml/#links) option. The `links` options, which modifies the container's [`/etc/hosts`](http://man7.org/linux/man-pages/man5/hosts.5.html) file, allows two Docker containers to communicate with each other. For example, the NGINX container is linked to both Tomcat containers:

```yaml
proxy:
  build: nginx/
  ports: "80:80"
  links:
   - app01
   - app02
```

Although container linking works, links are not very practical beyond a small number of static containers or a single container host. With linking, you must explicitly define each service-to-container relationship you want Docker to configure. Linking is not an option with [Docker Swarm](https://docs.docker.com/swarm/) to link containers across multiple virtual machine container hosts. With [Docker Networking](https://blog.docker.com/2015/06/networking-receives-an-upgrade/) in it's early 'experimental' stages and the Swarm limitation, it's hard to foresee the use of linking for any uses beyond limited development and test environments.

### Weave Net

Weave Net, aka Weave, is one of a trio of products developed by [Weaveworks](http://weave.works). The other two members of the trio include [Weave Run](http://weave.works/run/index.html) and [Weave Scope](http://weave.works/scope/index.html). According to Weaveworks' website, '_[Weave Net](http://weave.works/net/index.html) connects all your containers into a transparent, dynamic and resilient mesh. This is one of the easiest ways to set up clustered applications that run anywhere._' Weave allows us to eliminate the dependency on the `links` connect our containers. Weave does all the linking of containers for us automatically.

### Weave v1.1.0

If you worked with previous editions of Weave, you will appreciate that Weave versions [v1.0.x](https://github.com/weaveworks/weave/releases) and [v1.1.0](https://github.com/weaveworks/weave/releases) are significant steps forward in the evolution of Weave. Weaveworks' GitHub Weave Release [page](https://github.com/weaveworks/weave/releases) details the many improvements. I also suggest reading [Weave ‘Gossip’ DNS](http://blog.weave.works/2015/09/08/weave-gossip-dns/#more-1293), on Weavework's blog, before continuing. The post details the improvements of Weave v1.1.0\. Some of those key new features include:

*   Completely redesigned [weaveDNS](http://docs.weave.works/weave/latest_release/weavedns.html), dubbed 'Gossip DNS'
*   Registrations are broadcast to all weaveDNS instances
*   Registered entries are stored in-memory and handle lookups locally
*   Weave router’s gossip implementation periodically synchronizes DNS mappings between peers
*   Ability to recover from network partitions and other transient failures
*   Each peer is aware of the hostnames and IP address of all containers in the Weave network.
*   `weave launch` now launches all weave components, including the router, weaveDNS and the proxy, greatly simplifying setup
*   weaveDNS is now embedded in the Weave router

### Weave-based Network

In this post, we will reuse the Java Spring Music application from the last [post](https://programmaticponderings.wordpress.com/2015/09/07/building-and-deploying-a-multi-container-java-spring-mongodb-application-using-docker). However, we will replace the project's static dependencies on Docker links with Weave. This post will demonstrate the most basic features of Weave, using a single cluster. In a future post, we will demonstrate how easily Weave also integrates with multiple clusters.

All files for this post can be found in the `swarm-weave` branch of the [GitHub](https://github.com/garystafford/spring-music-docker/tree/swarm-weave) Repository. Instructions to clone repository below.

### Configuration

If you recall from the previous post, the Docker Compose YAML file (`docker-compose.yml`) looked similar to this:

```yaml
proxy:
  build: nginx/
  ports: "80:80"
  links:
   - app01
   - app02
  hostname: "proxy"

app01:
  build: tomcat/
  expose: "8080"
  ports: "8180:8080"
  links:
   - nosqldb
   - elk
  hostname: "app01"

app02:
  build: tomcat/
  expose: "8080"
  ports: "8280:8080"
  links:
   - nosqldb
   - elk
  hostname: "app01"

nosqldb:
  build: mongo/
  hostname: "nosqldb"
  volumes: "/opt/mongodb:/data/db"

elk:
  build: elk/
  ports:
   - "8081:80"
   - "8082:9200"
  expose: "5000/upd"

logspout:
  build: logspout/
  volumes: "/var/run/docker.sock:/tmp/docker.sock"
  links: elk
  ports: "8083:80"
  environment: ROUTE_URIS=logstash://elk:5000
```

Implementing Weave simplifies the `docker-compose.yml`, considerably. Below is the new Weave version of the `docker-compose.yml`. The `links` option have been removed from all containers. Additionally, the `hostnames` have been removed, as they serve no real purpose moving forward. The logspout service's `environment` option has been modified to use the elk container's full name as opposed to the hostname. The only addition is the [`volumes_from`](https://docs.docker.com/compose/yml/#volumes-from) option to the proxy service. We must ensure that the two Tomcat containers start before the NGINX containers. The `links` option indirectly provided this functionality, previously.

```yaml
proxy:
  build: nginx/
  ports:
   - "80:80"
  volumes_from:
   - app01
   - app02

app01:
  build: tomcat/
  expose:
   - "8080"
  ports:
   - "8180:8080"

app02:
  build: tomcat/
  expose:
   - "8080"
  ports:
   - "8280:8080"

nosqldb:
  build: mongo/
  volumes:
   - "/opt/mongodb:/data/db"

elk:
  build: elk/
  ports:
   - "8081:80"
   - "8082:9200"
  expose:
   - "5000/upd"

logspout:
  build: logspout/
  volumes:
   - "/var/run/docker.sock:/tmp/docker.sock"
  ports:
   - "8083:80"
  environment:
    - ROUTE_URIS=logstash://music_elk_1:5000
```

Next, we need to modify the NGINX configuration, slightly. In the previous post we referenced the Tomcat service names, as shown below.

```text
upstream backend {
  server app01:8080;
  server app02:8080;
}
```

Weave will automatically add the two Tomcat container names to the NGINX container's `/etc/hosts` file. We will add these Tomcat container names to NGINX's configuration file.

```text
upstream backend {
  server music_app01_1:8080;
  server music_app02_1:8080;
}
```

In an actual Production environment, we would use a template, along with a service discovery tool, such as [Consul](https://www.consul.io/), to automatically populate the container names, as containers are dynamically created or destroyed.

### Installing and Running Weave

After cloning this post's GitHub repository, I recommend first installing and configuring Weave. Next, build the container host VM using Docker Machine. Lastly, build the containers using Docker Compose. The `build_project.sh` script below will take care of all the necessary steps.

```shell
#!/bin/sh

########################################################################
#
# title:          Build Complete Project
# author:         Gary A. Stafford (https://programmaticponderings.com)
# url:            https://github.com/garystafford/sprint-music-docker  
# description:    Clone and build complete Spring Music Docker project
#
# to run:         sh ./build_project.sh
#
########################################################################

# install latest weave
curl -L git.io/weave -o /usr/local/bin/weave && 
chmod a+x /usr/local/bin/weave && 
weave version

# clone project
git clone -b swarm-weave \
  --single-branch --branch swarm-weave \
  https://github.com/garystafford/spring-music-docker.git && 
cd spring-music-docker

# build VM
docker-machine create --driver virtualbox springmusic --debug

# create directory to store mongo data on host
docker-machine ssh springmusic mkdir /opt/mongodb

# set new environment
docker-machine env springmusic && 
eval "$(docker-machine env springmusic)"

# launch weave and weaveproxy/weaveDNS containers
weave launch &&
tlsargs=$(docker-machine ssh springmusic \
  "cat /proc/\$(pgrep /usr/local/bin/docker)/cmdline | tr '\0' '\n' | grep ^--tls | tr '\n' ' '")
weave launch-proxy $tlsargs &&
eval "$(weave env)" &&

# test/confirm weave status
weave status &&
docker logs weaveproxy

# pull and build images and containers
# this step will take several minutes to pull images first time
docker-compose -f docker-compose.yml -p music up -d

# wait for container apps to fully start
sleep 15

# test weave (should list entries for all containers)
docker exec -it music_proxy_1 cat /etc/hosts 

# run quick test of Spring Music application
for i in {1..10}
do
  curl -I --url $(docker-machine ip springmusic)
done
```
One last test, to ensure that MongoDB is using the host's volume, and not storing data in the MongoDB container's `/data/db` directory, execute the following command: `docker-machine ssh springmusic ls -Alh /opt/mongodb`. You should see MongoDB-related content being stored here.

### Testing Weave

Running the `weave status` command, we should observe that Weave returned a status similar to the example below:

```text
gstafford@gstafford-X555LA:$ weave status

       Version: v1.1.0

       Service: router
      Protocol: weave 1..2
          Name: 6a:69:11:1b:b4:e3(springmusic)
    Encryption: disabled
 PeerDiscovery: enabled
       Targets: 0
   Connections: 0
         Peers: 1

       Service: ipam
     Consensus: achieved
         Range: [10.32.0.0-10.48.0.0)
 DefaultSubnet: 10.32.0.0/12

       Service: dns
        Domain: weave.local.
           TTL: 1
       Entries: 2

       Service: proxy
       Address: tcp://192.168.99.100:12375
```

Running the `docker exec -it music_proxy_1 cat /etc/hosts` command, we should observe that WeaveDNS has automatically added entries for all containers to the `music_proxy_1` container's `/etc/hosts` file. WeaveDNS will also remove the addresses of any containers that die. This offers a simple way to implement redundancy. 

```text
gstafford@gstafford-X555LA:$ docker exec -it music_proxy_1 cat /etc/hosts

# modified by weave
10.32.0.6       music_proxy_1
127.0.0.1       localhost

172.17.0.131    weave weave.bridge
172.17.0.133    music_elk_1 music_elk_1.bridge
172.17.0.134    music_nosqldb_1 music_nosqldb_1.bridge
172.17.0.138    music_app02_1 music_app02_1.bridge
172.17.0.139    music_logspout_1 music_logspout_1.bridge
172.17.0.140    music_app01_1 music_app01_1.bridge

::1             ip6-localhost ip6-loopback localhost
fe00::0         ip6-localnet
ff00::0         ip6-mcastprefix
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
```

Weave resolves the container's name to `eth0` IP address, created by Docker's [`docker0`](https://docs.docker.com/articles/networking/#summary) Ethernet bridge. Each container can now communicate with all other containers in the cluster.

[![Weave eth0 Network](https://programmaticponderings.files.wordpress.com/2015/09/weave-eth0-network.png)](https://programmaticponderings.files.wordpress.com/2015/09/weave-eth0-network.png)

### Results
Resulting virtual machines, network, images, and containers:

```shell
gstafford@gstafford-X555LA:$ docker-machine ls
NAME            ACTIVE   DRIVER       STATE     URL                         SWARM
springmusic     *        virtualbox   Running   tcp://192.168.99.100:2376   

gstafford@gstafford-X555LA:$ docker images
REPOSITORY             TAG                 IMAGE ID            CREATED             VIRTUAL SIZE
music_app02            latest              632c782010ac        3 days ago          370.4 MB
music_app01            latest              632c782010ac        3 days ago          370.4 MB
music_proxy            latest              171624a31920        3 days ago          144.5 MB
music_nosqldb          latest              2b3b46af5ef3        3 days ago          260.8 MB
music_elk              latest              5c18dae84b26        3 days ago          1.05 GB
weaveworks/weaveexec   v1.1.0              69c6bfa7934f        5 days ago          58.18 MB
weaveworks/weave       v1.1.0              5dccf0533147        5 days ago          17.53 MB
music_logspout         latest              fe64597ab0c4        8 days ago          24.36 MB
gliderlabs/logspout    master              40a52d6ca462        9 days ago          14.75 MB
willdurand/elk         latest              04cd7334eb5d        2 weeks ago         1.05 GB
tomcat                 latest              6fe1972e6b08        2 weeks ago         347.7 MB
mongo                  latest              5c9464760d54        2 weeks ago         260.8 MB
nginx                  latest              cd3cf76a61ee        2 weeks ago         132.9 MB

gstafford@gstafford-X555LA:$ weave ps
weave:expose 6a:69:11:1b:b4:e3
2bce66e3b33b fa:07:7e:85:37:1b 10.32.0.5/12
604dbbc4473f 6a:73:8d:54:cc:fe 10.32.0.4/12
ea64b42cf5a1 c2:69:73:84:67:69 10.32.0.3/12
85b1e8a9b8d0 aa:f7:12:cd:b7:13 10.32.0.6/12
81041fc97d1f 2e:1e:82:67:89:5d 10.32.0.2/12
e80c04bdbfaf 1e:95:a5:b2:9d:30 10.32.0.1/12
18c22e7f1c33 7e:43:54:db:8d:b8

gstafford@gstafford-X555LA:$ docker ps -a
CONTAINER ID        IMAGE                         COMMAND                  CREATED             STATUS              PORTS                                                                                            NAMES
2bce66e3b33b        music_app01                   "/w/w catalina.sh run"   3 days ago          Up 3 days           0.0.0.0:8180->8080/tcp                                                                           music_app01_1
604dbbc4473f        music_logspout                "/w/w /bin/logspout"     3 days ago          Up 3 days           8000/tcp, 0.0.0.0:8083->80/tcp                                                                   music_logspout_1
ea64b42cf5a1        music_app02                   "/w/w catalina.sh run"   3 days ago          Up 3 days           0.0.0.0:8280->8080/tcp                                                                           music_app02_1
85b1e8a9b8d0        music_proxy                   "/w/w nginx -g 'daemo"   3 days ago          Up 3 days           0.0.0.0:80->80/tcp, 443/tcp                                                                      music_proxy_1
81041fc97d1f        music_nosqldb                 "/w/w /entrypoint.sh "   3 days ago          Up 3 days           27017/tcp                                                                                        music_nosqldb_1
e80c04bdbfaf        music_elk                     "/w/w /usr/bin/superv"   3 days ago          Up 3 days           5000/0, 0.0.0.0:8081->80/tcp, 0.0.0.0:8082->9200/tcp                                             music_elk_1
8eafc6225fc1        weaveworks/weaveexec:v1.1.0   "/home/weave/weavepro"   3 days ago          Up 3 days                                                                                                            weaveproxy
18c22e7f1c33        weaveworks/weave:v1.1.0       "/home/weave/weaver -"   3 days ago          Up 3 days           172.17.42.1:53->53/udp, 0.0.0.0:6783->6783/tcp, 0.0.0.0:6783->6783/udp, 172.17.42.1:53->53/tcp   weave
```

### Spring Music Application Links

Assuming `springmusic` VM is running at `192.168.99.100`, these are the accessible URL for each of the environment's major components:

*   Spring Music: [192.168.99.100](http://192.168.99.100)
*   NGINX: [192.168.99.100/nginx_status](http://192.168.99.100/nginx_status)
*   Tomcat Node 1*: [192.168.99.100:8180/manager](http://192.168.99.100:8180/manager)
*   Tomcat Node 2*: [192.168.99.100:8280/manager](http://192.168.99.100:8280/manager)
*   Kibana: [192.168.99.100:8081](http://192.168.99.100:8081)
*   Elasticsearch: [192.168.99.100:8082](http://192.168.99.100:8082)
*   Elasticsearch: [192.168.99.100:8082/_status?pretty](http://192.168.99.100:8082/_status?pretty)
*   Logspout: [192.168.99.100:8083/logs](http://192.168.99.100:8083/logs)

_* The Tomcat user name is `admin` and the password is `t0mcat53rv3r`._

### Helpful Links

*   [Docker Network Configuration](https://docs.docker.com/articles/networking/)
*   [Weave ‘Gossip’ DNS](http://blog.weave.works/2015/09/08/weave-gossip-dns/)
*   [Networking Receives an Upgrade](https://blog.docker.com/2015/06/networking-receives-an-upgrade/) [Debian Linux: Configure Network Interfaces As A Bridge / Network Switch](http://www.cyberciti.biz/faq/debian-network-interfaces-bridge-eth0-eth1-eth2/) [Why I don't use Docker much anymore](https://blog.abevoelker.com/why-i-dont-use-docker-much-anymore/)
*   [This IP Thing](http://www.netfilter.org/documentation/HOWTO/networking-concepts-HOWTO-4.html#ss4.1)
*   [IP Route Management](http://linux-ip.net/html/tools-ip-route.html)