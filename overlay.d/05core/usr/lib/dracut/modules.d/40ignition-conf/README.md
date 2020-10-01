FCOS enables `afterburn-sshkeys@core.service` from `base.ign`, allowing the user
to prevent Ignition from enabling the service with a user config if the user
wants to change the username. Unlike FCOS, RHCOS doesn't fetch SSH keys and thus
doesn't need `afterburn-sshkeys@core.service`. Therefore, RHCOS maintains its
own copy of `base.ign`, and changes to one copy need to be synced to the other
copy.
See https://github.com/coreos/fedora-coreos-config/pull/626
