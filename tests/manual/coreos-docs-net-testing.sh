#!/usr/bin/bash
set -eu -o pipefail

# This script attempts to test the configurations in our documentation
# at https://docs.fedoraproject.org/en-US/fedora-coreos/sysconfig-network-configuration/.
# All it does is test the various documented scenarios via both the
# dracut kernel networking arguments approach, as well as the NM
# keyfiles provided via Ignition approach. The verification of the
# configurations is manual. You will be given a bash prompt and you
# can run commands to verify it matches what would be expected. The
# hostname in each scenario will give you a clue as to what you should
# be inspecting for.
#
# You can modify the "loopitems" array right before the for loops to
# comment out and only run certain tests. You can also comment out
# one of the for loops entirely to only run kargs or Ignition tests.
#
# Note that the DHCP vlan test will require that the NIC is attached
# to a network where DHCP is being served on that tagged network. When
# I test this way I usually stand up a separate VM on the same bridge
# and run dnsmasq on a tagged network like:
#
#     interface=eth1
#     cat <<EOF > /etc/dnsmasq.d/vlandhcp
#     interface=${interface}.100
#     bind-interfaces
#     dhcp-range=192.168.200.150,192.168.200.160,12h
#     EOF
#     ip link add link $interface name "${interface}.100" type vlan id 100
#     ip addr add 192.168.200.1/24 dev "${interface}.100"
#     ip link set "${interface}.100" up
#     systemctl enable dnsmasq --now
#
# - Dusty Mabe - dusty@dustymabe.com

vmname="coreos-docs-nettest"

butane_common=\
'variant: fcos
version: 1.0.0
passwd:
  users:
    - name: core
      ssh_authorized_keys:
        - $sshpubkey
systemd:
  units:
    - name: serial-getty@ttyS0.service
      dropins:
      - name: autologin-core.conf
        contents: |
          [Service]
          # Override Execstart in main unit
          ExecStart=
          # Add new Execstart with `-` prefix to ignore failure
          ExecStart=-/usr/sbin/agetty --autologin core --noclear %I $TERM
          TTYVTDisallocate=no
storage:
  files:
    - path: /etc/sysctl.d/20-silence-audit.conf
      contents:
        inline: |
          # Raise console message logging level from DEBUG (7) to WARNING (4)
          kernel.printk=4'

butane_hostname='
    - path: /etc/hostname
      mode: 0644
      contents:
        inline: |
          ${hostname}'

butane_disable_subnic2='
    - path: /etc/NetworkManager/system-connections/${subnic2}.nmconnection
      mode: 0600
      contents:
        inline: |
          [connection]
          id=${subnic2}
          type=ethernet
          interface-name=${subnic2}
          [ipv4]
          method=disabled
          [ipv6]
          method=disabled'

butane_staticip='
    - path: /etc/NetworkManager/system-connections/${interface}.nmconnection
      mode: 0600
      contents:
        inline: |
          [connection]
          id=${interface}
          type=ethernet
          interface-name=${interface}
          [ipv4]
          address1=${ip}/${prefix},${gateway}
          dhcp-hostname=${hostname}
          dns=${nameserver};
          dns-search=
          may-fail=false
          method=manual'

butane_staticbond='
    - path: /etc/NetworkManager/system-connections/${bondname}.nmconnection
      mode: 0600
      contents:
        inline: |
          [connection]
          id=${bondname}
          type=bond
          interface-name=${bondname}
          [bond]
          miimon=100
          mode=active-backup
          [ipv4]
          address1=${ip}/${prefix},${gateway}
          dhcp-hostname=${hostname}
          dns=${nameserver};
          dns-search=
          may-fail=false
          method=manual
    - path: /etc/NetworkManager/system-connections/${bondname}-slave-${subnic1}.nmconnection
      mode: 0600
      contents:
        inline: |
          [connection]
          id=${bondname}-slave-${subnic1}
          type=ethernet
          interface-name=${subnic1}
          master=${bondname}
          slave-type=bond
    - path: /etc/NetworkManager/system-connections/${bondname}-slave-${subnic2}.nmconnection
      mode: 0600
      contents:
        inline: |
          [connection]
          id=${bondname}-slave-${subnic2}
          type=ethernet
          interface-name=${subnic2}
          master=${bondname}
          slave-type=bond'

