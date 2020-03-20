#!/bin/bash

HOSTNAME="one02"
HOSTIP="10.0.1.12"
SUBNET="10.0.1.0/24"
BASEPATH="/opt/ceph/ceph-deploy"
CLUSTER="ceph"

build_etc_config(){
    echo "[global]
    fsid = 24197500-02F4-AAAA-9FD5-00BD6F93E7EA
    mon initial members = ${HOSTNAME}
    mon host = ${HOSTIP}
    auth cluster required = none
    auth service required = none
    auth client required = none
    osd pool default size = 3
    osd pool default pg num = 128
    osd pool default pgp num = 128
    public_network = ${SUBNET}
    cluster_network = ${SUBNET}" > /etc/ceph/ceph.conf
}

build_osd_key(){
    echo "[client.bootstrap-osd]
        caps mon = \"profile bootstrap-osd\"" > /var/lib/ceph/bootstrap-osd/ceph.keyring
    chmod 0644 /var/lib/ceph/bootstrap-osd/ceph.keyring
}

build_mon_key(){
    echo "[mon.]
        caps mon = \"allow *\"
    [client.bootstrap-osd]
        caps mon = \"profile bootstrap-osd\"" > /tmp/ceph.mon.keyring
    chmod 0644 /tmp/ceph.mon.keyring
}

case $1 in
install)
    /usr/sbin/groupadd ceph -g 167 -o -r
    /usr/sbin/useradd ceph -u 167 -o -r -g ceph -s /sbin/nologin -c "Ceph daemons"
    mkdir -p /etc/ceph/
    mkdir -p /var/run/ceph
    mkdir -p /var/log/ceph
    mkdir -p /var/lib/ceph/mon
    mkdir -p /var/lib/ceph/osd
    mkdir -p /var/lib/ceph/bootstrap-osd
    chmod 0755 /var/lib/ceph/bootstrap-osd
    mkdir -p /var/lib/ceph/mgr/${CLUSTER}-${HOSTNAME}
    chmod 0755 /var/lib/ceph/mgr/${CLUSTER}-${HOSTNAME}

    build_etc_config
    build_osd_key
    build_mon_key

    monmaptool --create --fsid 24197500-02F4-AAAA-9FD5-00BD6F93E7EA --add  mon.${HOSTNAME} ${HOSTIP}:6789 /tmp/monmap
    ceph-mon --cluster ${CLUSTER} --mkfs -i ${HOSTNAME} --monmap /tmp/monmap --keyring /tmp/ceph.mon.keyring

    chown -R ceph:ceph /etc/ceph/
    chown -R ceph:ceph /var/run/ceph
    chown -R ceph:ceph /var/log/ceph
    chown -R ceph:ceph /var/lib/ceph

    systemctl start ceph-mon@${HOSTNAME}
    systemctl start ceph-mgr@${HOSTNAME}
    ;;
remove)
    virsh destroy test
    virsh undefine test
    systemctl stop ceph-osd.target
    systemctl stop ceph-mon.target
    systemctl stop ceph-mgr.target
    rm -f /tmp/ceph.mon.keyring
    rm -f /tmp/monmap
    rm -rf /etc/ceph/
    rm -rf /var/log/ceph/
    rm -rf /var/lib/ceph/
    rm -rf /var/run/ceph/
    ;;
clean)
    for x in {b..l}; do echo "zap  /dev/sd$x"; ceph-volume lvm zap --destroy /dev/sd$x;done
    ;;
create)
    for x in {b..l}; do echo "zap  /dev/sd$x"; ceph-volume lvm create --bluestore --data  /dev/sd$x;done
    ;;
image)
    ceph osd pool create image 64 64
    ceph osd pool create disk 512 512
    ceph osd pool application enable image rbd
    ceph osd pool application enable disk rbd
    qemu-img convert -f qcow2 -O raw ${BASEPATH}/image-centos-74.qcow2 rbd:image/image-centos-74
    rbd create disk/big-disk --size 1T
    virsh define ${BASEPATH}/test.xml
    virsh start test
    ;;
lvm)
   for x in {b..l}; do echo "zap  /dev/sd$x";  wipefs --all /dev/sd$x;parted -s /dev/sd$x mklabel gpt mkpart lvm 0% 100%; pvcreate /dev/sd${x}1; done
    ;;
*)
    echo "usage: ./install.sh [install|remove]"
    ;;
esac
