# NAS 的 IPv6 端口放行机制

> 目标：只让内网**一台设备**（NAS）从公网访问 `tcp/udp 36353-36354`，
> 并且在前缀变化、设备重启、事件丢失等情况下**自动保持正确**。
>
> 相关脚本：`files/usr/sbin/nas-v6-firewall`、
> `files/etc/hotplug.d/iface/90-nas-v6`、
> `files/etc/init.d/ax6000-nas-v6-watch`。

> 文中所有地址都是文档地址（`2001:db8::/32`，RFC 3849），MAC 是虚构值。
> 真实的前缀、地址、MAC 一律不写进仓库。

## 1. 三个约束

1. **只有 IPv6 公网**。WAN 侧是 RFC1918 + CGNAT，端口映射无从谈起，只能走 v6 直连。
2. **规则不能对全网段开放**。`dest='*'` 等于内网每台设备的这两个端口都对公网可达，
   要收窄就必须指定 `dest_ip`。
3. **地址是动态的**。前缀由 ISP 通过 DHCPv6-PD 下发，重拨、续租、局端调整都会让它变。

三条叠加得出一个结论：**永远不要记录"地址"，只记录"身份"和"当前前缀"。**

## 2. 原理

### 2.1 变的只有前缀

```
2001:db8:aaaa:bbbb : a8bb:ccff:fedd:eeff
└──── 前缀 ────────┘ └── 由 MAC 推出，不变 ──┘
   随 PD 变化
```

所以每次只需要问两个问题：**当前公网前缀是什么**、**这台设备的后缀是什么**。

### 2.2 身份锚点：一个 MAC

MAC 存在设备的 `/etc/config/ax6000`，**不进这个仓库**——仓库是公开的，`files/` 会打进镜像。

- 第一次运行时，脚本从 NAS 的内网 IPv4 查一次 ARP，把 MAC 写回 UCI；
- 之后**永远**用 UCI 里的值，不再信任 ARP。

这条"只学一次"（TOFU）是关键：ARP 应答是无认证的，同网段任何机器都能抢答。
身份钉死之后，抢答就没有意义了。

### 2.3 地址推导顺序

| 顺序 | 做法 | 覆盖什么 |
|---|---|---|
| 1 | 邻居表里 **lladdr 等于该 MAC**、且落在当前前缀内的地址 | 一般情况；顺带兼容不用 EUI-64 的设备 |
| 2 | `当前前缀 + EUI-64(MAC)` | 邻居表为空 / NAS 刚上电还没完成 SLAAC |
| 3 | `当前前缀 + ax6000.nas.suffix` | 想在 NAS 侧关掉 EUI-64 时，显式指定后缀 |

三步都是**确定性**的，不需要猜，也不需要试。

### 2.4 可达性不是身份

旧版用 `ping` 判断候选地址是否可用，这混淆了两件事：

- `ping` 通只说明**有人应答**，不说明应答的是 NAS；
- `ping` 不通也不说明地址错了，可能只是 NAS 离线或屏蔽了 ICMPv6。

而且 NAS 离线时更应该把规则写对，等它上线就能用。所以现在 `ping` 只写进日志，
不参与写回判断。

## 3. 文件与持久化

| 仓库路径 | 镜像内路径 | 作用 |
|---|---|---|
| `files/usr/sbin/nas-v6-firewall` | 同路径 | 解析 + 写回 |
| `files/etc/hotplug.d/iface/90-nas-v6` | 同路径 | 接口事件触发 |
| `files/etc/init.d/ax6000-nas-v6-watch` | 同路径 | 每 10 分钟兜底 |
| `files/etc/uci-defaults/99-ax6000-defaults` | 同路径 | 首次启动 enable 上面那个服务 |

| 操作 | 三个脚本 | `nas_v6_ports` 规则 | `ax6000.nas.*` |
|---|---|---|---|
| 重启 / 断电 | 保留 | 保留 | 保留 |
| 刷机（保留配置） | 随新镜像重新提供 | 保留 | 保留 |
| 刷机（不保留配置） | 随新镜像重新提供 | 丢失，需重建 | 丢失，首次运行重新自举 |
| 恢复出厂 | 随新镜像重新提供 | 丢失 | 丢失 |

> 关键：规则在 `/etc/config`（overlay，刷机保留），脚本在 rootfs（squashfs，随包走）。
> 两者必须配套。刷了不含脚本的镜像，规则还在但地址不再跟随，而且**这个失效是静默的**。
>
> `enable` 产生的 `/etc/rc.d/S99*` 属于 overlay，不在默认 keep 清单里，
> 由 `uci-defaults` 在每次刷机后自动补上——那个文件在 squashfs 里，刷机后自然重新出现。

## 4. 一次前缀变化的完整时序

```
PPPoE 重拨 -> ISP 下发新 PD -> netifd 更新 wan_6 / br-lan -> ifupdate 事件
   |
   v /etc/hotplug.d/iface/90-nas-v6（抢锁）
   v /usr/sbin/nas-v6-firewall
   |- 读 br-lan 当前公网前缀（跳过 ULA / deprecated），norm6 归一化
   |- 邻居表按 lladdr 找该 MAC 在当前前缀内的地址
   |- 没有则用 当前前缀 + EUI-64(MAC)
   |- 与现有 dest_ip 归一化比较，不同才写
   '- uci set -> uci commit -> fw4 reload -> logger
```
## 5. 演进与踩过的坑

