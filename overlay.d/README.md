05core
-----

This overlay matches `fedora-coreos-base.yaml`; core Ignition+ostree bits.

10coreuser
---------

This part is separate from 05core to aid RHCOS, which still uses Ignition spec 2.

14NetworkManager-plugins
------------------------

Disables the Red Hat Linux legacy `ifcfg` format.

15fcos
------

Things that are more closely "Fedora CoreOS"; branding, services.

80experimental
--------------

Very FCOS specific, adds an experimental notice to the MOTD.
