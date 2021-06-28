#!/usr/bin/bash
set -eu -o pipefail
#set -x

# This script attempts to test networking configuration in various
# scenarios/configurations. It tries to test what should happen
# when initramfs networking is passed and/or networking config is
# passed via Ignition. It also tries to make sure that initramfs
# configured network is passed properly to the real root when it
# should be and not when it shouldn't be. See the following issue
# for more details: https://github.com/coreos/fedora-coreos-tracker/issues/394
# - Dusty Mabe - dusty@dustymabe.com

vmname="coreos-nettest"

fcct_common=\
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
    # pulling from a remote verifies we have networking in the initramfs
    - path: /home/core/remotefile
      mode: 0600
      user:
        name: core
      group:
        name: core
      contents:
        source: https://raw.githubusercontent.com/coreos/fedora-coreos-config/8b08bd030ef3968d00d4fea9a0fa3ca3fbabf852/COPYING
        verification:
          hash: sha512-d904690e4fc5defb804c2151e397cbe2aeeea821639995610aa377bb2446214c3433616a8708163776941df585b657648f20955e50d4b011ea2a96e7d8e08c66'

ignitionhostname='ignitionhost'
fcct_hostname='
    - path: /etc/hostname
      mode: 0644
      contents:
        inline: |
          ${ignitionhostname}'

fcct_static_nic0_ifcfg='
    - path: /etc/sysconfig/network-scripts/ifcfg-${nic0}
      mode: 0600
      contents:
        inline: |
          TYPE=Ethernet
          BOOTPROTO=none
          IPADDR=${ip}
          PREFIX=${prefix}
          GATEWAY=${gateway}
          DEFROUTE=yes
          IPV4_FAILURE_FATAL=no
          NAME=ethernet-${nic0}
          DEVICE=${nic0}
          ONBOOT=yes
          DNS1=${nameserverstatic}
    - path: /etc/sysconfig/network-scripts/ifcfg-${nic1}
      mode: 0600
      contents:
        inline: |
          TYPE=Ethernet
          BOOTPROTO=none
          NAME=ethernet-${nic1}
          DEVICE=${nic1}
          ONBOOT=no'

fcct_static_nic0='
    - path: /etc/NetworkManager/system-connections/${nic0}.nmconnection
      mode: 0600
      contents:
        inline: |
          [connection]
          id=${nic0}
          type=ethernet
          interface-name=${nic0}
          [ipv4]
          address1=${ip}/${prefix},${gateway}
          dns=${nameserverstatic};
          dns-search=
          may-fail=false
          method=manual
          [ipv6]
          method=disabled
    - path: /etc/NetworkManager/system-connections/${nic1}.nmconnection
      mode: 0600
      contents:
        inline: |
          [connection]
          id=${nic1}
          type=ethernet
          interface-name=${nic1}
          [ipv4]
          method=disabled
          [ipv6]
          method=disabled'

fcct_static_team0='
    - path: /etc/NetworkManager/system-connections/team0.nmconnection
      mode: 0600
      contents:
        inline: |
          [connection]
          id=team0
          type=team
          interface-name=team0
          [team]
          config={"runner": {"name": "activebackup"}, "link_watch": {"name": "ethtool"}}
          [ipv4]
          address1=${ip}/${prefix},${gateway}
          dns=${nameserverstatic};
          dns-search=
          may-fail=false
          method=manual
    - path: /etc/NetworkManager/system-connections/team0-slave-${nic0}.nmconnection
      mode: 0600
      contents:
        inline: |
          [connection]
          id=team0-slave-${nic0}
          type=ethernet
          interface-name=${nic0}
          master=team0
          slave-type=team
          [team-port]
          config={"prio": 100}
    - path: /etc/NetworkManager/system-connections/team0-slave-${nic1}.nmconnection
      mode: 0600
      contents:
        inline: |
          [connection]
          id=team0-slave-${nic1}
          type=ethernet
          interface-name=${nic1}
          master=team0
          slave-type=team
          [team-port]
          config={"prio": 100}'