butane_dhcpbridge='
    - path: /etc/NetworkManager/system-connections/${bridgename}.nmconnection
      mode: 0600
      contents:
        inline: |
          [connection]
          id=${bridgename}
          type=bridge
          interface-name=${bridgename}
          [bridge]
          [ipv4]
          dns-search=
          may-fail=false
          method=auto
    - path: /etc/NetworkManager/system-connections/${bridgename}-slave-${subnic1}.nmconnection
      mode: 0600
      contents:
        inline: |
          [connection]
          id=${bridgename}-slave-${subnic1}
          type=ethernet
          interface-name=${subnic1}
          master=${bridgename}
          slave-type=bridge
          [bridge-port]
    - path: /etc/NetworkManager/system-connections/${bridgename}-slave-${subnic2}.nmconnection
      mode: 0600
      contents:
        inline: |
          [connection]
          id=${bridgename}-slave-${subnic2}
          type=ethernet
          interface-name=${subnic2}
          master=${bridgename}
          slave-type=bridge
          [bridge-port]'

butane_dhcpteam='
    - path: /etc/NetworkManager/system-connections/${teamname}.nmconnection
      mode: 0600
      contents:
        inline: |
          [connection]
          id=${teamname}
          type=team
          interface-name=${teamname}
          [team]
          config={"runner": {"name": "activebackup"}, "link_watch": {"name": "ethtool"}}
          [ipv4]
          dns-search=
          may-fail=false
          method=auto
    - path: /etc/NetworkManager/system-connections/${teamname}-slave-${subnic1}.nmconnection
      mode: 0600
      contents:
        inline: |
          [connection]
          id=${teamname}-slave-${subnic1}
          type=ethernet
          interface-name=${subnic1}
          master=${teamname}
          slave-type=team
          [team-port]
          config={"prio": 100}
    - path: /etc/NetworkManager/system-connections/${teamname}-slave-${subnic2}.nmconnection
      mode: 0600
      contents:
        inline: |
          [connection]
          id=${teamname}-slave-${subnic2}
          type=ethernet
          interface-name=${subnic2}
          master=${teamname}
          slave-type=team
          [team-port]
          config={"prio": 100}'

butane_staticvlan='
    - path: /etc/NetworkManager/system-connections/${interface}.${vlanid}.nmconnection
      mode: 0600
      contents:
        inline: |
          [connection]
          id=${interface}.${vlanid}
          type=vlan
          interface-name=${interface}.${vlanid}
          [vlan]
          egress-priority-map=
          flags=1
          id=${vlanid}
          ingress-priority-map=
          parent=${interface}
          [ipv4]
          address1=${ip}/${prefix},${gateway}
          dhcp-hostname=${hostname}
          dns=${nameserver};
          dns-search=
          may-fail=false
          method=manual
    - path: /etc/NetworkManager/system-connections/${interface}.nmconnection
      mode: 0600
      contents:
        inline: |
          [connection]
          id=${interface}
          type=ethernet
          interface-name=${interface}
          [ipv4]
          dns-search=
          method=disabled
          [ipv6]
          addr-gen-mode=eui64
          dns-search=
          method=disabled'

butane_dhcpvlanbond='
    - path: /etc/NetworkManager/system-connections/${bondname}.${vlanid}.nmconnection
      mode: 0600
      contents:
        inline: |
          [connection]
          id=${bondname}.${vlanid}
          type=vlan
          interface-name=${bondname}.${vlanid}
          [vlan]
          egress-priority-map=
          flags=1
          id=${vlanid}
          ingress-priority-map=
          parent=${bondname}
          [ipv4]
          dns-search=
          may-fail=false
          method=auto
    - path: /etc/NetworkManager/system-connections/${bondname}.nmconnection
      mode: 0600
      contents:
        inline: |
          [connection]
          id=${bondname}
          type=bond
          interface-name=${bondname}
          [bond]
          miimon=100
          mode=active-backup
          [ipv4]
          method=disabled
          [ipv6]
          method=disabled
    - path: /etc/NetworkManager/system-connections/${bondname}-slave-${subnic1}.nmconnection
      mode: 0600
      contents:
        inline: |
          [connection]
          id=${bondname}-slave-${subnic1}
          type=ethernet
          interface-name=${subnic1}
          master=${bondname}
          slave-type=bond
    - path: /etc/NetworkManager/system-connections/${bondname}-slave-${subnic2}.nmconnection
      mode: 0600
      contents:
        inline: |
          [connection]
          id=${bondname}-slave-${subnic2}
          type=ethernet
          interface-name=${subnic2}
          master=${bondname}
          slave-type=bond'

check_requirement() {
    req=$1
    if ! which $req &>/dev/null; then
        echo "No $req. Can't continue" 1>&2
        return 1
    fi
}

