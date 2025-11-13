These overlay directories are automatically committed to the build OSTree repo
by coreos-assembler. They are then explicitly included in our various manifest
files via `ostree-layers` (this used to be done automatically, but that's no
longer the case).

05core
------

This overlay matches `fedora-coreos-base.yaml`; core Ignition+ostree bits.

This overlay is shared with RHCOS/SCOS 9.

08nouveau
---------

Blacklist the nouveau driver because it causes issues with some NVidia GPUs in EC2,
and we don't have a use case for FCOS with nouveau.

"Cannot boot an p3.2xlarge instance with RHCOS (g3.4xlarge is working)"
https://bugzilla.redhat.com/show_bug.cgi?id=1700056

09misc
------

Warning about `/etc/sysconfig`.

15fcos
------

Things that are more closely "Fedora CoreOS":

* disable password logins by default over SSH
* enable SSH keys written by Ignition and Afterburn
* branding (MOTD)
* enable FCOS-specific services by default
* display warnings on the console if no ignition config was provided or no ssh
  key found.
* display warnings if mount points are not set up properly

17fcos-container-signing
------------------------

Configuration for container signature verification for our
fedora-coreos containers pulled from quay.io. Initially adding
here in a separate overlay to make it easy to include on specific
streams for the time being. Eventually can probably put this in
15fcos.

18sshd-authorized-keys-file
---------------------------

Configuration to have OpenSSH read authorized keys from files in
`~/.ssh/authorized_keys.d/*` in addition to `~/.ssh/authorized_keys` (default).
We can drop this overlay once we have moved this configuration file to be
installed alongside the Afterburn and Ignition packages.

20platform-chrony
-----------------

Add static chrony configuration for NTP servers provided on platforms
such as `azure`, `aws`, `gcp`. The chrony config for these NTP servers
should override other chrony configuration (e.g. DHCP-provided)
configuration.

30lvmdevices
-------------------

Populate an lvmdevices(8) file to limit LVM from autoactivating all
devices it sees in a system. By default systems will get a "blank"
configuration file with a comment in it explaining what it is used
for. There is also a one-time "populate" service that will run and
add any devices it sees into the devices file. This will serve to
import existing devices on upgrading systems or new systems with
pre-existing LVM devices attached. See the tracker issue [1] for more
information.

[1] https://github.com/coreos/fedora-coreos-tracker/issues/1517

35container-signing-migration
-----------------------------

This overlay will be used to perform a migration such
that upgrading systems will start using container signatures
for verification as opposed to OSTree commit signatures.

This is a necessary step for F43 as part of the build-via-container
change [1]. See [2].

[1] https://github.com/coreos/fedora-coreos-tracker/issues/1969
[2] https://github.com/coreos/fedora-coreos-tracker/issues/2029

50alternatives
--------------

Temporary overlay for the alternatives migration scripts.
