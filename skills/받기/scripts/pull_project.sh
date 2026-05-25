#!/usr/bin/env bash
# pull_project.sh — 프로젝트를 로컬에 준비 (clone 또는 pull)
#
# 사용법:
#   bash pull_project.sh <project_name> <repo_url> [branch]
#   bash pull_project.sh <project_name> <repo_url> [branch] [target_dir]
#
# target_dir 미지정 시 기본 ~/<project_name>

set -uo pipefail

PROJECT="${1:?프로젝트명 누락}"
REPO_URL="${2:?repo URL 누락}"
BRANCH="${3:-main}"
TARGET="${4:-${HOME}/${PROJECT}}"

if [ -d "$TARGET/.git" ]; then
  # 기존 디렉토리: pull
  cd "$TARGET"

  CURRENT_BRANCH=$(git branch --show-current)
  if [ "$CURRENT_BRANCH" != "$BRANCH" ]; then
    echo "⚠️  현재 브랜치($CURRENT_BRANCH)와 받으려는 브랜치($BRANCH)가 다릅니다."
    echo "    자동 전환하지 않음. 호출자가 사용자에게 확인 후 처리하세요."
    echo "STATUS=branch_mismatch"
    echo "PATH=$TARGET"
    echo "CURRENT_BRANCH=$CURRENT_BRANCH"
    echo "WANTED_BRANCH=$BRANCH"
    exit 2
  fi

  # 로컬 변경 가드
  if [ -n "$(git status --short)" ]; then
    echo "⚠️  $TARGET 에 commit되지 않은 변경이 있습니다:"
    git status --short | sed 's/^/    /'
    echo ""
    echo "이걸 먼저 처리해야 안전하게 pull 할 수 있습니다."
    echo "STATUS=dirty_workdir"
    echo "PATH=$TARGET"
    exit 3
  fi

  echo "🔄 ${PROJECT}: git pull --ff-only (브랜치: $BRANCH)..."
  git fetch --quiet origin "$BRANCH"

  AHEAD=$(git rev-list --count "origin/${BRANCH}..HEAD" 2>/dev/null || echo "0")
  if [ "$AHEAD" != "0" ]; then
    echo "⚠️  로컬이 원격보다 $AHEAD commit 앞서있음 (divergence)."
    echo "    자동 merge 안 함."
    echo "STATUS=local_ahead"
    echo "PATH=$TARGET"
    echo "AHEAD=$AHEAD"
    exit 4
  fi

  git pull --quiet --ff-only origin "$BRANCH" || {
    echo "❌ pull 실패."
    echo "STATUS=pull_failed"
    echo "PATH=$TARGET"
    exit 5
  }

  echo "✅ pull 완료"
  echo "STATUS=ok_pulled"
  echo "PATH=$TARGET"
else
  # 신규 clone
  if [ -e "$TARGET" ]; then
    echo "❌ $TARGET 가 이미 존재하지만 git 저장소가 아닙니다."
    echo "    덮어쓰지 않음. 다른 위치를 지정하세요."
    echo "STATUS=target_occupied"
    echo "PATH=$TARGET"
    exit 6
  fi

  echo "📥 ${PROJECT}: 신규 clone → $TARGET"
  if ! git clone --quiet --branch "$BRANCH" "$REPO_URL" "$TARGET" 2>&1; then
    echo "❌ clone 실패. (private repo면 gh auth 확인)"
    echo "STATUS=clone_failed"
    echo "PATH=$TARGET"
    exit 7
  fi

  echo "✅ clone 완료"
  echo "STATUS=ok_cloned"
  echo "PATH=$TARGET"
fi

# HANDOFF.md 존재 여부 부가
if [ -f "$TARGET/HANDOFF.md" ]; then
  echo "HANDOFF=present"
else
  echo "HANDOFF=missing"
fi
