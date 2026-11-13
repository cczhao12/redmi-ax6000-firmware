#!/bin/sh
# 仓库静态断言 + 可选的 defconfig 结果断言。
# 用法:
#   sh scripts/validate-config.sh                  # 只校验仓库内文件（秒级，用于 PR）
#   sh scripts/validate-config.sh openwrt/.config  # 额外校验 make defconfig 结果
set -eu
# 不依赖 dirname：任意目录下都能定位到仓库根。
case "$0" in
  */*) cd "${0%/*}/.." ;;
  *)   cd .. ;;
esac
CONFIG="${1:-}"

fail() { echo "FAIL: $*" >&2; exit 1; }
ok() { echo "OK: $*"; }

# ---------------------------------------------------------------- 1. 固件脚本
FIRMWARE_FILES="files/etc/uci-defaults/99-ax6000-defaults
files/etc/init.d/ledinterval
files/etc/init.d/ax6000-firstboot-guard
files/etc/init.d/ax6000-perf"

for f in $FIRMWARE_FILES; do
  [ -f "$f" ] || fail "缺少固件脚本 $f"
  sh -n "$f" || fail "shell 语法错误: $f"
done

DEFAULTS=files/etc/uci-defaults/99-ax6000-defaults
GUARD=files/etc/init.d/ax6000-firstboot-guard
for needle in 'system.network_led' 'tcpcca=cubic' 'fullcone=1' \
              'flow_offloading=0' 'block-wan-mgmt' 'ax6000-firstboot-guard enable' \
              'mtk_smp enable' 'ax6000-perf enable' \
              'net.netfilter.nf_conntrack_max' 'net.core.netdev_max_backlog' \
              'nf_conntrack_tcp_timeout_established' 'vm.swappiness'; do
  grep -Fq "$needle" "$DEFAULTS" || fail "99-ax6000-defaults 缺少 $needle"
done
for needle in 'ttyd' 'dropbear' 'wifi down'; do
  grep -Fq "$needle" "$GUARD" || fail "ax6000-firstboot-guard 缺少 $needle"
done
grep -Fq 'return 0' files/etc/init.d/ledinterval \
  || fail 'ledinterval 缺少 return 0'
grep -Fq 'return 0' files/etc/init.d/ax6000-perf \
  || fail 'ax6000-perf 缺少 return 0'
grep -Fq 'scaling_governor' files/etc/init.d/ax6000-perf \
  || fail 'ax6000-perf 缺少 CPU governor 处理'
ok '固件脚本静态校验'

# ---------------------------------------------------------------- 2. 包清单
for f in config/required-packages.txt config/forbidden-packages.txt; do
  [ -f "$f" ] || fail "缺少 $f"
  [ -z "$(tail -c 1 "$f")" ] \
    || fail "$f 末行没有换行（while read 会漏掉最后一个包）"
done
for f in config/required-packages.txt config/forbidden-packages.txt; do
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    [ "${p#\#}" = "$p" ] || continue
    printf '%s' "$p" | grep -Eq '^[a-zA-Z0-9][a-zA-Z0-9._+-]*$' \
      || fail "$f 里有非法包名: $p"
  done < "$f"
done
while IFS= read -r p; do
  [ -n "$p" ] || continue
  [ "${p#\#}" = "$p" ] || continue
  if grep -Fxq "$p" config/forbidden-packages.txt; then
    fail "$p 同时出现在必需和禁止清单"
  fi
done < config/required-packages.txt
ok '包清单格式校验'

# ---------------------------------------------------------------- 3. feeds.lock
[ -f config/feeds.lock ] || fail '缺少 config/feeds.lock'
[ -z "$(tail -c 1 config/feeds.lock)" ] \
  || fail 'config/feeds.lock 末行没有换行'
feed_count=0
while IFS=' ' read -r name sha rest; do
  [ -n "$name" ] || continue
  [ "${name#\#}" = "$name" ] || continue
  [ -n "$sha" ] || fail "feeds.lock 行缺少 SHA: $name"
  printf '%s' "$sha" | grep -Eq '^[0-9a-f]{40}$' \
    || fail "feeds.lock 的 $name SHA 不是 40 位小写 hex: $sha"
  [ -z "$rest" ] || fail "feeds.lock 的 $name 有多余字段"
  feed_count=$((feed_count + 1))
done < config/feeds.lock
[ "$feed_count" -ge 1 ] || fail 'feeds.lock 没有有效条目'
ok "feeds.lock 校验（${feed_count} 个 feed）"

# ---------------------------------------------------------------- 4. defconfig
if [ -n "$CONFIG" ]; then
  [ -f "$CONFIG" ] \
    || fail "找不到 $CONFIG（先 cp config/ax6000.config openwrt/.config && make defconfig）"
  grep -Fxq 'CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_xiaomi_redmi-router-ax6000-mtkuboot=y' "$CONFIG" \
    || fail '没有选中 xiaomi_redmi-router-ax6000-mtkuboot'
  grep -Fxq 'CONFIG_PACKAGE_luci=y' "$CONFIG" \
    || fail 'LuCI 没有被显式选中'

  while IFS= read -r p; do
    [ -n "$p" ] || continue
    [ "${p#\#}" = "$p" ] || continue
    grep -Fxq "CONFIG_PACKAGE_${p}=y" "$CONFIG" || fail "缺少必需包: $p"
  done < config/required-packages.txt

  while IFS= read -r p; do
    [ -n "$p" ] || continue
    [ "${p#\#}" = "$p" ] || continue
    if grep -Fxq "CONFIG_PACKAGE_${p}=y" "$CONFIG"; then
      fail "不应出现的包: $p"
    fi
  done < config/forbidden-packages.txt
  ok "defconfig 断言: $CONFIG"
fi

echo 'OK: 全部校验通过'
