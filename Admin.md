# Administration

There exist some containers that are purely for Administration and not directly related to Kong processing.

## Keycloak:

URL: http://api.kong.lan:8080

Username: admin

Password: password

## HAProxy

https://www.haproxy.com/blog/dynamic-configuration-haproxy-runtime-api/

https://www.haproxy.com/documentation/hapee/1-9r1/onepage/management/#9.3

To use the haproxy API;

~~~
echo "help" | socat stdio tcp4-connect:api.kong.lan:9999
~~~

### Check DNS service discovery

HAProxy is configured to use DNS Service Discovery. For example, if you scale the kong-dp nodes then these should be picked up automatically and added into the pool. There are 20 "spaces" available for DNS records. For more details, refer to https://www.haproxy.com/blog/dns-service-discovery-haproxy/

You can check which Kong dataplanes are available in the pool with this command;

~~~
echo "show servers state kong_http_proxy_nodes" | socat stdio tcp4-connect:api.kong.lan:9999
~~~

As an example, if we start with 3 Kong dataplanes,

~~~
docker compose --compatibility up -d --scale kong-dp=3
~~~

then we can see the three address HAProxy will use to send requests;

~~~
echo "show servers state kong_http_proxy_nodes" | socat stdio tcp4-connect:api.kong.lan:9999
1
# be_id be_name srv_id srv_name srv_addr srv_op_state srv_admin_state srv_uweight srv_iweight srv_time_since_last_change srv_check_status srv_check_result srv_check_health srv_check_state srv_agent_state bk_f_forced_id srv_f_forced_id srv_fqdn srv_port srvrecord
18 kong_http_proxy_nodes 1 kong-proxy-http1 192.168.144.9 2 0 1 1 146 6 3 4 6 0 0 0 kong-dp 48000 -
18 kong_http_proxy_nodes 2 kong-proxy-http2 192.168.144.11 2 0 1 1 146 6 3 4 6 0 0 0 kong-dp 48000 -
18 kong_http_proxy_nodes 3 kong-proxy-http3 192.168.144.10 2 0 1 1 146 6 3 4 6 0 0 0 kong-dp 48000 -
18 kong_http_proxy_nodes 4 kong-proxy-http4 - 0 32 1 1 146 1 0 0 14 0 0 0 kong-dp 48000 -
18 kong_http_proxy_nodes 5 kong-proxy-http5 - 0 32 1 1 146 1 0 0 14 0 0 0 kong-dp 48000 -
18 kong_http_proxy_nodes 6 kong-proxy-http6 - 0 32 1 1 146 1 0 0 14 0 0 0 kong-dp 48000 -
18 kong_http_proxy_nodes 7 kong-proxy-http7 - 0 32 1 1 146 1 0 0 14 0 0 0 kong-dp 48000 -
18 kong_http_proxy_nodes 8 kong-proxy-http8 - 0 32 1 1 146 1 0 0 14 0 0 0 kong-dp 48000 -
18 kong_http_proxy_nodes 9 kong-proxy-http9 - 0 32 1 1 146 1 0 0 14 0 0 0 kong-dp 48000 -
18 kong_http_proxy_nodes 10 kong-proxy-http10 - 0 32 1 1 146 1 0 0 14 0 0 0 kong-dp 48000 -
18 kong_http_proxy_nodes 11 kong-proxy-http11 - 0 32 1 1 146 1 0 0 14 0 0 0 kong-dp 48000 -
18 kong_http_proxy_nodes 12 kong-proxy-http12 - 0 32 1 1 146 1 0 0 14 0 0 0 kong-dp 48000 -
18 kong_http_proxy_nodes 13 kong-proxy-http13 - 0 32 1 1 146 1 0 0 14 0 0 0 kong-dp 48000 -
18 kong_http_proxy_nodes 14 kong-proxy-http14 - 0 32 1 1 146 1 0 0 14 0 0 0 kong-dp 48000 -
18 kong_http_proxy_nodes 15 kong-proxy-http15 - 0 32 1 1 146 1 0 0 14 0 0 0 kong-dp 48000 -
18 kong_http_proxy_nodes 16 kong-proxy-http16 - 0 32 1 1 146 1 0 0 14 0 0 0 kong-dp 48000 -
18 kong_http_proxy_nodes 17 kong-proxy-http17 - 0 32 1 1 146 1 0 0 14 0 0 0 kong-dp 48000 -
18 kong_http_proxy_nodes 18 kong-proxy-http18 - 0 32 1 1 146 1 0 0 14 0 0 0 kong-dp 48000 -
18 kong_http_proxy_nodes 19 kong-proxy-http19 - 0 32 1 1 146 1 0 0 14 0 0 0 kong-dp 48000 -
18 kong_http_proxy_nodes 20 kong-proxy-http20 - 0 32 1 1 146 1 0 0 14 0 0 0 kong-dp 48000 -
~~~

