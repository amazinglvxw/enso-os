#!/usr/bin/env bash
# pac-pending-check.sh — SessionStart Hook: 检查并注入未回答的 PAC 挑战
#
# 流程:
#   1. 扫描 ~/.enso/pac/pending/ 目录
#   2. 找到最近的 pending 挑战 (按时间戳排序)
#   3. 输出 XML 供 claude-code 注入到对话上下文
#   4. 挑战保留在 pending/ 直到用户回答 (通过 stop hook 处理)
#
# 设计原则:
#   - 非阻断: 静默失败不影响 session 启动
#   - 最多注入 1 个挑战 (避免信息轰炸)
#   - 若距上次挑战 >30 天,提示用户是否主动废弃

set -euo pipefail

PAC_ENABLED="${PAC_ENABLED:-true}"
[ "$PAC_ENABLED" != "true" ] && exit 0

PAC_DIR="${ENSO_PAC_DIR:-$HOME/.enso/pac}"
PENDING_DIR="$PAC_DIR/pending"

# 无 pending 目录: 静默退出
[ ! -d "$PENDING_DIR" ] && exit 0

# 找到最近的 pending 挑战 (按修改时间倒序,取第一个)
LATEST_PENDING=""
LATEST_MTIME=0

for f in "$PENDING_DIR"/pac-*.xml; do
    [ ! -f "$f" ] && continue
    MTIME=$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo "0")
    if [ "$MTIME" -gt "$LATEST_MTIME" ]; then
        LATEST_MTIME="$MTIME"
        LATEST_PENDING="$f"
    fi
done

[ -z "$LATEST_PENDING" ] && exit 0
[ ! -r "$LATEST_PENDING" ] && exit 0

# 计算距今天数
NOW=$(date +%s)
DAYS_AGO=$(( (NOW - LATEST_MTIME) / 86400 ))

CHALLENGE_ID=$(basename "$LATEST_PENDING" .xml)

# 注入到 stdout (Claude Code 的 SessionStart hook 会把 stdout 加入 context)
cat <<HDR
<enso-pac-pending days-ago="${DAYS_AGO}" challenge-id="${CHALLENGE_ID}">
  <meta>
    上次 PAC 挑战距今 ${DAYS_AGO} 天,用户尚未回答。
    按照 PAC 协议,应在 session 开始时主动呈现,让用户选择:
      (a) 现在回答
      (b) 再拖 3 天 (提示会再次出现)
      (c) 撤销此次挑战
  </meta>
  <challenge>
HDR

cat "$LATEST_PENDING"

cat <<TAIL
  </challenge>
  <instruction>
    AI: 在今天对话开始时,请直接呈现这个挑战,问用户如何处理。
    不要跳过。不要假装没看见。这是系统级约束。
    若用户选 (c) 撤销,告知用户我们会记录,然后主动删除此挑战 (mv 到 history/dismissed/)。
    若用户选 (b) 再拖,重新设置 mtime 为今天。
    若用户选 (a) 现在回答,记录答案后 mv 到 history/answered/。
  </instruction>
</enso-pac-pending>
TAIL

exit 0
