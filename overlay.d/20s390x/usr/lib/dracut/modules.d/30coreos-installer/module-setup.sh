#!/bin/bash
# module-setup for coreos-installer

# called by dracut
check() {
    if [ "$arch" = "s390x" ]; then
	require_binaries curl || return 1
    fi
    return 0 # default to install this module
}

# called by dracut
depends() {
    if [ "$arch" = "s390x" ]; then
	echo network url-lib
    fi
    return 0
}

# called by dracut
install() {
    if [ "$arch" = "s390x" ]; then
	# s390x-tools
	inst_multiple zipl chreipl dasdfmt fdasd
	inst_multiple -o /lib/s390-tools/stage3.bin
	# coreos-installer
	inst /usr/bin/coreos-installer
	inst "${moddir}/coreos-installer.service" \
             "${systemdsystemunitdir}/coreos-installer.service"
	inst "${systemdsystemunitdir}/coreos-installer-reboot.service"
	inst "${systemdsystemunitdir}/coreos-installer-noreboot.service"
	inst "${systemdutildir}/system-generators/coreos-installer-generator"
	inst "${systemdsystemunitdir}/coreos-installer.target"
	inst "/usr/libexec/coreos-installer-service"
    fi
}
