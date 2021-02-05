FROM golang:1.15-alpine as builder

ARG REVISION

RUN mkdir -p /poginfo/

WORKDIR /poginfo

COPY . .

RUN go mod download

RUN CGO_ENABLED=0 go build -ldflags "-s -w \
    -X github.com/jojomomojo/poginfo/pkg/version.REVISION=${REVISION}" \
    -a -o bin/poginfo cmd/poginfo/*

RUN CGO_ENABLED=0 go build -ldflags "-s -w \
    -X github.com/jojomomojo/poginfo/pkg/version.REVISION=${REVISION}" \
    -a -o bin/podcli cmd/podcli/*

FROM alpine:3.12

ARG BUILD_DATE
ARG VERSION
ARG REVISION

LABEL maintainer="jojomomojo"

RUN addgroup -S app \
    && adduser -S -G app app \
    && apk --no-cache add \
    ca-certificates curl netcat-openbsd

WORKDIR /home/app

COPY --from=builder /poginfo/bin/poginfo .
COPY --from=builder /poginfo/bin/podcli /usr/local/bin/podcli
COPY ./ui ./ui
RUN chown -R app:app ./

USER app

CMD ["./poginfo"]