check_requirements() {
    reqs=(
        chcon
        envsubst
        butane
        jq
        ssh
        ssh-keygen
        virsh
        virt-cat
        virt-install
        virt-ls
    )
    for req in ${reqs[@]}; do
        check_requirement $req
    done
}

start_vm() {
    echo "Starting domain: $vmname"
    local disk=$1; shift
    local ignitionfile=$1; shift
    local kernel=$1; shift
    local initramfs=$1; shift
    local kernel_args=$@
    virt-install --name $vmname --ram 3096 --vcpus 2 --graphics=none \
                   --quiet --network bridge=virbr0 --network bridge=virbr0 \
                   --disk size=20,backing_store=${disk} \
                   --install kernel=${kernel},initrd=${initramfs},kernel_args_overwrite=yes,kernel_args="${kernel_args}" \
                   --qemu-commandline="-fw_cfg name=opt/com.coreos/config,file=$ignitionfile"
}

destroy_vm() {
    echo "Destroying domain: $vmname"
    # If the domain doesn't exist then return
    virsh dominfo $vmname &>/dev/null || return 0
    # Destroy domain and recover storage
    virsh destroy $vmname 1>/dev/null
    virsh undefine --nvram --remove-all-storage $vmname 1>/dev/null
}

create_ignition_file() {
    local butaneconfig=$1
    local ignitionfile=$2
    # uncomment and use ign-converter instead if on rhcos less than 4.6
    #echo "$butaneconfig" | butane --strict | ign-converter -downtranslate -output $ignitionfile
    echo "$butaneconfig" | butane --strict --output $ignitionfile
    chcon --verbose unconfined_u:object_r:svirt_home_t:s0 $ignitionfile &>/dev/null
}

