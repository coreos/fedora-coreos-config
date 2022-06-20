# common pieces of each of the no-default-initramfs-net-propagation tests
if ! journalctl -t coreos-teardown-initramfs | \
       grep 'info: skipping propagation of default networking configs'; then
    echo "no log message claiming to skip initramfs network propagation" >&2
    fail=1
fi

if [ -n "$(ls -A /etc/NetworkManager/system-connections/)" ]; then
    echo "configs exist in /etc/NetworkManager/system-connections/, but shouldn't" >&2
    fail=1
fi

# Also check /etc/sysconfig/network-scripts/ because ifcfg files are
# supported downstream. Need to ignore readme-ifcfg-rh.txt here because of
# https://gitlab.freedesktop.org/NetworkManager/NetworkManager/-/commit/96d7362
if [ -n "$(ls -A -I readme-ifcfg-rh.txt /etc/sysconfig/network-scripts/)" ]; then
    echo "configs exist in /etc/sysconfig/network-scripts/, but shouldn't" >&2
    fail=1
fi
