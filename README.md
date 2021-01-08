# Initial Setup

## Configuration

Create the SSL certificates for the api.kong.lan hostname [here](ssl-certs/README.md)

Create the hybrid CP/DP certs [here](ssl-certs/hybrid/README.md)

## Start containers

Set and env var for the license;

~~~
export KONG_LICENSE_DATA=`cat ./license.json`;
~~~

Then start the utility services & kong containers

~~~
docker-compose up -d
~~~

This will start Kong EE, Postgres, Keycloak, an LDAP (AD) server, an HAProxy server and a Locust load testing server. 

## Authentication

By default, ldap-auth is enabled and you can login with kong_admin/K1ngK0ng

You can look at the LDAP tree by searching as below;

~~~
ldapsearch -H "ldap://0.0.0.0:389" -D "cn=Administrator,cn=users,dc=ldap,dc=kong,dc=com" -w "Passw0rd" -b "dc=ldap,dc=kong,dc=com" "(sAMAccountName=kong_admin)"
~~~

## Test kong is working by making an Admin API request

It is necessary to pass the CA certificate with the request to allow curl to verify the certs (or use -k which is not recommended);

~~~
curl --cacert ./ssl-certs/rootCA.pem -H "kong-admin-token: password" https://api.kong.lan:48444/default/kong
~~~

## Default endpoints for HAProxy healthcheck & httpbin

A deck container is used to populate the endpoints used for the ha-proxy health check as well as creating a route/service for the local httpbin

## Test a proxy

Test the default API via the HAProxy (the Kong proxy ports are not exposed externally so access in *ONLY* via HaProxy);

~~~
$ curl http://api.kong.lan/httpbin/anything
{
  "args": {},
  "data": "",
  "files": {},
  "form": {},
  "headers": {
    "Accept": "*/*",
    "Connection": "keep-alive",
    "Host": "httpbin-1",
    "User-Agent": "curl/7.64.0",
    "X-Forwarded-Host": "api.kong.lan",
    "X-Forwarded-Prefix": "/httpbin"
  },
  "json": null,
  "method": "GET",
  "origin": "172.28.0.1, 172.28.0.13",
  "url": "http://api.kong.lan/anything"
}

$ curl -s --cacert ./ssl-certs/rootCA.pem https://api.kong.lan/httpbin/anything
{
  "args": {},
  "data": "",
  "files": {},
  "form": {},
  "headers": {
    "Accept": "*/*",
    "Connection": "keep-alive",
    "Host": "httpbin-1",
    "User-Agent": "curl/7.64.0",
    "X-Forwarded-Host": "api.kong.lan",
    "X-Forwarded-Prefix": "/httpbin"
  },
  "json": null,
  "method": "GET",
  "origin": "172.28.0.13",
  "url": "https://api.kong.lan/anything"
}
~~~

There is also a rate limited example, secured with key-auth and two consumers

~~~
$ curl http://api.kong.lan/limit-httpbin/anything?apikey=abc
{
  "args": {
    "apikey": "abc"
  },
  "data": "",
  "files": {},
  "form": {},
  "headers": {
    "Accept": "*/*",
    "Connection": "keep-alive",
    "Host": "kongpose_httpbin_2",
    "User-Agent": "curl/7.72.0",
    "X-Consumer-Id": "ef320150-1b41-4af7-b567-bce8e093c6a6",
    "X-Consumer-Username": "consA",
    "X-Credential-Identifier": "c507fb51-1af9-4ca9-b8bf-5a520c83be58",
    "X-Forwarded-Host": "api.kong.lan",
    "X-Forwarded-Path": "/limit-httpbin/anything",
    "X-Forwarded-Prefix": "/limit-httpbin"
  },
  "json": null,
  "method": "GET",
  "origin": "172.26.0.1, 172.26.0.23",
  "url": "http://api.kong.lan/anything?apikey=abc"
}
~~~

and

