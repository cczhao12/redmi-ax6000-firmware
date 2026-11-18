# Redmi AX6000 固件（激进最终版）

> 只针对 **Xiaomi Redmi Router AX6000**（MT7986A，MTK U-Boot 布局）。
> 不适用于 stock bootloader 布局，也不保证其他 AX6000 变体。
> 这是个人自用固件，不提供任何担保；刷机前先看 `docs/flashing.md` 和 `docs/recovery.md`。

## 这一版：不做保守回退

`3d34af8` / `3892b02` 的编译侧改动**全部保留**，包括之前为「提高成功率」回退的那 4 项：

- 上游默认跟 `25.12` 分支最新 HEAD（每次 run 解析 40 位 SHA）
- feeds 锁到 2026-11-13 各 feed HEAD
- `CONFIG_PKG_CHECK_FORMAT_SECURITY=y`、`CONFIG_PKG_RELRO_FULL=y`、`CONFIG_CCACHE=y`
- 显式 `CONFIG_PACKAGE_kmod-nft-fullcone=y`
- 包精简、移除 WOL、`hnat-detect`/`mtk-smp`、BBR 走 cubic
- CPU 固定频率运行（本内核未编 cpufreq/OPP，没有调频器可切）

**代价必须说清**：这就是 run #7 失败（`ERROR: package/kernel/linux failed to build.`）的编译输入，
成功不保证。但失败时**不用改代码**就能定位或回退：

| 输入 | 作用 |
|---|---|
| `upstream_ref` 留空 | 跟最新 HEAD，正式构建并发 Release（默认） |
| `upstream_ref=pinned` | 回退到 `config/upstream.lock`（`9f397975`，唯一出过包的那次） |
| `upstream_ref=<40 位 SHA>` | 指定版本测试构建，只产 artifact、不发 Release |
| `hardening=off` | 临时关掉 `CHECK_FORMAT_SECURITY` / `RELRO_FULL` / `CCACHE` 做 A/B |

编译失败会自动打印错误摘要并跑 `make -j1 V=s`，一次拿到具体出错的 kmod 和命令行。

## 编入固件的改进

**编译侧（改变包集合 / 编译选项）**

- **包精简**：ATA/SCSI/VFAT/NLS、ebtables、htop/nano/libncurses/terminfo、
  openssh-keygen/libfido2/libcbor/libevdev/libudev-zero、
  `luci-theme-bootstrap-mod`、`kmod-ifb` 全部不装。
- **移除 WOL**（`luci-app-wol` / `luci-i18n-wol-zh-cn` / `etherwake`）。
- `hnat-detect` / `mtk-smp` 显式锁定（MT7986 的 HNAT 检测与 SMP 调优）。
- `CONFIG_CCACHE=y`、`CONFIG_PKG_RELRO_FULL=y`、`CONFIG_PKG_CHECK_FORMAT_SECURITY=y`、
  `CONFIG_PKG_FORTIFY_SOURCE_2=y`。
- 显式 `CONFIG_PACKAGE_kmod-nft-fullcone=y`；删除上游已不存在的 `TURBOACC_INCLUDE_*` 残留。
- BBR 保持 `cubic`：`kmod-tcp-bbr` 保留（TurboACC 的 select 依赖），不注入 BBR sysctl。

> `kmod-nft-fullcone` 没有放进 `required-packages.txt` 的硬断言：`upstream_ref=pinned`
> 时上游 `9f397975` 没有这个包，defconfig 会丢弃它，硬断言会让回退模式直接红。
> 跟最新构建时它会被编进去；被丢弃时逐键差异检查会给 warning。

**运行时侧（`files/` 下 7 个脚本，全部进 rootfs）**

- 首启无口令保护：disable `ttyd` + `dropbear` + 所有 `wifi-device`，`wifi down`。
- 幂等默认值：显式 `flow_offloading=0` / `flow_offloading_hw=0` / `fullcone=1` / `fullcone6=0`、
  HNAT `fastpath=mediatek_hnat`；LAN/hostname/双 LED/WiFi country+ch1/uhttpd 双栈仅当为空写入。
