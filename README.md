# Redmi AX6000 固件（one-shot 版）

> 只针对 **Xiaomi Redmi Router AX6000**（MT7986A，MTK U-Boot 布局）。
> 不适用于 stock bootloader 布局，也不保证其他 AX6000 变体。
> 这是个人自用固件，不提供任何担保；刷机前先看 `docs/flashing.md` 和 `docs/recovery.md`。

## 这版是什么

把此前评审里“有利、可落地”的改动一次性合进原仓库 `cczhao12/redmi-ax6000-firmware`：

- 上游默认跟进 `chasey-dev/immortalwrt-mt798x-rebase` 的 `25.12` 分支 HEAD：每次 run 先解析最新 40 位 SHA，再按这个 SHA 拉取；实际 SHA 会写进 `BUILD_INFO.txt` 和 Release tag。本次验证基于 `daa7695e855d98abbd1b2df42b1dc03812b267b3`（2026-11-11）。
- feeds 锁定到 2026-11-13 的 `openwrt-25.12` HEAD，构建可复现；包版本会比设备上的 10-25 快照新。上游代码跟最新，feeds 仍按 lock 固定。
- 只编 `xiaomi_redmi-router-ax6000-mtkuboot` 一个设备。
- BBR 保持 `cubic`：删掉 `/etc/sysctl.d/12-tcp-bbr.conf`；`kmod-tcp-bbr` 还在（`luci-app-turboacc-mtk` 的 select 依赖），但 `tcpcca=cubic`。以后要 BBR 改 TurboACC 一处即可，不再被启动顺序覆盖。
- 显式锁定 `fullcone=1`、`fullcone6=0`、`flow_offloading=0`、`fastpath=mediatek_hnat`。
- 首启 root 密码为空时，自动关闭 ttyd 和 WiFi；设好密码后再手动开。
- 自动加一条 WAN 侧 `REJECT 22/80/7681` 的管理面规则。
- 包精简：去掉 AX6000 没有对应硬件的 ATA/SCSI/VFAT/NLS、ebtables、tcpdump、htop/nano、openssh-keygen/libfido2、wireless-tools、`luci-theme-bootstrap-mod`、`kmod-ifb`，以及你确认不用的 WOL（`luci-app-wol`/`luci-i18n-wol-zh-cn`/`etherwake`）。
- 构建硬化：`CONFIG_CCACHE=y`、`CONFIG_PKG_CHECK_FORMAT_SECURITY=y`、`CONFIG_PKG_RELRO_FULL=y`；保留 `CONFIG_DEVEL`/`CONFIG_TOOLCHAINOPTS` 以免工具链变化。
- Release 拆成 build（只读）/ release（`contents: write` + `environment: release`）两个 job；tag 加本仓库 commit；`BUILD_INFO.txt` 先生成再算 `SHA256SUMS.txt`；收全镜像、`.manifest`、`config.buildinfo`、`profiles.json`。
- 新增 `README`、`LICENSE`、`NOTICE`、`CHANGELOG`、刷机/救砖/默认值文档、PR 配置校验、上游 watch、Dependabot。

## 为什么不是“全删”

几个包看着没用，但有依赖链，这版**保留**了：

- `blockd` 依赖 `block-mount` 和 `kmod-fs-autofs4`；所以 `kmod-fs-autofs4` 不能删，否则 `blockd` 会被拆掉。
- `tc-tiny` 依赖 `kmod-sched-core`；两个都留。
- `zram-swap` 依赖 `kmod-zram`；两个都留。
- `luci-app-turboacc-mtk` 会 `select kmod-tcp-bbr`；模块保留，但 `tcpcca=cubic`，不装 BBR sysctl，所以 BBR 不会生效。
- `ttyd`/`luci-app-ttyd`、`autoreboot`、`openssh-sftp-server` 保留；WOL 已按你的要求移除。
- `libblkid`、`blockd` 保留；没有 USB/SATA 也不影响它们作为块设备栈的一部分。

MTK 厂商调试选项（WARP/ATE/AIR_MONITOR/SPECTRUM/ICAP 等）这轮**不动**，避免第一次构建就引入驱动编译或 WiFi 行为差异。

## 默认值

| 项目 | 默认 |
|---|---|
| 机型 | `xiaomi_redmi-router-ax6000-mtkuboot` |
| LAN | `192.168.6.1/24`，DHCP 开，IPv6 `ip6assign=60`（仅当原值为空/`192.168.1.1`） |
| 主机名 | `redmi-ax6000`（仅当为空/`OpenWrt`/`ImmortalWrt`） |
| 2.4G | 国家码 `CN`，信道 `1`（仅当为空/`auto`） |
| 5G | 不锁信道；沿用设备/上游默认 |
| uhttpd | `0.0.0.0:80` + `[::]:80`（仅当为空或只有 `0.0.0.0:80`） |
| HNAT | `fastpath=mediatek_hnat`，`fastpath_mh_bind_rate=30`，`fastpath_mh_update_nfct=0`（仅当为空） |
| fw4 卸载 | `flow_offloading=0`、`flow_offloading_hw=0`（MTK 平台用 HNAT，不用 fw4 offload） |
| 全锥形 | `fullcone=1`、`fullcone6=0`（仅当为空） |
| TCP CC | `cubic`（仅当为空；TurboACC 启动按自己的 `tcpcca` 值设置，不再有独立 BBR sysctl 抢先写入） |
| ttyd | `interface=@lan`、`/bin/login`；首启 root 空密码时 disable |
| WiFi 首启 | root 空密码时 disable 所有 `wifi-device`，避免开默认开放 AP |
| WAN 管理面 | 自动加 `block-wan-mgmt`：`src=wan`、`proto=tcp`、`dest_port=22 80 7681`、`target=REJECT` |
| LED | 状态灯/网络灯 `235/255/0`，`netdev` + `tx/rx`，interval 150ms |
| 其他 | `zram-swap`、`luci-app-autoreboot`、`openssh-sftp-server` 保留；WOL 不装 |

