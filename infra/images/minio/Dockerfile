FROM golang:1.24.8-alpine AS builder

ARG MINIO_VERSION=RELEASE.2025-10-15T17-29-55Z

RUN apk add --no-cache git ca-certificates

WORKDIR /src
RUN git clone --depth 1 --branch "${MINIO_VERSION}" \
    https://github.com/minio/minio.git .

RUN CGO_ENABLED=0 go build -trimpath -o /out/minio .

FROM alpine:3.22

RUN apk add --no-cache ca-certificates
COPY --from=builder /out/minio /usr/local/bin/minio

EXPOSE 9000 9001
ENTRYPOINT ["minio"]
CMD ["server", "/data", "--console-address", ":9001"]