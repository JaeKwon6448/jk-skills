#!/usr/bin/env bash
# handoff save — HANDOFF.md + 변경분을 commit + push
#
# 사용법:
#   bash save.sh "한 줄 요약"        # 커밋 메시지 한 줄 요약 받음
#   bash save.sh                      # 요약 미지정 시 자동 생성
#
# 주의: HANDOFF.md 본문은 호출하는 스킬(Claude)이 미리 갱신해두는 것을 가정.
# 이 스크립트는 git 작업만 담당한다.

set -uo pipefail

SUMMARY="${1:-작업 상태 저장}"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "❌ 여기는 git 저장소가 아닙니다: $(pwd)"
  echo "   git init && gh repo create 먼저 하세요."
  exit 1
fi

REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

PROJECT=$(basename "$REPO_ROOT")
BRANCH=$(git branch --show-current)

if [ -z "$BRANCH" ]; then
  echo "❌ detached HEAD 상태입니다. 브랜치로 먼저 이동하세요."
  exit 1
fi

# 안전 가드: .env / credentials 류 staged 여부 확인
SUSPICIOUS=$(git status --short | grep -iE '\.(env|pem|key)$|credentials|secret' || true)
if [ -n "$SUSPICIOUS" ]; then
  echo "⚠️  민감해 보이는 파일이 변경되었습니다:"
  echo "$SUSPICIOUS"
  echo ""
  echo "이대로 진행하면 안 됩니다. 호출한 Claude에게 보고하고 사용자 확인을 받으세요."
  exit 2
fi

# 변경 사항이 아예 없으면 push만 시도하고 종료
if [ -z "$(git status --short)" ]; then
  echo "ℹ️  로컬 변경 없음."
  UNPUSHED=$(git log "origin/${BRANCH}..HEAD" --oneline 2>/dev/null | wc -l | tr -d ' ')
  if [ "$UNPUSHED" != "0" ] && [ -n "$UNPUSHED" ]; then
    echo "🚀 푸시되지 않은 commit $UNPUSHED 개 — push 시도..."
    git push origin "$BRANCH"
    echo "✅ push 완료"
    # 인덱스 갱신 (새 commit이 있으니까)
    COMMIT_SHA=$(git rev-parse HEAD)
    REPO_URL=$(git config --get "remote.origin.url")
    bash "$(dirname "$0")/update_index.sh" "$PROJECT" "$REPO_URL" "$BRANCH" "$COMMIT_SHA" "$SUMMARY" || true
  else
    echo "✅ 원격과 동기화된 상태. 할 일 없음."
  fi
  exit 0
fi

# HANDOFF.md가 있으면 우선 stage. 그 외 변경된 tracked 파일도 stage (untracked는 명시적 추가만)
if [ -f HANDOFF.md ]; then
  git add HANDOFF.md
fi

# 변경된 tracked 파일들 자동 add (modified + deleted), untracked는 제외
git add -u

# Untracked 파일이 있으면 사용자에게 알려주되 자동 add는 하지 않음
UNTRACKED=$(git ls-files --others --exclude-standard)
if [ -n "$UNTRACKED" ]; then
  echo "ℹ️  Untracked 파일 (자동 추가 안 함, 필요 시 호출자가 git add 후 재시도):"
  echo "$UNTRACKED" | sed 's/^/    /'
  echo ""
fi

if [ -z "$(git diff --cached --name-only)" ]; then
  echo "ℹ️  Stage된 변경이 없습니다. (untracked만 있는 상태) — push 생략."
  exit 0
fi

# 커밋 (pre-commit hook 정상 실행, --no-verify 금지)
COMMIT_MSG="chore(handoff): ${SUMMARY}

작성 머신: $(hostname)
작성 시각: $(date '+%Y-%m-%d %H:%M %Z')

🤖 Generated with handoff skill"

git commit -m "$COMMIT_MSG" || {
  echo "❌ commit 실패 (pre-commit hook? 위 에러 메시지 확인)"
  exit 3
}

# Push
git push origin "$BRANCH" || {
  echo "❌ push 실패. 원격이 앞서 있을 수 있음 — git fetch 후 상황 확인 필요."
  echo "   주의: --force는 절대 자동으로 쓰지 말 것."
  exit 4
}

# 결과 요약
LAST_SHA=$(git rev-parse --short HEAD)
FULL_SHA=$(git rev-parse HEAD)
REPO_URL_RAW=$(git config --get "remote.origin.url")
REMOTE_URL=$(echo "$REPO_URL_RAW" | sed 's#git@github.com:#https://github.com/#; s#\.git$##')
CHANGED_COUNT=$(git diff-tree --no-commit-id --name-only -r HEAD | wc -l | tr -d ' ')

echo ""
echo "✅ 저장 완료"
echo "   프로젝트: $PROJECT ($BRANCH)"
echo "   변경 파일: $CHANGED_COUNT 개"
echo "   commit: $LAST_SHA"
if [ -n "$REMOTE_URL" ]; then
  echo "   링크: ${REMOTE_URL}/commit/${LAST_SHA}"
fi
echo ""

# === 인덱스 repo 갱신 (jk-handoff) ===
# 6번째 인자로 HANDOFF.md 절대 경로 전달 → snapshot 자동 저장
HANDOFF_ABS=""
[ -f "$REPO_ROOT/HANDOFF.md" ] && HANDOFF_ABS="$REPO_ROOT/HANDOFF.md"

bash "$(dirname "$0")/update_index.sh" "$PROJECT" "$REPO_URL_RAW" "$BRANCH" "$FULL_SHA" "$SUMMARY" "$HANDOFF_ABS" || {
  echo "⚠️  인덱스 갱신 실패 (메인 push는 성공). 다음에 받기 시 LATEST.json은 이전 값."
}

echo ""
echo "💡 다른 컴퓨터에서 이어가려면 그쪽 가서 \"받기\" 라고 말하세요."