- WAN 管理面 `block-wan-mgmt`（22/80/7681 REJECT，`family=any`）。
- 性能/稳定性：`mtk_smp` enable 兜底、`/etc/sysctl.conf` 四键、CPU 调频探测（本内核无 cpufreq，自动跳过）。
- NAS 的 IPv6 放行地址按 MAC 动态跟随（见下方专节），不再对全网段开放。
- 取消固件默认的 `min_cache_ttl=3600`，DNS 重新尊重上游 TTL。
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
| DNS 最小缓存 | 不设 `min_cache_ttl`（跟随上游 TTL；固件默认的 3600 会被删掉） |
| 首启管理面 | root 无口令时 disable `ttyd` + `dropbear`，并 disable 所有 `wifi-device` |
| WAN 管理面 | `block-wan-mgmt`：`src=wan`、`family=any`、`proto=tcp`、`dest_port=22 80 7681`、`target=REJECT` |
| LED | 状态灯/网络灯 `235/255/0`，`netdev` + `tx/rx`，interval 150ms |
| CPU 调频 | **不存在**：本内核未编 cpufreq/OPP，CPU 定频运行；`ax6000-perf` 只做探测 |
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

### 3. CPU 调频：本内核没有这个能力

2026-11-18 上机核对结论：**这个内核没有编 cpufreq/OPP**。

```sh
ls /sys/devices/system/cpu/cpufreq/                        # 空
ls /sys/devices/system/cpu/cpu0/ | grep -E 'cpufreq|opp'   # 无输出
lsmod | grep cpufreq                                       # 无模块
```

即 CPU 定频运行，`schedutil` / `performance` 这类档位在硬件层面不存在。
`ax6000-perf` 因此退化为探测脚本：开机检测到可写的 `scaling_governor` 才应用
`ax6000.perf.cpu_governor`，检测不到就记一条日志后直接退出：

```sh
logread -e ax6000-perf | tail -1
# ax6000-perf: no cpufreq support in this kernel; CPU runs at fixed frequency, nothing to tune
```

想真正拿到调频能力，需要在内核 config 打开 `CONFIG_CPU_FREQ` 并在 DTS/OPP 层接入，
属于要重新编译验证的改动，目前没有做。

刷完核对：

```sh
cat /proc/sys/net/netfilter/nf_conntrack_max
logread -e ax6000-perf | tail -1
/etc/init.d/mtk_smp enabled && echo mtk_smp-ok
head -1 /proc/interrupts
```

## IPv6 端口放行：只对一台设备开放，且跟着地址走

> 完整机制、演进过程与踩过的坑见 [`docs/ipv6-port-forwarding.md`](docs/ipv6-port-forwarding.md)。

背景：线路只有 IPv6 公网，NAS 需要从外网访问 `tcp/udp 36353-36354`。
原先那条规则是 `dest='*'`，等于**内网每台设备**都开了这两个端口；直接写死 NAS 的地址也不行 ——
前缀由 ISP 通过 PD 下发，重拨后会变。

做法：**不记地址，只记 MAC。**

```
MAC   52:54:00:12:34:56                 （示例值，换成你自己设备的）
IPv6  2001:db8:1:2:5054:00ff:fe12:3456   （文档专用前缀 2001:db8::/32）
      └──── 前缀（会变） ────┘└──── EUI-64：由 MAC 推导，永远不变 ────┘
```

NAS 用 EUI-64 接口标识，后缀不会变，所以每次只需问一句「它现在的全局地址是多少」。

> **脚本里既没有 MAC 也没有真实地址。** 第一次运行时它按内网 IPv4（默认 `192.168.6.4`，
> 可用 `uci set ax6000.nas.ip='192.168.6.x'` 覆盖）查一次 ARP，把 MAC **钉进
> `ax6000.nas.mac`**，之后永远用这个值，**不再信任 ARP**。
>
> 原因：ARP 应答没有认证。NAS 关机时同网段任何机器都能抢答它的 IPv4，
> 如果每次都重新反查，等于允许别人把这两个端口的公网转发劫持到自己身上；
> 钉死一次之后，抢答就没有意义了。
>
> 换 NAS 时改这一项：`uci set ax6000.nas.mac='AA:BB:CC:DD:EE:FF'`。
> 想彻底摆脱 EUI-64 时，用 `uci set ax6000.nas.suffix='::4'` 显式指定后缀。

