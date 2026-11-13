# Changelog

## 2026-11-13 — 平衡最终版（当前版本：改进全编入，只回退 4 项）

上一版为追求成功率把编译输入整体退回 `714b898`，等于把用户要的改进全砍了。本版重做：
**除下列 4 项外，所有改进都编入固件**。

### 只回退的 4 项

| 项 | 回退到 | 硬理由 |
|---|---|---|
| 上游「每次解析 `25.12` 最新 HEAD」 | 钉死 `9f397975...`（run #5 成功出包那次） | 主仓库代码直接决定 `package/kernel/linux`；run #7 换成 `daa7695e` 后失败在 `ERROR: package/kernel/linux failed to build.` |
| feeds 锁到 2026-11-13 HEAD | 锁到 run #5 触发时刻（`luci c38e5665`、`routing 48c80803`） | 与钉死上游配套；这两个 feed 前进过 |
| `CONFIG_PKG_CHECK_FORMAT_SECURITY=y` | 关闭 | 给所有包（含内核模块）加 `-Werror=format-security`，失败首要嫌疑 |
| 显式 `CONFIG_PACKAGE_kmod-nft-fullcone=y` | 不写 | 用上游 tree 核实 `9f397975` 里**没有这个包**，写了也会被 defconfig 丢弃；`fullcone=1` 靠 uci-defaults + fw4/libnftnl |

### 编入固件的改进（编译侧）

- **包精简、移除 WOL**（3d34 的核心诉求）全部恢复。
- `hnat-detect` / `mtk-smp` 显式锁定（已核实 `9f397975` 的 `package/mtk/applications/` 下两者都有；
  run #5 的 build.log 里 `hnat-detect` 本来就被编译过）。
- `CONFIG_CCACHE=y`、`CONFIG_PKG_RELRO_FULL=y`、`CONFIG_PKG_FORTIFY_SOURCE_2=y` 保留。
- 删除上游已不存在的 `TURBOACC_INCLUDE_*` 残留选项；不注入 BBR sysctl，`tcpcca=cubic`。
- 必需 / 禁止清单恢复到 39 / 39（去掉上游不存在的 `kmod-nft-fullcone`）。

### 编入固件的改进（运行时 + 工程化）

- `files/` 下 4 个脚本：首启无口令保护、幂等默认值、显式 `flow_offloading=0` / `fullcone=1`、
  WAN REJECT `family=any`、LED、`/etc/sysctl.conf` 四键、可选 CPU governor 档位、build-info。
- 脚本抽成仓库文件 + `cmp` 注入校验、断言统一、build/release 拆分与 `GH_REPO`、
  `SHA256SUMS.txt` 排除自身、`SOURCE_DATE_EPOCH`、逐键 config 差异、`jobs` 校验、
  失败错误摘要 + `-j1 V=s` 增量重试、无定时触发、全套文档。

### 校验

39 项必需包 / 39 项禁止包断言通过；三个 workflow 的 YAML 与 18 个 run 块 `bash -n` 通过；
5 个 shell 文件 `sh -n` 通过；上游 SHA、feeds.lock、`-j1 V=s` 均有断言覆盖。

## 2026-11-13 — 稳定优先版（已废弃，仅作历史记录）

### 为什么

用户要的是「极有可能编译成功的最终版」，不是诊断版。run #7 已确认失败在
`ERROR: package/kernel/linux failed to build.`；而 run #5（`714b898`）在同样的
`ubuntu-22.04` runner 上完整跑到 `make[2] checksum` 成功出包。
所以把**全部编译输入**原样搬回那次成功构建，只保留不参与编译的改进。

### 编译输入对照

| 项 | 本版（最终版） | 上一版（失败） |
|---|---|---|
| 上游 | 钉死 `9f397975c7b47ce6986a6e39529d2f72fd5c729d` | 每次解析 `25.12` HEAD `daa7695e...` |
| feeds | 锁到 run #5 时刻：`luci c38e5665`、`routing 48c80803`（另 3 个相同） | 锁到 2026-11-13：`luci 8f18275b`、`routing 625f9d84` |
| `config/ax6000.config` | 逐行回退到 `714b898` 的成功配置 | 3d34/3892 改动版 |
| 编译硬化 | 全关：无 `CCACHE`、无 `CHECK_FORMAT_SECURITY`、无 `RELRO_FULL` | 三项全开 |
| 包集合 | 成功基线原样（含 WOL、ATA/SCSI/VFAT/NLS、ebtables、tcpdump 等） | 精简版 |
| 必需 / 禁止清单 | 37 / 9（与基线 config 一致） | 40 / 39 |
| 编译命令 | `make -j$(nproc)` + 同 step 内 `make -j1 V=s` 增量重试 | 无重试 |

