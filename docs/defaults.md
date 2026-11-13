# 默认值明细

> **激进最终版**：不做保守回退。上游跟 `25.12` 最新、feeds 锁 2026-11-13、编译硬化全开、
> `kmod-nft-fullcone` 显式锁定；并关闭厂商调试（WARP/ATE/AIR_MONITOR/ICAP/SPECTRUM）
> 与内核调试（DEBUG_INFO 等）。运行时默认值由 `files/` 下的脚本注入固件，全部保留。
> 牺牲了确定性换取功能和性能，见 `docs/validation.md`。

注入镜像的脚本在仓库里是 `files/etc/uci-defaults/99-ax6000-defaults`、
`files/etc/init.d/ledinterval`、`files/etc/init.d/ax6000-firstboot-guard`、
`files/etc/init.d/ax6000-perf`；build workflow 用 `cp -a` 注入，并用 `cmp` 校验与仓库文件一致。
PR 会对它们做 `sh -n` 和关键内容断言。

`99-ax6000-defaults` 是幂等的：只在对应值为空（或仍是上游默认）时写入，避免每次 sysupgrade 覆盖你手改的设置。
OpenWrt 会在 uci-defaults 脚本成功执行一次后删除它；普通 sysupgrade 由新固件再次带来并执行。

## 网络

| UCI | 值 | 条件 |
|---|---|---|
| `network.lan.ipaddr` | `192.168.6.1` | 原值空或 `192.168.1.1`，且 `proto` 空/`static` |
| `network.lan.netmask` | `255.255.255.0` | 仅当 LAN section 不存在时 |
| `network.lan.device` | `br-lan` | 仅当 LAN section 不存在时 |
| `network.lan.proto` | `static` | 仅当 LAN section 不存在时 |
| `network.lan.ip6assign` | `60` | 仅当为空 |
| `system.@system[0].hostname` | `redmi-ax6000` | 仅当为空/`OpenWrt`/`ImmortalWrt` |

## 无线

| UCI | 值 | 条件 |
|---|---|---|
| `wireless.<dev>.country` | `CN` | 仅当为空（对所有 `wifi-device`，含 5G） |
| `wireless.<dev>.channel`（band=2g） | `1` | 仅当为空/`auto` |
| 5G 信道 | 不写 | 沿用设备/上游 |
| SSID/加密/密钥 | 不写 | 仓库不保存你的 WiFi 配置 |

## 服务

| UCI / 文件 | 值 | 条件 |
|---|---|---|
| `uhttpd.main.listen_http` | `0.0.0.0:80` + `[::]:80` | 仅当为空或只有 `0.0.0.0:80` |
| `turboacc.config.fastpath` | `mediatek_hnat` | 仅当为空（上游 TurboACC 的 uci-defaults 也会自动探测） |
| `turboacc.config.fastpath_mh_bind_rate` | `30` | 仅当为空 |
| `turboacc.config.fastpath_mh_update_nfct` | `0` | 仅当为空 |
| `turboacc.config.tcpcca` | `cubic` | 仅当为空；以后要 BBR 改这里，升级不会被重置 |
| `firewall.@defaults[0].fullcone` | `1` | 仅当为空 |
| `firewall.@defaults[0].fullcone6` | `0` | 仅当为空 |
| `firewall.@defaults[0].flow_offloading` | `0` | uci-defaults 显式写入，仅当为空 |
| `firewall.@defaults[0].flow_offloading_hw` | `0` | 同上 |
| `ax6000.perf.cpu_governor` | `schedutil` | **仅当 `ax6000.perf` 段不存在时**初始化，之后你的修改不会被覆盖 |
| `/etc/sysctl.conf` | 4 个键，见下节 | 每次按 key 幂等替换，不覆盖你加的其它项 |
| `/etc/init.d/ledinterval` | 启用 | 每次检查；`START=97`，写 150ms 到 `rgb:status`/`rgb:network` |
| `/etc/init.d/ax6000-firstboot-guard` | 启用 | 每次检查；`START=99` |
| `/etc/init.d/ax6000-perf` | 启用 | 每次检查；`START=98`，按 UCI 应用 CPU governor |
| `/etc/init.d/mtk_smp` | 启用 | 每次检查（兜底，见下节） |
| `/etc/config/upnpd` | 删除 | 每次（本版不装 UPnP） |

> `3892b02` 删除了 `CONFIG_PACKAGE_TURBOACC_INCLUDE_*`：上游 `luci-app-turboacc-mtk` 的 Makefile 里早已没有这些选项，
> 只有 `LUCI_DEPENDS:=+kmod-tcp-bbr @!PACKAGE_luci-app-turboacc`。
> 因此 `flow_offloading=0` 过去只是 fw4 的默认值，不是任何配置项保证的；现在由 uci-defaults 真正写入。

## 性能与稳定性（实验性，需上机验证）

### MTK SMP 调优兜底

上游 `package/mtk/applications/mtk-smp/files/smp.sh` 的 `setup_model()` 匹配 `*mediatek,mt7986*` 后走
`MT7986_whnat` 分支，把以太网 / WiFi IRQ 绑到不同 CPU，并按 band 数设置 RPS。
`CONFIG_PACKAGE_mtk-smp=y` 已装该包；OpenWrt 的 `default_postinst` 会自动 `enable` 包内 init 脚本，
所以 uci-defaults 里的 `/etc/init.d/mtk_smp enable` 是**兜底**，不是修复「包白装」——
目的是上游改包结构 / 去掉 init 时不至于静默失去 IRQ/RPS 调优。

