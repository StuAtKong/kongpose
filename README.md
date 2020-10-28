# Initial Setup

Set and env var for the license;

`export KONG_LICENSE_DATA=`cat /home/stu/kongpose/license.json`;`

Then run;

Start the service & kong containers

`docker-compose up -d`

This will start Kong EE, Postgres, Keycloak, an LDAP (AD) server and an HAProxy server. 

By default, basic-auth is enabled and you can login with kong_admin/password but there are scripts to populate the LDAP server with seed data. After population, it should be possible to login to Kong Manager with LDAP auth and kong_admin/K1ngK0ng.

```
docker exec -it --user root case-ad-server /bin/sh
sh /setup-ad/setup.sh
bash /setup-ad/seed.sh
samba -D
```

```
ldapsearch -H "ldap://0.0.0.0:389" -D "cn=Administrator,cn=users,dc=ldap,dc=kong,dc=com" -w "Passw0rd" -b "dc=ldap,dc=kong,dc=com" "(sAMAccountName=kong_admin)"
```

Populate a healthcheck endpoint and a default Route/Service with deck;

```
$ cat ~/.deck.yaml
# sample configuration file for global parameters of deck CLI.
kong-addr: https://mrdizzy.heronwood.co.uk:48444
headers:
- "kong-admin-token:password"
#- "kong-admin-user:super"
#- "Cookie:manager_session=oJIPHmQ9MhvBEeHJVnzCSw|1601499374|xtrHX98NvHloxwCx3bZnji6WKK8; Path=/; SameSite=Strict; Secure; HttpOnly"
no-color: false
verbose: 0

# tls-skip-verify: false
# tls-server-name: my-server-name.example.com
# ca_cert : custom PEM encoded CA cert
```

`deck sync -s workspace-compose.yaml`

Test the default API via the HAProxy (the Kong proxy ports are not exposed externally so access in *ONLY* via HaProxy);;

```
$ curl https://mrdizzy.heronwood.co.uk/httpbin/anything
{
  "args": {},
  "data": "",
  "files": {},
  "form": {},
  "headers": {
    "Accept": "*/*",
    "Connection": "keep-alive",
    "Host": "httpbin-1",
    "User-Agent": "curl/7.64.1",
    "X-Forwarded-Host": "kong-proxy.heronwood.co.uk"
  },
  "json": null,
  "method": "GET",
  "origin": "192.168.0.1",
  "url": "https://kong-proxy.heronwood.co.uk/anything"
}
```

# Keycloak:

URL: http://localhost:8080

Username: admin

Password: password

# HAProxy

https://www.haproxy.com/blog/dynamic-configuration-haproxy-runtime-api/

To use the haproxy API;

```
echo "help" | socat stdio tcp4-connect:127.0.0.1:9999
```

Test the default API via haproxy;

```
$ curl http://mrdizzy.heronwood.co.uk:8888/httpbin/anything
```
