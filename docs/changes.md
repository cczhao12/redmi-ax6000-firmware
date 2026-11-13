# 变更清单（one-shot vs 原仓库 / 当前设备）

## A. 相对原仓库 `cczhao12/redmi-ax6000-firmware`

| 项目 | 原仓库 | 这版 |
|---|---|---|
| 上游 | `9f397975...`，`ubuntu-22.04`，355 分钟 | 默认跟 `25.12` 分支 HEAD（本次基于 `daa7695e...`，2026-11-11）；`ubuntu-22.04` 和 355 分钟不变 |
| feeds | `feeds.conf.default` 分支浮动 | `config/feeds.lock` 锁到 2026-11-13 的 5 个 feed SHA；workflow 在 `feeds update` 后逐个 fetch/checkout |
| BBR | `CONFIG_PACKAGE_kmod-tcp-bbr=y` + `/etc/sysctl.d/12-tcp-bbr.conf`，但 TurboACC 启动覆盖成 cubic | 保留 `kmod-tcp-bbr`（`luci-app-turboacc-mtk` 的 select 依赖），删 BBR sysctl；TurboACC `tcpcca=cubic`；以后要 BBR 改 TurboACC 一处即可 |
| 全锥形 | 未在 uci-defaults 显式设置 | `fullcone=1`、`fullcone6=0`（仅当为空） |
| fw4 卸载 | 未显式设置 | `flow_offloading=0`、`flow_offloading_hw=0`（配置里已有，保持） |
| HNAT | 依赖上游 TurboACC 自动探测 | `fastpath=mediatek_hnat`、`bind_rate=30`、`update_nfct=0`（仅当为空） |
| ttyd | 默认运行，root 空密码可登录 | 保留包；首启 root 空密码时 `ttyd disable`；设密码后手动启用 |
| WiFi 首启 | 不处理 | root 空密码时 disable 所有 `wifi-device` + `wifi down` |
| WiFi 默认 | 2.4G 固定 ch1；无 country | country `CN`（仅当为空）；2.4G ch1（仅当为空/auto）；不锁 SSID/加密 |
| uhttpd | 0.0.0.0:80 + [::]:80 | 保留；仅当为空或只有 `0.0.0.0:80` 时补 `[::]:80` |
| WAN 管理面 | 无 | 自动加 `block-wan-mgmt`：22/80/7681 REJECT（不删自定义规则） |
| Release tag | `vYYYY.MM.DD-<上游sha7>` | `vYYYY.MM.DD-<上游sha7>-<本仓库sha7>`（tag 触发沿用你的 tag） |
| Release 权限 | workflow 级 `contents: write` | build 只读；release 单独 `contents: write` + `environment: release` |
| 输入 | `source_ref`/`jobs` 直接插值 | 走 `env`；`source_ref` 留空 = 上游 `25.12` 最新 HEAD，填 40 位小写 SHA = 钉死测试构建且不发 Release；`jobs` 由 shell 默认兜底 |
| 校验和 | 先 `SHA256SUMS` 再 `BUILD_INFO`；BUILD_INFO 不在校验范围 | 先 `BUILD_INFO`，再 `sha256sum ./*`；BUILD_INFO 也在校验范围 |
| 产物 | 只收 `*sysupgrade.bin` | 收 `*ax6000-mtkuboot*`、`.manifest`、`config.buildinfo`、`profiles.json`、`feeds.lock`、`BUILD_INFO`、`SHA256SUMS` |
| 构建信息 | 无 | `/etc/ax6000-build-info` + `BUILD_INFO.txt`（上游/本仓库 SHA、config SHA256、feeds lock SHA256、日期、kernel/WiFi 版本） |
| ccache | 无 | `CONFIG_CCACHE=y`，缓存 `openwrt/.ccache`；`CONFIG_DEVEL` 保留 |
| 硬化 | `CONFIG_PKG_CHECK_FORMAT_SECURITY is not set` | `CONFIG_PKG_CHECK_FORMAT_SECURITY=y`；`CONFIG_PKG_RELRO_FULL=y` |
| 失败重试 | 全量 `make -j1 V=s` 重试 | 去掉全量 -j1；build step 300 分钟，失败保留 `build.log`，下轮 ccache 重试 |
| 文档 | 无 README/LICENSE/NOTICE/CHANGELOG/刷机/救砖 | 全部补齐 |
| CI | 无 PR 校验、无上游 watch | `pr-check.yml` 配置校验；`upstream-watch.yml` 每周检查 `25.12` 分支是否可达，异常才开 issue；Dependabot 管 Actions |
| 包精简 | 含 ATA/SCSI/VFAT/NLS、autofs、ebtables、tcpdump、htop/nano、openssh-keygen/libfido2、wireless-tools、bootstrap-mod、kmod-ifb | 删 ATA/SCSI/VFAT/NLS、ebtables、tcpdump/libpcap/libcap-ng、htop/nano/libncurses/terminfo、openssh-keygen/libfido2/libcbor/libevdev/libudev-zero、wireless-tools、bootstrap-mod、kmod-ifb、WOL（`luci-app-wol`/`luci-i18n-wol-zh-cn`/`etherwake`）；**保留 `kmod-fs-autofs4` 给 `blockd` 依赖**，并保留 `libblkid`、`tc-tiny`/`kmod-sched-core`、zram、ttyd、autoreboot、openssh-sftp-server |
| 厂商调试 | WARP/ATE/AIR_MONITOR/SPECTRUM/ICAP | 不动（第一次构建先保稳定） |

