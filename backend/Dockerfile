# --- Build Stage ---
FROM golang:1.22-alpine AS builder

WORKDIR /app

# Copy dependency configs
COPY go.mod ./

# Fetch dependencies
RUN go mod download

# Copy source code
COPY . .

# Compile binary statically
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o server main.go

# --- Run Stage ---
FROM alpine:latest

WORKDIR /app

# Install root CA certificates for HTTPS OAuth requests
RUN apk --no-cache add ca-certificates tzdata

# Copy binary from build stage
COPY --from=builder /app/server .
COPY --from=builder /app/seeds/ir_brands.json ./seeds/

EXPOSE 8080

CMD ["./server"]