Scaling up the Kong dataplanes to 5 and we see the new dataplanes nodes are available

~~~
$ docker compose --compatibility up -d --scale kong-dp=5
~~~

~~~
echo "show servers state kong_http_proxy_nodes" | socat stdio tcp4-connect:api.kong.lan:9999
1
# be_id be_name srv_id srv_name srv_addr srv_op_state srv_admin_state srv_uweight srv_iweight srv_time_since_last_change srv_check_status srv_check_result srv_check_health srv_check_state srv_agent_state bk_f_forced_id srv_f_forced_id srv_fqdn srv_port srvrecord
18 kong_http_proxy_nodes 1 kong-proxy-http1 192.168.144.14 2 0 1 1 29 6 3 4 6 0 0 0 kong-dp 48000 -
18 kong_http_proxy_nodes 2 kong-proxy-http2 192.168.144.12 2 0 1 1 29 6 3 4 6 0 0 0 kong-dp 48000 -
18 kong_http_proxy_nodes 3 kong-proxy-http3 192.168.144.11 2 0 1 1 29 6 3 4 6 0 0 0 kong-dp 48000 -
18 kong_http_proxy_nodes 4 kong-proxy-http4 192.168.144.13 2 0 1 1 29 6 3 4 6 0 0 0 kong-dp 48000 -
18 kong_http_proxy_nodes 5 kong-proxy-http5 192.168.144.10 2 0 1 1 29 6 3 4 6 0 0 0 kong-dp 48000 -
18 kong_http_proxy_nodes 6 kong-proxy-http6 - 0 32 1 1 29 1 0 0 14 0 0 0 kong-dp 48000 -
18 kong_http_proxy_nodes 7 kong-proxy-http7 - 0 32 1 1 29 1 0 0 14 0 0 0 kong-dp 48000 -
18 kong_http_proxy_nodes 8 kong-proxy-http8 - 0 32 1 1 29 1 0 0 14 0 0 0 kong-dp 48000 -
18 kong_http_proxy_nodes 9 kong-proxy-http9 - 0 32 1 1 29 1 0 0 14 0 0 0 kong-dp 48000 -
18 kong_http_proxy_nodes 10 kong-proxy-http10 - 0 32 1 1 29 1 0 0 14 0 0 0 kong-dp 48000 -
18 kong_http_proxy_nodes 11 kong-proxy-http11 - 0 32 1 1 29 1 0 0 14 0 0 0 kong-dp 48000 -
18 kong_http_proxy_nodes 12 kong-proxy-http12 - 0 32 1 1 29 1 0 0 14 0 0 0 kong-dp 48000 -
18 kong_http_proxy_nodes 13 kong-proxy-http13 - 0 32 1 1 29 1 0 0 14 0 0 0 kong-dp 48000 -
18 kong_http_proxy_nodes 14 kong-proxy-http14 - 0 32 1 1 29 1 0 0 14 0 0 0 kong-dp 48000 -
18 kong_http_proxy_nodes 15 kong-proxy-http15 - 0 32 1 1 29 1 0 0 14 0 0 0 kong-dp 48000 -
18 kong_http_proxy_nodes 16 kong-proxy-http16 - 0 32 1 1 29 1 0 0 14 0 0 0 kong-dp 48000 -
18 kong_http_proxy_nodes 17 kong-proxy-http17 - 0 32 1 1 29 1 0 0 14 0 0 0 kong-dp 48000 -
18 kong_http_proxy_nodes 18 kong-proxy-http18 - 0 32 1 1 29 1 0 0 14 0 0 0 kong-dp 48000 -
18 kong_http_proxy_nodes 19 kong-proxy-http19 - 0 32 1 1 29 1 0 0 14 0 0 0 kong-dp 48000 -
18 kong_http_proxy_nodes 20 kong-proxy-http20 - 0 32 1 1 29 1 0 0 14 0 0 0 kong-dp 48000 -
~~~

