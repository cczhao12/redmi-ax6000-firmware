# 变更清单（平衡最终版 vs 原仓库 / 当前设备）

> **平衡最终版**：相对原 HEAD（`3892b02`）**只回退 4 项编译侧改动**（上游 HEAD、feeds 时刻、
> `CHECK_FORMAT_SECURITY`、上游不存在的 `kmod-nft-fullcone`），其余改进全部编入固件。
> 理由与逐项验证见 `docs/validation.md`；上一版「把编译输入全部退回 `714b898`」已废弃。

## A. 相对原仓库 `cczhao12/redmi-ax6000-firmware`

| 项目 | 原仓库 / 失败版 `3892b02` | 激进最终版 |
|---|---|---|
| 上游 | 每次解析 `25.12` HEAD | **相同**：每次解析 `25.12` 最新 HEAD；`upstream_ref=pinned` 时用 `config/upstream.lock` |
| feeds | 2026-11-13 的 5 个 SHA | **相同** |
| 编译硬化 | `CCACHE` / `CHECK_FORMAT_SECURITY` / `RELRO_FULL` 全开 | **相同**（全部保留） |
| `kmod-nft-fullcone` | 显式 `=y` | **相同**，显式 `=y`；不进 `required-packages.txt`，避免 pinned 模式误红 |
| 厂商调试 | WARP_DBG / MEMORY_LEAK_DBG / ATE / AIR_MONITOR / ICAP / SPECTRUM 全开 | **全部关闭**（减小驱动体积、去掉运行时调试开销） |
| 内核调试 | `DEBUG_INFO` / `DEBUG_MISC` / `LOCK_DEBUGGING` / `PCI_DEBUG` 开 | **全部关闭**（减小 build_dir、缩短编译时间） |
| 性能档位 | CPU `schedutil`；conntrack 按内存、backlog 1000 | CPU `performance`；conntrack `131072`、backlog `32768`、rmem/wmem 4MB |
| 包精简 | 3d34 的精简 | **全部保留**：ATA/SCSI/VFAT/NLS、ebtables、tcpdump/libpcap、htop/nano/libncurses/terminfo、openssh-keygen/libfido2/libcbor/libevdev/libudev-zero、wireless-tools、`luci-theme-bootstrap-mod`、`kmod-ifb` 不装 |
| WOL | 3d34 移除 | **保留移除**（`luci-app-wol` / `luci-i18n-wol-zh-cn` / `etherwake` 不装） |
| `hnat-detect` / `mtk-smp` | 3892 新增 | **保留**（已核实 `9f397975` 的 `package/mtk/applications/` 下两者都有） |
| 必需 / 禁止清单 | 40 / 39 | 39 / 39（去掉上游不存在的 `kmod-nft-fullcone`） |
| BBR | `kmod-tcp-bbr=y` + BBR sysctl，被 TurboACC 覆盖成 cubic | 保留 `kmod-tcp-bbr`（TurboACC 的 select 依赖），**删 BBR sysctl**，`tcpcca=cubic` |
| 全锥形 | 未在 uci-defaults 显式设置 | `fullcone=1`、`fullcone6=0`（仅当为空） |
| fw4 卸载 | 依赖已失效的 `TURBOACC_INCLUDE_*` 残留选项 | `flow_offloading=0`、`flow_offloading_hw=0` 由 uci-defaults **显式写入**（仅当为空） |
| HNAT | 依赖上游 TurboACC 自动探测 | `fastpath=mediatek_hnat`、`bind_rate=30`、`update_nfct=0`（仅当为空）；`mtk_smp` enable 兜底 |
| ttyd / SSH | 默认运行，root 空密码可登录 | 保留包；首启 root 无口令时 `ttyd disable` + `dropbear disable`；设密码后手动启用 |
| WiFi 首启 | 不处理 | root 无口令时 disable 所有 `wifi-device` + `wifi down` |
| WiFi 默认 | 2.4G 固定 ch1；无 country | country `CN`（所有 band，仅当为空）；2.4G ch1（仅当为空/auto）；不锁 SSID/加密 |
| uhttpd | 0.0.0.0:80 + [::]:80 | 保留；仅当为空或只有 `0.0.0.0:80` 时补 `[::]:80` |
| WAN 管理面 | 无 | 自动加 `block-wan-mgmt`：22/80/7681 REJECT，`family=any`，不删自定义规则 |
| 性能 / 稳定性（实验性） | 上游默认 | `mtk_smp` enable 兜底；`/etc/sysctl.conf` 幂等写 4 个键（conntrack 65536、backlog 16384、ESTABLISHED 86400、swappiness 100）；`ax6000-perf` 可选 CPU 调频档位（默认 `schedutil`）。**未上机验证** |
| 厂商调试选项 | WARP/ATE/AIR_MONITOR/SPECTRUM/ICAP 全开 | 保持原样（会影响闭源 WiFi 驱动编译，需单独一轮验证） |
| 固件脚本 | 三个脚本塞在 build workflow 的 heredoc 里，PR 无法校验 | 抽到 `files/` 共 4 个脚本，PR 做 `sh -n` + 关键内容断言，build 用 `cp -a` 注入并 `cmp` 校验一致 |
| Release tag | `vYYYY.MM.DD-<上游sha7>` | `vYYYY.MM.DD-<上游sha7>-<本仓库sha7>` |
| Release 权限 | workflow 级 `contents: write` | build 只读；release 单独 `contents: write` + `environment: release`，显式 `GH_REPO` / `--target` |
| 输入 | `source_ref` / `jobs` 直接插值 | 走 `env`；`source_ref` 留空 = 已验证 SHA，填 40 位 SHA = 测试构建且不发 Release；`jobs` 校验 1-64 |
| 校验和 | 先 `SHA256SUMS` 再 `BUILD_INFO` | 先 `BUILD_INFO`，再对除清单自身外的所有文件做 sha256 |
| 产物 | 只收 `*sysupgrade.bin` | 收 `*ax6000-mtkuboot*`、`.manifest`、`config.buildinfo`、`profiles.json`、`feeds.lock`、`BUILD_INFO`、`SHA256SUMS` |
| 构建信息 | 无 | `/etc/ax6000-build-info` + `BUILD_INFO.txt`；`BUILD_DATE` 取 `SOURCE_DATE_EPOCH` |
| 失败重试 | 3d34 删除了 `-j1` 重试 | `make -j$(nproc)` + 同 step 内 `make -j1 V=s` 增量重试；失败先打印错误摘要再 `tail -200` |
| 断言 | 三份副本且漂移 | 统一到 `scripts/validate-config.sh`；新增清单末行换行、包名格式、必需/禁止冲突、feeds.lock 格式校验 |
| 定时触发 | 无 | **没有定时触发**（按需求）；`upstream-watch.yml` 只做健康提示 |
| 文档 | 无 | README / LICENSE / NOTICE / CHANGELOG / docs 全套 |

