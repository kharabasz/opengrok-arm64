# opengrok-arm64

A Dockerfile that builds a native [OpenGrok](https://github.com/oracle/opengrok)
image for arm64 (Apple Silicon, Graviton, Ampere) as well as amd64.

The official [`opengrok/docker`](https://hub.docker.com/r/opengrok/docker)
image is published for amd64 only, so on an arm64 host it runs under qemu
emulation, and indexing is slow. Upstream tracks this in
[oracle/opengrok#3948](https://github.com/oracle/opengrok/issues/3948). Until
an official multi-arch image exists, this builds one locally.

## Build and run

```bash
docker build -t opengrok-native:1.14.20 .
```

Or use the example compose file, which indexes `~/git` read-only on
`http://127.0.0.1:8080`:

```bash
docker compose up -d
docker logs -f opengrok
```

The environment variables (`NOMIRROR`, `SYNC_PERIOD_MINUTES`, `INDEXER_OPT`,
and so on) are the same ones the official image supports; see its
[documentation](https://github.com/oracle/opengrok/tree/master/docker).

## How it differs from the official image

The base image, `tomcat:10.1.60-jdk21`, is already multi-arch, so the build
mostly follows [upstream's Dockerfile](https://github.com/oracle/opengrok/blob/1.14.20/Dockerfile)
with these changes:

- It unpacks the released `opengrok-<version>.tar.gz` instead of building
  OpenGrok from source with Maven, which makes the build take about a minute.
- It installs universal-ctags from apt instead of compiling it, and links it
  to `/usr/local/bin/ctags`, where upstream's `start.py` expects it.
- It installs git as the only version-control tool. Add Mercurial,
  Subversion and others to the `apt-get` line if you need them. (Upstream
  skips Perforce on aarch64 anyway.)
- Its entrypoint only chowns the writable directories (`/opengrok/data`,
  `/opengrok/etc` and the Tomcat webapps) before dropping to `appuser`. The
  stock entrypoint also chowns `/opengrok/src`, which fails when the sources
  are mounted read-only.

The start scripts in `/scripts` are taken from the same upstream release tag.

## Other versions

```bash
docker build --build-arg OPENGROK_VERSION=1.14.20 -t opengrok-native:1.14.20 .
```

Any version with a release tarball on the
[releases page](https://github.com/oracle/opengrok/releases) should work,
as long as its start scripts match this entrypoint.

## License

The Dockerfile is derived from OpenGrok's, so this repo uses the same
license, CDDL 1.0 ([LICENSE.txt](LICENSE.txt)).
