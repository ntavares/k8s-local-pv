
FROM centos:7

RUN yum -y update && \
    yum -y install epel-release lvm2 util-linux && \
    yum -y install python-pip && \
    pip install --upgrade pip && \
    ( rpm -qa | grep -q python-ipaddress && rpm -e --nodeps python-ipaddress || /bin/true ) && \
    pip install kubernetes && \
    yum clean all

COPY k8s-local-pv /k8s-local-pv
COPY static-pv-provisioner /root/static-pv-provisioner
