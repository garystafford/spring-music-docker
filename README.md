<em>Use the latest version of Weaveworks' Weave Net to network a multi-container, Dockerized Java Spring web application.</em>

<a href="https://programmaticponderings.files.wordpress.com/2015/09/introduction-weave-image.png"><img src="https://programmaticponderings.files.wordpress.com/2015/09/introduction-weave-image.png" alt="Introduction Weave Image" width="660" height="300" class="aligncenter size-full wp-image-6090" style="border:0 solid #ffffff;" /></a>

<h3>Introduction</h3>
The last <a href="https://programmaticponderings.wordpress.com/2015/09/07/building-and-deploying-a-multi-container-java-spring-mongodb-application-using-docker">post</a> demonstrated how to build and deploy the <a href="https://github.com/cloudfoundry-samples/spring-music">Java Spring Music</a> application to a VirtualBox, multi-container test environment. The environment contained (1) NGINX container, (2) load-balanced Tomcat containers, (1) MongoDB container, (1) ELK Stack container, and (1) Logspout container, all on one VM.

<a href="https://programmaticponderings.files.wordpress.com/2015/09/spring-music.png"><img src="https://programmaticponderings.files.wordpress.com/2015/09/spring-music.png" alt="Spring Music" width="660" height="387" class="aligncenter size-full wp-image-6011" style="border:0 solid #ffffff;" /></a>

In that post, we used Docker's <a href="https://docs.docker.com/compose/yml/#links"><code>links</code></a>  option. The <code>links</code> options, which modifies the container's <a href="http://man7.org/linux/man-pages/man5/hosts.5.html"><code>/etc/hosts</code></a> file, allows two Docker containers to communicate with each other. For example, the NGINX container is linked to both Tomcat containers:

<pre>
proxy:
  build: nginx/
  ports: "80:80"
  links:
   - app01
   - app02
</pre>

Although container linking works, links are not very practical beyond a small number of static containers or a single container host. With linking, you must explicitly define each service-to-container relationship you want Docker to configure. Linking is not an option with <a href="https://docs.docker.com/swarm/">Docker Swarm</a> to link containers across multiple virtual machine container hosts. With <a href="https://blog.docker.com/2015/06/networking-receives-an-upgrade/">Docker Networking</a> in it's early 'experimental' stages and the Swarm limitation, it's hard to foresee the use of linking for any uses beyond limited development and test environments.

<h3>Weave Net</h3>
Weave Net, aka Weave, is one of a trio of products developed by <a href="http://weave.works">Weaveworks</a>. The other two members of the trio include <a href="http://weave.works/run/index.html">Weave Run</a> and <a href="http://weave.works/scope/index.html">Weave Scope</a>. According to Weaveworks' website, '<em><a href="http://weave.works/net/index.html">Weave Net</a> connects all your containers into a transparent, dynamic and resilient mesh. This is one of the easiest ways to set up clustered applications that run anywhere.</em>' Weave allows us to eliminate the dependency on the <code>links</code> connect our containers. Weave does all the linking of containers for us automatically.

<h3>Weave v1.1.0</h3>
If you worked with previous editions of Weave, you will appreciate that Weave versions <a href="https://github.com/weaveworks/weave/releases">v1.0.x</a> and <a href="https://github.com/weaveworks/weave/releases">v1.1.0</a> are significant steps forward in the evolution of Weave. Weaveworks' GitHub Weave Release <a href="https://github.com/weaveworks/weave/releases">page</a> details the many improvements. I also suggest reading <a href="http://blog.weave.works/2015/09/08/weave-gossip-dns/#more-1293">Weave ‘Gossip’ DNS</a>, on Weavework's blog, before continuing. The post details the improvements of Weave v1.1.0. Some of those key new features include:

<ul>
<li>Completely redesigned <a href="http://docs.weave.works/weave/latest_release/weavedns.html">weaveDNS</a>, dubbed 'Gossip DNS' </li>
<li>Registrations are broadcast to all weaveDNS instances</li>
<li>Registered entries are stored in-memory and handle lookups locally</li>
<li>Weave router’s gossip implementation periodically synchronizes DNS mappings between peers</li>
<li>Ability to recover from network partitions and other transient failures</li>
<li>Each peer is aware of the hostnames and IP address of all containers in the Weave network.</li>
<li><code>weave launch</code> now launches all weave components, including the router, weaveDNS and the proxy, greatly simplifying setup</li>
<li>weaveDNS is now embedded in the Weave router</li>
</ul>

