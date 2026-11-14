# m2391 内核自动编译（跟上游 + Droidspaces + KernelSU）

> **作者 / 维护者**：DeepSeek Harness AI Agent（模型 `deepseek-v4.1-flash`）
> 负责：kABI 补丁、Droidspaces 配置、GitHub Actions 流水线、版本串对齐策略、本文档。
>
> **设备与需求方**：[@sjcasas1](https://github.com/sjcasas1)
> 负责：Meizu 20 Pro（m2391）真机验证、刷机、日志回报。
>
> 上游内核源码：[@baizhi958216/android_kernel_meizu_m2391](https://github.com/baizhi958216/android_kernel_meizu_m2391)（作者 baizhi958216，本项目未修改其仓库）

## 版本号从哪来（不需要连手机）

```
Makefile VERSION/PATCHLEVEL/SUBLEVEL      -> 5.15.223
build.config.constants BRANCH             -> android13-5.15 → android13
build.config.common KMI_GENERATION        -> 8
git rev-parse --short=12 HEAD             -> d7402701fe45   (12 位，与 git describe 一致)
=> 5.15.223-android13-8-gd7402701fe45
```

该串写进 `CONFIG_LOCALVERSION` 并关闭 `LOCALVERSION_AUTO`；补丁/KSU 的提交不会改变它。
编译后再断言 `kernel.release` 逐字符等于它，否则构建失败。**Release 标题就是这个串。**

## 刷前必做（10 秒）

```sh
adb shell uname -r      # 与 Release 标题对比
```

| 对比 | 含义 | 动作 |
|---|---|---|
| 一致 | ROM 与这版同源，模块可加载 | 刷 |
| 不一致 | ROM 内核旧于/新于该包 | 别刷；等 ROM 更新，或填 `expected_version` 钉旧串重编 |

## 触发与输入

| 方式 | 说明 |
|---|---|
| 手动 Run workflow | `expected_version` 留空 = 跟上游 HEAD；填 `adb shell uname -r` 的值 = 钉住该串对应提交并校验可复现 |
| 定时 | 每天 UTC 18:00（北京 02:00）跟上游最新 |
| 推送 | 改 `.github/workflows/build.yml` 或 `m2391-droidspaces/**` 自动重建 |

## 产物

| 文件 | 用途 |
|---|---|
| `kernel-m2391-droidspaces.zip` | AnyKernel3 刷机包（A/B、无版本白名单） |
| `kernel.config` | 本次配置（核对 `ANDROID_KABI_RESERVE` 等） |
| `KERNEL_VERSION.txt` | 本次内核版本串 |
| `Image` / `Image.gz` | 裸内核，自行打 boot.img 用 |

刷法：KernelSU-Next / Kernel Flasher 直刷入口载入 zip（自动写当前槽 `boot_a`）。
刷前备份 `adb shell su -c 'dd if=/dev/block/by-name/boot of=/sdcard/boot-backup.img'`；回滚 `fastboot flash boot boot-backup.img`。

## 硬约束

1. 不要开 `CONFIG_CFS_BANDWIDTH` / `CONFIG_CGROUP_PIDS`（破 kABI；`--cpus` / `--pids-limit` 因此不可用）
2. 不要开 FullLTO（16GB runner 在 `vmlinux.o` 阶段 OOM，exit 143）
3. kABI 补丁必须生效（`CONFIG_ANDROID_KABI_RESERVE=y`，流水线有硬断言）
4. anykernel.sh 里**值不能带未加引号的括号**（曾导致 `syntax error: unexpected "("`）；流水线现在会先 `sh -n` 校验

## 踩过的坑

| 现象 | 根因 | 修法 |
|---|---|---|
| `curl exit 22` | `clang-r450784e` 归档路径不存在 | 改用 apt `clang-14/lld-14/llvm-14` |
| `exit code 143` | FullLTO 在 16GB runner 被 OOM | 改 ThinLTO |
| 版本带 `-dirty` | 补丁未提交 | 打补丁后 commit |
| 版本变 `-g<别的sha>` | 提交改变了 HEAD | 强制 `CONFIG_LOCALVERSION` + 关 `AUTO` |
| 版本变 `5.15.223+` | `out/` 在源码树内 → 树脏 | 输出目录移到源码树外 |
| `Unsupported Android version` | anykernel 白名单不含 Android 17 | 清空 `supported.versions` |
| `syntax error: unexpected "("` | `kernel.string` 值含未加引号括号 | 加引号 + 流水线 `sh -n` 预检 |