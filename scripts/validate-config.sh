#!/bin/sh
# 本地 / PR 用的配置断言；workflow 里也有一份等价的检查。
# 用法: sh scripts/validate-config.sh [openwrt/.config]
set -eu
cd "$(dirname "$0")/.."
CONFIG="${1:-openwrt/.config}"

if [ ! -f "$CONFIG" ]; then
  echo "找不到 $CONFIG（先 cp config/ax6000.config openwrt/.config && make defconfig）"
  exit 1
fi

fail() {
  echo "FAIL: $*"
  exit 1
}

grep -q '^CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_xiaomi_redmi-router-ax6000-mtkuboot=y' "$CONFIG" \
  || fail "没有选中 xiaomi_redmi-router-ax6000-mtkuboot"
grep -q '^CONFIG_PACKAGE_luci=y' "$CONFIG" \
  || fail "LuCI 没有被显式选中"

while IFS= read -r p || [ -n "$p" ]; do
  [ -n "$p" ] || continue
  [ "${p#\#}" = "$p" ] || continue
  grep -q "^CONFIG_PACKAGE_${p}=y" "$CONFIG" || fail "缺少必需包: $p"
done < config/required-packages.txt

while IFS= read -r p || [ -n "$p" ]; do
  [ -n "$p" ] || continue
  [ "${p#\#}" = "$p" ] || continue
  if grep -q "^CONFIG_PACKAGE_${p}=y" "$CONFIG"; then
    fail "不应出现的包: $p"
  fi
done < config/forbidden-packages.txt

for f in \
  openwrt/package/base-files/files/etc/uci-defaults/99-ax6000-defaults \
  openwrt/package/base-files/files/etc/init.d/ledinterval \
  openwrt/package/base-files/files/etc/init.d/ax6000-firstboot-guard \
  openwrt/package/base-files/files/etc/ax6000-build-info
do
  if [ -e "$f" ]; then
    echo "OK: 已注入 $f"
  fi
done

DEFAULTS=openwrt/package/base-files/files/etc/uci-defaults/99-ax6000-defaults
if [ -f "$DEFAULTS" ]; then
  grep -q "system.network_led" "$DEFAULTS" \
    || fail "默认脚本缺少第二颗灯配置"
  grep -q "tcpcca='cubic'" "$DEFAULTS" \
    || fail "默认脚本缺少 tcpcca=cubic"
  grep -q "fullcone='1'" "$DEFAULTS" \
    || fail "默认脚本缺少 fullcone=1"
fi

echo "OK: $CONFIG 通过校验"
