# Initial Setup

## MAC M1 users

If you are unlucky enough to have a Mac with an M1 chip, you will have problems. Some of those problems are;

### Keycloak does not start

Try using the ```image: wizzn/keycloak:14``` image for the keycloak container


## Configuration

### DNS Resolution

:anger: IMPORTANT :anger:
The assumption is that Kong will be accessible via several domain names. These are used for Kong Manager, https proxy connections, mutual tls, etc. Configure the below hostnames, either directly in /etc/hosts of via your DNS provider. All these hostnames should resolve to the host running Kong. If using OSX, then it is possible to use a local dnsmasq server to answer all queries for a particular domain. For example, resolve all hostname for kong.lan to the IP of the host as per [this](https://passingcuriosity.com/2013/dnsmasq-dev-osx/)

Hostname | Purpose |
------------ |------------ |
manager.kong.lan | Kong Manager |
api.kong.lan | Admin API |
portal.kong.lan | Kong Developer Portal |
portal-api.kong.lan | Kong Developer Portal API |
proxy.kong.lan | API Proxies |
client.kong.lan | Mutual TLS Proxies |
keycloak.kong.lan | Local Keycloak instance for Authentication |
locust.kong.lan | Load testing tool |
redis-commander.kong.lan | Viewer for redis |

It is *NOT* recommended that you use localhost/127.0.0.1 as the address for Kong. Using localhost will give issues when trying to access services as the requests will not be looking at the correct endpoints. If needed, you can add a 2nd IP address to the lo0 interface in OSX with this command;

~~~shell
sudo ifconfig lo0 alias 10.0.10.1
~~~

For newer versions of Linux with ifconfig deprecated/removed, use the following command;

~~~shell
sudo ip addr add 10.0.10.1 dev lo
~~~

Now you can configure the hostname resolution to use 10.0.10.1 for the IP address. Note, this setting will not survive a reboot but you can setup an alias automatically on a boot like [this](https://medium.com/@david.limkys/permanently-create-an-ifconfig-loopback-alias-macos-b7c93a8b0db)

### SSL Certificates

The docker-compose file expects to find the SSL certifcate pairs in the `./ssl-certs`, `./ssl-certs/hybrid` and `./ssl-certs/client` directories in this repository; these directories are mapped via docker volumes in the docker-compose file for Kong to access the certificates. There are a few pairs of certificates required for HTTPS access to Kong Manager, the Developer Portal, etc and a final set for the Control Plane/Data Plane communication.

Some default certificates are included, but you can also create you own by following the steps below;

1) Create the SSL certificates for the api.kong.lan hostname [here](ssl-certs/README.md)

2) Create the hybrid CP/DP certs [here](ssl-certs/hybrid/README.md)

Make sure to install the private CA certificate to the OS truststore or you will have issues connecting to Kong Manager via the browser. Details can be found [here](ssl-certs/README.md#add-the-private-ca-to-the-os-trustore)

## Start containers

Set and env var for the license;

~~~shell
export KONG_LICENSE_DATA=`cat ./license.json`;
~~~

Then start the utility services & kong containers

~~~shell
docker compose up -d
~~~

Then stop all running kongpose containers

~~~shell
docker compose --profile everything down --volumes
~~~

## Authentication

By default, ldap-auth is enabled and you can login to Kong Manager with `kong_admin`/`K1ngK0ng` at https://manager.kong.lan

You can look at the LDAP tree by searching as below;

~~~shell
ldapsearch -H "ldap://0.0.0.0:389" -D "cn=Administrator,cn=users,dc=ldap,dc=kong,dc=com" -w "Passw0rd" -b "dc=ldap,dc=kong,dc=com" "(sAMAccountName=kong_admin)"
~~~

## Developer Portal

By default, the Developer Portal is configured to used OIDC (keycloak) for authentication. The keycloak instance has some accounts seeded in it that can be used to login to the DevPortal. Firstly, we need to create and approve a Kong Developer, which can be done either via the DevPortal signup and Kong Manager Developer account approval or via a couple of Admin API calls. We are using email for the user id and the keycloak user is setup with the email of `stu+dp@konghq.com` and the password value of `password`. You can also add your own user to Keycloak if you prefer to use a different email address.

### Create a Developer

~~~shell
curl --cacert ./ssl-certs/rootCA.pem -X POST 'https://portal-api.kong.lan/default/register' \
-H 'Content-Type: application/json' \
-D 'Kong-Admin-Token: password' \
--data-raw '{"email":"stu+dp@konghq.com",
 "password":"password",
 "meta":"{\"full_name\":\"Dev E. Loper\"}"
}'
~~~

### Approve the Developer

~~~shell
curl --cacert ./ssl-certs/rootCA.pem -X PATCH 'https://api.kong.lan/default/developers/stu+dp@konghq.com' \
--header 'Content-Type: application/json' \
--header 'Kong-Admin-Token: password' \
--data-raw '{"status": 0}'
~~~

You should now be able to login to the Developer Portal using `stu+dp@konghq.com`/`password` as the credentials.

### Upload a spec file

Add a very simple OAS 3.0 spec file for the Dad Jokes API

~~~shell
curl --http1.1 --cacert ./ssl-certs/rootCA.pem -X POST 'https://api.kong.lan/default/files' \
--header 'Kong-Admin-Token: password' \
--form 'path="specs/dadjokes.yaml"' \
--form 'contents=@"./devportal/dadjokes.yaml"'
~~~

## Adding Kong entities

If you want to add Kong entities, use deck to dump the configuration making sure to export the entity id's too;

~~~
deck dump --with-id --workspace default --output-file deck/default-entities.yaml
~~~

