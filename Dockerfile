# ---------------------------------------------------------------------------
#  Build stage
#
#  Built with --features tls: managed MySQL providers (Aiven, Railway, PlanetScale)
#  require an encrypted connection, unlike a local server. That pulls in `ring`,
#  which compiles C, hence build-essential.
# ---------------------------------------------------------------------------
FROM rust:1-slim-bookworm AS builder

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Dependencies are built first, against a stub main.rs, so that this layer stays
# cached when only application code changes.
COPY Cargo.toml Cargo.lock ./
RUN mkdir src && echo 'fn main() {}' > src/main.rs \
    && cargo build --release --features tls \
    && rm -rf src

COPY src ./src
# Touch main.rs so cargo rebuilds the binary rather than reusing the stub.
RUN touch src/main.rs && cargo build --release --features tls

# ---------------------------------------------------------------------------
#  Runtime stage - just the binary on a slim base, no Rust toolchain.
# ---------------------------------------------------------------------------
FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --shell /usr/sbin/nologin appuser

COPY --from=builder /app/target/release/tasklist-api /usr/local/bin/tasklist-api

USER appuser
WORKDIR /home/appuser

# Platforms that inject PORT override this; it is the fallback for plain
# `docker run`. DATABASE_URL must always be supplied at runtime.
ENV SERVER_ADDR=0.0.0.0:8080
EXPOSE 8080

CMD ["tasklist-api"]
