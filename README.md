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

By default, basic-auth is enabled and you can login with kong_admin/password.

There are scripts to populate the LDAP server with seed data. After population, it should be possible to login to Kong Manager with LDAP auth and kong_admin/K1ngK0ng (you will also need to edit the docker-compose.yaml file to change the admin_gui_auth and admin_gui_auth_conf (commented values in this file) and restart the kong CP.

~~~
docker exec -it --user root case-ad-server /bin/sh
sh /setup-ad/setup.sh
bash /setup-ad/seed.sh
samba -D
~~~

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

# Keycloak:

URL: http://localhost:8080

Username: admin

Password: password

# HAProxy

https://www.haproxy.com/blog/dynamic-configuration-haproxy-runtime-api/

To use the haproxy API;

~~~
echo "help" | socat stdio tcp4-connect:127.0.0.1:9999
~~~

# Locust

For some loadtesting ability, checkout locust; https://locust.io/

Locust is available in this case testing environment at http://api.kong.lan:8089/ and a simple test will hit the `httpbin/status/200` and `httpbin/status/503` endpoints in a 100-to-1 split. Edit the [locustfile.py](locust/locustfile.py) file to make the test more interesting.

# SMTP Server

Add a fake-smtp-server service. View the UI at http://api.kong.lan:1080/

# Redis

Need to see what is stored in redis? Try redis-commander at http://ap.kong.lan:8081