fcct_static_bond0='
    - path: /etc/NetworkManager/system-connections/bond0.nmconnection
      mode: 0600
      contents:
        inline: |
          [connection]
          id=bond0
          type=bond
          interface-name=bond0
          [bond]
          miimon=100
          mode=active-backup
          [ipv4]
          address1=${ip}/${prefix},${gateway}
          dns=${nameserverstatic};
          dns-search=
          may-fail=false
          method=manual
    - path: /etc/NetworkManager/system-connections/bond0-slave-${nic0}.nmconnection
      mode: 0600
      contents:
        inline: |
          [connection]
          id=bond0-slave-${nic0}
          type=ethernet
          interface-name=${nic0}
          master=bond0
          slave-type=bond
    - path: /etc/NetworkManager/system-connections/bond0-slave-${nic1}.nmconnection
      mode: 0600
      contents:
        inline: |
          [connection]
          id=bond0-slave-${nic1}
          type=ethernet
          interface-name=${nic1}
          master=bond0
          slave-type=bond'

fcct_static_br0='
    - path: /etc/NetworkManager/system-connections/br0.nmconnection
      mode: 0600
      contents:
        inline: |
          [connection]
          id=br0
          type=bridge
          interface-name=br0
          [bridge]
          [ipv4]
          address1=${ip}/${prefix},${gateway}
          dns=${nameserverstatic};
          dns-search=
          may-fail=false
          method=manual
    - path: /etc/NetworkManager/system-connections/br0-slave-${nic0}.nmconnection
      mode: 0600
      contents:
        inline: |
          [connection]
          id=br0-slave-${nic0}
          type=ethernet
          interface-name=${nic0}
          master=br0
          slave-type=bridge
          [bridge-port]
    - path: /etc/NetworkManager/system-connections/br0-slave-${nic1}.nmconnection
      mode: 0600
      contents:
        inline: |
          [connection]
          id=br0-slave-${nic1}
          type=ethernet
          interface-name=${nic1}
          master=br0
          slave-type=bridge
          [bridge-port]'

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
        fcct
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
    virt-install --name $vmname --ram 3096 --vcpus 2 --graphics=none --noautoconsole \
                   --quiet --network bridge=virbr0 --network bridge=virbr0 \
                   --disk size=20,backing_store=${disk} \
                   --install kernel=${kernel},initrd=${initramfs},kernel_args_overwrite=yes,kernel_args="${kernel_args}" \
                   --qemu-commandline="-fw_cfg name=opt/com.coreos/config,file=$ignitionfile"
}

