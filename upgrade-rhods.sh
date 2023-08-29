#!/bin/bash


wget https://rhods-devops.s3.amazonaws.com/IBM/WatsonX/latest_images
image=$(cat latest_images)
sed -i 's/image: */image: '$image'/g' config/catalogsource.yaml