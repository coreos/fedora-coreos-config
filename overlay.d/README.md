05core
-----

This overlay matches `fedora-coreos-base.yaml`; core Ignition+ostree bits.

08nouveau
---------

Blacklist the nouveau driver because it causes issues with some NVidia GPUs in EC2,
and we don't have a use case for FCOS with nouveau.

"Cannot boot an p3.2xlarge instance with RHCOS (g3.4xlarge is working)"
https://bugzilla.redhat.com/show_bug.cgi?id=1700056

10coreuser
---------

This part is separate from 05core to aid RHCOS, which still uses Ignition spec 2.

14NetworkManager-plugins
------------------------

Disables the Red Hat Linux legacy `ifcfg` format.

20platform-chrony
-----------------

Add static chrony configuration for NTP servers provided on platforms
such as `azure`, `aws`, `gcp`. The chrony config for these NTP servers
should override other chrony configuration (e.g. DHCP-provided)
configuration.

21dhcp-chrony
-------------

Handle DHCP-provided NTP servers and configure chrony to use them,
without overwriting platform-specific configuration. Can be removed
once changes in upstream chrony with support for per-platform
defaults (https://bugzilla.redhat.com/show_bug.cgi?id=1828434),
and handling in 20-chrony and chrony-helper using the defaults
lands in downstream packages. See upstream thread:
https://listengine.tuxfamily.org/chrony.tuxfamily.org/chrony-dev/2020/05/msg00022.html

15fcos
------

Things that are more closely "Fedora CoreOS"; branding, services.

80experimental
--------------

Very FCOS specific, adds an experimental notice to the MOTD.
