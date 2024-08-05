#!/bin/bash

# used gsed for MacOS
if [[ "$(uname)" == "Darwin" ]]; then
  if ! command -v gsed &>/dev/null; then
      echo "gsed is not installed. Please install it using 'brew install gnu-sed'."
      exit 1
  fi
  sed_command="gsed"
else
  sed_command="sed"
fi


# Create a temporary directory to store extracted secrets
secrets=$(mktemp -d)

# Extract the pull secret from OpenShift configuration
oc extract secret/pull-secret -n openshift-config --to="${secrets}"

# Check if the brew registry is already included in the pull secret
if ! grep -q 'brew.registry.redhat.io' "${secrets}/.dockerconfigjson"; then
  echo "Adding brew pull secret..."

  # Update the pull secret with brew registry credentials
  ${sed_command} -i 's/^{"auths":{/{"auths":{"brew.registry.redhat.io":{"auth":"'$(cat ~/.ssh/.brew_token)'"},/' "${secrets}"/.dockerconfigjson

  # Update the pull secret in OpenShift configuration
  oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson="${secrets}/.dockerconfigjson"
fi

# Clean up temporary directory
rm -rf "${secrets}"
