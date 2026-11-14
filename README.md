# m2391 内核自动编译（跟上游 + Droidspaces + KernelSU）

Meizu 20 Pro（m2391 / SM8550 / kalama，LineageOS 24，内核 5.15 GKI KMI 8）自动构建。
**默认每次取上游最新提交**，自动算版本串，开 Droidspaces、内置 KernelSU，只出 `Image`（boot-only，只刷 boot）。

## 版本号怎么来（不需要连手机）

```
Makefile 的 VERSION/PATCHLEVEL/SUBLEVEL   -> 5.15.223
build.config.constants 的 BRANCH           -> android13-5.15
build.config.common 的 KMI_GENERATION      -> 8
git rev-parse --short=11 HEAD              -> d7402701fe45
拼起来                                     -> 5.15.223-android13-8-gd7402701fe45
```

该串写进 `CONFIG_LOCALVERSION` 并关闭 `LOCALVERSION_AUTO`，所以补丁/KSU 提交不会改变它；
编译后再断言 `kernel.release` 等于它，否则构建失败。**Release 标题就是这个串。**

## 刷之前必做（10 秒）

```sh
adb shell uname -r     # 与 Release 标题对比
```

| 对比 | 含义 | 动作 |
|---|---|---|
| 一致 | ROM 与这版同源，模块可加载 | 刷 |
| 不一致 | ROM 内核旧于/新于该包 | 别刷；等 ROM 更新，或填 `expected_version` 钉住旧串重编 |

## 触发

| 方式 | 说明 |
|---|---|
| 手动 | Run workflow；`expected_version` 留空 = 跟上游 HEAD，填了 = 钉住该串的提交 |
| 定时 | 每天 UTC 18:00（北京 02:00）跟上游最新 |
| 推送 | 改 `.github/workflows/build.yml` 或 `m2391-droidspaces/**` 自动重建 |

## 产物

`Image` / `Image.gz` / `kernel.config` / `KERNEL_VERSION.txt` / `kernel-m2391-droidspaces.zip`（AnyKernel3，A/B）。

刷法：KernelSU-Next 或 Kernel Flasher 直刷入口载入 zip。
刷前备份：`adb shell su -c 'dd if=/dev/block/by-name/boot of=/sdcard/boot-backup.img'`；回滚：`fastboot flash boot boot-backup.img`。

## 硬约束

1. 不要开 `CONFIG_CFS_BANDWIDTH` / `CONFIG_CGROUP_PIDS`（破 kABI，必须重编并同刷全部模块；代价是 `--cpus` / `--pids-limit` 不可用）
2. 不要开 FullLTO（16GB runner 会在 `vmlinux.o` 被 OOM，exit 143），用 ThinLTO
3. kABI 补丁必须生效（`CONFIG_ANDROID_KABI_RESERVE=y`）
4. 版本串必须与手机模块一致

## 常见问题

| 现象 | 处理 |
|---|---|
| `Unsupported Android version` | 旧 anykernel 白名单；已清空 |
| 版本带 `-dirty` / `-g<别的sha>` | 已强制写死，不会再出现 |
| 开机后 Wi-Fi/相机失灵 | 对比 `uname -r` 与 Release 标题 |
| `disagrees about version of symbol` | 符号 CRC 变了，检查是否开了破 ABI 选项 |
| build 阶段 exit 143 | FullLTO OOM，保持 ThinLTO |