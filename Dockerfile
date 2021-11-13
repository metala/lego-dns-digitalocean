FROM golang:1.17-alpine as builder

RUN apk add --no-cache git \
    && go get -v github.com/go-acme/lego/v4/cmd/lego@v4.5.3

# Runtime image
FROM alpine:3.14

ENV LEGO_DNS=cloudflare
ENV LEGO_DOMAIN=
ENV LEGO_EMAIL=
ENV DIGITALOCEAN_API_KEY=
ENV DIGITALOCEAN_ENDPOINT_ID=
ENV LOOP_INTERVAL=1h

RUN apk add --no-cache ca-certificates curl jq openssl
COPY --from=builder /go/bin/lego /bin/lego
COPY *.sh /app/
RUN mkdir -p /app/.lego && chmod 777 /app 

WORKDIR /app
VOLUME ["/app/.lego"]
ENTRYPOINT ["/app/main.sh"]
CMD []

