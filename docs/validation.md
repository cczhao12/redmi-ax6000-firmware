# 配置验证记录（2026-11-13）

这不是完整编译记录；只验证 `config/ax6000.config` 在上游最新 `25.12` HEAD + 锁定 feeds 下能被 `make defconfig` 接受，并且必需/禁止包断言成立。

## 环境

- Ubuntu 22.04 云主机
- 上游：`chasey-dev/immortalwrt-mt798x-rebase` `25.12` 分支 HEAD `daa7695e855d98abbd1b2df42b1dc03812b267b3`（2026-11-11）
- feeds：`config/feeds.lock` 的 5 个 2026-11-13 SHA
- 命令：`cp config/ax6000.config openwrt/.config && make defconfig`
- 该云主机缺 `ncurses` 头文件，验证时用 `staging_dir/host/.prereq-build` 占位绕过；CI 会安装 `libncurses-dev`，不受此影响。

## 结果

- `make defconfig` 返回 0，写出 `.config` 1367 行。
- `CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_xiaomi_redmi-router-ax6000-mtkuboot=y`
- `CONFIG_PACKAGE_luci=y`
- 必需包：37/37 全部 `=y`。
- 禁止包：39 项 0 命中（含 WOL 的 `luci-app-wol`、`luci-i18n-wol-zh-cn`、`etherwake`）。
- `scripts/validate-config.sh` 对该 `.config` 返回 `OK`。
- 三个 workflow 通过 PyYAML、`actionlint v1.7.12`，17 个 `run` 块通过 `bash -n`。
- `CONFIG_CCACHE=y`、`CONFIG_DEVEL=y`、`CONFIG_TOOLCHAINOPTS=y`、`CONFIG_PKG_CHECK_FORMAT_SECURITY=y`、`CONFIG_PKG_RELRO_FULL=y`。
- `blockd=y`、`kmod-fs-autofs4=y`、`kmod-nft-fullcone=y`、`tc-tiny=y`、`kmod-sched-core=y`、`zram-swap=y`。
- `kmod-fs-vfat`、`kmod-nls-base`、`luci-theme-bootstrap-mod`、`ebtables`、`tcpdump`、`htop`、`nano`、`openssh-keygen`、`wireless-tools`、`kmod-ifb`、`luci-app-wol`、`etherwake` 均未选中。

## 关键发现：`kmod-tcp-bbr` 不能删

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

## 上游 feed 的 Kconfig 警告

`make defconfig` 过程中出现以下递归依赖警告，均来自 feed 包，不是本 config 引入：

- `dnsdist`
- `luci-app-weechat`
- `dnsdist-full`
- `snort3`
- `knot-resolver`
- `openappid`

`defconfig` 仍返回 0；这些包没有被本 config 选中。真正完整编译时如果它们参与构建，需要另行处理 feed 的 Kconfig 问题。

## 没有做的事

- 没有跑完整 `make -j` 编译（耗时和资源不允许在本次验证里完成）。
- 没有上机刷入；WiFi/HNAT/fullcone 的实际行为仍需刷机后验证。
- 没有做代码签名；产物只提供 SHA256。
