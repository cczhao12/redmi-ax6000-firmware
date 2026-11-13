# 配置验证记录

> 本文件按时间顺序保留多次验证结果。**读之前先看是哪一轮**：`3d34af8` 的 defconfig 结果
> 不能代表 `3892b02` 之后的 config；本轮 review 修订只做了静态验证，没有完整编译和上机。

## 2026-11-13 — 激进最终版（当前仓库状态）

**不做保守回退**：`3d34af8`/`3892b02` 的编译侧改动全部保留，并且进一步关闭调试项。

| 输入 | 当前值 |
|---|---|
| 上游 | 每次解析 `25.12` 最新 HEAD（`upstream_ref` 可覆盖） |
| feeds | 2026-11-13 的 5 个 SHA |
| 编译硬化 | `CHECK_FORMAT_SECURITY=y`、`RELRO_FULL=y`、`CCACHE=y` |
| fullcone | 显式 `CONFIG_PACKAGE_kmod-nft-fullcone=y` |
| 厂商调试 | WARP_DBG / MEMORY_LEAK_DBG / ATE / AIR_MONITOR / ICAP / SPECTRUM 全关 |
| 内核调试 | `KERNEL_DEBUG_INFO` / `DEBUG_MISC` / `LOCK_DEBUGGING_SUPPORT` / `PCI_DEBUG` 全关 |
| 性能 | CPU governor 默认 `schedutil`（7x24 不常驻满频）；conntrack `131072`、backlog `32768`、rmem/wmem 4MB |

**已知风险**：这正是 run #7 失败的输入（`ERROR: package/kernel/linux failed to build.`），
再加上关闭厂商调试和内核调试的新变量。关调试项可能触发驱动编译错误（某些宏被代码引用），
`KERNEL_DEBUG_INFO` 关闭一般是安全的（只减体积/缩短构建）。

**失败排查（不用改代码）**：
1. 看错误摘要 + `make -j1 V=s` 输出定位具体文件；
2. `hardening=off` 判定是否 format-security/RELRO/ccache；
3. `upstream_ref=pinned` 判定是否上游新 HEAD；
4. `upstream_ref=<中间 SHA>` 逐步逼近；
5. 结论回写本节。

## 2026-11-13 — 平衡最终版（已废弃，仅作历史记录）

| 只回退的项 | 依据 |
|---|---|
| 上游钉死 `9f397975...`（不再每次解析 `25.12` HEAD） | run #7 换成 `daa7695e` 后 `package/kernel/linux` 失败；run #5 用 `9f397975` 完整出包 |
| feeds 锁到 run #5 触发时刻（`luci c38e5665`、`routing 48c80803`） | 与钉死上游配套，用 `commits?until=2026-11-06T06:46:33Z` 还原 |
| 关闭 `CONFIG_PKG_CHECK_FORMAT_SECURITY` | `-Werror=format-security` 作用于所有包（含内核模块），首要嫌疑 |
| 不写 `CONFIG_PACKAGE_kmod-nft-fullcone=y` | 用 `9f397975` 的 git tree 全量核实：只有 `libnftnl` 的 fullcone patch，**没有这个 kmod 包**；`9f397975` 的 `netfilter.mk`/`netsupport.mk` 里也搜不到 fullcone 定义 |

**已编入**（编译侧）：包精简、移除 WOL、`hnat-detect`/`mtk-smp`（已核实 `9f397975` 的
`package/mtk/applications/` 下两者 Makefile 都存在，run #5 日志里 `hnat-detect` 本来就被编译）、
`CCACHE`、`RELRO_FULL`、`FORTIFY_SOURCE_2`、删除无效的 `TURBOACC_INCLUDE_*`、BBR sysctl 不注入。
必需/禁止清单 39/39。

**已编入**（运行时/工程化）：`files/` 4 个脚本、性能 sysctl 与 governor 档位、
CI/发布/断言/文档、`-j1 V=s` 增量重试与错误摘要、无定时触发。

**剩余风险**：`CCACHE` / `RELRO_FULL` / 精简后的 kmod 集合相对 run #5 仍是新变量；
但 `CHECK_FORMAT_SECURITY`（最可能致命）与上游 HEAD（主仓库代码）已回退，
且 `package/kernel/linux` 失败时 `-j1 V=s` 重试会给出详细日志。

