#!/usr/bin/env bash
# bootstrap.sh — 새 맥에서 한 번만 실행하면 jk-skills 전체 설치 완료
#
# 사용법:
#   curl -fsSL https://raw.githubusercontent.com/JaeKwon6448/jk-skills/main/bootstrap.sh | bash
#
# 또는:
#   gh repo clone JaeKwon6448/jk-skills ~/jk-skills && bash ~/jk-skills/bootstrap.sh

set -euo pipefail

echo "═══════════════════════════════════════════"
echo "  jk-skills bootstrap — JK 글로벌 스킬 설치"
echo "═══════════════════════════════════════════"
echo ""

# === 1) 사전 요구사항 확인 ===
echo "[1/5] 사전 요구사항 확인"

MISSING=()
for cmd in git gh python3; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    MISSING+=("$cmd")
  fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
  echo "❌ 필요한 명령이 없습니다: ${MISSING[*]}"
  echo ""
  echo "   macOS면:  brew install ${MISSING[*]}"
  echo "   그 다음 다시 실행하세요."
  exit 1
fi
echo "   ✓ git, gh, python3 OK"

# === 2) gh 인증 확인 ===
echo ""
echo "[2/5] GitHub 인증 확인"
if ! gh auth status >/dev/null 2>&1; then
  echo "❌ gh 인증이 안 되어있습니다."
  echo "   다음 명령으로 로그인 후 다시 실행하세요:"
  echo "     gh auth login"
  exit 1
fi
GH_USER=$(gh api user --jq '.login')
echo "   ✓ logged in as $GH_USER"

# === 3) jk-skills repo 준비 ===
echo ""
echo "[3/5] jk-skills repo 준비"
REPO_DIR="$HOME/jk-skills"

if [ -d "$REPO_DIR/.git" ]; then
  echo "   📂 이미 있음 → git pull"
  cd "$REPO_DIR"
  git pull --ff-only --quiet origin main || {
    echo "⚠️  pull 실패 (충돌 가능성). 수동 확인 필요."
  }
else
  if [ -e "$REPO_DIR" ]; then
    echo "❌ $REPO_DIR 가 이미 존재하지만 git repo가 아닙니다."
    echo "   다른 위치로 옮긴 후 다시 실행하세요."
    exit 1
  fi
  echo "   📥 clone https://github.com/JaeKwon6448/jk-skills"
  git clone --quiet https://github.com/JaeKwon6448/jk-skills "$REPO_DIR"
fi
echo "   ✓ $REPO_DIR 준비됨"

# === 4) install.sh 실행 (~/.claude/skills/ 에 symlink) ===
echo ""
echo "[4/5] 스킬을 ~/.claude/skills/ 에 symlink"
bash "$REPO_DIR/install.sh"

# === 5) jk-handoff 캐시 워밍 (받기를 즉시 빠르게) ===
echo ""
echo "[5/5] jk-handoff 인덱스 repo 캐시 워밍"
CACHE_DIR="$HOME/.cache/jk-handoff"
if [ ! -d "$CACHE_DIR/.git" ]; then
  mkdir -p "$(dirname "$CACHE_DIR")"
  echo "   📥 clone JaeKwon6448/jk-handoff → $CACHE_DIR"
  if git clone --quiet https://github.com/JaeKwon6448/jk-handoff "$CACHE_DIR" 2>&1; then
    echo "   ✓ 캐시 준비 완료"
  else
    echo "   ⚠️  clone 실패 (private repo면 gh auth 확인). 첫 /받기 호출 시 재시도됨."
  fi
else
  echo "   ✓ 이미 캐시 있음"
fi

# === 완료 ===
echo ""
echo "═══════════════════════════════════════════"
echo "  ✅ 설치 완료"
echo "═══════════════════════════════════════════"
echo ""
echo "  이제 어떤 프로젝트에서든:"
echo "    • \"받기\" 또는 \"이어가기\"  → 다른 머신 작업 받아오기"
echo "    • \"넘기기\" 또는 \"저장\"     → GitHub에 push + 인덱스 갱신"
echo ""
echo "  업데이트: cd ~/jk-skills && git pull"
echo ""
