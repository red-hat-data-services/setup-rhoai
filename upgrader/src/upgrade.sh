#!/bin/bash
curl https://rhods-devops.s3.amazonaws.com/IBM/WatsonX/latest_images -o /tmp/latest_images
export LATEST_IMAGE=$(cat /tmp/latest_images)
sed -i "s,image: .*,image: ${LATEST_IMAGE},g" catalogsource.yaml
token=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
oc login --token=$token --server=https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT_HTTPS --certificate-authority=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
oc apply -f catalogsource.yaml