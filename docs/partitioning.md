# RPi4 A/B Partition Plan (Example)

Assumes an SD/eMMC with GPT and the following layout:

- p1: boot (FAT32), 256MB, shared by both slots
- p2: rootfsA (ext4), 2GB
- p3: rootfsB (ext4), 2GB
- p4: data (ext4), 1GB

Mounts:
- /boot -> p1
- / -> active slot (p2 or p3)
- /data -> p4

Notes:
- RAUC uses p2/p3 as rootfs slots and a shared /boot partition.
- The WIC file in `yocto/meta-myproduct/recipes-core/images/my-hu-image.wks` matches this layout.
