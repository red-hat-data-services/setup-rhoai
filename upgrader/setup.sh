#!/bin/bash
oc new-project redhat-ods-operator || oc project redhat-ods-operator
oc apply -f k8s/upgrader-role.yaml
oc apply -f k8s/upgrader-sa.yaml
oc apply -f k8s/upgrader-rb.yaml
oc apply -f k8s/upgrader-cron.yaml
#oc edit cronjobs.batch -n redhat-ods-operator upgrader-cron