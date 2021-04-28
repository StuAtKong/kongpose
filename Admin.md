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

To view some HAProxy stats, look here;

http://api.kong.lan:8404/stats

## Locust

For some loadtesting ability, checkout locust; https://locust.io/

Locust is available in this case testing environment at https://locust.kong.lan/ 

A simple test will hit the `httpbin/status/200` and `httpbin/status/503` endpoints in a 100-to-1 split. Edit the [locustfile.py](locust/locustfile.py) file to make the test more interesting.

## SMTP Server

Add a fake-smtp-server service. View the UI at https://mail.kong.lan/

## Redis

Need to see what is stored in redis? Try redis-commander at http://api.kong.lan:8081

## Graylog

For Syslog/TCP/UDP log plugins, use Graylog. The default username/password to login is admin/admin

http://api.kong.lan:9000/

Two example inputs (System/Inputs) have been created via the "content packs" JSON file to listen on port 5555 for TCP and UDP.

## Zipkin

View traces here;

http://api.kong.lan:9411/

## PGAdmin

Need to view the postgres database? Try pgadmin

http://api.kong.lan:7071

## Kafka UI

Need to view the Kafka topics, messages, etc? Try kafdrop

http://kafka-ui.kong.lan:8787
