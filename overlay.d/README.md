These overlay directories are automatically committed to the build OSTree repo
by coreos-assembler. They are then explicitly included in our various manifest
files via `ostree-layers` (this used to be done automatically, but that's no
longer the case).

05core
------

This overlay matches `fedora-coreos-base.yaml`; core Ignition+ostree bits.

06el9
-----

This overlay includes content shared between FCOS and RHCOS/SCOS 9, but not
RHCOS 8.

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
