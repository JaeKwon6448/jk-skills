#!/usr/bin/env bash
# fetch_latest.sh — jk-handoff 인덱스 repo에서 받을 후보 조회
#
# 모드:
#   bash fetch_latest.sh                  # LATEST.json + 최근 5개 history
#   bash fetch_latest.sh --list           # 최근 10개 history (INDEX.md)
#   bash fetch_latest.sh --project <name> # 특정 프로젝트의 최신 entry
#
# 출력: KEY=VALUE 형식 + (옵션) 사람 가독 요약

set -uo pipefail

INDEX_REPO="JaeKwon6448/jk-handoff"
INDEX_URL="https://github.com/${INDEX_REPO}.git"
CACHE_DIR="${HOME}/.cache/jk-handoff"

MODE="${1:-latest}"
ARG2="${2:-}"

# === 1) 캐시 준비 (read-only) ===
mkdir -p "$(dirname "$CACHE_DIR")"
if [ ! -d "$CACHE_DIR/.git" ]; then
  echo "📥 jk-handoff 인덱스 첫 캐시 (clone)..." >&2
  rm -rf "$CACHE_DIR"
  if ! git clone --quiet "$INDEX_URL" "$CACHE_DIR" 2>&1; then
    echo "❌ jk-handoff clone 실패. gh auth status 확인하세요." >&2
    exit 10
  fi
fi

cd "$CACHE_DIR"
git fetch --quiet origin main
# 받기는 read-only 의도이므로 로컬 변경(있을 일 거의 없지만)을 보존하지 않음
git reset --quiet --hard origin/main

# === 2) 모드 분기 ===
case "$MODE" in
  --list)
    echo "═══ 최근 작업 이력 (jk-handoff INDEX.md) ═══"
    # INDEX.md에서 데이터 row만 (헤더와 |---| 제외) 최대 10개
    awk '/^\| [0-9]/ { print; n++; if (n>=10) exit }' INDEX.md
    ;;

  --project)
    if [ -z "$ARG2" ]; then
      echo "❌ 사용법: --project <프로젝트명>" >&2
      exit 2
    fi
    PROJ_FILE="projects/${ARG2}.md"
    if [ ! -f "$PROJ_FILE" ]; then
      echo "❌ projects/${ARG2}.md 없음. 한 번도 넘긴 적 없는 프로젝트입니다." >&2
      echo ""
      echo "사용 가능한 프로젝트:"
      ls projects/ | grep -v '^\.' | sed 's/\.md$//; s/^/  - /'
      exit 3
    fi
    # 가장 최근 entry 한 줄 추출 (헤더 다음 첫 데이터 row)
    LATEST_ROW=$(awk '/^\| [0-9]/ { print; exit }' "$PROJ_FILE")
    echo "═══ ${ARG2} 최신 ═══"
    echo "$LATEST_ROW"
    echo ""
    echo "═══ ${ARG2} 최근 5개 ═══"
    awk '/^\| [0-9]/ { print; n++; if (n>=5) exit }' "$PROJ_FILE"
    ;;

  latest|*)
    if [ ! -f LATEST.json ]; then
      echo "PROJECT="
      echo "STATUS=no_latest"
      echo "MESSAGE=LATEST.json 없음. jk-handoff repo가 손상되었을 수 있음."
      exit 0
    fi

    # LATEST.json 파싱 → KEY=VALUE 출력
    python3 <<'EOF'
import json, sys
try:
    with open("LATEST.json") as f:
        d = json.load(f)
except Exception as e:
    print(f"STATUS=parse_error")
    print(f"MESSAGE={e}")
    sys.exit(0)

project = d.get("project")
if not project:
    print("STATUS=empty")
    print("MESSAGE=아직 넘긴 적 없음. 먼저 다른 컴퓨터에서 /넘기기 하세요.")
    sys.exit(0)

print("STATUS=ok")
for k in ("project", "repo", "branch", "commit", "commit_short", "commit_url",
          "machine", "timestamp", "timestamp_utc", "summary"):
    v = d.get(k, "")
    if v is None:
        v = ""
    # multi-line value 방지
    v = str(v).replace("\n", " ").replace("\r", " ")
    print(f"{k.upper()}={v}")
EOF

    # 현재 머신 정보 + 다른-머신 경고 flag
    CURRENT_MACHINE=$(scutil --get ComputerName 2>/dev/null || hostname)
    echo "CURRENT_MACHINE=${CURRENT_MACHINE}"

    # LATEST 머신과 현재 머신이 다르면 경고 (None/빈값은 경고 안 함)
    LATEST_MACHINE=$(python3 -c "import json; m=json.load(open('LATEST.json')).get('machine'); print(m if m else '')")
    if [ -n "$LATEST_MACHINE" ] && [ "$LATEST_MACHINE" != "$CURRENT_MACHINE" ]; then
      echo "DIFFERENT_MACHINE_WARNING=yes"
      echo "WARNING_TEXT=마지막 작업은 [${LATEST_MACHINE}]에서 했습니다. 거기에 push 안 한 변경이 남아있을 수 있어요 — 확인하셨나요?"
    else
      echo "DIFFERENT_MACHINE_WARNING=no"
    fi

    # IN_FLIGHT.json: 여러 프로젝트가 in-flight 상태인지 알림 (받기가 옵션 제시 가능)
    if [ -f IN_FLIGHT.json ]; then
      python3 <<'EOF'
import json
try:
    with open("IN_FLIGHT.json") as f:
        flight = json.load(f)
    projects = flight.get("projects", {})
    n = len(projects)
    print(f"IN_FLIGHT_COUNT={n}")
    if n > 1:
        # LATEST 외의 활성 프로젝트들도 한 줄씩 출력
        with open("LATEST.json") as f2:
            latest_proj = json.load(f2).get("project")
        others = [p for p in projects if p != latest_proj]
        for i, name in enumerate(others, 1):
            e = projects[name]
            print(f"OTHER_{i}_PROJECT={name}")
            print(f"OTHER_{i}_MACHINE={e.get('machine','')}")
            print(f"OTHER_{i}_TIMESTAMP={e.get('timestamp','')}")
            print(f"OTHER_{i}_COMMIT_SHORT={e.get('commit_short','')}")
            print(f"OTHER_{i}_SUMMARY={e.get('summary','')}")
except Exception as ex:
    print(f"IN_FLIGHT_PARSE_ERROR={ex}")
EOF
    else
      echo "IN_FLIGHT_COUNT=0"
    fi

    echo ""
    echo "═══ 최근 5개 history (참고) ═══"
    awk '/^\| [0-9]/ { print; n++; if (n>=5) exit }' INDEX.md
    ;;
esac
