#!/bin/bash

export NAMESPACE=$1
oc get namespace ${NAMESPACE} -o json > tmp.json
jq '.spec.finalizers = []' tmp.json > tmp && mv tmp tmp.json
curl -k -H "Content-Type: application/json" -X PUT --data-binary @tmp.json http://127.0.0.1:8001/api/v1/namespaces/${NAMESPACE}/finalize