feed SHA 用 GitHub API `commits?sha=openwrt-25.12&until=2026-11-06T06:46:33Z` 还原到 run #5 触发时刻。
`pr-check.yml` 改用同一个钉死 SHA；`upstream-watch.yml` 降级为纯健康提示，不再暗示默认构建依赖分支 HEAD。

### 保留的改进（全部不参与编译）

- `files/` 下 4 个运行时脚本：幂等 uci-defaults（显式 `flow_offloading=0` / `fullcone=1`）、
  首启无口令保护（ttyd + dropbear + WiFi）、LED interval、可选 CPU governor 档位。
- 性能 / 稳定性：`mtk_smp` enable 兜底、`/etc/sysctl.conf` 4 个键、`ax6000-perf`。
- 工程化：脚本抽成仓库文件 + `cmp` 注入校验、断言统一到 `validate-config.sh`、
  build/release 拆分与 `GH_REPO`、`SHA256SUMS.txt` 排除自身、`SOURCE_DATE_EPOCH`、
  逐键 config 差异检查、`jobs` 校验、失败错误摘要 + `-j1 V=s` 重试、无定时触发。
- 全部文档与评审记录。

### 暂缓的改动（编译通过后逐项 A/B 恢复）

1. 先跑一次完整构建确认出包；
2. 单独开 `CONFIG_PKG_CHECK_FORMAT_SECURITY=y`，验证它是不是 `package/kernel/linux` 的元凶；
3. 再依次试 `RELRO_FULL` → `CCACHE` → 上游新 HEAD + 对应 feeds.lock → 包精简 / 移除 WOL。
   每项单独提交、单独完整编译，失败即可定位。回退方法见 `docs/validation.md`。

## 2026-11-13 — 针对真实构建失败 run 43415503297 的加固（日志已拿到，结论更新）

### 真实报错

用仓库所有者的只读 PAT 下载到了失败 `build.log`（6143 字节）和完整 job logs，最后三行是：

```
    ERROR: package/kernel/linux failed to build.
make -r world: build failed. Please re-run make with -j1 V=s or V=sc for a higher verbosity level to see what's going on
make: *** [.../include/toplevel.mk:233: world] Error 1
```

`编译` step 跑了 49.1 分钟后 `exit 2`，前 11 个 step 全绿。失败包是 **`package/kernel/linux`**（所有内核模块）；非 verbose 模式下看不到是哪个 kmod 出错，**必须 `-j1 V=s` 重跑才有完整报错**。

### 与成功构建的量化对照

| 指标 | 成功 run #5（`714b898` / `9f397975`） | 失败 run #7（`3892b02` / `daa7695e`） |
|---|---|---|
| `make[1] world` 轮数 | 1 | 1 |
| `arm-trusted-firmware-mediatek compile` 次数 | 8 | 8 |
| `tools/ccache compile` | 0 | **1** |
| `package/kernel/linux` | 1（成功） | 2（1 次 compile + 1 次 ERROR） |
| `ERROR:` | 0 | 1 |
| `make[2] checksum` | 1（完整跑到出包） | 0 |

- ATF 重复 8 次在成功/失败里**都有**，不是并行竞态特有；`world` 都是 1 轮，说明 **run #5 并没有触发 `714b898` workflow 里的 `-j1` 重试就成功了**。
  → 修正上一版推断：不能说「成功是靠重试救回来的」。重试是容错 / 诊断手段，不是已验证的修复。
- 6 处 `tmp/.config-package.in: recursive dependency detected!` 两次构建都有（来自 feeds，`docs/validation.md` 早已记录），不是本次失败原因。
- 原版那条 `config/ax6000.config 与 make defconfig 输出有差异` warning 的 `head -200` 全是 defconfig 补的 `CONFIG_BUSYBOX_CONFIG_*` 默认值，纯噪声。逐键比对（上一轮已改）才有诊断价值。
- 真正的编译侧差异：`CONFIG_CCACHE=y`（失败日志里多了 `tools/ccache compile`）、上游换成 `25.12` HEAD + 锁定 feeds、`CHECK_FORMAT_SECURITY` / `RELRO_FULL` 硬化、包精简。
- 首要嫌疑：`CONFIG_PKG_CHECK_FORMAT_SECURITY=y`（`-Werror=format-security`，厂商 / 内核模块最容易踩）与上游 `25.12` HEAD 的 kmod 兼容性。**未经 V=s 日志确认，不下定论。**

