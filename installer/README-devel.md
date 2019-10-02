These files will be copied to the target installer ISO
via the CoreOS Assembler buildextend-installer call. It
picks up all files in the coreos/fedora-coreos-config/installer/
directory and copies them to the base of the ISO. 

Files currently copied are:

- isolinux/boot.msg
- isolinux/isolinux.cfg

Files that get copied into efiboot.img in the ISO:

- EFI/grub.cfg 
