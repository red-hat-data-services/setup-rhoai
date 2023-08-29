#!/bin/bash
export VERSION=1.2
podman build -t quay.io/modh/nightlies-upgrader:${VERSION} .
podman tag quay.io/modh/nightlies-upgrader:${VERSION} quay.io/modh/nightlies-upgrader:latest
podman push quay.io/modh/nightlies-upgrader:${VERSION}
podman push quay.io/modh/nightlies-upgrader:latest