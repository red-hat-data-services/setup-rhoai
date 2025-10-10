# Install OpenShift AI dev build using a quay FBC image
* Make sure you have the "oc" cli installed
* Make sure you are logged in to the cluster from the cli as an admin
* Uninstall Openshift AI completely if it is installed
* Store the quay token in a file at this location - ~/.ssh/.rhoai_quay_ro_token
* Update the required index image in konflux/catalogsource.yaml as the value of "spec.image" field
* Run setup_rhoai.sh
* Once it is green go to "Operator Hub" in the cluster console and search for Openshift-AI
* You should be able see an alternate Openshift-AI tile (other than the official one) with the versions from the custom FBC build we configured
