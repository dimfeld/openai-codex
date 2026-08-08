#!/bin/bash
set -euxo pipefail


VERSION_PART=${1:-}
RUSTY_V8_VERSION=${RUSTY_V8_VERSION:-150.4.0}

if [[ ! "$RUSTY_V8_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "RUSTY_V8_VERSION must be a semantic version, got: $RUSTY_V8_VERSION" >&2
    exit 1
fi

case "$(uname -s):$(uname -m)" in
    Darwin:arm64|Darwin:aarch64)
        RUSTY_V8_TARGET=aarch64-apple-darwin
        ;;
    Darwin:x86_64)
        RUSTY_V8_TARGET=x86_64-apple-darwin
        ;;
    Linux:x86_64)
        RUSTY_V8_TARGET=x86_64-unknown-linux-gnu
        ;;
    *)
        echo "Unsupported host platform: $(uname -s) $(uname -m)" >&2
        exit 1
        ;;
esac

RUSTY_V8_RELEASE_TAG=rusty-v8-v${RUSTY_V8_VERSION}
RUSTY_V8_BASE_URL=https://github.com/openai/codex/releases/download/${RUSTY_V8_RELEASE_TAG}
RUSTY_V8_ARTIFACT_DIR=${TMPDIR:-/tmp}/codex-rusty-v8-${RUSTY_V8_VERSION}-${RUSTY_V8_TARGET}
RUSTY_V8_ARCHIVE_NAME=librusty_v8_ptrcomp_sandbox_release_${RUSTY_V8_TARGET}.a.gz
RUSTY_V8_BINDING_NAME=src_binding_ptrcomp_sandbox_release_${RUSTY_V8_TARGET}.rs
RUSTY_V8_CHECKSUM_NAME=rusty_v8_ptrcomp_sandbox_release_${RUSTY_V8_TARGET}.sha256

mkdir -p "$RUSTY_V8_ARTIFACT_DIR"
curl -fsSL "$RUSTY_V8_BASE_URL/$RUSTY_V8_ARCHIVE_NAME" \
    -o "$RUSTY_V8_ARTIFACT_DIR/$RUSTY_V8_ARCHIVE_NAME"
curl -fsSL "$RUSTY_V8_BASE_URL/$RUSTY_V8_BINDING_NAME" \
    -o "$RUSTY_V8_ARTIFACT_DIR/$RUSTY_V8_BINDING_NAME"
curl -fsSL "$RUSTY_V8_BASE_URL/$RUSTY_V8_CHECKSUM_NAME" \
    -o "$RUSTY_V8_ARTIFACT_DIR/$RUSTY_V8_CHECKSUM_NAME"

if command -v sha256sum >/dev/null 2>&1; then
    (cd "$RUSTY_V8_ARTIFACT_DIR" && sha256sum -c "$RUSTY_V8_CHECKSUM_NAME")
else
    (cd "$RUSTY_V8_ARTIFACT_DIR" && shasum -a 256 -c "$RUSTY_V8_CHECKSUM_NAME")
fi

export RUSTY_V8_ARCHIVE="$RUSTY_V8_ARTIFACT_DIR/$RUSTY_V8_ARCHIVE_NAME"
export RUSTY_V8_SRC_BINDING_PATH="$RUSTY_V8_ARTIFACT_DIR/$RUSTY_V8_BINDING_NAME"

if [[ "$VERSION_PART" =~ ^[0-9.]+$ ]]; then
    sed -i.bak -E "s/^version = \"0\\.[0-9]+\\.0\"$/version = \"0.${VERSION_PART}\"/" codex-rs/Cargo.toml
    rm -f codex-rs/Cargo.toml.bak
fi


cd codex-rs/cli
cargo install --locked --path .
cd ../code-mode-host
cargo install --locked --path .
if [[ "$(uname -s)" == "Linux" ]]; then
    cd ../linux-sandbox
    cargo install --locked --path .
fi
# Restore Cargo.lock so that next update wont cause a conflict
jj restore ../Cargo.lock ../Cargo.toml
