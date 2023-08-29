#!/bin/bash
oc delete -f k8s/upgrader-pod.yaml
oc delete -f k8s/upgrader-rb.yaml
oc delete -f k8s/upgrader-role.yaml
oc delete -f k8s/upgrader-sa.yaml
oc delete -f k8s/upgrader-cron.yaml