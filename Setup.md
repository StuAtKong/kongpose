# Initial Setup

## Configuration

The assumption is that Kong will be accessible via the api.kong.lan hostname. Ensure this resolves to the correct IP for where you will be running Kong.

The docker-compose file expects to find the SSL certifcate pairs in the `./ssl-certs` and `./ssl-certs/hybrid` directories in this repository; these directories are mapped via docker volumes in the docker-compose file for Kong to access the certificates. There are two sets of certificates required, the first for HTTPS access to Kong Manager and the second is for Control Plane/Data Plane communication.

1) Create the SSL certificates for the api.kong.lan hostname [here](ssl-certs/README.md)

2) Create the hybrid CP/DP certs [here](ssl-certs/hybrid/README.md)

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

