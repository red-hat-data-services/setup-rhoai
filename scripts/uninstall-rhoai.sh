#!/usr/bin/env bash

set -euo pipefail

OPENSHIFT_MARKETPLACE_NAMESPACE="openshift-marketplace"
RHODS_OPERATOR_NAMESPACE="redhat-ods-operator"
RHODS_APPS_NAMESPACE="redhat-ods-applications"
RHODS_AUTH_PROVIDER_NAMESPACE="redhat-ods-applications-auth-provider"
RHODS_MONITORING_NAMESPACE="redhat-ods-monitoring"
RHODS_NOTEBOOKS_NAMESPACE="rhods-notebooks"

# Read script arguments from the CLI
function usage() {
  echo "Usage: $0 -t <operator|addon>" 1>&2;
  exit 1
}

while getopts ":t:i:" o; do
  case "${o}" in
    t)
      INSTALLATION_TYPE=${OPTARG}
      if [[ ! ${INSTALLATION_TYPE} =~ ^(operator|addon)$ ]]; then
        usage
      fi
      ;;
    *)
      usage
      ;;
  esac
done
shift $((OPTIND-1))

if [ -z "${INSTALLATION_TYPE-}" ]; then
  usage
fi

echo "Removing RHODS... Be patient..."

# Delete all the KfDef instances - the CRDs might not have been installed
oc delete kfdef --all -n ${RHODS_NOTEBOOKS_NAMESPACE} --ignore-not-found || true
oc delete kfdef --all -n ${RHODS_MONITORING_NAMESPACE} --ignore-not-found || true
oc delete kfdef --all -n ${RHODS_APPS_NAMESPACE} --ignore-not-found || true

# Delete the RHODS operator
oc delete -f ${INSTALLATION_TYPE} --ignore-not-found
# Delete the RHODS operator catalog source
if [ ${INSTALLATION_TYPE} != "addon" ]; then
    oc delete -f config/catalogsource.yaml -n ${OPENSHIFT_MARKETPLACE_NAMESPACE} --ignore-not-found
fi

# cleanup of v2 resources
oc delete AcceleratorProfile --all -A --ignore-not-found || true
oc get DataScienceCluster --all-namespaces -o custom-columns=:metadata.name --ignore-not-found | xargs -I {} oc patch DataScienceCluster {} --type=merge -p '{"metadata": {"finalizers":null}}' || true
oc delete DataScienceCluster --all -A --ignore-not-found || true
oc get DataSciencePipelinesApplication --all-namespaces -o custom-columns=:metadata.name,:metadata.namespace --ignore-not-found | xargs -n 2 sh -c 'name=$1; namespace=$2; oc patch DataSciencePipelinesApplication $name --type=merge -p "{\"metadata\": {\"finalizers\":null}}" --namespace $namespace' sh || true
oc delete DataSciencePipelinesApplication --all -A --ignore-not-found || true
oc get DSCInitialization --all-namespaces -o custom-columns=:metadata.name --ignore-not-found | xargs -I {} oc patch DSCInitialization {} --type=merge -p '{"metadata": {"finalizers":null}}' || true
oc delete DSCInitialization --all -A --ignore-not-found || true
oc delete FeatureTracker --all -A --ignore-not-found || true
oc delete OdhApplication --all -A --ignore-not-found || true
oc delete OdhDashboardConfig --all -A --ignore-not-found || true
oc delete OdhDocument --all -A --ignore-not-found || true
oc delete TrustyAIService --all -A --ignore-not-found || true

# Delete all the RHOAI CRDs
oc delete crd kfdefs.kfdef.apps.kubeflow.org --ignore-not-found
oc delete crd acceleratorprofiles.dashboard.opendatahub.io --ignore-not-found
oc delete crd datascienceclusters.datasciencecluster.opendatahub.io --ignore-not-found
oc delete crd datasciencepipelinesapplications.datasciencepipelinesapplications.opendatahub.io  --ignore-not-found
oc delete crd dscinitializations.dscinitialization.opendatahub.io  --ignore-not-found
oc delete crd featuretrackers.features.opendatahub.io  --ignore-not-found
oc delete crd modelregistries.modelregistry.opendatahub.io  --ignore-not-found
oc delete crd odhapplications.dashboard.opendatahub.io  --ignore-not-found
oc delete crd odhdashboardconfigs.opendatahub.io  --ignore-not-found
oc delete crd odhdocuments.dashboard.opendatahub.io  --ignore-not-found
oc delete crd trustyaiservices.trustyai.opendatahub.io --ignore-not-found
oc delete crd trustyaiservices.trustyai.opendatahub.io.trustyai.opendatahub.io --ignore-not-found
oc delete crd inferenceservices.serving.kserve.io --ignore-not-found
oc delete crd inferencegraphs.serving.kserve.io --ignore-not-found
oc delete crd servingruntimes.serving.kserve.io --ignore-not-found

# Delete all the CodeFlare CRDs
oc delete crd appwrappers.workload.codeflare.dev --ignore-not-found
oc delete crd quotasubtrees.quota.codeflare.dev --ignore-not-found
oc delete crd schedulingspecs.workload.codeflare.dev --ignore-not-found

# Delete all the Ray CRDs
oc delete crd rayclusters.ray.io --ignore-not-found
oc delete crd rayjobs.ray.io --ignore-not-found
oc delete crd rayservices.ray.io --ignore-not-found

# Delete all the Kueue CRDs
oc delete crd admissionchecks.kueue.x-k8s.io --ignore-not-found
oc delete crd clusterqueues.kueue.x-k8s.io --ignore-not-found
oc delete crd localqueues.kueue.x-k8s.io --ignore-not-found
oc delete crd multikueueclusters.kueue.x-k8s.io --ignore-not-found
oc delete crd multikueueconfigs.kueue.x-k8s.io --ignore-not-found
oc delete crd provisioningrequestconfigs.kueue.x-k8s.io --ignore-not-found
oc delete crd resourceflavors.kueue.x-k8s.io --ignore-not-found
oc delete crd workloadpriorityclasses.kueue.x-k8s.io --ignore-not-found
oc delete crd workloads.kueue.x-k8s.io --ignore-not-found

# Delete all CRDs created by data-science-pipelines-operator (Argo Workflows, Kubeflow Pipelines ScheduledWorkflows, ...)
oc delete crd -l app.kubernetes.io/part-of=data-science-pipelines-operator -l app.opendatahub.io/data-science-pipelines-operator=true --ignore-not-found

# Delete all the RHODS namespaces
oc delete namespace --force ${RHODS_NOTEBOOKS_NAMESPACE} ${RHODS_APPS_NAMESPACE} ${RHODS_AUTH_PROVIDER_NAMESPACE} ${RHODS_MONITORING_NAMESPACE} ${RHODS_OPERATOR_NAMESPACE} --ignore-not-found
