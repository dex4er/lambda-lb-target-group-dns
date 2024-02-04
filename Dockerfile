FROM scratch

ARG VERSION
ARG REVISION
ARG BUILDDATE

WORKDIR /

COPY lambda-lb-target-group-dns entrypoint

ENTRYPOINT ["/entrypoint"]

LABEL \
  maintainer="Piotr Roszatycki <piotr.roszatycki@gmail.com>" \
  org.opencontainers.image.created=${BUILDDATE} \
  org.opencontainers.image.description="AWS Lambda which registers IP addresses to the LB Target Group based on DNS record" \
  org.opencontainers.image.licenses="MIT" \
  org.opencontainers.image.revision=${REVISION} \
  org.opencontainers.image.source=https://github.com/dex4er/lambda-lb-target-group-dns \
  org.opencontainers.image.title=lambda-lb-target-group-dns \
  org.opencontainers.image.url=https://github.com/dex4er/lambda-lb-target-group-dns \
  org.opencontainers.image.vendor=dex4er \
  org.opencontainers.image.version=v${VERSION}
