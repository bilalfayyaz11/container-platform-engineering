# syntax=docker/dockerfile:1.12

FROM golang:1.24-alpine AS dependencies

WORKDIR /src

COPY go.mod ./

RUN --mount=type=cache,id=go-module-cache,target=/go/pkg/mod,sharing=locked \
    go mod download

FROM dependencies AS validation

COPY main.go main_test.go ./

RUN --mount=type=cache,id=go-module-cache,target=/go/pkg/mod,sharing=locked \
    --mount=type=cache,id=go-build-cache,target=/root/.cache/go-build,sharing=locked \
    go test ./...

FROM validation AS builder

RUN --mount=type=cache,id=go-module-cache,target=/go/pkg/mod,sharing=locked \
    --mount=type=cache,id=go-build-cache,target=/root/.cache/go-build,sharing=locked \
    CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64 \
    go build \
      -trimpath \
      -ldflags="-s -w" \
      -o /out/service \
      .

FROM scratch AS runtime

COPY --from=builder /out/service /service

USER 65532:65532

EXPOSE 8080

ENTRYPOINT ["/service"]
