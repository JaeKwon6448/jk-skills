#!/usr/bin/env bash
# update_index.sh — jk-handoff 인덱스 repo 갱신
#
# save.sh가 자기 프로젝트 push 후 호출. cwd와 무관하게 작동.
#
# 사용법:
#   bash update_index.sh <project> <repo_url> <branch> <commit_sha> <summary>
#
# 실패해도 메인 push는 이미 끝났으므로 exit code로만 알림 (사용자 작업 차단 X).

set -uo pipefail

PROJECT="${1:?project name 누락}"
REPO_URL="${2:?repo URL 누락}"
BRANCH="${3:?branch 누락}"
COMMIT_SHA="${4:?commit sha 누락}"
SUMMARY="${5:-작업 상태 저장}"

INDEX_REPO="JaeKwon6448/jk-handoff"
INDEX_URL="https://github.com/${INDEX_REPO}.git"
CACHE_DIR="${HOME}/.cache/jk-handoff"

# 머신 이름 분리: 표시용(한글 OK) / 파일명용(ASCII 안전)
MACHINE=$(scutil --get ComputerName 2>/dev/null || hostname)
MACHINE_ID=$(scutil --get LocalHostName 2>/dev/null || hostname -s)
# fallback sanitize (혹시 LocalHostName에 비ASCII 섞이면)
MACHINE_ID=$(echo "$MACHINE_ID" | LC_ALL=C sed 's/[^A-Za-z0-9._-]/_/g')

TIMESTAMP=$(date '+%Y-%m-%d %H:%M %Z')
TIMESTAMP_ISO=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
TIMESTAMP_SLUG=$(date '+%Y-%m-%d_%H%M')
SHORT_SHA="${COMMIT_SHA:0:7}"
COMMIT_URL=$(echo "$REPO_URL" | sed 's#git@github.com:#https://github.com/#; s#\.git$##')/commit/${COMMIT_SHA}

# 호출자(save.sh)가 HANDOFF.md 경로를 6번째 인자로 넘기면 snapshot 저장
HANDOFF_PATH="${6:-}"

# === 1) 캐시 준비 ===
mkdir -p "$(dirname "$CACHE_DIR")"
if [ ! -d "$CACHE_DIR/.git" ]; then
  echo "📥 jk-handoff 인덱스 첫 캐시 (clone)..."
  rm -rf "$CACHE_DIR"
  git clone --quiet "$INDEX_URL" "$CACHE_DIR" || {
    echo "❌ jk-handoff clone 실패. 인덱스 갱신 건너뜀."
    exit 10
  }
fi

cd "$CACHE_DIR"

# 안전: 인덱스 repo의 로컬 변경은 항상 버려도 안전 (오직 이 스크립트만 씀)
git reset --hard --quiet HEAD
git pull --quiet --ff-only origin main || {
  # ff 실패 시 (push 충돌 등) — 강제로 원격 따라감 (인덱스는 멱등)
  git fetch --quiet origin main
  git reset --hard --quiet origin/main
}

# === 2) LATEST.json (가장 최근 1건) + IN_FLIGHT.json (멀티-프로젝트 상태) 갱신 ===
python3 - <<EOF
import json, os

entry = {
  "project": ${PROJECT@Q},
  "repo": ${REPO_URL@Q},
  "branch": ${BRANCH@Q},
  "commit": ${COMMIT_SHA@Q},
  "commit_short": ${SHORT_SHA@Q},
  "commit_url": ${COMMIT_URL@Q},
  "machine": ${MACHINE@Q},
  "timestamp": ${TIMESTAMP@Q},
  "timestamp_utc": ${TIMESTAMP_ISO@Q},
  "summary": ${SUMMARY@Q},
}

# LATEST.json: 항상 덮어쓰기 (가장 최근 1건)
with open("LATEST.json", "w") as f:
    json.dump(entry, f, indent=2, ensure_ascii=False)
    f.write("\n")

# IN_FLIGHT.json: 기존 다른 프로젝트 entry는 보존, 이번 프로젝트만 갱신
in_flight_path = "IN_FLIGHT.json"
if os.path.exists(in_flight_path):
    try:
        with open(in_flight_path) as f:
            flight = json.load(f)
        if not isinstance(flight, dict) or "projects" not in flight:
            flight = {"projects": {}, "last_updated": None}
    except Exception:
        flight = {"projects": {}, "last_updated": None}
else:
    flight = {"projects": {}, "last_updated": None}

