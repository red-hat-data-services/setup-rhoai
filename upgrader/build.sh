#!/bin/bash
export VERSION=1.2
export RUN_AS_USER=1001317986
#1001317986
sed -i "s,runAsUser: .*,runAsUser: ${RUN_AS_USER},g" k8s/upgrader-cron.yaml
sed -i "s,fsGroup: .*,fsGroup: ${RUN_AS_USER},g" k8s/upgrader-cron.yaml
cat k8s/upgrader-cron.yaml
podman build -t quay.io/modh/nightlies-upgrader:${VERSION} --build-arg RUN_AS_USER=${RUN_AS_USER} .
podman tag quay.io/modh/nightlies-upgrader:${VERSION} quay.io/modh/nightlies-upgrader:latest
podman push quay.io/modh/nightlies-upgrader:${VERSION}
podman push quay.io/modh/nightlies-upgrader:latest