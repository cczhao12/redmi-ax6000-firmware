# 默认值明细

`package/base-files/files/etc/uci-defaults/99-ax6000-defaults` 是幂等的：  
只在对应值为空（或仍是上游默认）时写入，避免每次 sysupgrade 覆盖你手改的设置。

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
| `wireless.<dev>.country` | `CN` | 仅当为空 |
| `wireless.<dev>.channel`（band=2g） | `1` | 仅当为空/`auto` |
| 5G 信道 | 不写 | 沿用设备/上游 |
| SSID/加密/密钥 | 不写 | 仓库不保存你的 WiFi 配置 |

## 服务

| UCI / 文件 | 值 | 条件 |
|---|---|---|
| `uhttpd.main.listen_http` | `0.0.0.0:80` + `[::]:80` | 仅当为空或只有 `0.0.0.0:80` |
| `turboacc.config.fastpath` | `mediatek_hnat` | 仅当为空（上游通常已自动探测） |
| `turboacc.config.fastpath_mh_bind_rate` | `30` | 仅当为空 |
| `turboacc.config.fastpath_mh_update_nfct` | `0` | 仅当为空 |
| `turboacc.config.tcpcca` | `cubic` | 仅当为空；以后要 BBR 改这里，升级不会被重置 |
| `firewall.@defaults[0].fullcone` | `1` | 仅当为空 |
| `firewall.@defaults[0].fullcone6` | `0` | 仅当为空 |
| `firewall.@defaults[0].flow_offloading` | `0` | 由 config（`CONFIG_PACKAGE_TURBOACC_INCLUDE_FLOW_OFFLOADING` 未设）保证；不写默认脚本 |
| `firewall.@defaults[0].flow_offloading_hw` | `0` | 同上 |
| `/etc/init.d/ledinterval` | 启用 | 每次检查；`START=97`，写 150ms 到 `rgb:status`/`rgb:network` |
| `/etc/config/upnpd` | 删除 | 每次（本版不装 UPnP） |

## 防火墙

自动规则 `block-wan-mgmt`（只在不存在时新增）：

```
config rule
    option name 'block-wan-mgmt'
    option src 'wan'
    option proto 'tcp'
    option dest_port '22 80 7681'
    option target 'REJECT'
```

只挡 WAN 侧管理面；不影响 LAN 访问 LuCI/SSH/ttyd，也不会删你已有的规则。

## 首启保护

`/etc/init.d/ax6000-firstboot-guard`（`START=99`）在每次 boot 检查：

```
root 密码字段长度 == 0
  → /etc/init.d/ttyd disable
  → 所有 wifi-device disabled=1
  → uci commit wireless
  → wifi down
```

`99-ax6000-defaults` 首次启动也做同样检查，保证新刷/恢复出厂时不会把 ttyd 和默认 WiFi 暴露出来。

## 不写的值

- WAN 协议（PPPoE/DHCP/静态）——你的宽带账号密码不放进仓库。
- WiFi SSID/密钥/加密方式——不放进仓库。
- 自定义 IPv6 放行规则（例如 `fn`，dest_port 36353-36354）——不放进仓库。
- 5G 信道/带宽——不锁，沿用设备默认。
