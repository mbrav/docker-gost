# docker-gost

[![ci](https://github.com/mbrav/docker-gost/actions/workflows/docker-hub.yml/badge.svg)](https://github.com/mbrav/docker-gost/actions/workflows/docker-hub.yml)
[![Hits-of-Code](https://hitsofcode.com/github/mbrav/docker-gost?branch=main)](https://hitsofcode.com/github/mbrav/docker-gost/view?branch=main)

Docker images with OpenSSL and Russian GOST crypto algorithms

This is the Git repo of the for [`docker-gost`](https://github.com/mbrav/docker-gost) Docker images. See [the Docker Hub page](https://hub.docker.com/repository/docker/mbrav/docker-gost/general) for the full readme on how to use this Docker image and for information regarding contributing and issues.

## Usage

To check if GOST ciphers are present, start container:

```shell
docker run --rm -it mbrav/docker-gost bash
```

Inside the container grep the list of available OpenSSL ciphers:

```shell
openssl ciphers | tr ":" "\n" | grep GOST
GOST2012-MAGMA-MAGMAOMAC
GOST2012-KUZNYECHIK-KUZNYECHIKOMAC
LEGACY-GOST2012-GOST8912-GOST8912
IANA-GOST2012-GOST8912-GOST8912
GOST2001-GOST89-GOST89
```

If you do not see this list, please file an issue.

### Creating a self-signed gost2001 certificate

1. **Generate a Private Key**: Once inside a `mbrav/docker-gost` container, create a private key:

```shell
openssl genpkey -algorithm gost2001 -pkeyopt paramset:A -out private.key
```

The `-pkeyopt paramset:A` option specifies that you want to use parameter set A, which corresponds to a particular curve. Different parameter sets (curves) may offer different levels of security and performance.

Keep in mind that GOST 2001 is a bit different from traditional key-based algorithms in this regard. You choose a parameter set (curve) based on your security requirements, and the key pair is generated accordingly. There isn't a direct control over "key length" as in some other algorithms.

Based on [`v3.0.2` version of gost-engine](https://github.com/gost-engine/engine/tree/v3.0.2), there are three Parameter sets for the gost2001 algorithm:

- [`ecp_id_GostR3410_2001_CryptoPro_A_ParamSet`](https://github.com/gost-engine/engine/blob/v3.0.2/ecp_id_GostR3410_2001_CryptoPro_A_ParamSet.c)
- [`ecp_id_GostR3410_2001_CryptoPro_B_ParamSet`](https://github.com/gost-engine/engine/blob/v3.0.2/ecp_id_GostR3410_2001_CryptoPro_B_ParamSet.c)
- [`ecp_id_GostR3410_2001_CryptoPro_C_ParamSet`](https://github.com/gost-engine/engine/blob/v3.0.2/ecp_id_GostR3410_2001_CryptoPro_C_ParamSet.c)

2. **Create a Certificate Signing Request (CSR)**: Generate a CSR using the private key you created in the previous step:

```shell
openssl req -new -key private.key -out csr.csr
```

3. **Generate a Self-Signed Certificate**: Now, use the private key and CSR to generate a self-signed certificate.

```shell
openssl x509 -req -days 365 -in csr.csr -signkey private.key -out certificate.crt
```

This command will create a self-signed certificate valid for 365 days.

4. **Verify the Certificate** (Optional): You can verify the details of the generated certificate using the following command:

```shell
openssl x509 -in certificate.crt -text -noout
```

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
