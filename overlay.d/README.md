05core
-----

This overlay matches `fedora-coreos-base.yaml`; core Ignition+ostree bits.

08nouveau
---------

Blacklist the nouveau driver because it causes issues with some NVidia GPUs in EC2,
and we don't have a use case for FCOS with nouveau.

"Cannot boot an p3.2xlarge instance with RHCOS (g3.4xlarge is working)"
https://bugzilla.redhat.com/show_bug.cgi?id=1700056

09misc
------

* Warning about `/etc/sysconfig`.
* Temporary systemd-tpmfiles.d config to fix ownership and permissions in /etc

14NetworkManager-plugins
------------------------

Disables the Red Hat Linux legacy `ifcfg` format.

15fcos
------

Things that are more closely "Fedora CoreOS":

* disable password logins by default over SSH
* enable SSH keys written by Ignition and Afterburn
* branding (MOTD)
* enable services by default (fedora-coreos-pinger)
* display warnings on the console if no ignition config was provided or no ssh
  key found.

20platform-chrony
-----------------

Add static chrony configuration for NTP servers provided on platforms
such as `azure`, `aws`, `gcp`. The chrony config for these NTP servers
should override other chrony configuration (e.g. DHCP-provided)
configuration.
