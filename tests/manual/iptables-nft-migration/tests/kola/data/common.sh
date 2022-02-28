OCIARCHIVE_URL=http://192.168.0.13:8000/fedora-coreos-35.20220210.dev.0-ostree.x86_64.ociarchive

upgrade() {
    curl -Lo /var/tmp/update.ociarchive "${OCIARCHIVE_URL}"
    rpm-ostree rebase --experimental ostree-unverified-image:oci-archive:/var/tmp/update.ociarchive
}

assert_iptables_legacy() {
    iptables --version | grep legacy
}

assert_iptables_nft() {
    iptables --version | grep nf_tables
}

assert_iptables_differs_from_default() {
    ostree admin config-diff | grep alternatives/iptables
}

assert_iptables_matches_default() {
    ! ostree admin config-diff | grep alternatives/iptables
}
