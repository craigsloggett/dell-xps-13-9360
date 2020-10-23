# Dell XPS 13 (9360)

A single place to put everything related to my laptop.

Before setting up a new Operating System on my laptop, I like to ensure that the stateful components
like the disk and EFI boot entries are wiped clean.

The tools used to accomplish this are `nvme-format(1)` and `efibootmgr(8)`.

To securely wipe the NVMe device,

```
nvme format /dev/nvme0 -ses 1 -n 1
```

To remove all EFI boot entries,

```
efibootmgr -b XXXX -B
```

# Fresh Install

## Prepare the Disk (Unencrypted)

I have partitioned my disk as follows:

| Partition          | Size   | Type             | Format |
|--------------------|--------|------------------|--------|
| /dev/nvme0n1p1     | 256M   | EFI System       | FAT32  |
| /dev/nvme0n1p2     | 238.2G | Linux Filesystem | EXT4   |

Format the new partitions:
```
# mkfs.fat  /dev/nvme0n1p1
# mkfs.ext4 /dev/nvme0n1p2
```

Getting ready for a new OS installation:
```
# mount /dev/nvme0n1p2 /mnt
# mkdir -p /mnt/boot
# mount /dev/nvme0n1p1 /mnt/boot
```

Create a 16G swapfile in the `/var` directory:
```
# mkdir -p /mnt/var
# dd if=/dev/zero of=/mnt/var/swapfile bs=4k count=4M
# chmod 600 /mnt/var/swapfile
```

## Prepare the OS

Regardless of the OS of choice, we need to perform the following:

1. Create a base filesystem layout.
2. Prepare the tooling (compiler, etc.).
3. Install a core set of binaries used to manage the system.

For simplicity, the above steps are typically done in advance and can be provided as a tarball 
you can extract to disk and used as the root of the new filesystem.

More elaborate installation processes can exist to let the user pick which core set of binaries
exist or add users, etc. -- but they all essentially boil down to the above process.

### Example

```
# cd
# url=https://github.com/kisslinux/repo/releases/download/2020.9-2
# curl -L -O "$url/kiss-chroot-2020.9-2.tar.xz"
# cd /mnt
# tar xvf "$HOME/kiss-chroot-2020.9-2.tar.xz"
```

## Configure the OS

At this point the root of the new filesystem is in place on disk, so configuring the OS can be
achieved by `chroot`ing into the new location. From there, only the core set of binaries will
be available.

## Add a User

Depending on the core binaries used, you have a couple different options to choose when creating a
user.

### Example

Busybox
https://git.busybox.net/busybox/tree/loginutils/adduser.c
```
adduser USERNAME
```

Shadow
https://raw.githubusercontent.com/shadow-maint/shadow/master/src/useradd.c
```
useradd -m USERNAME
```

## Setup a Bootloader

### EFISTUB

The Linux kernel comes with it's own booting mechanism built in, EFISTUB.

# Hardware

| Component          | Works? | Notes |
|--------------------|--------|-------|
| Audio              |        |       |
| Battery Status     |        |       |
| Bluetooth          |        |       |
| Ethernet           |        |       |
| Keyboard Backlight |        |       |
| Hibernation        |        |       |
| NVMe               | Yes    | `nvme-cli` can be used to managed this device. |
| UEFI               | Yes    |       |
| Suspend/Resume     |        |       |
| Thunderbolt 3      |        |       |
| Touchpad           |        |       |
| USB                |        |       |
| Video              |        |       |
| Webcam             |        |       |
| Wireless           |        |       |

## NVMe

Model Number: `THNSN5256GPUK NVMe TOSHIBA 256GB`

`nvme-sanitize(1)` and `nvme-format(1)` can be used to securely erase user data from the device.

`nvme-sanitize(1)` was added as part of the NVMe specification[1], version 1.3 and is *not* 
supported on this model.

```
# nvme id-ctrl /dev/nvme0 -H | grep "Format \|Crypto Erase\|Sanitize"
...
Format NVM Supported
Overwrite Sanitize Operation Not Supported
Block Erase Sanitize Operation Not Supported
Crypto Erase Sanitize Operation Not Supported
Crypto Erase Not Supported as part of Secure Erase
...
```

To securely format this NVMe device, 

```
nvme format /dev/nvme0 -ses 1 -n 1
```

[1] - https://nvmexpress.org/developers/nvme-specification/

## UEFI

The following are required Linux Kernel configuration options for UEFI systems:

```
CONFIG_RELOCATABLE=y
CONFIG_EFI=y
CONFIG_EFI_STUB=y
CONFIG_X86_SYSFB=y
CONFIG_FB_SIMPLE=y
CONFIG_FRAMEBUFFER_CONSOLE=y
```

### EFISTUB

`efibootmgr` is used to 