| 文件 | 作用 |
|---|---|
| `files/usr/sbin/nas-v6-firewall` | 一次性的"解析 + 写回"：按 MAC 取全局 IPv6，写入 `firewall.nas_v6_ports.dest_ip` 后 `fw4 reload`；结果与规则一致就直接退出 |
| `files/etc/hotplug.d/iface/90-nas-v6` | `wan` / `wan_6` 的 `ifup`、`ifupdate` 触发同步（前缀变化的主要路径） |
| `files/etc/init.d/ax6000-nas-v6-watch` | 每 10 分钟兜底跑一次。防的是「前缀变了但没触发接口事件」以及「事件来了但 NAS 还没完成 SLAAC」 |

规则本身是具名 section `nas_v6_ports`（`src=wan`、`family=ipv6`、`dest_port=36353-36354`、
`target=ACCEPT`）。脚本靠这个名字定位，**不要把它改回匿名 section**，否则脚本会找不到规则。

### 为什么不能"取邻居表里第一个匹配的地址"

实测过：同一台 NAS 在邻居表里有 4 条记录，其中**包含上一轮 PD 的旧前缀**：

```
2001:db8:aaaa:bbbb:5054:00ff:fe12:3456  STALE   ← 当前前缀
2001:db8:1111:2222:5054:00ff:fe12:3456  STALE   ← 上一轮前缀，已废弃
fd31:...          / fe80::...                   ← ULA 与链路本地
```

邻居表是缓存，旧条目不会因为前缀作废就消失，而且排序不保证。如果直接取第一个，
前缀切换后可能把规则钉到一个**已死的地址**上；更糟的是写进去之后"看起来成功了"，
就再也不会自我纠正。

所以候选地址必须同时满足两点：

1. **归属校验**：邻居表里这条记录的 `lladdr` 必须就是 NAS 的 MAC —— 不是"随便一个能应答的地址"；
2. **前缀校验**：它的 /64 必须是 `br-lan` 当前持有的公网前缀之一（跳过 ULA `fc00::/7`
   和已 `deprecated` 的旧前缀）。

两个都不满足时，才用「当前前缀 + 由 MAC 推导的 EUI-64 后缀」直接算出地址。
这一步是确定性推导，不依赖邻居表，所以 NAS 刚上电还没完成 SLAAC、甚至离线时，规则照样能先写对。

**可达性只写日志，不参与判断。** `ping` 通只说明"有人应答"，不说明应答的是 NAS；
`ping` 不通也不说明地址错了。而且 NAS 离线时，规则恰恰应该先写对，等它上线就能用。

实现上还有四个细节：

- **地址先归一化再比较**：`::` 压缩写法会让 `cut -d: -f1-4` 取错段（实测
  `fd31:a5df:b924::1` 会算出 `fd31:a5df:b924:`，末尾多一个空段），所以统一展开成
  32 位十六进制再比；
- **当前地址仍然有效就不动**：`dest_ip` 若同时通过归属校验和前缀校验，直接退出，
  避免多前缀或排序变化导致来回改写；
- **按 token 定位 `lladdr`，不写死字段序号**：`ip -6 neigh show dev br-lan` 在指定
  dev 过滤时**不打印** `dev <if>`（4 个字段），不带过滤时才打印（6 个字段）。
  写死 `$3` 会在两种调用方式之间静默失效；
- **同一时刻只跑一个实例**：`flock` 防止 hotplug 与 10 分钟定时器撞车。
  固件里是 busybox 版 flock，没有 `-w`，所以用 `-n` 加 1 秒重试。

### 验证

```sh
uci get ax6000.nas.mac                    # 钉住的 NAS MAC（第一次运行自动写入）
uci get firewall.nas_v6_ports.dest_ip     # 应等于 NAS 当前的全局 IPv6
nft list ruleset | grep 36353             # 应只有 daddr 锁定到 NAS 的那两条
logread -e nas-v6-fw | tail -5            # 地址变化时这里会留记录
/usr/sbin/nas-v6-firewall                 # 手动补一次
```

回归测试（把规则故意指向旧前缀地址，再手动跑一次，应立即纠正）：

```sh
uci set firewall.nas_v6_ports.dest_ip='2001:db8:dead:beef:5054:00ff:fe12:3456'
uci commit firewall
/usr/sbin/nas-v6-firewall
```

### 已知边界

- **NAS 关机 / 离线**：地址是确定性推导的，规则照样写对，日志里标「当前不可达」，等它上线即可用。
- **首次自举时有人抢答 ARP**：MAC 可能钉错。这个窗口只存在一次，日志会打印钉住的 MAC，
  发现不对就手动改 `ax6000.nas.mac`。想彻底避免，刷完机直接手动设一次。
