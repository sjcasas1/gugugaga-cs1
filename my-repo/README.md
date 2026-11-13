# m2391 内核自动编译仓库（同步上游 + Droidspaces）

这是**你自己拥有**的仓库：只存 5 个小文件，不存内核源码。
每次运行时先同步（clone）上游内核，再开 Droidspaces、编译、发布产物。

## 目录

```
.github/workflows/build.yml                 # 同步 + 编译 + 发 Release 的流水线
m2391-droidspaces/0001-...patch             # GKI kABI padding 补丁（SYSVIPC 放进 ABI 预留位）
m2391-droidspaces/droidspaces.config        # Droidspaces 需要的 CONFIG
m2391-droidspaces/anykernel.sh              # 打 AnyKernel3 刷机包的模板
last-build.json                             # 自动回写：记录最近一次编译的上游 commit
```

## 建立（一次性）

1. 新建**公开**仓库，例如 `m2391-kernel`（公开 = Actions 免费、不限分钟）。
2. 把本目录的 `.github`、`m2391-droidspaces`、`last-build.json` 上传进去（网页 Upload files 即可）。
   `.github` 目录拖不上去时用 Create new file 输 `.github/workflows/build.yml` 再粘贴。
3. Actions 标签 → 允许 workflows。
4. 直接可以跑了：`Actions → m2391-sync-and-build → Run workflow`。

## 三种触发方式

| 触发 | 说明 |
|---|---|
| 手动 | Run workflow，可临时改 `kernel_repo` / `kernel_branch` / `kernel_commit`（钉版本） |
| 定时 | 每天 UTC 18:00（北京时间 02:00）自动同步并编译一次 |
| 推送 | 改了 workflow 或 `m2391-droidspaces/**` 自动编译 |

> 公开仓库若连续 60 天没有活动，GitHub 会自动停用定时任务；手动 Run 一次即可恢复。

## 产物在哪

- **Release**：每次成功编译生成一个 `build-YYYYMMDD-<commit>` 标签，永久保留，手机浏览器就能下载。
- **Artifact**：本次 run 页面底部，保留 30 天。

内容：`Image` / `Image.gz` / `kernel.config` / `KERNEL_VERSION.txt` / `modules/` / `*.dtb` /
`kernel-m2391-droidspaces.zip`（AnyKernel3 刷机包，recovery 里刷，只换内核，保留 cmdline/dtb/ramdisk）。

## 「同步」的含义

不复制 110 万条提交的历史，而是**每次编译现场 clone 上游**：

- 不指定 commit → 永远用上游该分支最新提交（= 自动跟随上游）
- 指定 `kernel_commit` → 钉死某个版本，编译结果可复现

`last-build.json` 会被 workflow 自动回写成最近一次成功编译的 commit / 内核版本 / kABI 状态，
打开它就知道当前发出去的内核基于哪次上游提交。

## 刷机前必看：只刷 boot 还是连模块一起刷

看 Release 里 `kernel.config` 是否有 `CONFIG_ANDROID_KABI_RESERVE=y`（`last-build.json` 里也有 `kabi_padding` 字段）：

| kabi_padding | 含义 | 刷法 |
|---|---|---|
| `yes` | 补丁命中 ABI 预留位，符号 CRC 不变，厂商模块仍能加载 | 只刷 boot / 刷 AnyKernel3 包 |
| `no` | 这棵树没启用 ABI padding，结构体变大 | 必须把 `modules/` 一起刷进 vendor_dlkm，或整包重编 ROM |

验证：

```sh
adb shell droidspaces check
adb shell zcat /proc/config.gz | grep -E 'SYSVIPC|IPC_NS|DEVTMPFS|KABI'
adb shell dmesg | grep -i 'disagrees about version'   # 有输出 = 模块 ABI 不匹配
```

刷机前先备份 boot 分区（`adb shell dd if=/dev/block/by-name/boot of=/sdcard/boot.img`），
开不了机时 `fastboot flash boot boot.img` 救回。

## 为什么不用 Fork / 镜像仓库

| 方案 | 代价 |
|---|---|
| 本方案（每次 clone） | 上游更新自动跟上，仓库很小，不用维护 |
| Fork 上游 | 会得到一个 110 万提交的完整副本；上游更新要手动 Sync fork；fork 的 Actions 需单独启用 |
| 真镜像（定时 push 整库） | 每次要拉几 GB 历史再推回去，慢且占空间，收益与 clone 相同 |

只有一种情况需要 Fork：**你要直接改内核源码**（改驱动、改 DTS），而不是只在 CI 里加配置/打补丁。
那时 Fork 到你自己账号、把这套文件一起提交进 fork，再把 workflow 里的「clone 上游」删掉改成 checkout 当前仓库即可。