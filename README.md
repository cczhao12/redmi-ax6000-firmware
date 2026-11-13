# Redmi AX6000 固件（平衡最终版）

> 只针对 **Xiaomi Redmi Router AX6000**（MT7986A，MTK U-Boot 布局）。
> 不适用于 stock bootloader 布局，也不保证其他 AX6000 变体。
> 这是个人自用固件，不提供任何担保；刷机前先看 `docs/flashing.md` 和 `docs/recovery.md`。

## 这一版：改进全编入，只回退 4 项

相对原 HEAD（`3892b02`），**除下面 4 项外所有改进都编入固件**。目标是在大概率能编译成功的前提下，
产出与旧成功版明显不同的固件：包集合、运行时默认值、首启安全、性能参数、构建可复现性全都变了。

| 只回退的 4 项 | 回退到 | 硬理由 |
|---|---|---|
| 上游「每次解析 `25.12` 最新 HEAD」 | 钉死 `9f397975...`（run #5 成功出包那次） | 主仓库代码直接决定 `package/kernel/linux`；run #7 换成 `daa7695e` 后失败在 `ERROR: package/kernel/linux failed to build.` |
| feeds 锁到 2026-11-13 HEAD | 锁到 run #5 触发时刻（`luci c38e5665`、`routing 48c80803`） | 与钉死上游配套；11-13 后这两个 feed 前进过 |
| `CONFIG_PKG_CHECK_FORMAT_SECURITY=y` | 关闭（回到成功基线） | 给所有包（含内核模块）加 `-Werror=format-security`，是失败首要嫌疑 |
| 显式 `CONFIG_PACKAGE_kmod-nft-fullcone=y` | 不写 | 已核实钉死的上游 `9f397975` 里**没有这个包**，写了也会被 defconfig 静默丢弃；`fullcone=1` 由 uci-defaults + fw4/libnftnl 生效 |

`source_ref` 仍是升级上游的测试入口；`make -j1 V=s` 增量重试保留兜底。

## 编入固件的改进

**编译侧（改变包集合 / 编译选项）**

- **包精简**：ATA/SCSI/VFAT/NLS、ebtables、tcpdump/libpcap、htop/nano/libncurses/terminfo、
  openssh-keygen/libfido2/libcbor/libevdev/libudev-zero、wireless-tools、
  `luci-theme-bootstrap-mod`、`kmod-ifb` 全部不装。
- **移除 WOL**（`luci-app-wol` / `luci-i18n-wol-zh-cn` / `etherwake`）。
- `hnat-detect` / `mtk-smp` 显式锁定（已核实 `9f397975` 里都有；MT7986 的 HNAT 检测与 SMP 调优）。
- `CONFIG_CCACHE=y`、`CONFIG_PKG_RELRO_FULL=y`、`CONFIG_PKG_FORTIFY_SOURCE_2=y` 保留。
- 删掉上游已不存在的 `TURBOACC_INCLUDE_*` 残留选项。
- BBR 保持 `cubic`：`kmod-tcp-bbr` 保留（TurboACC 的 select 依赖），不注入 BBR sysctl。

**运行时侧（`files/` 下 4 个脚本，全部进 rootfs）**

- 首启无口令保护：disable `ttyd` + `dropbear` + 所有 `wifi-device`，`wifi down`。
- 幂等默认值：显式 `flow_offloading=0` / `flow_offloading_hw=0` / `fullcone=1` / `fullcone6=0`、
  HNAT `fastpath=mediatek_hnat`；LAN/hostname/双 LED/WiFi country+ch1/uhttpd 双栈仅当为空写入。
- WAN 管理面 `block-wan-mgmt`（22/80/7681 REJECT，`family=any`）。
- 性能/稳定性：`mtk_smp` enable 兜底、`/etc/sysctl.conf` 四键、可选 CPU governor 档位。
- `/etc/ax6000-build-info` 可自证构建版本。

**工程化**：脚本抽成仓库文件 + `cmp` 注入校验、断言统一到 `scripts/validate-config.sh`、
build/release 拆分与 `GH_REPO`、`SHA256SUMS.txt` 排除自身、`SOURCE_DATE_EPOCH`、逐键 config
差异检查、`jobs` 校验、失败错误摘要 + `-j1 V=s` 重试、无定时触发、全套文档。

## 为什么不是「全删」

几个包看着没用，但有依赖链，保留：

- `blockd` 依赖 `block-mount` 和 `kmod-fs-autofs4`，所以 `kmod-fs-autofs4` 不能删。
- `tc-tiny` 依赖 `kmod-sched-core`；两个都留。
- `zram-swap` 依赖 `kmod-zram`；两个都留。
- `luci-app-turboacc-mtk` 会 `select kmod-tcp-bbr`；模块保留但 `tcpcca=cubic`，不装 BBR sysctl。
- `ttyd` / `luci-app-ttyd`、`autoreboot`、`openssh-sftp-server` 保留。

