# Hybrid SSL certificates for CP/DP communication

Place the hybrid deployment certificiates here (cluster.key and cluster.crt)

You can start a temporary kong container using a command similar to below;

```
docker run --rm -it -v $(pwd)/ssl-certs/hybrid:/tmp/ssl/hybrid kong-docker-kong-enterprise-edition-docker.bintray.io/kong-enterprise-edition:2.2.0.0-alpine /bin/sh
```

Then run;

```
cd /tmp/ssl/hybrid
kong hybrid certs
```

See here for more info; https://docs.konghq.com/enterprise/2.1.x/deployment/hybrid-mode-setup/#step-1-generate-a-certificatekey-pair
