#!/bin/bash
oc new-project redhat-ods-operator || oc project redhat-ods-operator
oc apply -f k8s/upgrader-role.yaml
oc apply -f k8s/upgrader-sa.yaml
oc apply -f k8s/upgrader-rb.yaml
oc apply -f k8s/upgrader-cron.yaml

#oc apply -f k8s/upgrader-pod.yaml
#oc exec --stdin -n redhat-ods-operator --tty upgrader -- /bin/bash
#oc delete pod -n redhat-ods-operator upgrader