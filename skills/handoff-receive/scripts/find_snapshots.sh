#!/usr/bin/env bash
# find_snapshots.sh — 받기 직전에 호출. 비교할 두 snapshot 경로를 찾아 출력.
#
# 사용법: bash find_snapshots.sh <project_name>
#
# 출력 (KEY=VALUE):
#   PREV_SNAPSHOT=/path/to/Jaeui-MacBookPro__2026-05-25_19-55.md  또는 NONE
#   CURR_SNAPSHOT=/path/to/<latest>__<latest>.md  또는 NONE
#   PREV_TIMESTAMP=...
#   CURR_TIMESTAMP=...
#
# 로직:
#   prev = snapshots/<project>/<CURRENT_MACHINE_ID>__*.md 중 가장 최근
#          (이 머신이 마지막으로 떠날 때 저장한 것)
#   curr = snapshots/<project>/*.md 중 가장 최근
#          (LATEST = 다른 머신이 방금 넘긴 것, 또는 같은 머신 이어가기면 prev와 동일)

set -uo pipefail

PROJECT="${1:?프로젝트명 누락}"
CACHE_DIR="${HOME}/.cache/jk-handoff"
SNAPSHOT_DIR="${CACHE_DIR}/snapshots/${PROJECT}"

# 현재 머신 ID (update_index.sh와 동일 로직)
MACHINE_ID=$(scutil --get LocalHostName 2>/dev/null || hostname -s)
MACHINE_ID=$(echo "$MACHINE_ID" | LC_ALL=C sed 's/[^A-Za-z0-9._-]/_/g')

if [ ! -d "$SNAPSHOT_DIR" ]; then
  echo "PREV_SNAPSHOT=NONE"
  echo "CURR_SNAPSHOT=NONE"
  echo "STATUS=no_snapshots"
  exit 0
fi

# 가장 최근 1개 (모든 머신 통틀어) = CURR
CURR=$(ls -1 "$SNAPSHOT_DIR"/*.md 2>/dev/null | sort -r | head -1 || true)

# 현재 머신의 가장 최근 = PREV (단, CURR와 같은 파일이면 그 다음 것)
PREV=""
if [ -n "$CURR" ]; then
  # CURR이 이 머신 것이면, 이 머신 것 중 두 번째로 최근
  CURR_BASE=$(basename "$CURR")
  if echo "$CURR_BASE" | grep -q "^${MACHINE_ID}__"; then
    PREV=$(ls -1 "$SNAPSHOT_DIR"/${MACHINE_ID}__*.md 2>/dev/null | sort -r | sed -n '2p' || true)
  else
    PREV=$(ls -1 "$SNAPSHOT_DIR"/${MACHINE_ID}__*.md 2>/dev/null | sort -r | head -1 || true)
  fi
fi

echo "MACHINE_ID=${MACHINE_ID}"
echo "PREV_SNAPSHOT=${PREV:-NONE}"
echo "CURR_SNAPSHOT=${CURR:-NONE}"

# timestamp 추출 (파일명에서)
if [ -n "$PREV" ]; then
  ts=$(basename "$PREV" .md | sed 's/^[^_]*__//')
  echo "PREV_TIMESTAMP=${ts}"
fi
if [ -n "$CURR" ]; then
  ts=$(basename "$CURR" .md | sed 's/^[^_]*__//')
  mach=$(basename "$CURR" .md | sed 's/__.*$//')
  echo "CURR_TIMESTAMP=${ts}"
  echo "CURR_MACHINE_ID=${mach}"
fi
