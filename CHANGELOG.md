# Changelog

## 2026-11-13 — one-shot

### 构建 / 发布
- 拆分 build（`contents: read`）与 release（`contents: write` + `environment: release`）两个 job。
- 默认跟进上游 `25.12` 分支 HEAD；每次 run 解析最新 40 位 SHA，实际 SHA 写入 `BUILD_INFO` 和 tag。
- `source_ref` 留空 = 跟进最新；填 40 位小写 commit SHA = 钉死测试构建，不发 Release。
- `jobs` 输入走 env，不再直接拼进 shell。
- tag 增加本仓库 commit：`vYYYY.MM.DD-<上游sha7>-<本仓库sha7>`。
- `BUILD_INFO.txt` 先生成，再 `sha256sum ./*`；BUILD_INFO 纳入校验。
- 收集 `*ax6000-mtkuboot*`、`.manifest`、`config.buildinfo`、`profiles.json`、`feeds.lock`。
- 注入 `/etc/ax6000-build-info`，镜像可自证上游/本仓库/config/feeds 版本。
- 去掉全量 `-j1` 重试；build step 300 分钟，失败保留 `build.log`。
- 新增 ccache 缓存、`SOURCE_DATE_EPOCH`、`feeds.lock` 锁定。

### 配置
- 保留 `CONFIG_PACKAGE_kmod-tcp-bbr`（`luci-app-turboacc-mtk` 的 select 依赖），但删除 BBR sysctl；`tcpcca` 保持 cubic。
- 显式 `CONFIG_PACKAGE_kmod-nft-fullcone=y`。
- 新增 `CONFIG_CCACHE=y`、`CONFIG_PKG_CHECK_FORMAT_SECURITY=y`、`CONFIG_PKG_RELRO_FULL=y`。
- 保留 `CONFIG_DEVEL`/`CONFIG_TOOLCHAINOPTS`，避免工具链变化。
- 精简 ATA/SCSI/VFAT/NLS、ebtables、tcpdump/libpcap/libcap-ng、htop/nano/libncurses/terminfo、openssh-keygen/libfido2/libcbor/libevdev/libudev-zero、wireless-tools、`luci-theme-bootstrap-mod`、`kmod-ifb`、WOL（`luci-app-wol`/`luci-i18n-wol-zh-cn`/`etherwake`）。
- 保留 `blockd`/`kmod-fs-autofs4`（依赖）、`libblkid`、`tc-tiny`/`kmod-sched-core`、zram、ttyd、autoreboot、sftp-server。

### 默认值 / 安全
- `99-ax6000-defaults` 改为幂等：只在值为空/上游默认时写 hostname、LED、uhttpd、WiFi country/ch1、TurboACC、fullcone。
- 首启 root 密码为空：ttyd disable + 所有 wifi-device disable + `wifi down`；`ax6000-firstboot-guard` 每次 boot 兜底。
- 自动加 WAN 管理面 `block-wan-mgmt`（22/80/7681 REJECT）。
- 保留 `fullcone=1`、`fullcone6=0`、`flow_offloading=0`、`fastpath=mediatek_hnat`。
- 保留 235/255/0 双灯、ledinterval 150ms、2.4G ch1、uhttpd 双栈。

### 仓库
- 新增 README、LICENSE、NOTICE、CHANGELOG、docs/flashing、docs/recovery、docs/defaults、docs/changes。
- 新增 `scripts/validate-config.sh`、`pr-check.yml`、`upstream-watch.yml`、`dependabot.yml`、`.gitignore`。
- 新增 `docs/validation.md`：记录 `make defconfig` 验证结果与 `kmod-tcp-bbr` 的 select 依赖。
- feeds 锁定到 2026-11-13 的 5 个 SHA。
