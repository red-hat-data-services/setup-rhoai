#!/bin/sh

#scripts/./uninstall_ODH.sh
scripts/./add_brew_pull_secret.sh
oc apply -f config/imagepolicy.yaml
oc apply -f config/catalogsource.yaml