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

15fcos
------

Things that are more closely "Fedora CoreOS"; branding, services.

20s390x
-------

For CoreOS installation on IBM Z we need to have coreos-installer within initramfs. 
Usually for Linux installation on zVM we fetch kernel, ramdisk and parameters file
into 'reader queue' and boot kernel like this:

`#cp ipl c`

During `cosa buildextend-live` ramdisk gets generated, but contains no coreos-installer,
so DASD disk couldn't be formatted and partitioned, and consequently used. 
That's why we put coreos-installer into initramfs and perform CoreOS installation. 

80experimental
--------------

Very FCOS specific, adds an experimental notice to the MOTD.
