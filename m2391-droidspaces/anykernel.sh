# AnyKernel3 template for Meizu 20 Pro (m2391) — A/B 设备（AB_OTA_UPDATER=true）
kernel.string=Droidspaces kernel for Meizu 20 Pro (m2391)
do.devicecheck=1
do.modules=0
do.systemless=0
do.cleanup=1
do.cleanuponabort=0
device.name1=m2391
device.name2=meizu
supported.versions=13 14 15 16
supported.patchlevels=

# m2391 是 A/B：必须让 AnyKernel3 自动追加当前槽位后缀（boot_a / boot_b）
block=/dev/block/bootdevice/by-name/boot
is_slot_device=1
ramdisk_compression=auto
