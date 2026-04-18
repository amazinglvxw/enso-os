#!/usr/bin/env zsh
# execlog-guard.sh — Stop hook (v3): 最终安全网
# v3 change: 恢复真正阻断(exit 2)，首次阻断+设flag，第二次放行防死锁
# 两层防线: PostToolUse(实时提醒) → Stop(最终校验)
# Exit: 0=放行, 2=阻断(首次)+提醒

EXECLOG="$HOME/.claude/projects/-Users-user-Desktop/memory/execution-log.jsonl"
SESSION_START_FILE="/tmp/claude-session-start"
TRACKING_FILE="/tmp/claude-execlog-tracking"
REMINDED_FLAG="/tmp/claude-execlog-reminded"

# 防无限循环：已提醒过一次就放行
if [[ -f "$REMINDED_FLAG" ]]; then
  rm -f "$REMINDED_FLAG" "$TRACKING_FILE"
  exit 0
fi

# 读取会话开始时间戳
if [[ ! -f "$SESSION_START_FILE" ]]; then
  exit 0
fi
SESSION_START=$(<"$SESSION_START_FILE")
[[ "$SESSION_START" =~ ^[0-9]+$ ]] || exit 0

# 尾部 JSON 完整性校验 (v3.1): 防止并发写入竞态导致脏行
# 检查最后 3 行都可解析, 有损坏 → stderr 警告但不阻断 (修复由 Agent 在 Stop 后自行负责)
if [[ -s "$EXECLOG" ]] && command -v python3 >/dev/null 2>&1; then
  TAIL_CHECK=$(tail -n 3 "$EXECLOG" | python3 -c "
import json, sys
bad = []
for i, line in enumerate(sys.stdin, 1):
    line = line.strip()
    if not line:
        continue
    try:
        json.loads(line)
    except json.JSONDecodeError as e:
        bad.append(f'tail[{i}]: {str(e)[:60]}')
if bad:
    print('\n'.join(bad))
" 2>/dev/null)
  if [[ -n "$TAIL_CHECK" ]]; then
    echo "⚠️  execution-log.jsonl 尾部 JSON 损坏:" >&2
    echo "$TAIL_CHECK" >&2
    echo "(不阻断本次 Stop, 请下次会话修复; 备份在 .bak-* 文件)" >&2
  fi
fi

# 优先检查 PostToolUse 追踪文件（更可靠）
if [[ -f "$TRACKING_FILE" ]]; then
  LAST_WRITE=$(<"$TRACKING_FILE")
  if [[ "$LAST_WRITE" =~ ^[0-9]+$ ]] && [[ "$LAST_WRITE" -ge "$SESSION_START" ]]; then
    # PostToolUse 已确认本次会话有 execution-log 写入
    rm -f "$TRACKING_FILE"
    exit 0
  fi
fi

# 回退检查: 文件修改时间
if [[ -s "$EXECLOG" ]]; then
  FILE_MTIME=$(stat -f %m "$EXECLOG" 2>/dev/null || stat -c %Y "$EXECLOG" 2>/dev/null || echo "0")
  [[ "$FILE_MTIME" =~ ^[0-9]+$ ]] || FILE_MTIME=0
  if [[ "$FILE_MTIME" -ge "$SESSION_START" ]]; then
    rm -f "$TRACKING_FILE"
    exit 0
  fi
fi

# 无新条目 → 真正阻断（首次），设flag防死锁
touch "$REMINDED_FLAG"
CURRENT_COUNT=$(wc -l < "$EXECLOG" 2>/dev/null | tr -d ' ')

echo "🔴 execution-log.jsonl 本次会话无新写入（当前 ${CURRENT_COUNT:-0} 条）。" >&2
echo "请写入至少一条执行日志后再结束会话。" >&2
echo '格式: {"ts":"ISO时间","skill":"SESSION","task":"一句话描述","status":"success|partial|fail","detail":"可选细节","q_delta":0}' >&2
exit 2  # v3: 恢复真正阻断
