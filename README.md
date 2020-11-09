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

Either set the deck environment variables;

~~~
export DECK_TLS_SERVER_NAME="api.kong.lan"
export DECK_KONG_ADDR="https://api.kong.lan:48444"
export DECK_CA_CERT=`cat ssl-certs/rootCA.pem`
~~~

and then populate a healthcheck endpoint and a default Route/Service with deck;

~~~
deck sync -s workspace-compose.yaml --headers kong-admin-token:password
~~~

*** I can't (yet) get this working :-( ***

or create the ~/.deck.yaml file and make sure the kong-addr is correct and add the rootCA.pem contents to the ca_cert parameter

~~~
$ cat ~/.deck.yaml
# sample configuration file for global parameters of deck CLI.
kong-addr: https://api.kong.lan:48444
headers:
- "kong-admin-token:password"
#- "kong-admin-user:super"
#- "Cookie:manager_session=oJIPHmQ9MhvBEeHJVnzCSw|1601499374|xtrHX98NvHloxwCx3bZnji6WKK8; Path=/; SameSite=Strict; Secure; HttpOnly"
no-color: false
verbose: 0

# tls-skip-verify: false
# tls-server-name: my-server-name.example.com
# ca_cert : custom PEM encoded CA cert
ca_cert :
  -----BEGIN CERTIFICATE-----
  MIIEBzCCAu+gAwIBAgIUG9T7bTwrVOdH+BNk7KWZgq/nVEcwDQYJKoZIhvcNAQEL
  BQAwgZIxCzAJBgNVBAYTAlVLMRIwEAYDVQQIDAlIYW1wc2hpcmUxEjAQBgNVBAcM
  CUFsZGVyc2hvdDEQMA4GA1UECgwHS29uZyBVSzEQMA4GA1UECwwHU3VwcG9ydDEY
  MBYGA1UEAwwPU3VwcG9ydCBSb290IENBMR0wGwYJKoZIhvcNAQkBFg5zdHVAa29u
  Z2hxLmNvbTAeFw0yMDEwMzAxMjA1NDJaFw0yMzA4MjAxMjA1NDJaMIGSMQswCQYD
  VQQGEwJVSzESMBAGA1UECAwJSGFtcHNoaXJlMRIwEAYDVQQHDAlBbGRlcnNob3Qx
  EDAOBgNVBAoMB0tvbmcgVUsxEDAOBgNVBAsMB1N1cHBvcnQxGDAWBgNVBAMMD1N1
  cHBvcnQgUm9vdCBDQTEdMBsGCSqGSIb3DQEJARYOc3R1QGtvbmdocS5jb20wggEi
  MA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCzR46YaAECb+K1YmAXhb6XICku
  y1+xeVKqCnUJutDTvBlN2S4NnKxZn4BXgv83ormjN8XdP6U7abRz0nyuaLPJrfPT
  chMA2Dcvk+jrLRamKDa0LyxAiX/ViB6ENwktbJRm81zP/zIx4HEwHActxQYEkQuW
  +aFNpR0S9zgWEUyExnvarWexG8Y7M7WTohPFzWPsQyTvS9gnNTjN7obY6YTXPlfT
  rhQPNQcySLUbzRaxNjIl8sxCGMk7TU80QHCFV99KQEKia4PJh+9pi62eEFYC6LlC
  Vn9Wun5KqPCOvBs8nrSQu14kTsq4dSwD0sbwPoOzlXE/5v5vPadjapntEC2RAgMB
  AAGjUzBRMB0GA1UdDgQWBBR2ySl/TAlFDGO3NAVlyJaZR+XZtzAfBgNVHSMEGDAW
  gBR2ySl/TAlFDGO3NAVlyJaZR+XZtzAPBgNVHRMBAf8EBTADAQH/MA0GCSqGSIb3
  DQEBCwUAA4IBAQCq2G68TQetpZsJcRVX/r+GxdgH/EtA2GfsVeuLvrLdO70u85y7
  tonGTvPSltnZ+tS+7IUgNbjuJ+KZPWQK2ScSmq//8i6rIGJqNl9z8Z9K3h+efMT8
  JAXzKgNaw+tGnWKiBE3d6ksmhD+tIfxzDYFwmRxuyTfJZHLrBa+DKlvAEu3z1vX5
  A5qpckbGfEQ5PJRg/PjfuxfSSIRLjDaq+jGd3hvSsHagYDmDpXfwyJUNoTpg+jY+
  BHtaDJAJ+W83/LP7VviHNjZ7+qKYuDTTvT5+o55AG1OR1jsFpvbSzi+Ucs2ExOXb
  78Pm3Sm2u9c6L6TpXYUaq9S1VQ+8Iqxyk4ZF
  -----END CERTIFICATE-----
~~~

and then populate a healthcheck endpoint and a default Route/Service with deck;

~~~
deck sync -s workspace-compose.yaml
~~~

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