- **NAS 换了、MAC 没跟着改**：规则会指向一个不存在的地址（fail-closed，不会误开给别的设备），
  日志显示「当前不可达」。
- **NAS 开了 IPv6 隐私扩展（temporary 地址）**：临时地址和稳定地址来自同一个 MAC，
  邻居表里会同时出现，脚本取第一个，可能取到会过期的临时地址。
  **建议在 NAS 上关掉**：`net.ipv6.conf.all.use_tempaddr=0`。
- **`dest_ip` 为空**：这条规则等于对内网全网段放行。脚本在身份无法确定时会把规则临时
  `enabled=0` 并在日志里警告；修好后记得手动 `enabled=1`。
- **规则被改名/删除**：脚本只记日志跳过，不会创建残缺 section。
- **持久化分层**：`/usr/sbin`、`/etc/hotplug.d` 在 rootfs（squashfs），**只有刷含本提交的固件才带**；
  而规则和 `ax6000.nas.mac` 在 `/etc/config`，刷机保留配置时会继承。两者必须配套 ——
  如果刷了不含本脚本的旧包，规则还在但地址不再自动跟随。

## 首启安全窗口（重要）

1. 用**网线**接 LAN 口，访问 `http://192.168.6.1`。
2. 设置 root 密码。
3. 到 LuCI 手动启用 WiFi；需要 SSH / 网页终端再启用 dropbear / ttyd。

> 首启仍保留 LAN 侧 LuCI（空密码）作为设密码入口，请只在隔离网络里首启。
> 被 `disable` 过的服务不会自动恢复。`block-wan-mgmt` 追加在规则末尾，前面若有自定义 WAN ACCEPT 就不会命中。

## 构建

### 手动触发

- `upstream_ref=pinned`（**默认**）：用 `config/upstream.lock` 钉死的 `458d2f7e`（自己 fork 的 `25.12` HEAD，2026-11-18 与上游同步，run #21 已验证），构建输入固定、可复现。
- `upstream_ref` 填 **40 位小写 SHA**：按该 SHA 做**测试构建**，只上传 artifact、不发 Release。**升级上游走这个入口。**
- `upstream_ref` 留空：解析 fork 的 `25.12` 最新 HEAD（只在刚 sync 完想试探时用，不推荐）。
- `hardening`：`on`（默认，`CHECK_FORMAT_SECURITY`/`RELRO_FULL`/`CCACHE` 全开）/ `off`（临时关这三项定位失败）。
- `jobs` 填 1-64，留空取 `nproc`。

### 上游来源与升级

上游用的是**你自己的 fork** `cczhao12/immortalwrt-mt798x-rebase`，不是 `chasey-dev/` 原库。
好处：上游改名/删库/强推都不影响你，以后想打 patch 也直接在这里改。

升级流程：

1. 在 GitHub 上 sync fork（或把某个上游 commit push 进去）；
2. `workflow_dispatch` 用 `upstream_ref=<新 SHA>` 做测试构建（只产 artifact、不发 Release）；
3. 完整编译成功、上机观察正常后，改 `config/upstream.lock`，并同步检查 `config/feeds.lock` 与 `config/ax6000.config`；
4. `upstream-watch.yml` 每周只做一件事：对比 fork 分支和 lock，**不一致就开 issue 提醒可以升级**，不改构建、不自动发布。

### push tag

`v*` tag 会触发正式构建，tag 直接用你的 tag 名。

> **没有定时触发**：构建只由手动 `workflow_dispatch` 和 `v*` tag 发起；
> `upstream-watch.yml` 每周只做上游可达性提示，不触发构建。

### 自动 tag

```
vYYYY.MM.DD-<上游 sha7>-<本仓库 sha7>
```

`BUILD_DATE` 取自上游 commit 的 `SOURCE_DATE_EPOCH`，同一组输入重建产物字节一致。

### 产物

`out/` 含 `*ax6000-mtkuboot*sysupgrade.bin`、`*.manifest`、`config.buildinfo`、`profiles.json`、
`BUILD_INFO.txt`、`SHA256SUMS.txt`（对除自身外的所有文件做 sha256）、`feeds.lock`。

## 如果这次构建失败

默认就是最激进的输入，所以失败并不意外。**不用改代码**，按下面顺序二分：