**后续**：编译通过后可单独开 `CHECK_FORMAT_SECURITY` 验证假设；用 `source_ref` 测上游新 HEAD，
成功后再改 `UPSTREAM_SHA` / `feeds.lock` / 把 `kmod-nft-fullcone` 加回来。每项单独完整编译。

## 2026-11-13 — 稳定优先版（已废弃，仅作历史记录）

**目标从「诊断失败」改为「极有可能编译成功」。** 依据：本仓库在 Actions 上唯一一次完整成功的构建是
run #5（`714b898`），失败的是 run #7（`3892b02`，`ERROR: package/kernel/linux failed to build.`）。
因此把**全部编译输入**还原到 run #5，只保留不参与编译的改进。

| 输入 | run #5 成功 | run #7 失败 | 最终版 |
|---|---|---|---|
| 上游 SHA | `9f397975...` | `daa7695e...`（25.12 HEAD） | **`9f397975...`** |
| feed `luci` | `c38e5665`（11-05） | `8f18275b`（11-11） | **`c38e5665`** |
| feed `routing` | `48c80803`（10-14） | `625f9d84`（11-06 17:14） | **`48c80803`** |
| `packages`/`telephony`/`video` | 与 11-13 lock 相同 | 相同 | 相同 |
| `CONFIG_CCACHE` | 未设 | `=y` | **未设** |
| `CONFIG_PKG_CHECK_FORMAT_SECURITY` | `is not set` | `=y` | **`is not set`** |
| `CONFIG_PKG_RELRO_FULL` | 未设 | `=y` | **未设** |
| kmod / 用户态包集合 | 完整基线 | 精简版 | **完整基线** |
| 必需 / 禁止包 | 37 / 9 | 40 / 39 | **37 / 9** |
| `make` | `-j8` + `-j1 V=s` 重试 | `-j$(nproc)` 无重试 | **`-j$(nproc)` + `-j1 V=s` 重试** |

feed SHA 用 `commits?sha=openwrt-25.12&until=2026-11-06T06:46:33Z&per_page=1` 还原。
`config/ax6000.config` 的 `CONFIG_*` 行与 `714b898` 逐行一致（仅头部注释不同）。

**保留的改进全部不参与编译**：`files/` 下 4 个运行时脚本、性能 sysctl 与 governor 档位、
CI/发布/断言/文档工程化、`-j1 V=s` 失败重试与错误摘要。

**暂缓**：跟进上游最新、包精简 / 移除 WOL、3 个编译硬化选项、显式 `kmod-nft-fullcone` /
`hnat-detect` / `mtk-smp`。恢复顺序（每项单独提交 + 单独完整编译）：
1. 先跑一次最终版确认出包；
2. 单独开 `CONFIG_PKG_CHECK_FORMAT_SECURITY=y`（`package/kernel/linux` 首要嫌疑）；
3. 再依次试 `RELRO_FULL` → `CCACHE` → 上游新 HEAD + 对应 feeds.lock → 包精简 / 移除 WOL。
任一步失败即回退该步，不要叠加。

## 2026-11-13 — one-shot（`3d34af8`）原始记录

这不是完整编译记录；只验证 `config/ax6000.config` 在上游当时 `25.12` HEAD + 锁定 feeds 下能被 `make defconfig` 接受，并且必需/禁止包断言成立。

### 环境

- Ubuntu 22.04 云主机
- 上游：`chasey-dev/immortalwrt-mt798x-rebase` `25.12` 分支 HEAD `daa7695e855d98abbd1b2df42b1dc03812b267b3`（2026-11-11）
- feeds：`config/feeds.lock` 的 5 个 2026-11-13 记录的 SHA
- 命令：`cp config/ax6000.config openwrt/.config && make defconfig`
- 该云主机缺 `ncurses` 头文件，验证时用 `staging_dir/host/.prereq-build` 占位绕过；CI 会安装 `libncurses-dev`，不受此影响。

### 结果

- `make defconfig` 返回 0，写出 `.config` 1367 行。
- `CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_xiaomi_redmi-router-ax6000-mtkuboot=y`
- `CONFIG_PACKAGE_luci=y`
- 必需包：**37/37** 全部 `=y`。
  - 已过时：`3892b02` 往 `required-packages.txt` 加了 `hnat-detect`、`mtk-smp`、`ip-bridge`，现在是 **40 项**；这次结果不覆盖新增的 3 项。
