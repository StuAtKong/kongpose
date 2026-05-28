# Hybrid SSL certificates for CP/DP communication

Place the hybrid deployment certificates here (`cluster.key` and `cluster.crt`).

See the Kong docs for background; https://docs.konghq.com/gateway/latest/production/deployment-topologies/hybrid-mode/setup/#generate-a-certificate-key-pair

## Quickest option: openssl on the host

`kong hybrid gen_cert` is a thin wrapper around openssl, so you can generate the pair directly without spinning up a container. From the repo root:

```
cd ssl-certs/hybrid
openssl req -new -x509 -nodes -newkey ec:<(openssl ecparam -name secp384r1) \
  -keyout cluster.key -out cluster.crt -days 1095 -subj "/CN=kong_clustering"
chmod 644 cluster.key
```

The `chmod` is needed because openssl writes the key with `0600` perms by default, and the non-root `kong` user inside the container won't be able to read it otherwise (nginx will fail to load the cluster cert key with `Permission denied`).

## Alternative: one-shot Docker command

If you'd rather use the Kong image (for parity with CI, etc.), run it as a single command instead of an interactive shell:

```
docker run --rm --user root \
  -v $(pwd)/ssl-certs/hybrid:/tmp/ssl/hybrid -w /tmp/ssl/hybrid \
  kong/kong-gateway:3.14.0.3 kong hybrid gen_cert
```

Because this runs as root inside the container, the resulting files will be owned by root on the host. Fix the key permissions so your user can read it:

```
sudo chown $(id -u):$(id -g) ssl-certs/hybrid/cluster.{key,crt}
```
