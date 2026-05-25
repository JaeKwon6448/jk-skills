#!/usr/bin/env bash
# handoff status — 저장하지 않고 현재 상태만 보여줌
set -uo pipefail

cd "$(pwd)"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "❌ 여기는 git 저장소가 아닙니다: $(pwd)"
  exit 1
fi

REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

PROJECT=$(basename "$REPO_ROOT")
BRANCH=$(git branch --show-current)
REMOTE=$(git config --get "branch.${BRANCH}.remote" 2>/dev/null || echo "origin")

echo "📂 프로젝트: $PROJECT"
echo "🌿 브랜치: $BRANCH"
echo ""

if [ -f HANDOFF.md ]; then
  LAST_LINE=$(grep -m1 '최종 업데이트' HANDOFF.md || echo "")
  if [ -n "$LAST_LINE" ]; then
    echo "📄 HANDOFF.md $LAST_LINE"
  else
    echo "📄 HANDOFF.md 존재 (메타데이터 없음)"
  fi
else
  echo "📄 HANDOFF.md 없음 (아직 save 한 적 없음)"
fi
echo ""

echo "─── 변경된 파일 ───"
CHANGES=$(git status --short)
if [ -z "$CHANGES" ]; then
  echo "(없음 — working tree 깨끗함)"
else
  echo "$CHANGES"
fi
echo ""

# 원격과의 차이 (fetch 없이 마지막으로 알려진 상태 기준)
if git rev-parse --verify "${REMOTE}/${BRANCH}" >/dev/null 2>&1; then
  AHEAD=$(git rev-list --count "${REMOTE}/${BRANCH}..HEAD" 2>/dev/null || echo "?")
  BEHIND=$(git rev-list --count "HEAD..${REMOTE}/${BRANCH}" 2>/dev/null || echo "?")
  echo "─── 원격(${REMOTE}/${BRANCH}) 대비 ───"
  echo "ahead: $AHEAD commit(s) | behind: $BEHIND commit(s)"
  echo "(주의: fetch 안 한 상태일 수 있음. 정확히 보려면: git fetch)"
else
  echo "─── 원격 추적 없음 ──"
fi
