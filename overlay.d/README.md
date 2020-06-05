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

Warning about `/etc/sysconfig`.

10coreuser
---------

This part is separate from 05core to aid RHCOS, which still uses Ignition spec 2.

14NetworkManager-plugins
------------------------

Disables the Red Hat Linux legacy `ifcfg` format.

15fcos
------

Things that are more closely "Fedora CoreOS":

* disable password logins by default over SSH
* branding (MOTD)
* enable services by default (fedora-coreos-pinger)
* display warnings on the console if no ignition config was provided or no ssh
  key found.

20platform-chrony
-----------------

Platform aware timeserver setup for chrony daemon.
