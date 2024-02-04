# lambda-lb-target-group-dns

[![GitHub](https://img.shields.io/github/v/tag/dex4er/lambda-lb-target-group-dns?label=GitHub)](https://github.com/dex4er/lambda-lb-target-group-dns)
[![Snapshot](https://github.com/dex4er/lambda-lb-target-group-dns/actions/workflows/snapshot.yaml/badge.svg)](https://github.com/dex4er/lambda-lb-target-group-dns/actions/workflows/snapshot.yaml)
[![Release](https://github.com/dex4er/lambda-lb-target-group-dns/actions/workflows/release.yaml/badge.svg)](https://github.com/dex4er/lambda-lb-target-group-dns/actions/workflows/release.yaml)
[![Trunk Check](https://github.com/dex4er/lambda-lb-target-group-dns/actions/workflows/trunk.yaml/badge.svg)](https://github.com/dex4er/lambda-lb-target-group-dns/actions/workflows/trunk.yaml)
[![Docker Image Version](https://img.shields.io/docker/v/dex4er/lambda-lb-target-group-dns?label=Docker&logo=docker&sort=semver)](https://hub.docker.com/r/dex4er/lambda-lb-target-group-dns)
[![Amazon ECR Image Version](https://img.shields.io/docker/v/dex4er/lambda-lb-target-group-dns?label=Amazon%20ECR&logo=Amazon+AWS&sort=semver)](https://gallery.ecr.aws/dex4er/lambda-lb-target-group-dns)

AWS Lambda which registers IP addresses to the LB Target Group based on DNS
record.

!!! It is not ready to use yet !!!

## Usage

```sh
lambda-lb-target-group-dns
```

### Docker

From DockerHub:

```sh
docker pull dex4er/lambda-lb-target-group-dns
```

or from Amazon ECR Public:

```sh
docker pull public.ecr.aws/dex4er/lambda-lb-target-group-dns
```

Supported tags:

- vX.Y.Z-linux-amd64
- vX.Y.Z-linux-arm64
- vX.Y.Z
- vX.Y
- vX
- latest

## License

The MIT License (MIT)

Copyright (c) 2024 Piotr Roszatycki <piotr.roszatycki@gmail.com>
