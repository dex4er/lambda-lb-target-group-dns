FROM goreleaser/goreleaser:v1.24.0 AS goreleaser

FROM golang:1.22.1 AS build

WORKDIR /src

COPY Makefile go.mod go.sum ./
COPY --from=goreleaser /usr/bin/goreleaser /usr/bin/goreleaser
RUN make download

COPY . .
RUN make build

FROM scratch

WORKDIR /

COPY --from=build /src/lambda-lb-target-group-dns /entrypoint
COPY ./LICENSE /README.md /

ENTRYPOINT ["/entrypoint"]

LABEL \
  maintainer="Piotr Roszatycki <piotr.roszatycki@gmail.com>" \
  org.opencontainers.image.description="AWS Lambda which registers IP addresses to the LB Target Group based on DNS record" \
  org.opencontainers.image.licenses="MIT" \
  org.opencontainers.image.source=https://github.com/dex4er/lambda-lb-target-group-dns \
  org.opencontainers.image.title=lambda-lb-target-group-dns \
  org.opencontainers.image.url=https://github.com/dex4er/lambda-lb-target-group-dns \
  org.opencontainers.image.vendor=dex4er
