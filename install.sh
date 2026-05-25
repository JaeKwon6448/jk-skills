#!/usr/bin/env bash
# install.sh — jk-skills의 스킬들을 ~/.claude/skills/ 에 symlink로 설치
#
# Idempotent: 몇 번 실행해도 안전. 새 스킬이 추가되면 자동으로 link.
# 사용법: bash install.sh

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$REPO_DIR/skills"
SKILLS_DST="$HOME/.claude/skills"

if [ ! -d "$SKILLS_SRC" ]; then
  echo "❌ $SKILLS_SRC 가 없습니다. jk-skills repo 구조가 깨졌어요." >&2
  exit 1
fi

mkdir -p "$SKILLS_DST"

echo "📦 jk-skills 설치 중 → $SKILLS_DST"
echo ""

INSTALLED=0
SKIPPED=0

for skill_dir in "$SKILLS_SRC"/*/; do
  [ -d "$skill_dir" ] || continue
  name=$(basename "$skill_dir")
  target="$SKILLS_DST/$name"

  if [ -L "$target" ]; then
    # 이미 symlink — 갱신 (어디를 가리키는지 확인)
    current=$(readlink "$target")
    if [ "$current" = "$skill_dir" ] || [ "$current" = "${skill_dir%/}" ]; then
      echo "✓ $name (이미 올바른 symlink)"
      SKIPPED=$((SKIPPED + 1))
      continue
    fi
    rm "$target"
    ln -s "${skill_dir%/}" "$target"
    echo "🔗 $name (symlink 갱신: $current → ${skill_dir%/})"
    INSTALLED=$((INSTALLED + 1))
  elif [ -d "$target" ]; then
    # 일반 디렉토리 — 백업 후 symlink
    backup="$target.bak.$(date +%Y%m%d-%H%M%S)"
    mv "$target" "$backup"
    ln -s "${skill_dir%/}" "$target"
    echo "🔗 $name (기존 디렉토리 → $backup 으로 백업 후 symlink)"
    INSTALLED=$((INSTALLED + 1))
  else
    # 신규
    ln -s "${skill_dir%/}" "$target"
    echo "✨ $name (새로 설치)"
    INSTALLED=$((INSTALLED + 1))
  fi
done

echo ""
echo "──────────────────────────────────"
echo "✅ 완료: $INSTALLED 개 설치/갱신, $SKIPPED 개 변경 없음"
echo ""
echo "다음 단계: Claude Code를 새로 열면 스킬이 트리거됩니다."
echo "       또는 이미 열려있다면 다음 메시지부터 인식됩니다."