check_vm() {
    local dhcp=$1
    local interfaces=$2
    local numkeyfiles=$3
    local ip=$4
    local dev=$5
    local hostname=$6
    local nameserver=$7
    local sshkeyfile=$8
    local ssh_config=' -o CheckHostIP=no'
    ssh_config+=' -o UserKnownHostsFile=/dev/null'
    ssh_config+=' -o StrictHostKeyChecking=no'
    ssh_config+=" -i $sshkeyfile"

    if [ $dhcp == 'dhcp' ]; then
        macinfo=$(virsh dumpxml $vmname | grep 'mac address' | head -n 1)
        macregex='(..:..:..:..:..:..)'
        if ! [[ $macinfo =~ $macregex ]]; then
            echo -e "\nCould not detect MAC in $macinfo" 2>&1
            return 1
        fi
        mac="${BASH_REMATCH[1]}"
        echo "Using DHCP.. Detected MAC address is ${mac}"
        echo "Waiting a bit to give networking some time"
        sleep 30 # wait a long enough time for real root networking to be brought up
        ip=$(ip -j neighbor show dev virbr0 | jq -r ".[] | select(.lladdr == \"${mac}\").dst")
        echo "Detected IP address is '${ip}'"
        if [ -z "$ip" ]; then
            echo -e "\nCould not detect DHCP ipv4 address" 2>&1
            return 1
        fi
    fi

    export SSH_AUTH_SOCK=  # since we're providing our own key
    local ssh="ssh -q $ssh_config -l core $ip"

    # Wait for system to come up
    try=10

    echo 'waiting on ssh connection to come up'
    while true; do
        $ssh /usr/bin/true && echo && break
        echo -n '.'
        sleep 5
        ((try--))
        if [ $try -eq 0 ]; then
            echo -e "\nTimeout while trying to reach $ip" 2>&1
            return 1
        fi
    done
    # The output gives us something like:
    #
    #   ip -j -4 -o address show up | jq .
    #   [
    #     {
    #       "addr_info": [
    #         {
    #           "index": 1,
    #           "dev": "lo",
    #           "family": "inet",
    #           "local": "127.0.0.1",
    #           "prefixlen": 8,
    #           "scope": "host",
    #           "label": "lo",
    #           "valid_life_time": 4294967295,
    #           "preferred_life_time": 4294967295
    #         }
    #       ]
    #     },
    #     {
    #       "addr_info": [
    #         {
    #           "index": 5,
    #           "dev": "bond0",
    #           "family": "inet",
    #           "local": "192.168.122.111",
    #           "prefixlen": 24,
    #           "broadcast": "192.168.122.255",
    #           "scope": "global",
    #           "noprefixroute": true,
    #           "label": "bond0",
    #           "valid_life_time": 4294967295,
    #           "preferred_life_time": 4294967295
    #         }
    #       ]
    #     }
    #   ]
    ipinfo=$($ssh ip -j -4 -o address show up)
    hostnameinfo=$($ssh hostnamectl | grep 'Static hostname')
    resolvedotconf=$($ssh cat /etc/resolv.conf)
    keyfiles=$($ssh ls /etc/NetworkManager/system-connections/)
    detectedkeyfiles=$($ssh ls /etc/NetworkManager/system-connections/ | wc -l)
    rc=0

    # verify that the hostname is correct
    if [[ ! $hostnameinfo =~ "Static hostname: $hostname" ]]; then
        rc=1
        echo "ERROR: Hostname information was not what was expected" 1>&2
    fi

    # verify that the right number of NetworkManager keyfiles got created
    # use `echo -n | wc -l` so we can properly detect 0. Wasn't working
    # with `wc -l <<< $keyfiles`.
    if [ ${detectedkeyfiles} != ${numkeyfiles} ]; then
        rc=1
        echo "ERROR: Expected ${numkeyfiles} NM keyfiles, found ${detectedkeyfiles}" 1>&2
    fi

    # verify that the nameserver got set
    if grep systemd-resolved &>/dev/null <<< "$resolvedotconf"; then
        nameserverinfo=$($ssh resolvectl dns)
    else
        nameserverinfo="$resolvedotconf"
    fi
    if ! grep $nameserver &>/dev/null <<< "$nameserverinfo"; then
        rc=1
        echo "ERROR: Nameserver information was not what was expected" 1>&2
    fi

    # verify that there are the right number of ipv4 devices "up"
    if [ $(jq length <<< $ipinfo) != "$((interfaces+1))" ]; then
        rc=1
        echo "ERROR: More interfaces up than expected" 1>&2 
    fi
    # verify that the first one in loopback
    if [ $(jq -r .[0].addr_info[0].dev <<< $ipinfo) != 'lo' ]; then
        rc=1
        echo "ERROR: The first active interface is not 'lo'" 1>&2 
    fi
    # verify that the second one is the expected device
    if [ $(jq -r .[1].addr_info[0].dev <<< $ipinfo) != "${dev}" ]; then
        rc=1
        echo "ERROR: The second active interface is not ${dev}" 1>&2 
    fi
    # verify that the second one has the IP we assigned
    if [ $(jq -r .[1].addr_info[0].local <<< $ipinfo) != "${ip}" ]; then
        rc=1
        echo "ERROR: The second active interface does not have expected ip" 1>&2 
    fi

    if [ "$rc" != '0' ]; then
        echo "$hostnameinfo"
        echo "$nameserverinfo"
        echo "$keyfiles"
        jq -r .[].addr_info[].dev 1>&2 <<< $ipinfo
        jq -r .[].addr_info[].local 1>&2 <<< $ipinfo
        true
    else
        echo "Check for ${hostname} + dns:${nameserver} + ${dev}/${ip} passed!"
    fi
    return $rc
}