### 本轮改动（诊断优先）

- **恢复 `make -j1 V=s` 增量重试**：`3d34af8` 以「全量 -j1 重试做不完」为由删掉，但 OpenWrt `make` 是增量的，重试只继续未完成的包；更关键的是 **make 自己就提示 `re-run with -j1 V=s`**，这一步能在失败时自动产出定位所需的详细日志。重试必须放在**同一个 step 内**——单开 `if: failure()` 的 step 即使成功也无法撤销 job 的失败状态。
- 失败时先 grep 错误摘要（`error:` / `Error N` / `No rule` / `Killed` / `undefined reference` / `failed`），再 `tail -200`，再重试；`编译` step 超时 300 → 335 分钟。

### 结论

**本改进版仍会在 `package/kernel/linux` 处失败**（编译输入与 #7 一致，重试修不了确定性编译错误），但会产出 `V=s` 详细日志。下一步：跑一次改进版构建拿 V=s 日志定位具体 kmod；或按 README「编译失败排查」先 `jobs=1`、临时关 3 个硬化选项做 A/B。

## 2026-11-13 — 追加调整（移除定时构建 + 性能/稳定性）

### 按需求移除定时构建

- 删除 `build-ax6000.yml` 的 `on: schedule` 触发，以及 `src` 步骤里定时 run 专属的 `RELEASE=false` 逻辑。
- 同步删掉 README / CHANGELOG / docs 里的定时构建描述。**构建只由手动 `workflow_dispatch` 和 `v*` tag 发起**；`upstream-watch.yml` 仍只做可达性告警，不触发构建。
- artifact 的 `retention-days` 与定时无关，保留。

### 性能 / 稳定性（实验性，未上机验证）

依据来自上游 `25.12` 源码，不是凭空加参数：

- `package/mtk/applications/mtk-smp/files/smp.sh` 的 `setup_model()` 有 `*mediatek,mt7986*)` → `MT7986_whnat` 分支，做 IRQ 亲和性 + RPS 多核分担。核实 `default_postinst` 会自动 enable 包内 init 脚本，所以 `99-ax6000-defaults` 里的 `/etc/init.d/mtk_smp enable` 是**兜底**而非"修复白装"，防止上游改包结构后静默失效。
- 上游 `package/base-files/files/etc/sysctl.conf` 明确写着自定义 sysctl 应写该文件、不要写 `/etc/sysctl.d/*`（后者默认不备份、`10-default.conf` 升级会被覆盖）。据此用 awk 按 key 幂等替换 4 个值：
  - `net.netfilter.nf_conntrack_max=65536`（HNAT + 多连接，表满会丢新建连接）
  - `net.core.netdev_max_backlog=16384`（四核 + RPS 下小包突发）
  - `net.netfilter.nf_conntrack_tcp_timeout_established=86400`（僵死连接从 5 天缩到 1 天）
  - `vm.swappiness=100`（配合已装 `zram-swap`，降低 OOM 概率）
  - 首次启动 `sysctl -p` 立即应用；之后由 `/etc/init.d/sysctl` 负责。
- **不**加 `kernel.panic_on_oops`：上游 `10-default.conf` 已有 `kernel.panic=3`，内核也有 `CONFIG_MEDIATEK_WATCHDOG=y`，把 oops 变 panic 容易让驱动偶发异常变成循环重启。
- 上游 `target/linux/mediatek/filogic/config-6.12` 同时编了 `CONFIG_CPU_FREQ_GOV_PERFORMANCE=y` 和默认 `CONFIG_CPU_FREQ_DEFAULT_GOV_SCHEDUTIL=y`。新增 `files/etc/init.d/ax6000-perf`，每次 boot 读 `ax6000.perf.cpu_governor`，**默认 `schedutil`（零行为变化）**，可改 `performance` 并一键回退；governor 名做白名单校验，sysfs 不可写时静默跳过。
- `scripts/validate-config.sh` 与 build workflow 的 `chmod` / `cmp` 列表同步纳入新脚本，并断言 `mtk_smp enable`、4 个 sysctl key、`scaling_governor`、`return 0`。
- `config/ax6000.config` **不动任何编译选项**：MTK 厂商调试开关（WARP_DBG / WARP_MEMORY_LEAK_DBG / ATE / AIR_MONITOR / ICAP / SPECTRUM）会影响闭源 WiFi 驱动编译，只在注释里记为「下一步可选优化，需单独一轮完整编译 + 上机验证」。

