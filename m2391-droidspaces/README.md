# m2391 内核自动编译仓库（Droidspaces + KernelSU）

Meizu 20 Pro（m2391，SM8550 / kalama）在 LineageOS 24 内核树上开启 **Droidspaces** 支持，并内置 **KernelSU**，每次自动同步上游后编译、发布。

## 目录

| 文件 | 作用 |
|---|---|
| `.github/workflows/build.yml` | 同步上游 → 打补丁 → 合配置 → 编 Image → 打包 → 发 Release |
| `m2391-droidspaces/0001-ABI-use-ABI-padding-for-SYSVIPC.patch` | 把 SYSVIPC 放进 `task_struct` 的 ABI padding，保住 GKI kABI |
| `m2391-droidspaces/droidspaces.config` | Droidspaces 所需 CONFIG 的最小集合 |
| `m2391-droidspaces/anykernel.sh` | AnyKernel3 模板（A/B、无版本校验） |
| `last-build.json` | 最近一次成功构建的上游 commit / 内核版本 |

## 关键约束（改之前先读）

1. **vermagic 必须与手机现有模块一致**。内核 release 形如 `5.15.223-android13-8-gd7402701fe45`，其中 `-android13-8` 来自 `LOCALVERSION`（KMI generation 8）。流水线用输入 `localversion` 传入，默认 `-android13-8`；如与 `adb shell uname -r` 不同，改这个输入，否则 vendor_dlkm 里的模块会报 `version magic ... should be ...` 全部拒载。
2. **kABI 不能动**。`CONFIG_SYSVIPC` 会撑大 `task_struct`，必须配合 kABI 补丁把它挪进 ABI 预留位；流水线里有硬断言，`CONFIG_ANDROID_KABI_RESERVE` 不为 `y` 就直接失败。
3. **不要开 `CONFIG_CFS_BANDWIDTH` / `CONFIG_CGROUP_PIDS`**。它们改变调度器/cgroup 结构体，没有任何 padding 兜得住，只有重编并同时刷 `vendor_dlkm` + `system_dlkm` 才行。代价仅是 Droidspaces 的 `--cpus` / `--pids-limit` 两个开关不可用。
4. **FullLTO 在 16GB runner 上会被 OOM 杀掉**（表现为 `exit code 143` + `runner received a shutdown signal`）。所以配置里用 `CONFIG_LTO_CLANG_THIN`，CFI 保留。

## 构建产物

Release 里的资产：

| 文件 | 用途 |
|---|---|
| `kernel-m2391-droidspaces.zip` | AnyKernel3 刷机包（recovery 或 Kernel Flasher/KernelSU 直刷） |
| `kernel.config` | 本次实际配置，刷前核对用 |
| `KERNEL_VERSION.txt` | 本次内核版本串（应与手机 `uname -r` 一致） |
| `Image` / `Image.gz` | 裸内核，用于自己重打包 boot.img |

## 刷机（A/B 设备，无需第三方 recovery）

1. 下载 `kernel-m2391-droidspaces.zip`
2. **备份现有 boot**：`adb shell su -c 'dd if=/dev/block/by-name/boot of=/sdcard/boot-backup.img'` + `adb pull`
3. 用 Kernel Flasher / KernelSU 管理器的直刷入口载入 zip（A/B 自动写当前槽 `boot_a/boot_b`）
4. 重启后验证：

```sh
adb shell uname -r                                                # 应与 Release 的 KERNEL_VERSION.txt 一致
adb shell zcat /proc/config.gz | grep -E 'SYSVIPC|IPC_NS|DEVTMPFS|ANDROID_KABI|KSU'
adb shell dmesg | grep -i 'disagrees about version'              # 应为空
droidspaces check                                                 # 或在 App 里检查要求
```

## 回滚

```sh
fastboot flash boot boot-backup.img
fastboot reboot
```

## 常见问题

| 现象 | 原因 / 处理 |
|---|---|
| AnyKernel3 报 `Unsupported Android version` | 旧包带 `supported.versions` 白名单；已清空 |
| 内核版本带 `-dirty` | 补丁未提交进 git；流水线已用 commit 消除，vermagic 才能与 ROM 一致 |
| 开机后 Wi-Fi/相机/触摸失灵 | vermagic 不匹配 → 模块未加载；调 `localversion` 与 `uname -r` 对齐 |
| 模块报 `disagrees about version of symbol` | kABI 变了；确认 `CONFIG_ANDROID_KABI_RESERVE=y` 与补丁生效 |
| build 阶段 `exit code 143` | FullLTO 被 OOM 杀；保持 ThinLTO |
| `--cpus` / `--pids-limit` 灰掉 | 预期行为，见上面第 3 条 |

## 触发方式

- 手动：Actions → m2391-sync-and-build → Run workflow（可填 `kernel_commit` 钉版本）
- 定时：每天 UTC 18:00（北京 02:00）
- 推送：改 workflow 或 `m2391-droidspaces/**` 自动重建