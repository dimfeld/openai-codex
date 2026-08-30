#!/bin/bash
set -euxo pipefail

VERSION_PART=${1}
TAG=rust-v0.${VERSION_PART}

jj git fetch --remote upstream -t "$TAG"
jj rebase -r current_base+::less-strict-rm-matching -d "$TAG@upstream" --ignore-immutable
jj b m current_base -t "$TAG@upstream" --allow-backwards

# There's usually a conflict in the version number in Cargo.toml
jj new current_base+
jj resolve codex-rs/Cargo.toml --tool=:ours || true

jj new less-strict-rm-matching
jj git push -b less-strict-rm-matching -b current_base

./build_fork.sh "$VERSION_PART"