MTK 厂商调试选项（WARP/ATE/AIR_MONITOR/SPECTRUM/ICAP、`WARP_MEMORY_LEAK_DBG` 等）保持成功基线原样：
它们会影响闭源 WiFi 驱动编译，需要单独一轮完整编译 + 上机验证。

## 默认值

| 项目 | 默认 |
|---|---|
| 机型 | `xiaomi_redmi-router-ax6000-mtkuboot` |
| LAN | `192.168.6.1/24`，DHCP 开，IPv6 `ip6assign=60`（仅当原值为空/`192.168.1.1`） |
| 主机名 | `redmi-ax6000`（仅当为空/`OpenWrt`/`ImmortalWrt`） |
| 无线 | 所有 `wifi-device` 国家码 `CN`；2.4G 信道 `1`（仅当为空/`auto`）；5G 不锁信道 |
| uhttpd | `0.0.0.0:80` + `[::]:80`（仅当为空或只有 `0.0.0.0:80`） |
| HNAT | `fastpath=mediatek_hnat`，`fastpath_mh_bind_rate=30`，`fastpath_mh_update_nfct=0`（仅当为空） |
| fw4 卸载 | `flow_offloading=0`、`flow_offloading_hw=0`（uci-defaults 显式写入，仅当为空） |
| 全锥形 | `fullcone=1`、`fullcone6=0`（仅当为空；模块由上游默认提供） |
| TCP CC | `cubic`（仅当为空；TurboACC 按自己的 `tcpcca` 设置） |
| 首启管理面 | root 无口令时 disable `ttyd` + `dropbear`，并 disable 所有 `wifi-device` |
| WAN 管理面 | `block-wan-mgmt`：`src=wan`、`family=any`、`proto=tcp`、`dest_port=22 80 7681`、`target=REJECT` |
| LED | 状态灯/网络灯 `235/255/0`，`netdev` + `tx/rx`，interval 150ms |
| CPU 调频 | `schedutil`（上游默认）；可切 `performance`，见下节 |
| 其他 | WOL 不装；`zram-swap`、`luci-app-autoreboot`、`openssh-sftp-server` 保留 |

> 已手改的值不会被覆盖。例外：`block-wan-mgmt`、首启空密码保护、`/etc/sysctl.conf` 的 4 个键每次升级检查补齐。

## 性能与稳定性（实验性，需上机验证）

参数都偏保守、可回退，但**没有上机回归**。依据见 `docs/validation.md`。

### 1. MTK SMP 调优兜底

上游 `mtk-smp` 的 `smp.sh` 按 `*mediatek,mt7986*` 走 `MT7986_whnat`，做 IRQ 亲和 + RPS 多核分担。
OpenWrt 打包时会自动 enable 包内 init 脚本，uci-defaults 再 `enable` 一次作为兜底。

### 2. `/etc/sysctl.conf` 幂等写入 4 个键

上游 base-files 明确要求自定义 sysctl 写 `/etc/sysctl.conf`（`sysctl.d/*` 默认不备份、`10-default.conf` 会被覆盖）。
脚本用 awk 按 key 替换，不覆盖你加的其它项：

| 键 | 值 | 目的 | 回退 |
|---|---|---|---|
| `net.netfilter.nf_conntrack_max` | `65536` | HNAT/多连接防表满丢包 | `16384` |
| `net.core.netdev_max_backlog` | `16384` | 四核 + RPS 小包突发 | `1000` |
| `net.netfilter.nf_conntrack_tcp_timeout_established` | `86400` | 僵死 ESTABLISHED 5 天 → 1 天 | `432000` |
| `vm.swappiness` | `100` | 配合 `zram-swap` 降 OOM | `60` |

> 不加 `kernel.panic_on_oops`：上游 `10-default.conf` 已有 `kernel.panic=3`，内核有 `MEDIATEK_WATCHDOG`；
> 把 oops 变 panic 容易让驱动偶发异常变循环重启。`nf_conntrack_max` 约多占 20-30MB 内存。

### 3. 可选 CPU 调频档位

`ax6000-perf` 每次 boot 读 `ax6000.perf.cpu_governor`，默认 `schedutil`（零行为变化），
可切 `performance`（温度/功耗上升）并一键回退：

```sh
uci set ax6000.perf.cpu_governor='performance'; uci commit ax6000; /etc/init.d/ax6000-perf start
# 回退
uci set ax6000.perf.cpu_governor='schedutil'; uci commit ax6000; /etc/init.d/ax6000-perf start
```

刷完核对：

```sh
cat /proc/sys/net/netfilter/nf_conntrack_max
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
/etc/init.d/mtk_smp enabled && echo mtk_smp-ok
head -1 /proc/interrupts
```

## 首启安全窗口（重要）

1. 用**网线**接 LAN 口，访问 `http://192.168.6.1`。
2. 设置 root 密码。
3. 到 LuCI 手动启用 WiFi；需要 SSH / 网页终端再启用 dropbear / ttyd。

> 首启仍保留 LAN 侧 LuCI（空密码）作为设密码入口，请只在隔离网络里首启。
> 被 `disable` 过的服务不会自动恢复。`block-wan-mgmt` 追加在规则末尾，前面若有自定义 WAN ACCEPT 就不会命中。

