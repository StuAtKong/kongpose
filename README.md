# Kongpose

A comprehensive docker-compose file to get Kong EE up and running with minimal effort. Several examples of Kong entities are created along with some utility/administration containers.

## Setup

The initial setup is detailed in [Setup](Setup.md)

## Custom plugins (git submodules)

Custom plugins are consumed from their own repos as git submodules under
`custom_plugins/`, rather than vendored directly into this repo. Two are
wired up as examples:

| Plugin | Repo | Path | Pinned to |
|---|---|---|---|
| `ocsp-stapling` | [kong-plugin-ocsp-stapling](https://github.com/StuAtKong/kong-plugin-ocsp-stapling) | `custom_plugins/kong-plugin-ocsp-stapling` | tag `0.5.1` |
| `log-filter` | [kong-plugin-log-filter](https://github.com/KongHQ-CX/kong-plugin-log-filter) | `custom_plugins/kong-plugin-log-filter` | commit `033cdf0` (no tags upstream yet) |

A plain `git clone` leaves these directories **empty**. Fetch them before
starting containers:

```bash
# fresh clone
git clone --recurse-submodules <kongpose-url>
# existing clone
git submodule update --init --recursive
```

Both plugins are disabled by default — see [Setup.md](Setup.md#custom-plugins)
for how to enable them via `docker-compose.custom-plugins.yaml`.

Prefer pinning each submodule to a release tag, so every clone gets
identical, tested plugin code — `ocsp-stapling` is pinned to `0.5.1` this
way. `log-filter` has no tags upstream yet, so it's pinned to a specific
commit instead; switch it to a tag as soon as the upstream repo cuts one.
To move to a newer release/commit:

```bash
git -C custom_plugins/<plugin-dir> fetch --tags   # omit --tags if the repo has none
git -C custom_plugins/<plugin-dir> checkout <new-tag-or-commit>
git add custom_plugins/<plugin-dir> && git commit -m "Bump <plugin> to <new-tag-or-commit>"
```

Submodules are checked out in detached-HEAD state. If you need to make and
commit changes to a plugin itself from within its submodule directory, check
out that repo's default branch first (`main` for `ocsp-stapling`, `master`
for `log-filter`).

### Adding another custom plugin

1. Add it as a submodule: `git submodule add <repo-url> custom_plugins/<plugin-repo-name>`
2. Pin it to a release tag if the upstream repo has one, otherwise a specific commit.
3. Add its plugin name to `KONG_PLUGINS` and a bind mount for `kong-cp`/`kong-dp`
   in `docker-compose.custom-plugins.yaml`, following the existing entries as a
   template — that file is where all custom-plugin config lives, not the base
   `docker-compose.yaml`.

## Examples

Some Kong examples are described in [Examples](Examples.md)

## Administration

There are some administration tools/utilities in [Admin](Admin.md)