1. 先看「编译错误摘要」和 `make -j1 V=s` 的输出，定位到具体出错的 `.c`/`.ko`。
2. 用 `hardening=off` 重跑：判定是不是 `CHECK_FORMAT_SECURITY`/`RELRO_FULL`/`CCACHE` 的问题。
3. 默认已是 pinned（`9f397975`，唯一完整出包过的输入），所以优先怀疑本仓库的 config 改动，而不是上游。
4. 仍失败就逐个回退 config 改动（例如临时恢复 `kmod-nft-compat`），每次重跑。
5. 结论回写 `docs/validation.md`。

> 这些开关只是失败后的排查手段，**不改变默认的激进配置**。

## 刷机

见 [`docs/flashing.md`](docs/flashing.md)。救砖见 [`docs/recovery.md`](docs/recovery.md)。

1. `sha256sum -c SHA256SUMS.txt`
2. LuCI → 系统 → 备份/刷写固件，选 `*ax6000-mtkuboot*sysupgrade.bin`
3. 普通升级保留配置；要干净刷就取消“保留配置”，但会丢 WiFi/自定义 IPv6 规则
4. 刷完等 3-5 分钟，LAN 访问 `192.168.6.1`

## 已知边界

- **性能参数未上机验证**：4 个 sysctl 值都是保守建议；CPU governor 一项已确认本内核不支持（见上）。
- **不做代码签名**：只提供 SHA256，请核对后再刷。
- **CI 只验证编译和配置**：WiFi/HNAT/fullcone 需要上机验证。
- **PR 检查不编译**：`pr-check.yml` 只跑 `make defconfig` + 配置断言，可能出现「PR 绿、build 红」，真正的编译结论以 build workflow 为准。
- **驱动补丁依赖上游代码结构**：见 [`docs/known-issues.md`](docs/known-issues.md)；补丁应用失败时 `WiFi 驱动预编译（smoke）` 会先红，不会浪费整轮。
- **自定义配置不在仓库里**：WiFi SSID/密钥、IPv6 放行规则 `nas_v6_ports` 恢复出厂会丢（刷机保留配置则不丢），先备份 `/etc/config`。
- **全锥形不等于公网 NAT1**：WAN 是 RFC1918 地址，上游还有 CGNAT。
- **只支持 MTK U-Boot 布局**：不要拿 stock bootloader 镜像互刷。

## 目录

```
.github/workflows/build-ax6000.yml            主构建/发布（上游钉死 458d2f7e）
.github/workflows/pr-check.yml               PR / push 配置与脚本校验
.github/workflows/upstream-watch.yml         上游健康提示（不触发构建）
config/ax6000.config                         激进配置（包精简 + 硬化全开 + 关厂商调试）
config/feeds.lock                            2026-11-13 的 5 个 feed SHA
config/upstream.lock                         已验证出过包的上游 SHA（upstream_ref=pinned）
config/required-packages.txt                 构建后必须存在（39 项）
config/forbidden-packages.txt                构建后不应存在（39 项）
files/etc/uci-defaults/99-ax6000-defaults    注入镜像的幂等默认配置 + 性能 sysctl
files/etc/init.d/ledinterval                 LED interval 150ms
files/etc/init.d/ax6000-firstboot-guard      首启无口令保护
files/etc/init.d/ax6000-perf                 CPU 调频探测（本内核无 cpufreq，自动跳过）
files/usr/sbin/nas-v6-firewall               按钉住的 MAC 同步 NAS 的 IPv6 放行地址
files/etc/hotplug.d/iface/90-nas-v6          wan / wan_6 事件触发地址同步
files/etc/init.d/ax6000-nas-v6-watch         每 10 分钟兜底同步（防漏事件，单次带超时）
scripts/validate-config.sh                   静态断言 + defconfig 断言（唯一实现）
docs/changes.md                              变更清单
docs/defaults.md                             默认值明细
docs/validation.md                           成功基线 / 失败对照 / 恢复路线
docs/flashing.md                             刷机
docs/recovery.md                             救砖
docs/ipv6-port-forwarding.md                 NAS IPv6 放行机制（原理 / 漏洞 / 运维）
```

## 许可

构建脚本和配置以 GPL-2.0-or-later 发布；完整文本见 `LICENSE`。固件包含 ImmortalWrt/OpenWrt 及第三方组件，详见 `NOTICE`。商用或公开分发前请自行复核厂商 binary/firmware 的再分发条款。