## B. 相对你当前设备（2026-11-13 现场）

> 当前设备运行态已和原仓库默认值对齐：uhttpd 双栈、2.4G ch1、235 双灯、ledinterval 150ms、
> HNAT on、fullcone=1、flow_offloading=0、cubic。变化主要在包集合、首启保护、性能参数与构建可复现性。

| 项目 | 当前设备 | 刷平衡版后 |
|---|---|---|
| 包数量 | 268 个 | **会减少**：ATA/SCSI/VFAT/NLS、ebtables、tcpdump/libpcap/libcap-ng、htop/nano/libncurses/terminfo、openssh-keygen/libfido2/libcbor/libevdev/libudev-zero、wireless-tools、`luci-theme-bootstrap-mod`、`kmod-ifb`、WOL 不再装；`hnat-detect` / `mtk-smp` 显式锁定 |
| WOL | 已装 `luci-app-wol` + `etherwake` | **不装** |
| `kmod-nft-fullcone` | 已装 | 钉死上游无此包，不显式锁定；`fullcone=1` 仍写入 UCI，靠 fw4 + libnftnl patch |
| ttyd | 已装并运行；已设 root 密码 | 正常 sysupgrade 不触发首启保护；`sysupgrade -n` / 恢复出厂时 root 为空，ttyd 与 dropbear 默认关闭 |
| WiFi | 2.4G `psk2+ccmp`、5G `sae-mixed`、CN；SSID/密钥自配 | 仓库不写 SSID/密钥；干净刷会丢，首启空密码还会 disable WiFi |
| 自定义 IPv6 规则 `fn` | 已存在（dest_port 36353-36354） | 正常升级保留；干净刷/恢复出厂会丢，先备份 `/etc/config` |
| WAN 管理面 | 只有默认防火墙 | 新增 `block-wan-mgmt`（含 `family=any`） |
| conntrack / backlog / swappiness | 上游默认 | `/etc/sysctl.conf` 幂等写 65536 / 16384 / 86400 / 100 |
| CPU 调频 | `schedutil` | 默认仍是 `schedutil`；可改 `ax6000.perf.cpu_governor='performance'` |
| 构建信息 | 无 | 新增 `/etc/ax6000-build-info` |
| LuCI/包版本 | `luci-base 26.298.29275~c84adb9`（2026-10-25） | 按 run #5 时刻的 feed 锁定，包版本与该次成功构建一致 |

## C. 刷机前必须知道

1. **只编 MTK U-Boot 布局**：`xiaomi_redmi-router-ax6000-mtkuboot`，不要和 stock bootloader 镜像互刷。
2. **首启安全窗口**：root 无口令时 ttyd + dropbear + WiFi 默认关；用网线进 LuCI 设密码，再手动启用。LAN 侧 LuCI 在设密码前仍是空密码 root，请只在隔离网络里首启。
3. **全锥形不等于公网 NAT1**：WAN 是 RFC1918 地址，上游还有 CGNAT。
4. **不要指望恢复出厂保留自定义配置**：先备份 `/etc/config`。
5. **没有代码签名**：只保证 `SHA256SUMS.txt`，请核对后再刷。
6. **CI 只验证编译和配置**：WiFi/HNAT/fullcone 需要上机验证。
7. **性能参数是实验性的**：4 个 sysctl 值、CPU governor 档位、`mtk_smp` 的实际收益都没上机验证；刷完按 `docs/defaults.md` 核对清单观察 1-2 天，不舒服就按回退值改。
8. **编译输入只回退了 4 项**：上游 `9f397975` + run #5 时刻的 feeds、关闭 `CHECK_FORMAT_SECURITY`、不写不存在的 `kmod-nft-fullcone`。想升级上游，先用 `source_ref` 做测试构建，完整编译成功后再改 `UPSTREAM_SHA` 与 `config/feeds.lock`，顺序见 `docs/validation.md`。
