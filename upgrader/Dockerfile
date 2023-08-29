FROM fedora:38
ARG RUN_AS_USER=1001
RUN mkdir tools && curl https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable-4.6/openshift-client-linux.tar.gz -o tools/openshift-client-linux.tar.gz && \
    tar -xvf tools/openshift-client-linux.tar.gz -C tools/ && chmod +x tools/oc && mv tools/oc /usr/local/bin
COPY src /nightlies
WORKDIR /nightlies

RUN oc version && echo $RUN_AS_USER
RUN echo "chown $RUN_AS_USER /nightlies && chgrp $RUN_AS_USER /nightlies "
RUN chown -R $RUN_AS_USER:$RUN_AS_USER /nightlies
#  && chgrp $RUN_AS_USER /nightlies
USER ${RUN_AS_USER}
WORKDIR /nightlies
ENTRYPOINT ["/nightlies/upgrade.sh"]