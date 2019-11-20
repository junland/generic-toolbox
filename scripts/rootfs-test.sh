#!/bin/bash

set -e

trap umount_chroot HUP INT QUIT TERM SIGHUP SIGINT SIGQUIT SIGILL SIGABRT SIGKILL SIGTRAP SIGTERM SIGSTOP SIGSEGV

msg() {
	printf '[\033[32m INFO\033[m ] %s\n' "$@"
}

warn() {
    printf '[\033[33m WARN\033[m ] %s\n' "$@"
}

fail() {
	printf '[\033[31m FAIL\033[m ] %s\n' "$@"
	exit 1
}

mount_chroot() {
	msg "Mounting chroot..."
	mount -v --bind /dev $ROOTFS/dev
	mount -vt devpts devpts $ROOTFS/dev/pts -o gid=5,mode=620
	mount -vt proc proc $ROOTFS/proc
	mount -vt sysfs sysfs $ROOTFS/sys
	mount -vt tmpfs tmpfs $ROOTFS/run
	msg "Done mounting chroot."
}

umount_chroot() {
	msg "Unmounting chroot..."
	umount -v $ROOTFS/dev/pts || true
	umount -v $ROOTFS/dev || true
	umount -v $ROOTFS/run || true
	umount -v $ROOTFS/proc || true
	umount -v $ROOTFS/sys || true
	msg "Done unmounting chroot."
}

run_chroot_cmd() {
  chroot "$ROOTFS" /usr/bin/env -i \
	  HOME=/ \
	  TERM="$TERM" \
	  LC_ALL=POSIX \
	  MAKEFLAGS="-j2" \
	  PS1='(chroot)$ ' \
	  PATH=/bin:/usr/bin:/sbin:/usr/sbin /bin/ash -c "$1"
}

qemu_system_inject() {
  if [ "$HOST_ARCH" != "$ROOTFS_ARCH" ]; then
      case $ROOTFS_ARCH in
        x86_64 | x86-64)
          msg "Copying /usr/bin/qemu-system-x86_64 to $ROOTFS"
          cp /usr/bin/qemu-system-x86_64 $ROOTFS/usr/bin
          ;;
        aarch64 | arm64)
          msg "Copying /usr/bin/qemu-system-aarch64 to $ROOTFS"
          cp /usr/bin/qemu-system-aarch64 $ROOTFS/usr/bin
          ;;
        *)
          fail "Architecture is not supported by 'stage2-build' script -- ( $ROOTFS_ARCH )"
          ;;
      esac
  else
      msg "Host and root filesystem architectures are the same."
  fi
}

if [ ! -n "$1" ]; then
  fail "Need to specify the directory for the root filesystem..."
fi

if [ ! -d "$1" ]; then
  fail "Root filesystem does not exist..."
fi

if [ ! -n "$2" ]; then
  fail "Need to specify the architecture for the root filesystem..."
fi

export ROOTFS=$1
export ROOTFS_ARCH=$2
export HOST_ARCH=$(uname -m)

case $ROOTFS_ARCH in
		x86_64)
			msg "Setting architecture for x86_64..."
			;;
		aarch64)
			msg "Setting architecture for aarch64..."
			;;
		*)
			fail "Architecture is not supported by 'rootfs-test' script -- ( $ROOTFS_ARCH )"
			;;
esac

qemu_system_inject

mount_chroot

msg "Testing rootfs..."

run_chroot_cmd "cd / && gcc test.c -o test"

msg "Done..."
