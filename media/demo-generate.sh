#!/usr/bin/env bash
# docker run --rm -it -e UID=$(id -u) -v $PWD:/vhs --entrypoint=bash ghcr.io/charmbracelet/vhs media/demo-generate.sh
# ./media/demo-generate.sh
apt update -qq; apt install curl tar xz-utils figlet -y -qq --no-install-recommends
find ./media/ -name "*.gif" -delete
find ./media/ -name "*.mp4" -delete
find ./media/ -name "*.png" -delete
find ./media/ -name "*.webm" -delete
mkdir -p "${HOME}/.local/share/" media/screenshots media/videos
find "${HOME}/.local/share/fonts" -delete
mkdir -p media/screenshots/ media/videos/
vhs media/title.tape
vhs media/demo.tape
chown $UID ./media/ -R
