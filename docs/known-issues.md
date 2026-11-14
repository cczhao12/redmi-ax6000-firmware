# 已知问题

## 1. mt_wifi 在 `CONFIG_MTK_MGMT_TXPWR_CTRL=y` 下编译失败

- **现象**：全量编译末期 `package/mtk/drivers/mt_wifi` 失败：
  ```
  ap_cfg.c:3903: error: implicit declaration of function 'wtbl_update_pwr_offset'
  ```
- **根因**：上游 7.6.7.2（7672）与 7.6.7.3（7673）的 `ap_cfg.c`、`cmm_cfg.c` 在
  `#ifdef MGMT_TXPWR_CTRL` 下调用了 `wtbl_update_pwr_offset()`，但没有 include 声明它的
  `mt_wifi/include/mac/mac_mt/fmac/mt_fmac.h`；`cmm_cfg.c` 同宏下还有两处调用。
- **为什么换 7672 也没用**：两份 tarball 都有同样的缺失。
- **为什么上游没发现**：上游 `defconfig/mt7986-ax6000.config` 也把该选项设为 `y`，
  但没有用这份 defconfig 做全量编译验证。
- **处理**：本仓库 `patches/mt_wifi/042-fix-mgmt-txpwr.patch`，workflow 在 checkout 上游后
  注入到 `patches-7672/` 与 `patches-7673/`（不改 fork，避免 `Sync fork` 的 fast-forward 冲突）。
  补丁哈希写进 `BUILD_INFO.txt` / `/etc/ax6000-build-info`。
- **兜底**：若上游代码变动导致补丁应用失败，`WiFi 驱动预编译（smoke）` 步骤会先失败，
  不会浪费整轮；此时把 `CONFIG_MTK_MGMT_TXPWR_CTRL` 改为不选中即可绕过
  （代价：失去管理帧发射功率控制，家用基本无感）。

## 2. PR 检查只跑 defconfig，不编译

`pr-check.yml` 只做 `make defconfig` + 配置断言，所以同一个 commit 可能出现
"PR 绿、build 红"。看 PR 结论时请注意这个边界，真正的编译结论以 build workflow 为准。

## 3. 全量 `.config` 快照会随上游漂移

`config/ax6000.config` 是完整快照，上游增删符号后 `make defconfig` 会静默归一化。
workflow 对显式键做逐键比对（warning）；关键键（目标机型、WiFi 驱动版本 7673、
`MGMT_TXPWR_CTRL`）已在 `scripts/validate-config.sh` 里升级为硬失败。
中期计划：改成「上游 `defconfig/mt7986-ax6000.config` + 只写差异的 overlay」。

## 4. `kmod-nft-compat` 与 `ip_tables.ko`

`kmod-nft-compat` 的 `DEPENDS` 里有 `+kmod-nf-ipt`，后者要求 `net/ipv4/netfilter/ip_tables.ko`；
而上游 `target/linux/generic/config-6.12` 默认把 `CONFIG_IP_NF_IPTABLES` /
`CONFIG_NETFILTER_XTABLES` 关掉，模块不编，打包时直接 `ERROR: module ... is missing`。
fw4 与 `nftables` 都不依赖它，所以现在直接禁掉。若以后要恢复，必须同时打开那两个内核符号。
