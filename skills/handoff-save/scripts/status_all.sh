#!/usr/bin/env bash
# status_all.sh — 알려진 활성 프로젝트들의 git 상태를 한꺼번에 스캔
#
# 목적: 머신을 옮기기 전에 "어디 미저장 작업 있나" 한눈에 확인.
# "넘기기 잊고 머신 전환" 실수 예방용.
#
# 사용법:
#   bash status_all.sh                # 기본 후보 (~/stock-team, ~/honi-team, ~/jk-skills)
#   bash status_all.sh ~/foo ~/bar    # 명시 지정
#
# 자동 보강: jk-handoff/IN_FLIGHT.json에 기록된 프로젝트들도 후보에 포함

set -uo pipefail

CURRENT_MACHINE=$(scutil --get ComputerName 2>/dev/null || hostname)
CACHE_DIR="${HOME}/.cache/jk-handoff"

# === 후보 프로젝트 수집 ===
# 1) 인자로 받은 경로
# 2) 알려진 기본 후보
# 3) IN_FLIGHT.json의 프로젝트들 (이름 → ~/<이름>)

declare -a CANDIDATES
if [ $# -gt 0 ]; then
  CANDIDATES=("$@")
else
  for default in "$HOME/stock-team" "$HOME/honi-team" "$HOME/jk-skills"; do
    CANDIDATES+=("$default")
  done
  # IN_FLIGHT.json에서 추가 후보 (인덱스 캐시가 있으면)
  if [ -f "$CACHE_DIR/IN_FLIGHT.json" ]; then
    while IFS= read -r proj; do
      [ -z "$proj" ] && continue
      path="$HOME/$proj"
      # 이미 있는지 확인
      found=0
      for c in "${CANDIDATES[@]}"; do
        [ "$c" = "$path" ] && found=1 && break
      done
      [ $found -eq 0 ] && CANDIDATES+=("$path")
    done < <(python3 -c "
import json
try:
    with open('$CACHE_DIR/IN_FLIGHT.json') as f:
        d = json.load(f)
    for p in d.get('projects', {}).keys():
        print(p)
except Exception:
    pass
")
  fi
fi

echo "📋 활성 프로젝트 상태 스캔 (현재 머신: ${CURRENT_MACHINE})"
echo "═══════════════════════════════════════════"

ANY_DIRTY=0
ANY_UNPUSHED=0

for dir in "${CANDIDATES[@]}"; do
  name=$(basename "$dir")
  if [ ! -d "$dir/.git" ]; then
    printf "⏭️  %-20s  git 저장소 아님 또는 없음 (%s)\n" "$name" "$dir"
    continue
  fi

  cd "$dir"
  branch=$(git branch --show-current 2>/dev/null || echo "?")
  dirty=$(git status --short 2>/dev/null | wc -l | tr -d ' ')

  # 원격과의 차이 (fetch 안 한 상태일 수 있으니 알려진 것만)
  unpushed="?"
  if git rev-parse --verify "origin/${branch}" >/dev/null 2>&1; then
    unpushed=$(git rev-list --count "origin/${branch}..HEAD" 2>/dev/null || echo "?")
  fi

  if [ "$dirty" = "0" ] && [ "$unpushed" = "0" ]; then
    printf "✅ %-20s  깨끗 (브랜치: %s)\n" "$name" "$branch"
  elif [ "$dirty" != "0" ]; then
    printf "⚠️  %-20s  %s개 파일 미커밋 (브랜치: %s)\n" "$name" "$dirty" "$branch"
    ANY_DIRTY=1
  else
    printf "📤 %-20s  %s commit 미푸시 (브랜치: %s)\n" "$name" "$unpushed" "$branch"
    ANY_UNPUSHED=1
  fi
done

echo "═══════════════════════════════════════════"
if [ $ANY_DIRTY -eq 1 ] || [ $ANY_UNPUSHED -eq 1 ]; then
  echo "💡 미저장 작업 있음. 머신 옮기기 전에 해당 디렉토리에서 \"넘기기\" 하세요."
else
  echo "✨ 모든 프로젝트 깨끗. 안심하고 머신 옮겨도 됩니다."
fi