- 禁止包：39 项 0 命中（含 WOL 的 `luci-app-wol`、`luci-i18n-wol-zh-cn`、`etherwake`）。
- `scripts/validate-config.sh` 对该 `.config` 返回 `OK`（当时的旧版脚本；本轮已重构）。
- 三个 workflow 通过 PyYAML、`actionlint v1.7.12`，**17 个** `run` 块通过 `bash -n`（`3892b02` 和本轮修订后未重跑 actionlint）。
- `CONFIG_CCACHE=y`、`CONFIG_DEVEL=y`、`CONFIG_TOOLCHAINOPTS=y`、`CONFIG_PKG_CHECK_FORMAT_SECURITY=y`、`CONFIG_PKG_RELRO_FULL=y`。
- `blockd=y`、`kmod-fs-autofs4=y`、`kmod-nft-fullcone=y`、`tc-tiny=y`、`kmod-sched-core=y`、`zram-swap=y`。
- `kmod-fs-vfat`、`kmod-nls-base`、`luci-theme-bootstrap-mod`、`ebtables`、`tcpdump`、`htop`、`nano`、`openssh-keygen`、`wireless-tools`、`kmod-ifb`、`luci-app-wol`、`etherwake` 均未选中。

### 关键发现：`kmod-tcp-bbr` 不能删

`tmp/.config-package.in` 的 `PACKAGE_luci-app-turboacc-mtk` 段：

```kconfig
config PACKAGE_luci-app-turboacc-mtk
	tristate "luci-app-turboacc-mtk... LuCI support for MTK HNAT"
	depends on !PACKAGE_luci-app-turboacc
	select PACKAGE_kmod-tcp-bbr
	select PACKAGE_libc
```

结论：只要保留 `luci-app-turboacc-mtk`，`kmod-tcp-bbr` 必然被 select。最终选择：

- 保留 `CONFIG_PACKAGE_kmod-tcp-bbr=y`；
- `turboacc.config.tcpcca='cubic'`；
- 不注入 `/etc/sysctl.d/12-tcp-bbr.conf`；
- BBR 模块存在但未启用；以后要 BBR 只改 TurboACC 的 `tcpcca`。

### 上游 feed 的 Kconfig 警告

`make defconfig` 过程中出现以下递归依赖警告，均来自 feed 包，不是本 config 引入：
`dnsdist`、`luci-app-weechat`、`dnsdist-full`、`snort3`、`knot-resolver`、`openappid`。
`defconfig` 仍返回 0；这些包没有被本 config 选中。

### 当时没做的事

- 没有跑完整 `make -j` 编译。
- 没有上机刷入；WiFi/HNAT/fullcone 的实际行为仍需刷机后验证。
- 没有做代码签名；产物只提供 SHA256。

## 2026-11-13 — `3892b02` 之后的事实核对

- 上游 `25.12` HEAD 仍是 `daa7695e855d98abbd1b2df42b1dc03812b267b3`（2026-11-11），分支存在。
- 上游 `feeds.conf.default` 的 feed 来源与各 `openwrt-25.12` HEAD 已通过 GitHub API 核对，和 `config/feeds.lock` 完全一致：

| feed | 实际 clone 的仓库 | HEAD | commit 日期 |
|---|---|---|---|
| packages | `immortalwrt/packages` | `fa25995d74a7` | 2026-10-28 |
| luci | `immortalwrt/luci` | `8f18275bb510` | 2026-11-11 |
| routing | `openwrt/routing` | `625f9d844680` | 2026-11-06 |
| telephony | `openwrt/telephony` | `c58ec5a67039` | 2026-05-27 |
| video | `openwrt/video` | `094bf58da668` | 2025-11-27 |

> 注意 `packages` / `luci` 来自 **immortalwrt 的 fork**，不是 openwrt 官方仓库；核对 lock 时别找错仓库。
> 各 commit 日期相差一年是正常的：`feeds.lock` 里的 2026-11-13 是「锁定日期」，不是 commit 日期。

