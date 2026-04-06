FROM golang:1.26.1-alpine AS builder

WORKDIR /src

COPY app/go.mod app/go.sum ./
RUN go mod download

COPY app/ ./

ARG VCS_REF=dev

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build \
    -ldflags="-s -w -X github.com/stefanprodan/podinfo/pkg/version.REVISION=${VCS_REF}" \
    -a \
    -o /out/podinfo \
    ./cmd/podinfo/*

FROM alpine:3.23

RUN addgroup -S app && adduser -S app -G app && \
    apk add --no-cache ca-certificates tzdata

WORKDIR /app

COPY --from=builder /out/podinfo /app/podinfo

USER app

EXPOSE 9898

ENTRYPOINT ["/app/podinfo"]
CMD ["--port=9898", "--host=0.0.0.0", "--level=info"]
