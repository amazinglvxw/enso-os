#!/usr/bin/env bash
# business-closure-guard.sh — Stop Hook: 强制业务闭环
# 每次会话结束必须沉淀≥1条可执行业务动作到 execution-log 或 NOW.md
# v1: exit 2 真阻断 + REMINDED_FLAG 防死锁
#
# 检查逻辑:
# 1. execution-log 本次会话有条目 → pass
# 2. NOW.md 本次会话有更新 → pass
# 3. 都没有 → block (首次), 放行 (第二次，防死锁)
#
# 豁免条件:
# - 纯系统维护会话（scheduled task自动运行）
# - 会话时长 < 2分钟（快速问答）
set -euo pipefail

REMINDED_FLAG="/tmp/claude-biz-closure-reminded"
SESSION_START_FILE="/tmp/claude-session-start"
EXECLOG="$HOME/.claude/projects/-Users-user-Desktop/memory/execution-log.jsonl"
NOW_MD="$HOME/.claude/projects/-Users-user-Desktop/memory/NOW.md"
TRACKING_FILE="/tmp/claude-execlog-tracking"

# 防死锁：已提醒过一次就放行
if [ -f "$REMINDED_FLAG" ]; then
  rm -f "$REMINDED_FLAG"
  exit 0
fi

# 读取会话开始时间
if [ ! -f "$SESSION_START_FILE" ]; then
  exit 0
fi
SESSION_START=$(cat "$SESSION_START_FILE")
case "$SESSION_START" in ''|*[!0-9]*) exit 0 ;; esac

# 豁免: 会话时长 < 120秒（快速问答不强制）
NOW_TS=$(date +%s)
DURATION=$(( NOW_TS - SESSION_START ))
if [ "$DURATION" -lt 120 ]; then
  exit 0
fi

# 检查1: execution-log 本次会话有新条目
if [ -f "$TRACKING_FILE" ]; then
  LAST_WRITE=$(cat "$TRACKING_FILE" 2>/dev/null || echo "0")
  case "$LAST_WRITE" in ''|*[!0-9]*) LAST_WRITE=0 ;; esac
  if [ "$LAST_WRITE" -ge "$SESSION_START" ]; then
    exit 0
  fi
fi

# 检查1b: execution-log 文件修改时间
if [ -s "$EXECLOG" ]; then
  FILE_MTIME=$(stat -f %m "$EXECLOG" 2>/dev/null || stat -c %Y "$EXECLOG" 2>/dev/null || echo "0")
  case "$FILE_MTIME" in ''|*[!0-9]*) FILE_MTIME=0 ;; esac
  if [ "$FILE_MTIME" -ge "$SESSION_START" ]; then
    exit 0
  fi
fi

# 检查2: NOW.md 本次会话有更新
if [ -f "$NOW_MD" ]; then
  NOW_MTIME=$(stat -f %m "$NOW_MD" 2>/dev/null || stat -c %Y "$NOW_MD" 2>/dev/null || echo "0")
  case "$NOW_MTIME" in ''|*[!0-9]*) NOW_MTIME=0 ;; esac
  if [ "$NOW_MTIME" -ge "$SESSION_START" ]; then
    exit 0
  fi
fi

# 都没有 → 阻断
touch "$REMINDED_FLAG"
echo "🔴 业务闭环检查失败：本次会话未产出任何业务沉淀。" >&2
echo "请在结束前至少做以下之一：" >&2
echo "  1. 写入 execution-log 一条业务动作记录" >&2
echo "  2. 更新 NOW.md 业务状态" >&2
echo '格式: {"ts":"ISO时间","skill":"SESSION","task":"一句话描述","status":"success","detail":"","q_delta":0}' >&2
exit 2