main() {
    qcow=$1
    local ip='10.10.10.10'
    local gateway='10.10.10.1'
    local netmask='255.255.255.0'
    local prefix='24'
    local hostname='myhostname'
    local interface='ens2'
    local nameserver='8.8.8.8'
    local bondname='bond0'
    local teamname='team0'
    local bridgename='br0'
    local subnic1='ens2'
    local subnic2='ens3'
    local vlanid='100'

    local kernel="${PWD}/coreos-nettest-kernel"
    local initramfs="${PWD}/coreos-nettest-initramfs"
    local sshkeyfile="${PWD}/coreos-nettest-sshkey"
    local sshpubkeyfile="${PWD}/coreos-nettest-sshkey.pub"
    local ignitionfile="${PWD}/coreos-nettest-config.ign"
    local sshpubkey
    local butane
     
    check_requirements

    # Find out which partition is the boot partition
    partition=$(guestfish --ro -a $qcow <<EOF
    run
    findfs-label boot
    exit
EOF
    )

    # Grab kernel/initramfs from the disk
    files=$(virt-ls -a $qcow -m $partition -R /ostree/)
    for f in $files; do
        if [[ "${f}" =~ hmac$ ]]; then
            # ignore .vmlinuz-5.5.9-200.fc31.x86_64.hmac
            true
        elif [[ "${f}" =~ img$ ]]; then
            # grab initramfs in the form initramfs-5.5.9-200.fc31.x86_64.img
            virt-cat -a $qcow -m $partition "/ostree/${f}" > $initramfs
        elif [[ "${f}" =~ '/vmlinuz' ]]; then
            # grab kernel in the form vmlinuz-5.5.9-200.fc31.x86_64
            virt-cat -a $qcow -m $partition "/ostree/${f}" > $kernel
        fi
    done

    # Dumb detection of if this is RHCOS or FCOS and setting variables
    # accordingly
    if [[ $qcow =~ 'rhcos' ]]; then
        rhcos=1
        nic0=ens2
        nic1=ens3
        bls_file=ostree-1-rhcos.conf
    else
        rhcos=0
        nic0=ens2
        nic1=ens3
        bls_file=ostree-1-fedora-coreos.conf
    fi

    # Grab kernel arguments from the disk and use them
    # - strip `options ` from the front of the line
    # - strip `$ignition_firstboot`
    common_args=$(virt-cat -a $qcow -m $partition "/loader.1/entries/${bls_file}" | \
                  grep -P '^options' | \
                  sed -e 's/options //' | \
                  sed -e 's/$ignition_firstboot//')
    common_args+=' ignition.firstboot' # manually set ignition.firstboot
   #common_args+=' rd.break=pre-mount'

    # export these values so we can substitute the values
    # in using the envsubst command
    export ip gateway netmask prefix interface nameserver bondname teamname bridgename subnic1 subnic2 vlanid

    butane_none=$(echo "${butane_common}" | envsubst)

    export hostname="staticip"
    x="${common_args} rd.neednet=1"
    x+=" ip=${ip}::${gateway}:${netmask}:${hostname}:${interface}:none:${nameserver}"
    x+=" ip=${subnic2}:off"
    initramfs_staticip=$x
    butane_initramfs_staticip="${butane_none}"
    butane_staticip=$(echo "${butane_common}${butane_hostname}${butane_staticip}${butane_disable_subnic2}" | envsubst)

    export hostname="staticbond"
    x="${common_args} rd.neednet=1"
    x+=" ip=${ip}::${gateway}:${netmask}:${hostname}:${bondname}:none:${nameserver}"
    x+=" bond=${bondname}:${subnic1},${subnic2}:mode=active-backup,miimon=100"
    initramfs_staticbond=$x
    butane_initramfs_staticbond="${butane_none}"
    butane_staticbond=$(echo "${butane_common}${butane_hostname}${butane_staticbond}" | envsubst)

    export hostname="dhcpbridge"
    x="${common_args} rd.neednet=1"
    x+=" ip=${bridgename}:dhcp"
    x+=" bridge=${bridgename}:${subnic1},${subnic2}"
    x+=" nameserver=${nameserver}"
    initramfs_dhcpbridge=$x
    butane_initramfs_dhcpbridge=$(echo "${butane_common}${butane_hostname}" | envsubst)
    butane_dhcpbridge=$(echo "${butane_common}${butane_hostname}${butane_dhcpbridge}" | envsubst)

    export hostname="dhcpteam"
    x="${common_args} rd.neednet=1"
    x+=" ip=${teamname}:dhcp"
    x+=" team=${teamname}:${subnic1},${subnic2}"
    x+=" nameserver=${nameserver}"
    initramfs_dhcpteam=$x
    butane_initramfs_dhcpteam=$(echo "${butane_common}${butane_hostname}" | envsubst)
    butane_dhcpteam=$(echo "${butane_common}${butane_hostname}${butane_dhcpteam}" | envsubst)

    export hostname="staticvlan"
    x="${common_args} rd.neednet=1"
    x+=" ip=${ip}::${gateway}:${netmask}:${hostname}:${interface}.${vlanid}:none:${nameserver}"
    x+=" vlan=${interface}.${vlanid}:${interface}"
    x+=" ip=${subnic2}:off"
    initramfs_staticvlan=$x
    butane_initramfs_staticvlan="${butane_none}"
    butane_staticvlan=$(echo "${butane_common}${butane_hostname}${butane_staticvlan}${butane_disable_subnic2}" | envsubst)

    export hostname="dhcpvlanbond"
    x="${common_args} rd.neednet=1"
    x+=" ip=${bondname}.${vlanid}:dhcp"
    x+=" bond=${bondname}:${subnic1},${subnic2}:mode=active-backup,miimon=100"
    x+=" vlan=${bondname}.${vlanid}:${bondname}"
    initramfs_dhcpvlanbond=$x
    butane_initramfs_dhcpvlanbond=$(echo "${butane_common}${butane_hostname}" | envsubst)
    butane_dhcpvlanbond=$(echo "${butane_common}${butane_hostname}${butane_dhcpvlanbond}" | envsubst)

    destroy_vm || true

    loopitems=(
        staticip
        staticbond
        dhcpbridge
        dhcpteam
        staticvlan
       #dhcpvlanbond  # Requires special setup, see top of file comment
    )

    create_ignition_file "$butane_none" $ignitionfile
    for net in ${loopitems[@]}; do
        var="initramfs_${net}"
        kernel_args=${!var}
        var="butane_initramfs_${net}"
        butaneconfig=${!var}
        create_ignition_file "$butaneconfig" $ignitionfile
        start_vm $qcow $ignitionfile $kernel $initramfs "${kernel_args}"
        destroy_vm
    done

    for net in ${loopitems[@]}; do
        var="butane_${net}"
        butaneconfig=${!var}
        kernel_args=${common_args}
        create_ignition_file "$butaneconfig" $ignitionfile
        start_vm $qcow $ignitionfile $kernel $initramfs "${kernel_args}"
        destroy_vm
    done

    # clean up temporary files
    for file in $kernel $initramfs $sshkeyfile $sshpubkeyfile $ignitionfile; do
        rm -f $file
    done

}


main $@

