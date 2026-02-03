#!/bin/sh

#scripts/./uninstall-rhoai.sh -t operator
konflux/./add_quay_pull_secret.sh
oc apply -f konflux/imagepolicy.yaml
oc apply -f konflux/catalogsource.yaml