- 新增的 `hnat-detect` / `mtk-smp` 确实存在于上游 `package/mtk/applications/`。`hnat-detect` 会通过自己的 `99-hnat-detect` 往 `/etc/config/firewall` 加一个 `include` section（不影响本项目的 `block-wan-mgmt` rule）。
- 上游 `luci-app-turboacc-mtk/Makefile` 只有 `LUCI_DEPENDS:=+kmod-tcp-bbr @!PACKAGE_luci-app-turboacc`，**没有** `TURBOACC_INCLUDE_*` 选项；`3892b02` 删掉的是早已失效的残留行。它自己的 uci-defaults 也用 `set_default` 保护已有值，不会覆盖本项目的 `tcpcca` / `fastpath`。
- **`3892b02` 之后没有重新跑过 `make defconfig` 和完整编译**。上面的 37/37 不能代表当前 config。

## 2026-11-13 — 性能/稳定性参数的依据（源码核对）

这一轮没有凭空加参数，逐项对照了上游 `25.12` 源码：

| 调整 | 依据文件 | 结论 |
|---|---|---|
| `mtk_smp` 兜底 enable | `package/mtk/applications/mtk-smp/files/smp.sh` | `setup_model()` 有 `*mediatek,mt7986*)` → `MT7986_whnat`，做 IRQ 亲和 + RPS |
| sysctl 写 `/etc/sysctl.conf` | `package/base-files/files/etc/sysctl.conf` | 文件内注释明确要求写这里，不要写 `/etc/sysctl.d/*`（默认不备份、`10-default.conf` 会被覆盖） |
| 不加 `kernel.panic_on_oops` | `package/base-files/files/etc/sysctl.d/10-default.conf` | 已有 `kernel.panic=3`；`config-6.12` 也有 `CONFIG_MEDIATEK_WATCHDOG=y` |
| CPU governor 档位 | `target/linux/mediatek/filogic/config-6.12` | `CONFIG_CPU_FREQ_GOV_PERFORMANCE=y` + `CONFIG_CPU_FREQ_DEFAULT_GOV_SCHEDUTIL=y`；`CONFIG_RPS=y`、`CONFIG_RFS_ACCEL=y`、`CONFIG_SMP=y` |
| 包内 init 会自动 enable | `package/base-files/files/lib/functions.sh` `default_postinst()` | 遍历文件列表里的 `/etc/init.d/` 并 `enable`，所以 `mtk_smp enable` 是兜底而不是修复「白装」 |
| 不动 MTK 调试选项 | `target/linux/mediatek/filogic/config-6.12` + `config/ax6000.config` | `CONFIG_DEBUG_INFO=y`、`CONFIG_WARP_DBG_SUPPORT=y`、`CONFIG_WARP_MEMORY_LEAK_DBG=y` 等会影响闭源 WiFi 驱动编译，需单独一轮验证 |

## 2026-11-13 — 真实构建失败（Actions run #7 / 43415503297）

如实记录能核实到什么、不能核实到什么。

| 项 | 值 |
|---|---|
| run | `43415503297`（#7），head `3892b02`，手动触发 |
| 结果 | `build` job failure，`编译` step #12 `exit code 2`；#13 / #14 / `release` 被跳过 |
| 耗时 | 总 57m34s；`编译` step 49.1 min；`预下载源码` 3.6 min；前 11 个 step 全 success |
| annotations | error：`Process completed with exit code 2.`；warning：`config/ax6000.config 与 make defconfig 输出有差异，建议回写`；warning：Node.js 20 弃用 |
| artifact | `build-log-daa7695e855d98abbd1b2df42b1dc03812b267b3`，1363 字节 |
| 对照 | run #5（`714b898`，上游钉死 `9f397975`）**成功**；run #6（`3d34af8`）在 `编译` step 被手动取消 |

### 已拿到的真实报错

用仓库所有者的只读 PAT 下载了失败 `build.log`（6143 字节）与完整 job logs。结尾是：

```
    ERROR: package/kernel/linux failed to build.
make -r world: build failed. Please re-run make with -j1 V=s or V=sc for a higher verbosity level to see what's going on
make: *** [.../include/toplevel.mk:233: world] Error 1
```

失败包是 **`package/kernel/linux`**（所有内核模块）。非 verbose 模式看不到具体哪个 kmod 出错，**必须 `make -j1 V=s` 才会有完整报错**。

### 与成功 run #5 的 build.log 量化对照

