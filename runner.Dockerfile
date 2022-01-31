# Build the manager binary
FROM golang:1.17 as builder

RUN apt-get update && apt-get install -y unzip

WORKDIR /workspace
# Copy the Go Modules manifests
COPY go.mod go.mod
COPY go.sum go.sum
# cache deps before building and copying source so that we don't need to re-download as much
# and so that source changes don't invalidate our downloaded layer
RUN go mod download

# Copy the go source
COPY cmd/runner/main.go cmd/runner/main.go
COPY api/ api/
COPY controllers/ controllers/
COPY runner/ runner/
COPY utils/ utils/

# Build
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -o tf-runner cmd/runner/main.go

ADD https://releases.hashicorp.com/terraform/1.1.4/terraform_1.1.4_linux_amd64.zip /terraform_1.1.4_linux_amd64.zip
RUN unzip -q /terraform_1.1.4_linux_amd64.zip


FROM alpine:3.15

LABEL org.opencontainers.image.source="https://github.com/chanwit/tf-controller"

RUN apk add --no-cache ca-certificates tini git openssh-client gnupg

COPY --from=builder /workspace/tf-runner /usr/local/bin/
COPY --from=builder /workspace/terraform /usr/local/bin/

# Create minimal nsswitch.conf file to prioritize the usage of /etc/hosts over DNS queries.
# https://github.com/gliderlabs/docker-alpine/issues/367#issuecomment-354316460
RUN [ ! -e /etc/nsswitch.conf ] && echo 'hosts: files dns' > /etc/nsswitch.conf

RUN addgroup -S runner && adduser -S runner -G runner && chmod +x /usr/local/bin/terraform

USER runner

ENV GNUPGHOME=/tmp

ENTRYPOINT [ "/sbin/tini", "--", "tf-runner" ]
