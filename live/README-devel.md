These files will be copied into the built OSTree at
/usr/lib/coreos-assembler/lite/ by CoreOS Assembler.
The file will then be picked up when building live media
and copied to the base of the ISO.

Files currently copied are:

- isolinux/boot.msg
- isolinux/isolinux.cfg

Files that get copied into efiboot.img in the ISO:

- EFI/grub.cfg
