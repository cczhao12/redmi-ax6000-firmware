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

## 5. 不要在 `make world` 之前单独编 mt_wifi 做 smoke

试过两次，都失败在与驱动无关的地方：

| run | 报错 | 原因 |
|---|---|---|
| #16 | `staging_dir/host/bin/openssl: No such file or directory` | `make package/xxx/compile` 不会构建 host 工具，缺 `tools/install` |
| #17 | `No rule to make target '.../linux-6.12.112/.config'`（`conninfra` / `gpio-button-hotplug` 失败） | 缺 `target/compile`，内核 `.config` 还没生成；这两个都是内核相关包 |

补齐 `tools/install` + `toolchain/install` + `target/compile` 之后，总耗时与直接 `make world` 基本相同，
收益只剩「早 20 分钟暴露」，不划算，已撤掉。

**兜底方案**（现在的做法）：`make world` 失败后，从日志里解析出 `ERROR: package/xxx failed to build`，
对那个包单独跑 `make <pkg>/compile V=s`。此时内核已编好，依赖齐全，几秒钟就能拿到具体报错行。

> 教训：smoke 这类"提前编译"只有在能便宜地准备好依赖链时才划算；
> OpenWrt 的包依赖内核 `.config`，这个前置本身就是 world 的大部分工作量。

## 6. 不要关 mt_wifi 的厂商调试宏（ICAP / SPECTRUM / AIR_MONITOR / ATE / WARP_DBG）

run #18 实测：关闭 \CONFIG_MTK_ICAP_SUPPORT\ / \CONFIG_MTK_SPECTRUM_SUPPORT\ 后，
\mt_wifi/embedded/common/cmm_info.c\ 编译失败：

\cmm_info.c:19700: error: unknown type name \'PHY_ICS_START_T\'
cmm_info.c:19713: error: \'ICS_MODE\' undeclared
cmm_info.c:19751: error: \'ICS_PARTITION\' undeclared
cmm_info.c:19789: error: \'PHY_ICS_MODE\' undeclared
\
原因：\ICS_*\ 枚举与 \PHY_ICS_START_T\ 类型只在 ICAP / SPECTRUM / PHY_ICS 宏打开时才有定义
（源码注释：\case ICS_MODE: /* 0:icap mode, 1:spectrum mode, 2:phy ics mode */\），
而 \cmm_info.c\ 的使用处没有被同一个 \#ifdef\ 包住。

**结论**：这 6 个厂商调试项（\WARP_DBG\ / \WARP_MEMORY_LEAK_DBG\ / \ATE\ / \AIR_MONITOR\ /
\ICAP\ / \SPECTRUM\）必须保持上游默认 \=y\。关掉换不来可见收益，却会直接打断编译。
\CONFIG_MTK_MGMT_TXPWR_CTRL=y\ 仍然需要 \patches/mt_wifi/042-fix-mgmt-txpwr.patch\，两者独立。

## 7. WiFi 温度显示依赖 wireless-tools（iwpriv）

LuCI 概览页的 `Temperature` 来自 `ubus call luci getTempInfo`，其实现是：

```
getTempInfo  ->  popen('/sbin/tempinfo')
```

`/sbin/tempinfo` 在 `mediatek/filogic` 分支调用 `get_mtwifi_temp()`：

```sh
temp="$(iwpriv ${ifname} stat | awk '/CurrentTemperature/ {printf("%d°C", $3)}')"
```

**必须要有 `iwpriv`（属于 `wireless-tools`）**，否则 `wifi_temp` 为空，
界面只显示 `CPU: xx°C`。所以 `wireless-tools` 不是可选工具，是温度显示的功能依赖。

验证：

```sh
ubus call luci getTempInfo     # 期望 {"tempinfo": "CPU: 41.4°C, WiFi: 48°C/46°C"}
iwpriv ra0 stat | grep CurrentTemperature
```

`apk add wireless-tools` 能临时恢复，但装在 overlay，**刷机/恢复出厂后丢失**，
所以已写进 `config/ax6000.config` 与 `config/required-packages.txt`。
