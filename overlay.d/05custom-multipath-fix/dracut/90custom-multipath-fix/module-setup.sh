#!/bin/bash
check() {
    require_binaries multipath || return 1
}

depends() {
    echo dm
    return 0
}

install() {
    inst_multiple multipath
    inst_hook pre-mount 90 "$moddir/run-multipath.sh"
}