## 构建

### 手动触发

- `source_ref` **留空**：用已验证的 `UPSTREAM_SHA`（`9f397975...`），构建成功后自动发 Release。
- `source_ref` 填 **40 位小写 commit SHA**：按该 SHA 做**测试构建**，只上传 artifact、不发 Release。
  这是升级上游前的验证入口。
- `jobs` 填 1-64，留空取 `nproc`。

### push tag

`v*` tag 会触发正式构建，tag 直接用你的 tag 名。

> **没有定时触发**：构建只由手动 `workflow_dispatch` 和 `v*` tag 发起；
> `upstream-watch.yml` 每周只做上游健康提示，不触发构建、不影响钉死的 `UPSTREAM_SHA`。

### 自动 tag

```
vYYYY.MM.DD-<上游 sha7>-<本仓库 sha7>
```

`BUILD_DATE` 取自上游 commit 的 `SOURCE_DATE_EPOCH`，同一组输入重建产物字节一致。

### 产物

`out/` 含 `*ax6000-mtkuboot*sysupgrade.bin`、`*.manifest`、`config.buildinfo`、`profiles.json`、
`BUILD_INFO.txt`、`SHA256SUMS.txt`（对除自身外的所有文件做 sha256）、`feeds.lock`。

## 想把回退的 4 项再拿回来

不要一次叠加，每项单独提交 + 单独完整编译，失败即回退该步：

1. 先跑一次本版确认出包（对照 `docs/validation.md` 的 run #5 成功日志，应看到 `make[2] checksum`）。
2. 单独开 `CONFIG_PKG_CHECK_FORMAT_SECURITY=y` —— 它是 `package/kernel/linux` 失败的首要嫌疑。
3. 用 `source_ref` 填上游 `25.12` 新 HEAD 做一次测试构建（不发 Release），成功后再改
   `UPSTREAM_SHA` 与 `config/feeds.lock`，并把 `kmod-nft-fullcone` 加回来（新上游才有这个包）。
4. 把结果回写 `docs/validation.md`。

> 其余改进（包精简、移除 WOL、`hnat-detect`/`mtk-smp`、`CCACHE`/`RELRO_FULL`、全部运行时与工程化改动）
> **已经在这一版里了**，不需要等编译通过后再加。

## 刷机

见 [`docs/flashing.md`](docs/flashing.md)。救砖见 [`docs/recovery.md`](docs/recovery.md)。

1. `sha256sum -c SHA256SUMS.txt`
2. LuCI → 系统 → 备份/刷写固件，选 `*ax6000-mtkuboot*sysupgrade.bin`
3. 普通升级保留配置；要干净刷就取消“保留配置”，但会丢 WiFi/自定义 IPv6 规则
4. 刷完等 3-5 分钟，LAN 访问 `192.168.6.1`

## 已知边界

- **性能参数未上机验证**：4 个 sysctl 值、CPU governor 档位都是保守建议。
- **不做代码签名**：只提供 SHA256，请核对后再刷。
- **CI 只验证编译和配置**：WiFi/HNAT/fullcone 需要上机验证。
- **自定义配置不在仓库里**：WiFi SSID/密钥、IPv6 放行规则 `fn` 恢复出厂会丢，先备份 `/etc/config`。
- **全锥形不等于公网 NAT1**：WAN 是 RFC1918 地址，上游还有 CGNAT。
- **只支持 MTK U-Boot 布局**：不要拿 stock bootloader 镜像互刷。

## 目录

```
.github/workflows/build-ax6000.yml            主构建/发布（上游钉死 9f397975）
.github/workflows/pr-check.yml               PR / push 配置与脚本校验
.github/workflows/upstream-watch.yml         上游健康提示（不触发构建）
config/ax6000.config                         精简版配置（上游钉死 9f397975）
config/feeds.lock                            run #5 时刻的 5 个 feed SHA
config/required-packages.txt                 构建后必须存在（39 项）
config/forbidden-packages.txt                构建后不应存在（39 项）
files/etc/uci-defaults/99-ax6000-defaults    注入镜像的幂等默认配置 + 性能 sysctl
files/etc/init.d/ledinterval                 LED interval 150ms
files/etc/init.d/ax6000-firstboot-guard      首启无口令保护
files/etc/init.d/ax6000-perf                 可选 CPU 调频档位（默认 schedutil）
scripts/validate-config.sh                   静态断言 + defconfig 断言（唯一实现）
docs/changes.md                              变更清单
docs/defaults.md                             默认值明细
docs/validation.md                           成功基线 / 失败对照 / 恢复路线
docs/flashing.md                             刷机
docs/recovery.md                             救砖
```

## 许可

构建脚本和配置以 GPL-2.0-or-later 发布；完整文本见 `LICENSE`。固件包含 ImmortalWrt/OpenWrt 及第三方组件，详见 `NOTICE`。商用或公开分发前请自行复核厂商 binary/firmware 的再分发条款。