## B. 相对你当前设备（2026-11-13 现场）

> 当前设备运行态已经和原仓库 HEAD 的默认值对齐：uhttpd 双栈、2.4G ch1、235 双灯、ledinterval 150ms、HNAT on、fullcone=1、flow_offloading=0、cubic。  
> 所以“刷这版”不会在这些值上产生可见变化；变化主要在包集合、构建来源和首启保护。

| 项目 | 当前设备 | 刷这版后 |
|---|---|---|
| BBR 包 | 已装 `kmod-tcp-bbr`，运行值 cubic | 仍装 `kmod-tcp-bbr`（TurboACC 的 select 依赖），运行值仍是 cubic；不装 BBR sysctl |
| WOL | 已装 `luci-app-wol` + `etherwake` | 不装 `luci-app-wol`/`luci-i18n-wol-zh-cn`/`etherwake`；WOL 功能移除 |
| ttyd | 已装并运行；你已设 root 密码 | 正常 sysupgrade（保留配置）不触发首启保护，ttyd 保持现状；`sysupgrade -n`/恢复出厂时 root 为空，ttyd 默认关闭 |
| WiFi | 2.4G `psk2+ccmp`、5G `sae-mixed`、CN；SSID/密钥你自配 | 仓库不写 SSID/密钥；正常升级保留；干净刷会丢，首启空密码还会 disable WiFi |
| 自定义 IPv6 规则 `fn` | 已存在（dest_port 36353-36354） | 正常升级保留；干净刷/恢复出厂会丢（不在仓库里） |
| 包数量 | 268 个 | 会减少：ATA/SCSI/VFAT/NLS、ebtables、tcpdump/libpcap/libcap-ng、htop/nano/libncurses/terminfo、openssh-keygen/libfido2/libcbor/libevdev/libudev-zero、wireless-tools、`luci-theme-bootstrap-mod`、`kmod-ifb`、WOL（`luci-app-wol`/`luci-i18n-wol-zh-cn`/`etherwake`）不再装 |
| 保留的“看似无用”包 | `blockd`、`kmod-fs-autofs4`、`libblkid`、`kmod-sched-core`、`zram-swap`、ttyd、autoreboot、sftp-server | 继续保留（依赖或功能）；WOL 不再保留 |
| `kmod-nft-fullcone` | 已装 | 继续装；config 显式 `=y`，不再靠依赖碰运气 |
| `luci-theme-bootstrap-mod` | config 里 `=y`，设备上没有 | 这版删掉，避免“配置说要有、实际没有” |
| `ebtables`/`libpcap`/`libcbor` | config 里 `=y`，设备上没有 | 这版删掉，减少歧义 |
| LuCI/包版本 | `luci-base 26.298.29275~c84adb9`（2026-10-25） | 按 2026-11-13 feed 锁定，包版本会前移；第一次刷完建议对比 |
| uhttpd | 0.0.0.0:80 + [::]:80 | 不变（条件写入，已有双栈就不动） |
| 2.4G/5G | 2.4G ch1 HE20；5G auto HE160 | 不变（2.4G 仅空/auto 才写 ch1；5G 不锁） |
| LED | 235/255/0，双灯，150ms | 不变（已有 `status_led`/`network_led` 就不重写；缺 network 灯才补） |
| WAN 管理面 | 当前只有默认防火墙，没有专门的 22/80/7681 REJECT 规则 | 新增 `block-wan-mgmt`；不删你已有的规则 |
| 构建信息 | 无 `/etc/ax6000-build-info` | 新增，能自证上游/本仓库/config/feeds 版本 |
| Release/CI | 原仓库无 | 新增；这版本身还没提交/推送，需你决定 |

## C. 刷机前必须知道

1. **只编 MTK U-Boot 布局**：`xiaomi_redmi-router-ax6000-mtkuboot`。不要和 stock bootloader 镜像互刷。
2. **首启安全窗口**：root 密码为空时，ttyd + WiFi 默认关；用网线进 LuCI 设密码。已有密码的正常 sysupgrade 不受影响。
3. **全锥形不等于公网 NAT1**：WAN 是 `10.27.97.170`（RFC1918），上游还有 CGNAT；`fullcone=1` 只到路由器。
4. **不要指望恢复出厂保留自定义配置**：WiFi SSID/密钥、IPv6 规则 `fn` 都会丢；先备份 `/etc/config`。
5. **feed 版本前移**：2026-11-13 锁定比设备 10-25 快照新；第一次构建后先对比包版本，再决定是否长期用。
6. **没有代码签名**：只保证 `SHA256SUMS.txt`；请核对后再刷。
