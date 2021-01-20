# Examples

## Test kong is working by making an Admin API request

It is necessary to pass the CA certificate with the request to allow curl to verify the certs (or use -k which is not recommended);

~~~
curl --cacert ./ssl-certs/rootCA.pem -H "kong-admin-token: password" https://api.kong.lan:8444/default/kong
~~~

## Simple echo proxy

Test the default API via the HAProxy (the Kong proxy ports are not exposed externally so access in *ONLY* via HaProxy);

~~~
$ curl http://proxy.kong.lan/httpbin/anything
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
    "X-Forwarded-Host": "proxy.kong.lan",
    "X-Forwarded-Prefix": "/httpbin"
  },
  "json": null,
  "method": "GET",
  "origin": "172.28.0.1, 172.28.0.13",
  "url": "http://proxy.kong.lan/anything"
}

$ curl -s --cacert ./ssl-certs/rootCA.pem --http2 https://proxy.kong.lan/httpbin/anything
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
    "X-Forwarded-Host": "proxy.kong.lan",
    "X-Forwarded-Prefix": "/httpbin"
  },
  "json": null,
  "method": "GET",
  "origin": "172.28.0.13",
  "url": "https://proxy.kong.lan/anything"
}
~~~

## Rate limited proxy

There is also a rate limited example, secured with key-auth and two consumers

~~~
$ curl http://proxy.kong.lan/limit-httpbin/anything?apikey=abc
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
    "X-Forwarded-Host": "proxy.kong.lan",
    "X-Forwarded-Path": "/limit-httpbin/anything",
    "X-Forwarded-Prefix": "/limit-httpbin"
  },
  "json": null,
  "method": "GET",
  "origin": "172.26.0.1, 172.26.0.23",
  "url": "http://proxy.kong.lan/anything?apikey=abc"
}
~~~

and

~~~
$ curl http://proxy.kong.lan/limit-httpbin/anything?apikey=123
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
    "X-Forwarded-Host": "proxy.kong.lan",
    "X-Forwarded-Path": "/limit-httpbin/anything",
    "X-Forwarded-Prefix": "/limit-httpbin"
  },
  "json": null,
  "method": "GET",
  "origin": "172.26.0.1, 172.26.0.23",
  "url": "http://proxy.kong.lan/anything?apikey=123"
}
~~~