<h3>Weave-based Network</h3>
In this post, we will reuse the Java Spring Music application from the last <a href="https://programmaticponderings.wordpress.com/2015/09/07/building-and-deploying-a-multi-container-java-spring-mongodb-application-using-docker">post</a>. However, we will replace the project's static dependencies on Docker links with Weave. This post will demonstrate the most basic features of Weave, using a single cluster. In a future post, we will demonstrate how easily Weave also integrates with multiple clusters.

All files for this post can be found in the <code>weave</code> branch of the <a href="https://github.com/garystafford/spring-music-docker/tree/weave">GitHub</a> Repository. Instructions are below.

<h3>Configuration</h3>
If you recall from the previous post, the Docker Compose YAML file (<code>docker-compose.yml</code>) looked similar to this:

<pre>
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
</pre>

Implementing Weave simplifies the <code>docker-compose.yml</code>, considerably. Below is the new Weave version of the <code>docker-compose.yml</code>. The <code>links</code> option have been removed from all containers. Additionally, the <code>hostnames</code> have been removed, as they serve no real purpose moving forward. The logspout service's <code>environment</code> option has been modified to use the elk container's full name as opposed to the hostname.

The only addition is the <a href="https://docs.docker.com/compose/yml/#volumes-from"><code>volumes_from</code></a> option to the proxy service. We must ensure that the two Tomcat containers start before the NGINX containers. The <code>links</code> option indirectly provided this functionality, previously.

<pre>
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
</pre>

Next, we need to modify the NGINX configuration, slightly. In the previous post we referenced the Tomcat service names, as shown below.

<pre>
upstream backend {
  server app01:8080;
  server app02:8080;
}
</pre>

Weave will automatically add the two Tomcat container names to the NGINX container's <code>/etc/hosts</code> file. We will add these Tomcat container names to NGINX's configuration file.

<pre>
upstream backend {
  server music_app01_1:8080;
  server music_app02_1:8080;
}
</pre>

In an actual Production environment, we would use a template, along with a service discovery tool, such as <a href="https://www.consul.io/">Consul</a>, to automatically populate the container names, as containers are dynamically created or destroyed.

<h3>Installing and Running Weave</h3>
After cloning this post's GitHub repository, I recommend first installing and configuring Weave. Next, build the container host VM using Docker Machine. Lastly, build the containers using Docker Compose. The script below will take care of all the necessary steps.

<pre>
# install weave v1.1.0
curl -L git.io/weave -o /usr/local/bin/weave && 
chmod a+x /usr/local/bin/weave && 
weave version

# clone project
git clone https://github.com/garystafford/spring-music-docker.git && 
cd spring-music-docker

# build VM
docker-machine create --driver virtualbox springmusic --debug

# create diectory to store mongo data on host
docker ssh springmusic mkdir /opt/mongodb

# set new environment
docker-machine env springmusic && 
eval "$(docker-machine env springmusic)"

# launch weave and weaveproxy/weaveDNS containers
weave launch
tlsargs=$(docker-machine ssh springmusic \
  "cat /proc/\$(pgrep /usr/local/bin/docker)/cmdline | tr '&#092;&#048;' '\n' | grep ^--tls | tr '\n' ' '")
weave launch-proxy $tlsargs
eval "$(weave env)"

# test/confirm weave status
weave status 
docker logs weaveproxy

# pull build artifacts, built by Travis CI, 
# from source code repository
sh ./pull_build_artifacts.sh

# build images and containers
docker-compose -f docker-compose.yml -p music up -d

# wait for container apps to fully start
sleep 15

# test weaveDNS (should list entries for all containers)
docker exec -it music_proxy_1 cat /etc/hosts 

# run quick test of Spring Music application
for i in {1..10}
do
  curl -I --url $(docker-machine ip springmusic)
done
</pre>

<h3>Testing Weave</h3>
Running the <code>weave status</code> command, we should observe that Weave returned a status similar to the example below:

<pre>
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
</pre>

