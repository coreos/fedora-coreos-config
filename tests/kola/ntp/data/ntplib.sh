# This is a library created for our NTP tests

# shellcheck disable=SC1091
. "$KOLA_EXT_DATA/commonlib.sh"

ntp_test_setup() {
    ntp_host_ip=$1

    # create a network namespace
    ip netns add container

    # create veth pair and assign a namespace to veth-container
    ip link add veth-host type veth peer name veth-container
    ip link set veth-container netns container

    # assign an IP address to the `veth-container` interface and bring it up
    ip netns exec container ip address add 172.16.0.1/24 dev veth-container
    ip netns exec container ip link set veth-container up

    # run podman commands to set up dnsmasq server
    pushd "$(mktemp -d)"
    container=$(get_fedora_container_ref)
    cat <<EOF >Dockerfile
FROM $container
RUN rm -f /etc/yum.repos.d/*.repo \
&& curl -L https://raw.githubusercontent.com/coreos/fedora-coreos-config/testing-devel/fedora-archive.repo -o /etc/yum.repos.d/fedora-archive.repo
RUN dnf -y install systemd dnsmasq iproute iputils \
&& dnf clean all \
&& systemctl enable dnsmasq
RUN echo -e 'dhcp-range=172.16.0.10,172.16.0.20,12h\nbind-interfaces\ninterface=veth-container\ndhcp-option=option:ntp-server,$ntp_host_ip' > /etc/dnsmasq.d/dhcp
CMD [ "/sbin/init" ]
EOF

    podman build -t dnsmasq .
    popd
    podman run -d --rm --name dnsmasq --privileged --network ns:/var/run/netns/container dnsmasq

    # Tell NM to manage the `veth-host` interface and bring it up (will attempt DHCP).
    # Do this after we start dnsmasq so we don't have to deal with DHCP timeouts.
    nmcli dev set veth-host managed yes
    ip link set veth-host up
}

check_for_ntp_server() {
    ntp_host_ip=$1
    ntp_sources_cmd=$2

    ntp_server=""
    retries=300
    while [[ $retries -gt 0 ]]; do
         ntp_sources=$($ntp_sources_cmd)
         [[ "$ntp_sources" =~ "$ntp_host_ip" ]] && break
         echo "waiting for ntp server to appear"
         sleep 1
         retries=$((retries - 1))
    done

    if [ $retries -eq  0 ]; then
        fatal "propagation of ntp server information via dhcp failed"
    fi
}
