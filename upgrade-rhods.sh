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

wget https://rhods-devops.s3.amazonaws.com/IBM/WatsonX/latest_images
image=$(cat latest_images)
${sed_command} -i 's/image: */image: '$image'/g' config/catalogsource.yaml