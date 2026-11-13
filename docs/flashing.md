# 刷机

> 只适用于 **Xiaomi Redmi Router AX6000 / MT7986A / MTK U-Boot 布局**。  
> 不要刷 stock bootloader 布局的镜像；不要把别的机型镜像改文件名硬刷。

## 0. 先备份

SSH 或 LuCI 里：

```sh
sysupgrade -b /tmp/ax6000-backup-$(date +%Y%m%d).tar.gz
```

把生成的 tar.gz 下载到电脑。它会包含 `/etc/config`（WiFi、防火墙、DHCP、自定义规则等）。

## 1. 校验

把 `*ax6000-mtkuboot*sysupgrade.bin`、`SHA256SUMS.txt`、`BUILD_INFO.txt` 放到同一目录：

```sh
sha256sum -c SHA256SUMS.txt
```

Windows 可用：

```powershell
Get-FileHash .\*ax6000-mtkuboot*sysupgrade.bin -Algorithm SHA256
```

和 `SHA256SUMS.txt` 里的值对比。

## 2. LuCI 刷写

1. 浏览器打开 `http://192.168.6.1`。
2. 系统 → 备份/刷写固件。
3. 选择 `*ax6000-mtkuboot*sysupgrade.bin`。
4. **普通升级**：保留“保留配置”勾选；WiFi、防火墙、自定义规则都会保留。
5. **干净刷/恢复出厂**：取消“保留配置”；WiFi SSID/密钥、IPv6 规则 `fn` 等会丢，需重新配。
6. 点“刷写”，期间不要断电、不要关网页。

## 3. CLI 刷写

把镜像传到路由器 `/tmp`：

```sh
sysupgrade -v /tmp/*ax6000-mtkuboot*sysupgrade.bin
```

干净刷：

```sh
sysupgrade -n -v /tmp/*ax6000-mtkuboot*sysupgrade.bin
```

`-n` 不保留 `/etc/config`；适合大版本切换或配置已经乱了。

## 4. 首次启动

- 等 3-5 分钟（MTK WiFi 驱动首次初始化会慢）。
- 网线接 LAN 口，访问 `http://192.168.6.1`。
- 如果 root 密码为空：ttyd 和 WiFi 默认被关闭；先设 root 密码，再到 LuCI 手动启用 WiFi/ttyd。
- 如果保留了原配置且有 root 密码：首启保护不会触发，ttyd/WiFi 按原配置。

## 5. 刷完建议检查

```sh
# 版本/构建信息
cat /etc/ax6000-build-info

# HNAT
cat /sys/kernel/debug/hnat/hook_toggle
grep -E 'NAPT|IPv6_5T' /sys/kernel/debug/hnat/hnat_entry | head

# TurboACC
uci show turboacc

# TCP CC
sysctl net.ipv4.tcp_congestion_control

# fullcone
uci show firewall | grep -E 'fullcone|flow_offloading'

# 包集合
apk list --installed | wc -l
apk list --installed | grep -E 'kmod-tcp-bbr|luci-theme-bootstrap-mod|ebtables|tcpdump|htop|nano'
```

预期：`hook_toggle=enabled`；`tcpcca=cubic`；`fullcone=1`；`flow_offloading=0`。`kmod-tcp-bbr` 会出现（`luci-app-turboacc-mtk` 的 select 依赖），这是正常的；它不等于 BBR 已启用，运行值以 `sysctl` 为准。

## 6. 回滚

- 如果还能进 LuCI：直接刷回上一个 `*sysupgrade.bin`。
- 如果进不了系统：见 [`recovery.md`](recovery.md)。
- 配置备份可用 `sysupgrade -r` 恢复（在能进系统时）。
