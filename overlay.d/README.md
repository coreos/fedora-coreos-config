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

20platform-chrony
-----------------

Add static chrony configuration for NTP servers provided on platforms
such as `azure`, `aws`, `gcp`. The chrony config for these NTP servers
should override other chrony configuration (e.g. DHCP-provided)
configuration.

25-azure-udev-rules
-------------------

Add udev rules for SRIOV networking on Azure. The udev rules are also
needed in the initramfs [1] and are delivered here via a dracut
module. This may be able to be removed once an upstream PR [2]
merges, though we need to make sure the RPM [3] includes the dracut
bits to include the rules in the initramfs too.

[1] https://github.com/coreos/fedora-coreos-tracker/issues/1383
[2] https://github.com/Azure/WALinuxAgent/pull/1622
[3] https://src.fedoraproject.org/rpms/WALinuxAgent/pull-request/4


30gcp-udev-rules
-------------------

Add udev rules and scripts needed from google-guest-configs [1] for disk
configuration in GCP, such as local SSD controllers (nvme and scsi).

The udev rules are also needed in the initramfs [2] and are delivered here via a dracut
module.

There is an opened BZ [3] requesting a subpackage of google-compute-engine-guest-configs
containing only what we need. Once we get it, we can include this rpm in the
OS (Fedora/RHEL) and drop this module entirely.

[1] https://github.com/GoogleCloudPlatform/guest-configs/tree/master/src/lib/udev
[2] https://issues.redhat.com/browse/OCPBUGS-10942
[3] https://bugzilla.redhat.com/show_bug.cgi?id=2182865