~~~
$ curl http://api.kong.lan/limit-httpbin/anything?apikey=123
{
  "args": {
    "apikey": "123"
  },
  "data": "",
  "files": {},
  "form": {},
  "headers": {
    "Accept": "*/*",
    "Connection": "keep-alive",
    "Host": "kongpose_httpbin_2",
    "User-Agent": "curl/7.72.0",
    "X-Consumer-Id": "36fb326f-e011-4d2b-8acc-dd9638615d8b",
    "X-Consumer-Username": "consB",
    "X-Credential-Identifier": "a01449f0-bf58-44ec-8a5c-1f38deabcb93",
    "X-Forwarded-Host": "api.kong.lan",
    "X-Forwarded-Path": "/limit-httpbin/anything",
    "X-Forwarded-Prefix": "/limit-httpbin"
  },
  "json": null,
  "method": "GET",
  "origin": "172.26.0.1, 172.26.0.23",
  "url": "http://api.kong.lan/anything?apikey=123"
}
~~~

Send a few requests, get a 429 response and take a look in [redis](README.md#redis) ;-)

# Keycloak:

URL: http://localhost:8080

Username: admin

Password: password

# HAProxy

https://www.haproxy.com/blog/dynamic-configuration-haproxy-runtime-api/

https://www.haproxy.com/documentation/hapee/1-9r1/onepage/management/#9.3

To use the haproxy API;

~~~
echo "help" | socat stdio tcp4-connect:api.kong.lan:9999
~~~

## Gracefully remove server from rotation
~~~
echo "set server kong_http_proxy_nodes/kongpose_kong-dp_3 state drain" | socat stdio tcp4-connect:api.kong.lan:9999
echo "set server kong_https_proxy_nodes/kongpose_kong-dp_3 state drain" | socat stdio tcp4-connect:api.kong.lan:9999
~~~

## Disable healthchecks for server
~~~
echo "disable health kong_http_proxy_nodes/kongpose_kong-dp_3" | socat stdio tcp4-connect:api.kong.lan:9999
echo "disable health kong_https_proxy_nodes/kongpose_kong-dp_3" | socat stdio tcp4-connect:api.kong.lan:9999
~~~

## Set weight for server
~~~
echo "set server kong_http_proxy_nodes/kongpose_kong-dp_3 weight 50%" | socat stdio tcp4-connect:api.kong.lan:9999
echo "set server kong_https_proxy_nodes/kongpose_kong-dp_3 weight 50%" | socat stdio tcp4-connect:api.kong.lan:9999
~~~

## Enable healthchecks for server
~~~
echo "enable health kong_http_proxy_nodes/kongpose_kong-dp_3" | socat stdio tcp4-connect:api.kong.lan:9999
echo "enable health kong_https_proxy_nodes/kongpose_kong-dp_3" | socat stdio tcp4-connect:api.kong.lan:9999
~~~

## Add server back to rotation
~~~
echo "set server kong_http_proxy_nodes/kongpose_kong-dp_3 state ready" | socat stdio tcp4-connect:api.kong.lan:9999
echo "set server kong_https_proxy_nodes/kongpose_kong-dp_3 state ready" | socat stdio tcp4-connect:api.kong.lan:9999
~~~

To view some HAProxy stats, look here;

http://api.kong.lan:8404/stats

# Locust

For some loadtesting ability, checkout locust; https://locust.io/

Locust is available in this case testing environment at http://api.kong.lan:8089/ and a simple test will hit the `httpbin/status/200` and `httpbin/status/503` endpoints in a 100-to-1 split. Edit the [locustfile.py](locust/locustfile.py) file to make the test more interesting.

# SMTP Server

Add a fake-smtp-server service. View the UI at http://api.kong.lan:1080/

# Redis

Need to see what is stored in redis? Try redis-commander at http://api.kong.lan:8081

# Graylog

For Syslog/TCP/UDP log plugins, use Graylog. The default username/password to login is admin/admin

http://api.kong.lan:9000/

Create an Input (System/Inputs) to listen on port 5555 for TCP and UDP.

# Zipkin

View traces here;

http://api.kong.lan:9411/
