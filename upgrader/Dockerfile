FROM fedora:38
RUN mkdir tools && curl https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable-4.6/openshift-client-linux.tar.gz -o tools/openshift-client-linux.tar.gz && \
    tar -xvf tools/openshift-client-linux.tar.gz -C tools/ && chmod +x tools/oc && mv tools/oc /usr/bin
COPY src /nightlies
WORKDIR /nightlies
RUN oc version
ENTRYPOINT ["/nightlies/upgrade.sh"]