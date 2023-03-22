#!/bin/bash
## kola:
##   # This test reprovisions the rootfs.
##   tags: "platform-independent reprovision"
##   # Root reprovisioning requires at least 4GiB of memory.
##   minMemory: 4096
##   # A TPM backend device is not available on s390x to suport TPM.
##   architectures: "!s390x"
##   # This test includes a lot of disk I/O and needs a higher
##   # timeout value than the default.
##   timeoutMin: 15

set -xeuo pipefail

. $KOLA_EXT_DATA/commonlib.sh

# run the tests
. $KOLA_EXT_DATA/luks-test.sh
