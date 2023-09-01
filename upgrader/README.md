# RHODS Nightlies Upgrader
1. Using this tool your OpenShift cluster will automatically upgrade to latest RHODS nightly
2. It fetches the details of latest nightly image from a public S3 location
3. It creates a k8s cronjob which runs once a day and update the cluster with latest nightly
4. RHODS team only needs to update the S3 object with latest image, rest all the upgrade will happen automatically
5. It's a scalable approach, it can be used to keep any number of clusters updated to the latest nightly
6. Avoids unnecessary efforts to manually update the cluster with latest nightly

# Setup Nightlies Upgrader
* Make sure you have openshift CLI
* Login to the cluster from CLI with admin credentials
* Clone the github repo and cd to the upgrader dir
* Give execute permission to setup.sh (chmod +x setup.sh)
* run setup.sh (./setup.sh)
* Done!!