Running the <code>docker exec -it music_proxy_1 cat /etc/hosts</code> command, we should observe that Weave has automatically added entries for all containers to the <code>music_proxy_1</code> container's <code>/etc/hosts</code> file.

<pre>
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
</pre>

Weave resolves the container's name to <code>eth0</code> IP address, created by Docker's <a href="https://docs.docker.com/articles/networking/#summary"><code>docker0</code></a> Ethernet bridge. Each container can now communicate with all other containers in the cluster.

<a href="https://programmaticponderings.files.wordpress.com/2015/09/weave-eth0-network.png"><img src="https://programmaticponderings.files.wordpress.com/2015/09/weave-eth0-network.png" alt="Weave eth0 Network" width="660" height="300" class="aligncenter size-full wp-image-6105" style="border:0 solid #ffffff;" /></a>

<strong>Results</strong>
Resulting virtual machine, images, and containers:

<pre>
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
85b1e8a9b8d0        music_proxy                   "/w/w nginx -g &#039;daemo"   3 days ago          Up 3 days           0.0.0.0:80->80/tcp, 443/tcp                                                                      music_proxy_1
81041fc97d1f        music_nosqldb                 "/w/w /entrypoint.sh "   3 days ago          Up 3 days           27017/tcp                                                                                        music_nosqldb_1
e80c04bdbfaf        music_elk                     "/w/w /usr/bin/superv"   3 days ago          Up 3 days           5000/0, 0.0.0.0:8081->80/tcp, 0.0.0.0:8082->9200/tcp                                             music_elk_1
8eafc6225fc1        weaveworks/weaveexec:v1.1.0   "/home/weave/weavepro"   3 days ago          Up 3 days                                                                                                            weaveproxy
18c22e7f1c33        weaveworks/weave:v1.1.0       "/home/weave/weaver -"   3 days ago          Up 3 days           172.17.42.1:53->53/udp, 0.0.0.0:6783->6783/tcp, 0.0.0.0:6783->6783/udp, 172.17.42.1:53->53/tcp   weave
</pre>

<h3>Spring Music Application Links</h3>
Assuming <code>springmusic</code> VM is running at <code>192.168.99.100</code>, these are the accessible URL for each of the environment's major components:

<ul>
<li>Spring Music: <a href="http://192.168.99.100">192.168.99.100</a></li>
<li>NGINX: <a href="http://192.168.99.100/nginx_status">192.168.99.100/nginx_status</a></li>
<li>Tomcat Node 1*: <a href="http://192.168.99.100:8180/manager">192.168.99.100:8180/manager</a></li>
<li>Tomcat Node 2*: <a href="http://192.168.99.100:8280/manager">192.168.99.100:8280/manager</a></li>
<li>Kibana: <a href="http://192.168.99.100:8081">192.168.99.100:8081</a></li>
<li>Elasticsearch: <a href="http://192.168.99.100:8082">192.168.99.100:8082</a></li>
<li>Elasticsearch: <a href="http://192.168.99.100:8082/_status?pretty">192.168.99.100:8082/_status?pretty</a></li>
<li>Logspout: <a href="http://192.168.99.100:8083/logs">192.168.99.100:8083/logs</a></li>
</ul>

<em>* The Tomcat user name is <code>admin</code> and the password is <code>t0mcat53rv3r</code>.</em>

<h3>Helpful Links</h3>
<ul>
<li><a href="https://docs.docker.com/articles/networking/">Docker Network Configuration</a></li>
<li><a href="http://blog.weave.works/2015/09/08/weave-gossip-dns/">Weave ‘Gossip’ DNS</a></li>
<li><a href="https://blog.docker.com/2015/06/networking-receives-an-upgrade/">Networking Receives an Upgrade</a>
<a href="http://www.cyberciti.biz/faq/debian-network-interfaces-bridge-eth0-eth1-eth2/">Debian Linux: Configure Network Interfaces As A Bridge / Network Switch</a>
<a href="https://blog.abevoelker.com/why-i-dont-use-docker-much-anymore/">Why I don't use Docker much anymore</a></li>
<li><a href="http://www.netfilter.org/documentation/HOWTO/networking-concepts-HOWTO-4.html#ss4.1">This IP Thing</a></li>
<li><a href="http://linux-ip.net/html/tools-ip-route.html">IP Route Management</a></li>
</ul>