### `/etc/sysctl.conf` 的 6 个键

上游 `package/base-files/files/etc/sysctl.conf` 明确写着：自定义项应写这个文件，
不要写 `/etc/sysctl.d/*`（该目录默认不备份、`10-default.conf` 升级时会被覆盖）。
脚本用 awk 按 `key=` 精确匹配行首，删掉同名旧值再追加，用户自己加的其它项保持不变。

| 键 | 值 | 类别 | 目的 | 回退 |
|---|---|---|---|---|
| `net.netfilter.nf_conntrack_max` | `131072` | 性能 + 稳定性 | HNAT / 多连接 / P2P 下内核按内存自动算的上限偏小，表满会丢新建连接 | `65536` |
| `net.core.netdev_max_backlog` | `32768` | 性能 | 四核 + RPS 下小包突发的收包队列，减少 rx 丢包 | `16384` |
| `net.core.rmem_max` | `4194304` | 性能 | 抬高 socket 收缓冲上限，给大吞吐场景留余量 | `212992` |
| `net.core.wmem_max` | `4194304` | 性能 | 同上（发送方向） | `212992` |
| `net.netfilter.nf_conntrack_tcp_timeout_established` | `86400` | 稳定性 | 僵死 ESTABLISHED 从内核默认 5 天缩到 1 天，加速表项回收（活跃连接会被刷新） | `432000` |
| `vm.swappiness` | `100` | 稳定性 | 已装 `zram-swap`，优先把匿名页换到压缩内存，降低 OOM 概率 | `60` |

首次启动会 `sysctl -p /etc/sysctl.conf` 立即应用，之后由 `/etc/init.d/sysctl` 负责。

**刻意不加** `kernel.panic_on_oops`：上游 `10-default.conf` 已有 `kernel.panic=3`，
`config-6.12` 也有 `CONFIG_MEDIATEK_WATCHDOG=y`；把 oops 也变 panic 会让 WiFi 驱动偶发异常变成循环重启。

**代价**：`nf_conntrack_max=131072` 在 512MB 内存下约 40-50MB，属于激进档；内存吃紧改回 `65536`。

### CPU 调频档位

`config-6.12` 同时编了 `CONFIG_CPU_FREQ_GOV_PERFORMANCE=y` 和
`CONFIG_CPU_FREQ_DEFAULT_GOV_SCHEDUTIL=y`。`ax6000-perf`（`START=98`）每次 boot 读
`ax6000.perf.cpu_governor`，白名单只允许 `schedutil|performance|ondemand|conservative|powersave|userspace`，
非法值回落 `schedutil`；sysfs 不可写时静默跳过。**默认 `performance`**（满频，降突发延迟，温度/功耗上升）。

```sh
uci set ax6000.perf.cpu_governor='schedutil'     # 想省电降温
uci commit ax6000 && /etc/init.d/ax6000-perf start

uci set ax6000.perf.cpu_governor='performance'   # 回到默认满频
uci commit ax6000 && /etc/init.d/ax6000-perf start
```

### 刷完核对

```sh
cat /proc/sys/net/netfilter/nf_conntrack_max
cat /proc/sys/net/netfilter/nf_conntrack_tcp_timeout_established
cat /proc/sys/net/core/netdev_max_backlog
cat /proc/sys/vm/swappiness
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
/etc/init.d/mtk_smp enabled && echo mtk_smp-ok
head -1 /proc/interrupts
```

## 防火墙

自动规则 `block-wan-mgmt`（只在不存在时新增）：

```
config rule
    option name 'block-wan-mgmt'
    option src 'wan'
    option family 'any'
    option proto 'tcp'
    option dest_port '22 80 7681'
    option target 'REJECT'
```

只挡 WAN 侧管理面；不影响 LAN 访问 LuCI/SSH/ttyd，也不会删你已有的规则。
局限：这条规则追加在规则表末尾，若你已有更靠前的 WAN ACCEPT 规则，它不会命中；
多 WAN / 自定义 zone（例如单独的 `wan6`）也要自己补规则。

## 首启保护

`/etc/init.d/ax6000-firstboot-guard`（`START=99`）在每次 boot 检查：

```
root 的 shadow 口令字段为空，或以 ! / * 开头（锁定），或 /etc/shadow 不可读
  → /etc/init.d/ttyd disable
  → /etc/init.d/dropbear disable
  → 所有 wifi-device disabled=1
  → uci commit wireless
  → wifi down
  → return 0
```

`99-ax6000-defaults` 首次启动也做同样检查，并负责 `enable` 全部 4 个注入的 init 脚本。

> 首启仍保留 LAN 侧 LuCI（空密码）作为设置 root 密码的入口，请只在隔离网络里首启。
> 设好密码后，被 `disable` 过的 dropbear / ttyd / WiFi 不会自动恢复，需要手动启用。

## 不写的值

- WAN 协议（PPPoE/DHCP/静态）——你的宽带账号密码不放进仓库。
- WiFi SSID/密钥/加密方式——不放进仓库。
- 自定义 IPv6 放行规则（例如 `fn`，dest_port 36353-36354）——不放进仓库。
- 5G 信道/带宽——不锁，沿用设备默认。
- MTK 厂商调试选项（WARP_DBG / WARP_MEMORY_LEAK_DBG / ATE / AIR_MONITOR / ICAP / SPECTRUM）——会影响闭源 WiFi 驱动编译，需单独一轮完整编译 + 上机验证，本轮不动。
