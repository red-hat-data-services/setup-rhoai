#!/bin/bash

token=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
oc login --token=$token --server=https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT_HTTPS --certificate-authority=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
export LATEST_IMAGE=$(curl https://rhods-devops.s3.amazonaws.com/IBM/WatsonX/latest_images)
sed "s,image: .*,image: ${LATEST_IMAGE},g" catalogsource.yaml | oc apply -f -