Send a few requests, get a 429 response and take a look in [redis](Admin.md#redis) ;-)

## OIDC Auth

An endpoint of `/auth/oidc` exists with auth_code and bearer authentication methods. A user exists in keycloak with username `keycloak_user` and password `password`. The client_id and secret are pre-set during the default Keycloak configuration.

### Bearer

Get an auth token by calling the Keycloak `/token` endpoint and assigning the token to an ENV var;

```
TOKEN=`curl -s -X POST 'http://proxy.kong.lan:8080/auth/realms/kong/protocol/openid-connect/token' \
       --header 'content-type: application/x-www-form-urlencoded'  \
      --data-urlencode 'client_id=kong' \
      --data-urlencode 'client_secret=ab523f45-e04a-43ec-bac7-2e268c2ff05c'  \
      --data-urlencode 'username=keycloak_user'  \
      --data-urlencode 'password=password'  \
      --data-urlencode 'grant_type=password' | jq -r '.access_token'`
```

Call the Kong proxy protected by the OIDC plugin with the access token in the header;

```
curl -v -H "Authorization: Bearer $TOKEN" http://proxy.kong.lan/auth/oid
```

### Auth Code

Open this link in a browser and login with the `keycloak_user` user;

http://proxy.kong.lan/auth/oidc

## Mutual-TLS Auth

The mutual-tls Route is configured to use the `client.kong.lan` hostname. The curl call passes the client certificate and key. The certificate exchange can be seen in the verbose headers from the curl call and the reponse has details of the mtls-consumer for consumer mapping in the plugin;

```
$ curl -v --cacert ./ssl-certs/rootCA.pem --key ./ssl-certs/client/client.key --cert ./ssl-certs/client/client.pem https://client.kong.lan/auth/mtls/anything
*   Trying 192.168.1.196:443...
* Connected to client.kong.lan (192.168.1.196) port 443 (#0)
* ALPN, offering h2
* ALPN, offering http/1.1
* successfully set certificate verify locations:
*  CAfile: ./ssl-certs/rootCA.pem
*  CApath: /etc/ssl/certs
* TLSv1.3 (OUT), TLS handshake, Client hello (1):
* TLSv1.3 (IN), TLS handshake, Server hello (2):
* TLSv1.3 (IN), TLS handshake, Encrypted Extensions (8):
* TLSv1.3 (IN), TLS handshake, Request CERT (13):
* TLSv1.3 (IN), TLS handshake, Certificate (11):
* TLSv1.3 (IN), TLS handshake, CERT verify (15):
* TLSv1.3 (IN), TLS handshake, Finished (20):
* TLSv1.3 (OUT), TLS change cipher, Change cipher spec (1):
* TLSv1.3 (OUT), TLS handshake, Certificate (11):
* TLSv1.3 (OUT), TLS handshake, CERT verify (15):
* TLSv1.3 (OUT), TLS handshake, Finished (20):
* SSL connection using TLSv1.3 / TLS_AES_256_GCM_SHA384
* ALPN, server accepted to use h2
* Server certificate:
*  subject: C=UK; ST=Hampshire; L=Aldershot; O=Kong UK; OU=Support; CN=client.kong.lan; emailAddress=stu@konghq.com
*  start date: Jan 20 13:42:28 2021 GMT
*  expire date: Jun  4 13:42:28 2022 GMT
*  subjectAltName: host "client.kong.lan" matched cert's "client.kong.lan"
*  issuer: C=UK; ST=Hampshire; L=Aldershot; O=Kong UK; OU=Support; CN=Support Root CA; emailAddress=stu@konghq.com
*  SSL certificate verify ok.
* Using HTTP2, server supports multi-use
* Connection state changed (HTTP/2 confirmed)
* Copying HTTP/2 data in stream buffer to connection buffer after upgrade: len=0
* Using Stream ID: 1 (easy handle 0x55e6a5dcb100)
> GET /auth/mtls/anything HTTP/2
> Host: client.kong.lan
> user-agent: curl/7.74.0
> accept: */*
>
* TLSv1.3 (IN), TLS handshake, Newsession Ticket (4):
* TLSv1.3 (IN), TLS handshake, Newsession Ticket (4):
* old SSL session ID is stale, removing
* Connection state changed (MAX_CONCURRENT_STREAMS == 128)!
< HTTP/2 200
< content-type: application/json
< content-length: 600
< server: gunicorn/19.9.0
< date: Wed, 20 Jan 2021 13:52:18 GMT
< access-control-allow-origin: *
< access-control-allow-credentials: true
< x-kong-upstream-latency: 3
< x-kong-proxy-latency: 4
< via: kong/2.2.1.0-enterprise-edition
<
{
  "args": {},
  "data": "",
  "files": {},
  "form": {},
  "headers": {
    "Accept": "*/*",
    "Connection": "keep-alive",
    "Host": "kongpose_httpbin_1",
    "User-Agent": "curl/7.74.0",
    "X-Consumer-Custom-Id": "mtls_id",
    "X-Consumer-Id": "c4d20dc1-d486-4c79-bf93-2a6ad4af4781",
    "X-Consumer-Username": "mtls-consumer",
    "X-Forwarded-Host": "client.kong.lan",
    "X-Forwarded-Path": "/auth/mtls/anything",
    "X-Forwarded-Prefix": "/auth/mtls"
  },
  "json": null,
  "method": "GET",
  "origin": "192.168.224.25",
  "url": "https://client.kong.lan/anything"
}
* Connection #0 to host client.kong.lan left intact
```

## Websocket Example

The echo-server can be used for websocket echo functionality. There is a default route setup on `/echo` that can be connected to with `websocat` or a websocket client of your choice. This server will echo back any data sent to it;

```
$ websocat ws://proxy.kong.lan/echo
Request served by d5dd815f8b0d
this is an echo
this is an echo
```

Compared to an HTTP request to this server;

```
$ curl http://proxy.kong.lan/echo
Request served by d5dd815f8b0d

HTTP/1.1 GET /

Host: echo-server:8080
Connection: keep-alive
X-Forwarded-Proto: http
X-Forwarded-Path: /echo
User-Agent: curl/7.74.0
X-Real-Ip: 192.168.80.1
Accept: */*
X-Forwarded-For: 192.168.80.1, 192.168.80.22
X-Forwarded-Host: proxy.kong.lan
X-Forwarded-Port: 48000
X-Forwarded-Prefix: /echo
```

## GRPC Example

### TLS

```
$ grpcurl -cacert ./ssl-certs/rootCA.pem -v -H 'kong-debug: 1' -d '{"greeting": "Kong 1.3!"}'  proxy.kong.lan:443 hello.HelloService.SayHello

Resolved method descriptor:
rpc SayHello ( .hello.HelloRequest ) returns ( .hello.HelloResponse );

Request metadata to send:
kong-debug: 1

Response headers received:
content-type: application/grpc
date: Wed, 13 Jan 2021 12:20:23 GMT
kong-route-id: 126677da-3ebb-4d72-b52e-b2cb31309383
kong-route-name: local-grpc-sayHello
kong-service-id: 70ff022b-b275-4d49-8f5a-a7b16ed8c78e
kong-service-name: local-grpc-server
server: openresty
via: kong/2.2.1.0-enterprise-edition
x-kong-proxy-latency: 1
x-kong-upstream-latency: 2

Response contents:
{
  "reply": "hello Kong 1.3!"
}

Response trailers received:
(empty)
Sent 1 request and received 1 response
```

```
$ grpcurl -cacert ./ssl-certs/rootCA.pem -v -H 'kong-debug: 1' -d '{"greeting": "Kong 1.3!"}'  proxy.kong.lan:443 hello.HelloService.LotsOfReplies

Resolved method descriptor:
rpc LotsOfReplies ( .hello.HelloRequest ) returns ( stream .hello.HelloResponse );

Request metadata to send:
kong-debug: 1

Response headers received:
content-type: application/grpc
date: Wed, 13 Jan 2021 12:19:17 GMT
kong-route-id: 1307e24e-0c3d-40bf-875a-d0ff61861c8d
kong-route-name: local-grpc-lotsOfReplies
kong-service-id: 70ff022b-b275-4d49-8f5a-a7b16ed8c78e
kong-service-name: local-grpc-server
server: openresty
via: kong/2.2.1.0-enterprise-edition
x-kong-proxy-latency: 1
x-kong-upstream-latency: 1

Response contents:
{
  "reply": "hello Kong 1.3!"
}

Response contents:
{
  "reply": "hello Kong 1.3!"
}

Response contents:
{
  "reply": "hello Kong 1.3!"
}

Response contents:
{
  "reply": "hello Kong 1.3!"
}

Response contents:
{
  "reply": "hello Kong 1.3!"
}

Response contents:
{
  "reply": "hello Kong 1.3!"
}

Response contents:
{
  "reply": "hello Kong 1.3!"
}

Response contents:
{
  "reply": "hello Kong 1.3!"
}

Response contents:
{
  "reply": "hello Kong 1.3!"
}

Response contents:
{
  "reply": "hello Kong 1.3!"
}

Response trailers received:
(empty)
Sent 1 request and received 10 responses
```