> 这些默认只在对应值**为空**时写入；已经手动改过的 hostname、LED、WiFi 国家码/信道、uhttpd、TurboACC、fullcone 不会在每次升级时被强行覆盖。  
> 例外：`block-wan-mgmt` 规则和首启空密码保护是每次升级都会检查/补齐的。

## 首启安全窗口（重要）

镜像里的 root 密码是空的。首次启动（包括恢复出厂/新刷）时：

1. 用**网线**接 LAN 口，访问 `http://192.168.6.1`。
2. 设置 root 密码。
3. 到 LuCI 手动启用 WiFi；需要网页终端再启用 ttyd。

`99-ax6000-defaults` 和 `/etc/init.d/ax6000-firstboot-guard` 会在 root 密码为空时：

- `ttyd disable`
- 所有 `wifi-device` 设 `disabled=1`，并 `wifi down`

已有 root 密码的普通 `sysupgrade`（保留 `/etc/config`）不会触发这段逻辑，ttyd/WiFi 保持你当前的状态。

> 本轮只关了 ttyd 的首启空密码入口；dropbear 仍按上游默认。若你也想连 SSH 一起关，在 `ax6000-firstboot-guard` 里加一行 `/etc/init.d/dropbear disable` 即可。

## 构建

### 手动触发

- `workflow_dispatch` 的 `source_ref` **留空**：每次 run 都解析上游 `25.12` 分支最新 HEAD，构建成功且产物齐全后自动发 Release。
- `source_ref` 填 **40 位小写 commit SHA**：按这个 SHA 做测试构建，只上传 artifact，不会发 Release；不接受分支/tag。

### push tag

`v*` tag 会触发正式构建，tag 直接用你的 tag 名。

### 自动 tag

非 tag 触发时：

```
vYYYY.MM.DD-<上游 sha7>-<本仓库 sha7>
```

例如 `v2026.11.13-daa7695-abc1234`。tag 里的上游 SHA 是本次实际构建的 SHA；同一 commit 同一天重建会命中同一个 tag；release job 用 `--clobber` 覆盖同一 commit 的产物。不同上游 commit 不会撞车。

### 产物

`out/` 里包含：

- `*ax6000-mtkuboot*sysupgrade.bin`
- `*.manifest`
- `config.buildinfo`
- `profiles.json`
- `BUILD_INFO.txt`（上游 SHA、本仓库 SHA、config SHA256、feeds lock SHA256、构建时间、kernel/WiFi 版本）
- `SHA256SUMS.txt`（先写 BUILD_INFO，再对所有文件做 sha256）
- `feeds.lock`（实际 checkout 的 feed SHA）

## 刷机

见 [`docs/flashing.md`](docs/flashing.md)。救砖见 [`docs/recovery.md`](docs/recovery.md)。

一句话版本：

1. `sha256sum -c SHA256SUMS.txt`
2. LuCI → 系统 → 备份/刷写固件，选 `*ax6000-mtkuboot*sysupgrade.bin`
3. 普通升级保留配置；要干净刷就取消“保留配置”，但会丢 WiFi/自定义 IPv6 规则
4. 刷完等 3-5 分钟，LAN 访问 `192.168.6.1`

## 已知边界

- **全锥形只到路由器**：WAN 是 PPPoE，地址 `10.27.97.170` 属 RFC1918，上游还有 CGNAT；路由器侧 `fullcone=1` 不等于公网 NAT1。公网 NAT 类型取决于上游。
- **不做代码签名**：只提供 SHA256；请从本仓库 Actions 产物或 Release 下载，核对 `SHA256SUMS.txt`。
- **CI 只验证编译和配置**：不跑硬件回归；WiFi/HNAT/fullcone 需要上机验证。
- **feed 锁定日期**：包版本会比设备上的 2026-10-25 快照新；第一次构建后建议对比 `apk list --installed` 和 LuCI 版本。
- **自定义配置不在仓库里**：WiFi SSID/密钥、你当前的 IPv6 放行规则 `fn`（dest_port 36353-36354）都不会自动恢复；恢复出厂会丢，请自己备份 `/etc/config`。
- **只支持 MTK U-Boot 布局**：不要拿 stock bootloader 的镜像互刷。

## 目录

```
.github/workflows/build-ax6000.yml   主构建/发布
.github/workflows/pr-check.yml       PR 配置校验
.github/workflows/upstream-watch.yml 上游 25.12 可达性健康检查
config/ax6000.config                 make defconfig 输入
config/feeds.lock                    2026-11-13 feed 锁定
config/required-packages.txt         构建后必须存在
config/forbidden-packages.txt        构建后不应存在
scripts/validate-config.sh           本地/PR 配置断言
docs/changes.md                      相对原仓库/当前设备的变更清单
docs/defaults.md                     默认值明细
docs/validation.md                   上游最新+锁定 feeds 的 defconfig 验证记录
docs/flashing.md                     刷机
docs/recovery.md                     救砖
```

## 许可

构建脚本和配置以 GPL-2.0-or-later 发布；完整文本见 `LICENSE`。固件包含 ImmortalWrt/OpenWrt 及第三方组件，详见 `NOTICE`。商用或公开分发前请自行复核厂商 binary/firmware 的再分发条款。