flight["projects"][entry["project"]] = {
    k: v for k, v in entry.items() if k != "project"
}
flight["last_updated"] = ${TIMESTAMP_ISO@Q}
flight["last_updated_machine"] = ${MACHINE@Q}

with open(in_flight_path, "w") as f:
    json.dump(flight, f, indent=2, ensure_ascii=False)
    f.write("\n")
EOF

# === 3) INDEX.md prepend ===
# 헤더 row 바로 다음 (|---|--- 줄 뒤)에 새 row 삽입
NEW_ROW="| ${TIMESTAMP} | ${PROJECT} | ${MACHINE} | [\`${SHORT_SHA}\`](${COMMIT_URL}) | ${SUMMARY} |"

if [ -f INDEX.md ]; then
  awk -v row="$NEW_ROW" '
    /^\|---/ && !done { print; print row; done=1; next }
    { print }
  ' INDEX.md > INDEX.md.tmp && mv INDEX.md.tmp INDEX.md
else
  # 인덱스 파일 손상 시 재생성
  cat > INDEX.md <<HEADER
# 작업 타임라인

> 가장 최신이 맨 위. \`/넘기기\` 호출 시마다 한 줄 prepend.

| 시각 | 프로젝트 | 머신 | commit | 요약 |
|---|---|---|---|---|
${NEW_ROW}
HEADER
fi

# === 4) projects/<project>.md prepend ===
PROJ_FILE="projects/${PROJECT}.md"
mkdir -p projects
PROJ_ROW="| ${TIMESTAMP} | ${MACHINE} | [\`${SHORT_SHA}\`](${COMMIT_URL}) | ${BRANCH} | ${SUMMARY} |"

if [ ! -f "$PROJ_FILE" ]; then
  cat > "$PROJ_FILE" <<HEADER
# ${PROJECT} — 넘기기 이력

> 이 프로젝트의 모든 넘기기 기록. 최신이 맨 위.

| 시각 | 머신 | commit | 브랜치 | 요약 |
|---|---|---|---|---|
${PROJ_ROW}
HEADER
else
  awk -v row="$PROJ_ROW" '
    /^\|---/ && !done { print; print row; done=1; next }
    { print }
  ' "$PROJ_FILE" > "$PROJ_FILE.tmp" && mv "$PROJ_FILE.tmp" "$PROJ_FILE"
fi

# === 4.5) snapshots/<project>/<MACHINE_ID>__<TIMESTAMP_SLUG>.md — HANDOFF.md 시계열 사본 ===
SNAPSHOT_PATH=""
if [ -n "$HANDOFF_PATH" ] && [ -f "$HANDOFF_PATH" ]; then
  SNAPSHOT_DIR="snapshots/${PROJECT}"
  mkdir -p "$SNAPSHOT_DIR"
  SNAPSHOT_PATH="${SNAPSHOT_DIR}/${MACHINE_ID}__${TIMESTAMP_SLUG}.md"

  # 메타데이터 헤더 + 원본 HANDOFF.md 본문
  {
    echo "<!--"
    echo "snapshot_meta:"
    echo "  project: ${PROJECT}"
    echo "  machine: ${MACHINE}"
    echo "  machine_id: ${MACHINE_ID}"
    echo "  timestamp: ${TIMESTAMP}"
    echo "  timestamp_utc: ${TIMESTAMP_ISO}"
    echo "  commit: ${COMMIT_SHA}"
    echo "  branch: ${BRANCH}"
    echo "  summary: ${SUMMARY}"
    echo "-->"
    echo ""
    cat "$HANDOFF_PATH"
  } > "$SNAPSHOT_PATH"
fi

# === 5) commit + push ===
git add LATEST.json IN_FLIGHT.json INDEX.md "$PROJ_FILE"
[ -n "$SNAPSHOT_PATH" ] && git add "$SNAPSHOT_PATH"

if [ -z "$(git diff --cached --name-only)" ]; then
  echo "ℹ️  인덱스에 변경 없음 (이미 동일한 상태)"
  exit 0
fi

git -c user.name="JK ($MACHINE)" -c user.email="pobox1254@gmail.com" \
  commit --quiet -m "넘기기: ${PROJECT} ← ${MACHINE} (${SHORT_SHA})

${SUMMARY}"

git push --quiet origin main || {
  echo "⚠️  인덱스 push 실패. 다음 넘기기 때 재시도됨 (메인 push는 이미 성공)."
  exit 11
}

echo "✅ 인덱스 갱신: https://github.com/${INDEX_REPO}/blob/main/INDEX.md"
