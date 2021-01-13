# Hybrid SSL certificates for CP/DP communication

Place the hybrid deployment certificiates here (cluster.key and cluster.crt)

See here for info on creating cluster certificates; https://docs.konghq.com/enterprise/2.1.x/deployment/hybrid-mode-setup/#step-1-generate-a-certificatekey-pair

To create the certificates, you can start a temporary kong container using a command as below (this maps the repository directory to the container which allows the certificates to be saved to the docker host);

```
docker run --rm -it --user root -v $(pwd)/ssl-certs/hybrid:/tmp/ssl/hybrid kong-docker-kong-enterprise-edition-docker.bintray.io/kong-enterprise-edition:2.2.0.0-alpine /bin/sh
```

Then run;

```
cd /tmp/ssl/hybrid
kong hybrid gen_cert
exit
```

Make sure the permissions for the cluster certs are correct (they will be owned by root). It is likely you'll need to run `sudo chmod 644 cluster.key` for the hybrid cluster ssl key.
