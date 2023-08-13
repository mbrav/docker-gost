# docker-gost

[![ci](https://github.com/mbrav/docker-gost/actions/workflows/docker-hub.yml/badge.svg)](https://github.com/mbrav/docker-gost/actions/workflows/docker-hub.yml)
[![Hits-of-Code](https://hitsofcode.com/github/mbrav/docker-gost?branch=main)](https://hitsofcode.com/github/mbrav/docker-gost/view?branch=main)

Docker images with OpenSSL and Russian GOST crypto algorithms

This is the Git repo of the for [`docker-gost`](https://github.com/mbrav/docker-gost) Docker images. See [the Docker Hub page](https://hub.docker.com/repository/docker/mbrav/docker-gost/general) for the full readme on how to use this Docker image and for information regarding contributing and issues.

## Supported tags and their respective Dockerfiles

The `mbrav/docker-gost` repository is tagged with the following scheme where `x.x.x` is the OpenSSL version and `y.y.y` is the nginx version:

- **Debian 12 ("*Bookworm*")**:
  - Tags: `latest`, `bookworm`, `bookworm-x.x.x`
  - Dockerfile: [debian-bookworm/Dockerfile](https://github.com/mbrav/docker-gost/blob/main/debian-bookworm/Dockerfile)
- **Debian 12 ("*Bookworm*") with Nginx**:
  - Tags: `bookworm-nginx`, `bookworm-nginx-x.x.x`, `bookworm-nginx-x.x.x-y.y.y`, `nginx`, `nginx-x.x.x`, `nginx-x.x.x-y.y.y`
  - Dockerfile: [debian-bookworm/nginx.Dockerfile](https://github.com/mbrav/docker-gost/blob/main/debian-bookworm/nginx.Dockerfile)
- **Alpine 3**:
  - Tags: `alpine`, `alpine-x.x.x`
  - Dockerfile: [alpine/Dockerfile](https://github.com/mbrav/docker-gost/blob/main/alpine/Dockerfile)
- **Alpine 3 with Nginx**: *WIP*

See [`data.json`](https://github.com/mbrav/docker-gost/blob/main/data.json) metadata file for actual information.

## About this Repo

- **Maintained by**: [mbrav](https://github.com/mbrav)
- **Where to get help**: Literally nowhere, hence the reason I created this repository.
- **Why to use this image**: If your application needs [`openssl`](https://github.com/openssl/openssl) with GOST crypto algorithms ([`gost-engine`](https://github.com/gost-engine/engine)). Docker images are available at [`mbav/docker-gost`](https://github.com/mbrav/docker-gost) and are automatically built and uploaded to Docker Hub using [GitHub actions](https://github.com/mbrav/docker-gost/actions/workflows/docker-hub.yml).

## Contributing

Please see the [contributing guide](https://github.com/mbrav/docker-gost/blob/main/CONTRIBUTING.md) for guidelines on how to best contribute to this project.

## License

[![License](https://img.shields.io/badge/License-BSD_3--Clause-yellow.svg)](https://opensource.org/licenses/BSD-3-Clause)
[BSD 3-Clause LICENSE](https://github.com/mbrav/docker-gost/blob/main/LICENSE)

As for any pre-built image usage, it is the image user's responsibility to ensure that any use of this image complies with any relevant licenses for all software contained within.

&copy; [mbrav](https://github.com/mbrav) 2023