If you send a request to the http proxy listener, the nHAProxy will add a header with the IP adress of the Kong dataplane that it used. You can see the requests are send to all the Kong dataplanes with a check like this;

~~~
$ for i in {1..10}
> do
>   echo `curl -s -I http://proxy.kong.lan/httpbin/anything | grep -i "x-kong-dp-node"`;
>   sleep 0.5
> done
x-kong-dp-node: 192.168.144.12
x-kong-dp-node: 192.168.144.11
x-kong-dp-node: 192.168.144.13
x-kong-dp-node: 192.168.144.10
x-kong-dp-node: 192.168.144.14
x-kong-dp-node: 192.168.144.12
x-kong-dp-node: 192.168.144.11
x-kong-dp-node: 192.168.144.13
x-kong-dp-node: 192.168.144.10
x-kong-dp-node: 192.168.144.14
~~~

### Gracefully remove server from rotation
~~~
echo "set server kong_http_proxy_nodes/kongpose_kong-dp_3 state drain" | socat stdio tcp4-connect:api.kong.lan:9999
echo "set server kong_https_proxy_nodes/kongpose_kong-dp_3 state drain" | socat stdio tcp4-connect:api.kong.lan:9999
~~~

### Disable healthchecks for server
~~~
echo "disable health kong_http_proxy_nodes/kongpose_kong-dp_3" | socat stdio tcp4-connect:api.kong.lan:9999
echo "disable health kong_https_proxy_nodes/kongpose_kong-dp_3" | socat stdio tcp4-connect:api.kong.lan:9999
~~~

### Set weight for server
~~~
echo "set server kong_http_proxy_nodes/kongpose_kong-dp_3 weight 50%" | socat stdio tcp4-connect:api.kong.lan:9999
echo "set server kong_https_proxy_nodes/kongpose_kong-dp_3 weight 50%" | socat stdio tcp4-connect:api.kong.lan:9999
~~~

### Enable healthchecks for server
~~~
echo "enable health kong_http_proxy_nodes/kongpose_kong-dp_3" | socat stdio tcp4-connect:api.kong.lan:9999
echo "enable health kong_https_proxy_nodes/kongpose_kong-dp_3" | socat stdio tcp4-connect:api.kong.lan:9999
~~~

### Add server back to rotation
~~~
echo "set server kong_http_proxy_nodes/kongpose_kong-dp_3 state ready" | socat stdio tcp4-connect:api.kong.lan:9999
echo "set server kong_https_proxy_nodes/kongpose_kong-dp_3 state ready" | socat stdio tcp4-connect:api.kong.lan:9999
~~~

To add more Data Plane nodes, simply scale the service and then add the DP nodes into the haproxy rotation.

~~~
docker-compose up -d --scale kong-dp=5
echo "set server kong_http_proxy_nodes/kongpose_kong-dp_2 state ready" | socat stdio tcp4-connect:api.kong.lan:9999
echo "set server kong_https_proxy_nodes/kongpose_kong-dp_2 state ready" | socat stdio tcp4-connect:api.kong.lan:9999
~~~


To view some HAProxy stats, look here;

http://api.kong.lan:8404/stats

## Locust

For some loadtesting ability, checkout locust; https://locust.io/

Locust is available in this case testing environment at https://locust.kong.lan/ 

A simple test will hit the `httpbin/status/200` and `httpbin/status/503` endpoints in a 100-to-1 split. Edit the [locustfile.py](locust/locustfile.py) file to make the test more interesting.

## SMTP Server

Add a fake-smtp-server service. View the UI at https://mail.kong.lan/

## Redis

Need to see what is stored in redis? Try redis-commander at https://redis-commander.kong.lan/

## Graylog

For Syslog/TCP/UDP log plugins, use Graylog. The default username/password to login is admin/admin

https://graylog.kong.lan/

Two example inputs (System/Inputs) have been created via the "content packs" JSON file to listen on port 5555 for TCP and UDP.

## Zipkin

View traces here;

http://api.kong.lan:9411/

## PGAdmin

Need to view the postgres database? Try pgadmin

http://api.kong.lan:7071

## Kafka UI

Need to view the Kafka topics, messages, etc? Try kafdrop

https://kafka-ui.kong.lan/
