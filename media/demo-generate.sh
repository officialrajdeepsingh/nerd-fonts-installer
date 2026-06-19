#!/usr/bin/env bash
# docker run --rm -it -v $PWD:/vhs --entrypoint=bash ghcr.io/charmbracelet/vhs
# ./media/demo-generate.sh
apt update -qq; apt install curl tar xz-utils -y -qq --no-install-recommends
mkdir -p "${HOME}/.local/share/"
find "${HOME}/.local/share/fonts" -delete
vhs media/demo.tape