| 指标 | 成功 #5（`714b898` / `9f397975`） | 失败 #7（`3892b02` / `daa7695e`） |
|---|---|---|
| 日志行数 | 233 | 143 |
| `make[1] world` 轮数 | 1 | 1 |
| `arm-trusted-firmware-mediatek compile` | 8 | 8 |
| `tools/ccache compile` | 0 | **1** |
| `package/kernel/linux` | 1（成功） | 2（compile + ERROR） |
| `ERROR:` | 0 | 1 |
| `make[2] checksum` | 1（跑完出包） | 0 |

- ATF 重复 8 次两次都有 → **不是并行竞态特有现象**；`world` 都只有 1 轮 → run #5 **没有**触发 `714b898` workflow 里的 `-j1` 重试就成功了。修正此前「成功靠重试救回」的推断：重试是容错/诊断手段，不是已验证修复。
- job logs 里 6 处 `tmp/.config-package.in: recursive dependency detected!` 两次都有（来自 feeds 包，早有记录），不是失败原因。
- 那条 `config 与 defconfig 输出有差异` warning 的 `head -200` 全是 defconfig 补的 `CONFIG_BUSYBOX_CONFIG_*` 默认值，纯噪声；上一轮改成逐键比对后才可能看出真正的键差异。
- 编译侧真实差异：`CONFIG_CCACHE=y`（失败日志多出 `tools/ccache compile`）、上游 `25.12` HEAD + 锁定 feeds、`CHECK_FORMAT_SECURITY` / `RELRO_FULL`、包精简、去掉 `-j1` 重试。
- **首要嫌疑但未证实**：`CONFIG_PKG_CHECK_FORMAT_SECURITY=y`（`-Werror=format-security`，厂商/内核模块最易踩）与上游 `25.12` HEAD 的 kmod 兼容性。没有 V=s 日志不下定论。

### 本改进版的影响

除「恢复同 step 内的 `make -j1 V=s` 增量重试」和「差异检查改逐键比对」外，上游 / feeds / config 的编译选项全部保持原样。
因此**同一编译错误仍会复现**，但失败时会自动产出错误摘要和 `V=s` 详细日志（make 自己也提示 `re-run with -j1 V=s`），下一次就能定位具体 kmod。
排查顺序见 README「编译失败排查」，拿到 V=s 日志后把结论回写本节。

## 2026-11-13 — review 修订的静态验证

| 项 | 命令 / 方法 | 结果 |
|---|---|---|
| shell 语法 | `sh -n` 5 个脚本（`validate-config.sh` + 4 个 `files/` 脚本） | 通过 |
| 仓库静态断言 | `sh scripts/validate-config.sh` | 固件脚本（含 `mtk_smp enable`、4 个 sysctl key、`scaling_governor`）、包清单格式、`feeds.lock`（5 个 feed）通过 |
| defconfig 断言逻辑 | `sh scripts/validate-config.sh config/ax6000.config` | 37 个必需包 / 9 个禁止包通过（用仓库 config 代替 defconfig 输出，仅验证断言逻辑，不等于真实 defconfig 结果） |
| workflow YAML | PyYAML 解析 3 个 workflow + 结构检查 | 通过；`build-ax6000.yml` 的 `on:` 只有 `workflow_dispatch` 和 `push: tags: v*`，**无 schedule** |
| run 块语法 | 18 个 `run` 块（替换 `${{ }}` 后）`bash -n` | 通过 |
| 换行 / 编码 | 全仓库文本统一 LF、无 BOM | 通过 |

### 本轮没做的事

- 没有重跑 `actionlint`（3d34 时跑过，之后的 workflow 改动只做了 PyYAML + `bash -n`）。
- 没有跑 `make defconfig` / 完整 `make -j` 编译（本地无 OpenWrt 构建环境）。
- 没有上机刷入。首启 dropbear 关闭、`flow_offloading=0` 显式写入、`family=any`、`hnat-detect` 与 HNAT 的协同都需要一次完整编译 + 上机验证。
- **性能/稳定性参数完全未上机验证**：4 个 sysctl 值、`mtk_smp` 实际 IRQ 分布、`performance` 档位的温度与吞吐收益，都只是基于源码和常识的保守建议。刷完请按 `docs/defaults.md` 的核对清单逐项看，并观察 1-2 天的内存占用、连接表使用量、温度与是否有重启。
- 没有做代码签名。