## 2026-11-13 — review 修订（基于 `3892b02`）

### 修复

- `release` / `upstream-watch` 两个 job 没有 `actions/checkout`，显式设置 `GH_REPO` 并给所有 `gh` 命令传 `--repo`；`gh release create` 补 `--target "${GITHUB_SHA}"`。
- `SHA256SUMS.txt` 生成时排除清单自身，避免复用 `out/` 时把旧清单算进去、随后被覆写导致 `sha256sum -c` 失败。
- `BUILD_INFO.txt` 和 `/etc/ax6000-build-info` 的 `BUILD_DATE` 改用 `SOURCE_DATE_EPOCH`，同一组输入重建产物一致，tag 幂等 / `--clobber` 才成立。
- 首启保护补 `dropbear disable`；空密码判定扩展到 `!` / `*` 锁定标记和 `/etc/shadow` 缺失；uci-defaults 首次启动也执行 `wifi down`。
- 显式写入 `flow_offloading=0` / `flow_offloading_hw=0`。`3892b02` 删除了上游早已不存在的 `TURBOACC_INCLUDE_*` 残留选项后，这两个值实际没有任何代码落地，只靠 fw4 默认值；`docs/defaults.md` 却仍引用已删除的选项。
- `block-wan-mgmt` 加 `family=any`，覆盖 IPv6。
- `ledinterval` / `ax6000-firstboot-guard` 的 `boot()` 显式 `return 0`，避免最后一次 `[ -d ] && ...` 短路返回 1。

### 工程化

- 三个注入脚本从 workflow heredoc 抽到 `files/`：build 用 `cp -a` 注入 + `cmp` 校验一致性，PR 可以 `sh -n` 校验语法与关键内容，避免再现 `3892b02` 里“脚本写了但忘了 enable”的问题。
- 断言逻辑统一到 `scripts/validate-config.sh`：删掉 build workflow 里重复且已漂移的必需/禁止包循环；新增清单末行换行、包名格式、required/forbidden 冲突、`feeds.lock` 格式与数量校验；包匹配改用 `grep -Fx` 避免正则通配。
- `config` 与 `make defconfig` 的差异检查改为只比对仓库显式声明的键，不再每次因 defconfig 补默认值而刷屏。
- `jobs` 输入校验 1-64；`预下载源码` 加 45 分钟上限；编译失败打印 `build.log` 尾部；artifact 加 `retention-days`。
- `pr-check` 增加 `files/**` 路径与 push main 触发；`upstream-watch` 的 issue 查重加 `--state all`；`pr-check` 的 feed 锁定补上 HEAD 一致性断言（此前只有 build workflow 有）。
- 按需求**不引入定时触发**，构建入口保持手动 + `v*` tag 两个。

### 文档

- 补记 `3892b02` 的改动；修正 `docs/validation.md` 里 37/37 的过时数字并标注未重新做完整 defconfig；同步默认值、目录、首启说明和已知边界。

## 2026-11-13 — `3892b02`（原仓库，补记）

- 首启保护脚本补 `/etc/init.d/ax6000-firstboot-guard enable`（此前脚本存在但从未被启用，保护逻辑等于没跑）。
- 必需/禁止包 `while read` 加 `|| [ -n "$p" ]`，修复清单末行无换行时漏检最后一个包。
- `pr-check.yml` 从钉死 `9f397975...` 改为解析 `25.12` 最新 HEAD；`upstream-watch.yml` 的 jq 加 `// empty`。
- config 新增 `hnat-detect` / `mtk-smp`（上游 25.12 的 HNAT 检测与 SMP 调优），移除上游已不存在的 `TURBOACC_INCLUDE_*` 残留选项；required 清单同步加 `hnat-detect` / `mtk-smp` / `ip-bridge`。
- 未同步：CHANGELOG、README、`docs/validation.md`（仍写 37/37）、`docs/defaults.md`（仍引用已删除选项）。

## 2026-11-13 — one-shot (`3d34af8`)

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
