#!/bin/bash

oc create configmap delete-self-managed-odh -n redhat-ods-operator
oc label configmap/delete-self-managed-odh api.openshift.com/addon-managed-odh-delete=true -n redhat-ods-operator
oc delete -f catalogsource.yaml
oc delete namespace redhat-ods-operator
oc new-project redhat-ods-operator
