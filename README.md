# Kongpose

A comprehensive docker-compose file to get Kong EE up and running with minimal effort. Several examples of Kong entities are created along with some utility/administration containers.

## Setup

The initial setup is detailed in [Setup](Setup.md)

## Custom plugins (git submodule)

On this branch the `ocsp-stapling` plugin is consumed from its own repo
([kong-plugin-ocsp-stapling](https://github.com/StuAtKong/kong-plugin-ocsp-stapling))
as a git submodule under `custom_plugins/kong-plugin-ocsp-stapling`. A
plain `git clone` leaves that directory **empty**, and the container's
`./custom_plugins` bind mount would then have no plugin to load. Fetch it
before `docker compose up`:

```bash
# fresh clone
git clone --recurse-submodules <kongpose-url>
# existing clone
git submodule update --init --recursive
```

To move to a newer plugin release, check out the tag inside the submodule
and commit the new pointer:

```bash
git -C custom_plugins/kong-plugin-ocsp-stapling fetch --tags
git -C custom_plugins/kong-plugin-ocsp-stapling checkout <new-tag>
git add custom_plugins/kong-plugin-ocsp-stapling && git commit -m "Bump ocsp-stapling to <new-tag>"
```

## Examples

Some Kong examples are described in [Examples](Examples.md)

## Administration

There are some administration tools/utilities in [Admin](Admin.md)
