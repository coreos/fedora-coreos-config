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

16disable-zincati
-----------------

Disable Zincati on non-production streams:
https://github.com/coreos/fedora-coreos-tracker/issues/163

17fedora-modularity
-------------------

Check for layered modularity RPMs to warn users of the retirement in Fedora 39
via Console Login Helper Messages.

Remove once Fedora 39 lands in all streams.

20platform-chrony
-----------------

Add static chrony configuration for NTP servers provided on platforms
such as `azure`, `aws`, `gcp`. The chrony config for these NTP servers
should override other chrony configuration (e.g. DHCP-provided)
configuration.

25azure-udev-rules
-------------------

Add udev rules for SRIOV networking on Azure. The udev rules are also
needed in the initramfs [1] and are delivered here via a dracut
module. This may be able to be removed once an upstream PR [2]
merges, though we need to make sure the RPM [3] includes the dracut
bits to include the rules in the initramfs too.

[1] https://github.com/coreos/fedora-coreos-tracker/issues/1383
[2] https://github.com/Azure/WALinuxAgent/pull/1622
[3] https://src.fedoraproject.org/rpms/WALinuxAgent/pull-request/4

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

40grub
------

Add in static grub configs that will be leveraged by bootupd when
managing bootloaders. See https://github.com/coreos/bootupd/pull/543
