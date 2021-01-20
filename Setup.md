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

## Developer Portal

By default, the Developer Portal is configured to used OIDC (keycloak) for authentication. The keycloak instance has some accounts seeded in it that can be used to login to the DevPortal. Firstly, we need to create and approve a Kong Developer, which can be done either via the DevPortal signup and Kong Manager Developer account approval or via a couple of Admin API calls. We are using email for the user id and the keycloak user is setup with the email of `stu+dp@konghq.com` and the password value of `password`. You can also add your own user to Keycloak if you prefer to use a different email address.

### Create a Developer

~~~
curl --cacert ./ssl-certs/rootCA.pem -X POST 'https://api.kong.lan:8447/default/register' \
-H 'Content-Type: application/json' \
-D 'Kong-Admin-Token: password' \
--data-raw '{"email":"stu+dp@konghq.com",
 "password":"password",
 "meta":"{\"full_name\":\"Dev E. Loper\"}"
}'
~~~

### Approve the Developer

~~~
curl --cacert ./ssl-certs/rootCA.pem -X PATCH 'https://api.kong.lan:8444/default/developers/stu+dp@konghq.com' \
--header 'Content-Type: application/json' \
--header 'Kong-Admin-Token: password' \
--data-raw '{"status": 0}'
~~~

You should now be able to login to the Developer Portal using `stu+dp@konghq.com`/`password` as the credentials.
