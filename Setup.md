# Initial Setup

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

Do *NOT* use localhost/127.0.0.1 as the address for Kong. Using localhost will give issues when trying to access services as the requests will not be looking at the correct endpoints. Use the IP address of your host for the DNS resolution IP address. If needed, you can add a 2nd IP address to the lo0 interface in OSX with this command;

~~~shell
sudo ifconfig lo0 alias 10.0.10.1
~~~

Now you can configure the hostname resolution to use 10.0.10.1 for the IP address.

### SSL Certificates

The docker-compose file expects to find the SSL certifcate pairs in the `./ssl-certs` and `./ssl-certs/hybrid` directories in this repository; these directories are mapped via docker volumes in the docker-compose file for Kong to access the certificates. We will create our own private CA and use this to sign a wildcart certificate for `*.kong.lan` to ease the installation process.


Some default certificates are included, but you can also create you own by following the steps below;

1) Create the SSL certificates for the api.kong.lan hostname [here](ssl-certs/README.md)

2) Create the hybrid CP/DP certs [here](ssl-certs/hybrid/README.md)

Make sure to install the private CA certificate to the OS truststore or you will have issues connecting to Kong Manager via the browser. Details can be found [here](ssl-certs/README.md#add-the-private-ca-to-the-os-trustore)

## Start containers

### Start the kong containers

~~~shell
docker-compose up -d
~~~

This will start Postgres, Kong EE, an SMTP server  and a local instance of httpbin to allow local testing.

### Upload a license

~~~shell
curl --http1.1 -k -X POST 'https://api.kong.lan:8444/licenses' -F "payload=@/home/stu/.kong-license-data/license.json"
~~~

### Recreate the CP to enable EE features

~~~shell
docker-compose stop kong-cp; docker-compose rm -f kong-cp; docker-compose up -d kong-cp
~~~

There is no authentication configured in the docker compose file. You can access Kong Manager at the below URL;

https://manager.kong.lan:8445

## Authentication

To enable Kong Manager authentication, uncomment the below lines in the docker-compose.yaml file for the kong-cp service;

~~~shell
KONG_ADMIN_GUI_AUTH: "basic-auth"
KONG_ADMIN_GUI_SESSION_CONF: "{ \"cookie_name\": \"manager-session\", \"secret\": \"this_is_my_other_secret\", \"storage\": \"kong\", \"cookie_secure\":true, \"cookie_lifetime\":36000}"
~~~

Recreate the kong-cp to enable the authentication features

~~~shell
docker-compose stop kong-cp; docker-compose rm -f kong-cp; docker-compose up -d kong-cp
~~~

There is no authentication configured in the docker compose file. You can access Kong Manager at the below URL;

https://manager.kong.lan:8445

You can login to Kong Manager with `kong_admin`/`password`


## Developer Portal

By default, the Developer Portal is configured to used `basic-auth` for authentication. Firstly, we need to create and approve a Kong Developer, which can be done either via the DevPortal signup and Kong Manager Developer account approval or via a couple of Admin API calls. 

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

