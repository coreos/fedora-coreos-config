FROM quay.io/coreos-assembler/fcos:testing-devel
ADD fcos-continuous.repo /etc/yum.repos.d
ADD overrides.yaml /etc/rpm-ostree/origin.d/overrides.yaml
RUN rpm-ostree ex rebuild