reboot_vm() {
    echo "Rebooting domain: $vmname"
    # The reboot after a virt-install --install will not boot the VM
    # back up. Let's use `virsh shutdown` && `virsh start` instead
    virsh shutdown $vmname 1>/dev/null
    sleep 10
    virsh start $vmname 1>/dev/null
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
    local fcctconfig=$1
    local ignitionfile=$2
    # uncomment and use ign-converter instead if on rhcos less than 4.6
    #echo "$fcctconfig" | fcct --strict | ign-converter -downtranslate -output $ignitionfile
    echo "$fcctconfig" | fcct --strict --output $ignitionfile
    chcon --verbose unconfined_u:object_r:svirt_home_t:s0 $ignitionfile &>/dev/null
}


main() {
    qcow=$1
    local ip='192.168.122.111'
    local netmask='255.255.255.0'
    local prefix='24'
    local gateway='192.168.122.1'
    local nameserverdhcp='192.168.122.1'
    local nameserverstatic='208.67.222.222' # opendns server
    local initramfshostname='initrdhost'
    local kernel="${PWD}/coreos-nettest-kernel"
    local initramfs="${PWD}/coreos-nettest-initramfs"
    local sshkeyfile="${PWD}/coreos-nettest-sshkey"
    local sshpubkeyfile="${PWD}/coreos-nettest-sshkey.pub"
    local ignitionfile="${PWD}/coreos-nettest-config.ign"
    local sshpubkey
    local fcct
     
    check_requirements

    # generate an ssh key to use:
    rm -f $sshkeyfile $sshpubkeyfile
    ssh-keygen -N '' -C '' -f $sshkeyfile &>/dev/null
    sshpubkey=$(cat $sshpubkeyfile)

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
    nics="${nic0},${nic1}"

    #Here is an example where you can quickly hack the initramfs and
    #add files that you want to use to test (when developing). For
    # example if you want to test out coreos-teardown-initramfs-network.sh
    # you can do:
   #mkdir -p /tmp/fakeroot/usr/sbin
   #cp /path/to/ignition-dracut/dracut/30ignition/coreos-teardown-initramfs-network.sh /tmp/fakeroot/usr/sbin/coreos-teardown-initramfs-network
   #(cd /tmp/fakeroot; find . | cpio -o -c) >> $initramfs

    # Grab kernel arguments from the disk and use them
    # - strip `options ` from the front of the line
    # - strip `$ignition_firstboot`
    common_args=$(virt-cat -a $qcow -m $partition "/loader.1/entries/${bls_file}" | \
                  grep -P '^options' | \
                  sed -e 's/options //' | \
                  sed -e 's/$ignition_firstboot//')
    common_args+=' ignition.firstboot' # manually set ignition.firstboot
   #common_args+=' rd.break=pre-pivot'


    # For net.ifnames=0 check (i.e., eth0 check)
    devname=eth0
    x="${common_args} rd.neednet=1 ip=${devname}:dhcp"
    initramfs_dhcp_eth0=$x

    devname=$nic0
    x="${common_args} rd.neednet=1 ip=${devname}:dhcp"
    initramfs_dhcp_nic0=$x

    devname=$nic0
    x="${common_args} rd.neednet=1 ip=${nic0}:dhcp ip=${nic1}:dhcp"
    initramfs_dhcp_nic0nic1=$x

    devname=$nic0
    x="${common_args} rd.neednet=1 ip=${nic1}:off"
    x+=" ip=${ip}::${gateway}:${netmask}:${initramfshostname}:${devname}:none:${nameserverstatic}"
    initramfs_static_nic0=$x

    devname=bond0
    x="${common_args} rd.neednet=1"
    x+=" ip=${ip}::${gateway}:${netmask}:${initramfshostname}:${devname}:none:${nameserverstatic}"
    x+=" bond=${devname}:${nics}:mode=active-backup,miimon=100"
    initramfs_static_bond0=$x

    devname=team0
    x="${common_args} rd.neednet=1"
    x+=" ip=${ip}::${gateway}:${netmask}:${initramfshostname}:${devname}:none:${nameserverstatic}"
    x+=" team=${devname}:${nics}"
    initramfs_static_team0=$x

    devname=br0
    x="${common_args} rd.neednet=1"
    x+=" ip=${ip}::${gateway}:${netmask}:${initramfshostname}:${devname}:none:${nameserverstatic}"
    x+=" bridge=${devname}:${nics}"
    initramfs_static_br0=$x

    # export these values so we can substitute the values
    # in using the envsubst command
    export ip prefix nameserverstatic gateway sshpubkey ignitionhostname nic0 nic1

    fcct_none=$(echo "${fcct_common}" | envsubst)
    fcct_static_nic0=$(echo "${fcct_common}${fcct_hostname}${fcct_static_nic0}" | envsubst)
    fcct_static_bond0=$(echo "${fcct_common}${fcct_hostname}${fcct_static_bond0}" | envsubst)
    fcct_static_team0=$(echo "${fcct_common}${fcct_hostname}${fcct_static_team0}" | envsubst)
    fcct_static_br0=$(echo "${fcct_common}${fcct_hostname}${fcct_static_br0}" | envsubst)
    fcct_static_nic0_ifcfg=$(echo "${fcct_common}${fcct_hostname}${fcct_static_nic0_ifcfg}" | envsubst)

    # If the VM is still around for whatever reason, destroy it
    destroy_vm || true

    # On RHCOS we support both ifcfg and NM keyfiles. If we provide an
    # ifcfg file via Ignition then we SHOULD NOT propagate initramfs
    # networking. Do a ifcfg check to make sure.
    if [ "$rhcos" == 1 ]; then
        echo -e "\n###### Testing ifcfg file via Ignition disables initramfs propagation\n"
        create_ignition_file "$fcct_static_nic0_ifcfg" $ignitionfile
        start_vm $qcow $ignitionfile $kernel $initramfs "$initramfs_static_bond0"
        check_vm 'none' 1 0 $ip $nic0 $ignitionhostname $nameserverstatic $sshkeyfile
        reboot_vm
        check_vm 'none' 1 0 $ip $nic0 $ignitionhostname $nameserverstatic $sshkeyfile
        destroy_vm
    fi

    # Do a `coreos.no_persist_ip` check. In this case we won't pass any networking
    # configuration via Ignition either, so we'll just end up with DHCP and a
    # static hostname that is unset (`n/a`).
    echo -e "\n###### Testing coreos.no_persist_ip disables initramfs propagation\n"
    create_ignition_file "$fcct_none" $ignitionfile
    start_vm $qcow $ignitionfile $kernel $initramfs "${initramfs_static_nic0} coreos.no_persist_ip"
    check_vm 'dhcp' 2 0 $ip $nic0 'n/a' $nameserverdhcp $sshkeyfile
    reboot_vm
    check_vm 'dhcp' 2 0 $ip $nic0 'n/a' $nameserverdhcp $sshkeyfile
    destroy_vm

    # Do a `coreos.force_persist_ip` check. In this case we won't pass any networking
    # configuration via Ignition either, so we'll just end up with DHCP and a
    # static hostname that is unset (`n/a`).
    echo -e "\n###### Testing coreos.force_persist_ip forces initramfs propagation\n"
    create_ignition_file "$fcct_static_nic0" $ignitionfile
    start_vm $qcow $ignitionfile $kernel $initramfs "${initramfs_static_bond0} coreos.force_persist_ip"
    check_vm 'none' 1 3 $ip bond0 $ignitionhostname $nameserverstatic $sshkeyfile
    reboot_vm
    check_vm 'none' 1 3 $ip bond0 $ignitionhostname $nameserverstatic $sshkeyfile
    destroy_vm

    # Do a check for the `nameserver=` initramfs arg. Need to test along with
    # the $initramfs_dhcp_nic0nic1 because that brings up more than one
    # interface and is one that doesn't specify the nameserver as part of the
    # ip= karg.
    #
    # The upstream bug [1] is multi-faceted and there are several checks that
    # need to be done to verify it is fixed. The first is to verify that placing
    # namesever= before ip= kargs doesn't yield an extra default.nm_connection
    # file. The second is to verify that the nameserver entry gets placed into
    # all connections that get created (i.e. ens2.nm_connection and ens3.nm_connection).
    # 
    # We'll perform the first check automatically in check_vm by verifying the
    # number of keyfiles is 2, along with checking that the dns server did make
    # it into the resolv.conf or resolvectl (systemd-resolvd). We won't
    # automatically check that each file has the dns entry for now, but anyone
    # can manually run this and grab a console to the VM and verify that.
    # 
    # [1] https://gitlab.freedesktop.org/NetworkManager/NetworkManager/issues/391
    echo -e "\n###### Testing initramfs nameserver= option\n"
    create_ignition_file "$fcct_none" $ignitionfile
    start_vm $qcow $ignitionfile $kernel $initramfs "nameserver=${nameserverstatic} ${initramfs_dhcp_nic0nic1}"
    check_vm 'dhcp' 2 2 $ip $nic0 'n/a' $nameserverstatic $sshkeyfile
    reboot_vm
    check_vm 'dhcp' 2 2 $ip $nic0 'n/a' $nameserverstatic $sshkeyfile
    destroy_vm

    # Do a `net.ifnames=0` check and make sure eth0 is the interface name.
    # We don't pass any hostname information so it will just be (`n/a`).
    echo -e "\n###### Testing net.ifnames=0 gives us legacy NIC naming\n"
    create_ignition_file "$fcct_none" $ignitionfile
    start_vm $qcow $ignitionfile $kernel $initramfs "${initramfs_dhcp_eth0} net.ifnames=0"
    check_vm 'dhcp' 2 1 $ip 'eth0' 'n/a' $nameserverdhcp $sshkeyfile
    # Don't reboot and do another check because we didn't persist the net.ifnames=0 karg
    # TODO persist the net.ifnames karg and do another check after a reboot.
    destroy_vm

    initramfsloop=(
        dhcp_nic0
        static_nic0
        static_bond0
        static_team0
        static_br0
    )

    fcctloop=(
        none
        static_nic0
        static_bond0
        static_team0
        static_br0
    )
        
    for initramfsnet in ${initramfsloop[@]}; do
        for fcctnet in ${fcctloop[@]}; do
            method='none'; interfaces=1;
            nameserver=${nameserverstatic}
            numkeyfiles=3
            if [ "${fcctnet}" == 'none' ]; then
                # because we propagate initramfs networking if no real root networking 
                devname=${initramfsnet##*_}
                hostname=${initramfshostname}
                # If we're using dhcp for initramfs and not providing any real root 
                # networking then we need to tell check_vm we're using DHCP and set
                # a few other values.
                if [ "${initramfsnet}" == 'dhcp_nic0' ]; then
                    method='dhcp'
                    interfaces=2
                    numkeyfiles=1
                    hostname='n/a'
                    nameserver=${nameserverdhcp}
                fi
                # If we're not using a virtual NIC (bond, bridge, team, etc)
                # then only two keyfiles will be created.
                if [ "${initramfsnet}" == 'static_nic0' ]; then
                    numkeyfiles=2
                fi
            else
                devname=${fcctnet##*_}
                hostname=${ignitionhostname}
                # If we're not using a virtual NIC (bond, bridge, team, etc)
                # then only two keyfiles will be created.
                if [ "${fcctnet}" == 'static_nic0' ]; then
                    numkeyfiles=2
                fi
            fi
            # If devname=nic0 then replace with ${nic0} variable
            [ $devname == "nic0" ] && devname=${nic0}
            fcctvar="fcct_${fcctnet}"
            fcctconfig=${!fcctvar}
            initramfsvar="initramfs_${initramfsnet}"
            kernel_args=${!initramfsvar}

            echo -e "\n###### Testing initramfs: ${initramfsnet} + ignition/fcct: ${fcctnet}\n"

            create_ignition_file "$fcctconfig" $ignitionfile
            start_vm $qcow $ignitionfile $kernel $initramfs "${kernel_args}"
            check_vm $method $interfaces $numkeyfiles $ip $devname $hostname $nameserver $sshkeyfile
            reboot_vm
            check_vm $method $interfaces $numkeyfiles $ip $devname $hostname $nameserver $sshkeyfile
            destroy_vm
        done
    done

    # clean up temporary files
    for file in $kernel $initramfs $sshkeyfile $sshpubkeyfile $ignitionfile; do
        rm -f $file
    done

}


main $@