| 版本 | 做法 | 为什么改 |
|---|---|---|
| v0 | LuCI 里一条 `dest='*'` | 内网所有设备都开放 |
| v1 | 写死 NAS 的 IPv6 | 前缀一换就失效 |
| v2 | 按 MAC 解析（IP -> MAC -> v6） | 解决漂移，但取"第一个匹配" |
| v3 | 加前缀校验 + ping 校验 + EUI-64 兜底 + 定时器 | 解决旧前缀残留 |
| v4 | `norm6` 归一化 + `flock` + 沿用当前值 | 修压缩地址错位、并发 |
| v5 | 修死分支、去掉"ping 当身份"、TOFU 钉 MAC、过滤 deprecated、`timeout` 包住单次执行 | 见下 |

### 5.1 v4 里三个真实存在的问题

**1. 邻居表分支永远匹配不到。** v4 用 `tolower($3) == mac` 比较 MAC，
但 `ip -6 neigh` 的字段是：

```
2001:db8:aaaa:bbbb:a8bb:ccff:fedd:eeff dev br-lan lladdr aa:bb:cc:dd:ee:ff REACHABLE
                  $1                    $2   $3      $4        $5           $6
```

`$3` 是**接口名**，不是 MAC。于是 v4 的整条邻居表分支是死代码，
实际每次都在走 EUI-64 兜底——NAS 一旦改用 stable-privacy 或隐私地址就彻底失效，
且日志只有一行"没有可用的全局 IPv6"。

**2. ping 被当成身份校验。** 配合"沿用当前值只比较前缀 + ping"，
同网段任何能应答的地址都会被永久认可。NAS 关机期间抢答它的内网 IPv4，
就能把这两个端口的公网转发劫持到自己身上。

**3. `lan_prefixes` 不过滤 `deprecated`。** 前缀轮换时旧 /64 仍以 `deprecated`
挂在 br-lan 上（`valid_lft` 未到期），v4 把它当作"当前持有"，
规则会被钉在废弃前缀上，要等旧前缀彻底过期才自愈。

## 6. 运维

```sh
uci get firewall.nas_v6_ports.dest_ip     # 规则当前指向
uci get ax6000.nas.mac                    # 钉住的 NAS MAC
nft list ruleset | grep 36353             # 实际生效的 nft 规则
logread -e nas-v6-fw | tail -10           # 变更历史 / 失败原因
/etc/init.d/ax6000-nas-v6-watch status    # 兜底服务在跑吗
```

手动触发一次：`/usr/sbin/nas-v6-firewall`

| 日志 | 含义 | 处理 |
|---|---|---|
| `dest_ip X -> Y  [mac ...]  可达` | 正常变更 | 无需处理 |
| `dest_ip X -> Y  [mac ...]  当前不可达` | 地址已写对，但 NAS 现在不应答 | 等它上线；长期如此查 SLAAC |
| `首次运行：把 192.168.6.4 的 MAC 钉入 ...` | 自举完成 | 记下这个 MAC，换 NAS 时要用 |
| `拿不到 NAS 的 MAC ...` | NAS 不在 ARP 表 | 检查 NAS 是否在线 / LAN 口 |
| `br-lan 没有公网 IPv6 前缀` | WAN v6 没起来 | `ubus call network.interface.wan_6 status` |
| `已临时 disable nas_v6_ports` | `dest_ip` 为空且身份未知，按 fail-closed 处理 | 修好后手动 `enabled=1` |

换 NAS：

```sh
uci set ax6000.nas.mac='aa:bb:cc:dd:ee:ff'
uci commit ax6000
/usr/sbin/nas-v6-firewall
```

回滚：把 `dest_ip` 写死成当前地址即可（脚本比较后认为"没变"就不再动），
或者停掉兜底服务：

```sh
/etc/init.d/ax6000-nas-v6-watch stop
/etc/init.d/ax6000-nas-v6-watch disable
```

## 7. 安全边界

| 问题 | 影响 | 现状 |
|---|---|---|
| 前缀变了但既无事件、定时器也未到 | 最多 10 分钟外网不可达 | 接受 |
| 首次自举时有内网机器抢答 ARP | 可能钉错 MAC | 只发生一次，日志会打印钉住的 MAC，发现后手动改 |
| NAS 真的换了、MAC 没更新 | 规则指向不会存在的地址 | fail-closed，日志显示"当前不可达" |
| 每次变化都是全量 `fw4 reload` | 毫秒级中断 | 变化很罕见，接受 |

**以下几件事脚本管不了，建议单独处理：**

- 规则对所有 IPv6 源地址开放，没有白名单。建议加 `src_ip`、只留 `tcp`（去掉 `udp`），
  或者干脆不开口，用 WireGuard / Tailscale 入站。
- EUI-64 的后缀由 MAC 决定，知道 OUI 和 `/64` 后地址是可枚举的（只剩 24 位）。
  不要把"IPv6 地址空间大"当成防护。
- 文档、提交信息、issue 里不要出现真实前缀、真实地址、真实 MAC。
  示例统一用 `2001:db8::/32` 和 `aa:bb:cc:dd:ee:ff`。