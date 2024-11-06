secrets=$(mktemp -d)
oc extract secret/pull-secret -n openshift-config --to="${secrets}"
if ! grep 'quay.io/rhoai' < "${secrets}"/.dockerconfigjson
then
  echo adding quay pull secret
  sed -i 's/^{"auths":{/{"auths":{"quay.io\/rhoai":{"auth":"'$(cat ~/.ssh/.rhoai_quay_ro_token)'"},/' "${secrets}"/.dockerconfigjson
  oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson="${secrets}"/.dockerconfigjson
fi
#rm -rf "${secrets}"
