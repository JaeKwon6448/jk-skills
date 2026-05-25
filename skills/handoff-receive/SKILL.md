---
name: handoff-receive
description: "받기" — 다른 컴퓨터에서 작업하던 것을 이어받는 스킬. JK의 인덱스 repo `jk-handoff`의 `LATEST.json` 또는 `IN_FLIGHT.json`을 조회해서 가장 최근 작업 또는 여러 in-flight 프로젝트를 확인하고, 해당 프로젝트를 자동 clone 또는 pull한 뒤 `HANDOFF.md`를 읽어 "지금 무엇부터 시작하면 되는지" 사용자에게 브리핑한다. **트리거: "받기", "받아오기", "이어가기", "다른 컴퓨터에서 왔어", "어제 어디까지 했지", "다시 시작", "오늘 뭐부터", "resume", "continue work".** 슬래시 `/받기`, `/이어가기`도 받음. **반대 방향(현재 작업을 GitHub로 내보내기)은 별도 [handoff-save] 스킬을 사용한다 — "저장", "백업", "넘겨" 등은 받기가 아니라 넘기기로.**
---

# 받기 — 다른 컴퓨터의 작업을 이어가기

## 이 스킬의 목적

JK는 여러 컴퓨터를 오가며 같은 프로젝트를 작업한다.
새 머신에서, 혹은 며칠 만에 돌아온 머신에서 — "내가 어제 뭘 하고 있었지?" "어느 프로젝트가 가장 최근 작업이지?" "어디부터 시작해야 하지?" 를 단번에 해소한다.

핵심: **`jk-handoff` 인덱스 repo가 단일 진실 소스**.
- `LATEST.json` → 가장 최근 작업 1건 (받기가 첫 번째로 읽음)
- `INDEX.md` → 전체 타임라인 (사용자가 "다른 것 받을래" 하면 후보 제시용)
- `projects/<프로젝트>.md` → 특정 프로젝트의 모든 이력

받기는 이걸 읽어서 → 해당 프로젝트를 로컬에 준비(clone/pull) → HANDOFF.md 읽고 브리핑.

---

## 작동 흐름

### 1단계: 인덱스 조회 (항상 가장 먼저)

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/fetch_latest.sh"
```

출력 형식 (KEY=VALUE):
```
STATUS=ok
PROJECT=stock-team
REPO=https://github.com/JaeKwon6448/stock-team.git
BRANCH=main
COMMIT=abc123def...
COMMIT_SHORT=abc123d
COMMIT_URL=https://github.com/.../commit/abc123def
MACHINE=MacBook-Pro
TIMESTAMP=2026-05-25 23:55 KST
SUMMARY=OE 엔진 v2 매수 신호 튜닝
CURRENT_MACHINE=Jae의 MacBook Pro
DIFFERENT_MACHINE_WARNING=yes        ← 다른 머신에서 온 경우
WARNING_TEXT=마지막 작업은 [MacBook-Pro]에서 했습니다...
IN_FLIGHT_COUNT=2                    ← 활성 중인 프로젝트 수
OTHER_1_PROJECT=honi-team            ← LATEST 외의 다른 활성 프로젝트
OTHER_1_MACHINE=MacBook-Air
OTHER_1_TIMESTAMP=2026-05-25 18:00 KST
OTHER_1_SUMMARY=수학 진도 정리
```

플러스 최근 5개 history 표.

**중요 — 출력을 어떻게 활용**:
- `STATUS=empty` → "먼저 다른 컴퓨터에서 /넘기기 하세요" 안내 후 종료
- `DIFFERENT_MACHINE_WARNING=yes` → 받기 진행 전에 한 줄 경고 추가 (아래 2단계 참조)
- `IN_FLIGHT_COUNT > 1` → 다른 활성 프로젝트도 있음. 사용자에게 "LATEST(stock-team)만 받을지 / honi-team도 받을지 / 다른 거 명시할지" 선택 제시

### 2단계: 사용자에게 안내 + 확인

LATEST가 비어있으면 (아직 넘긴 적 없음) → "아직 jk-handoff에 기록된 작업이 없어요. 먼저 다른 컴퓨터에서 `/넘기기` 하셔야 해요." 안내 후 종료.

LATEST가 있으면 — **현재 머신과 비교**해서 다른 머신에서 온 작업인지 같은 머신에서 이어가는 건지 분기:

- **다른 머신에서 온 경우** (`DIFFERENT_MACHINE_WARNING=yes`): "stock-team을 3시간 전 MacBook-Pro에서 작업하셨네요. **⚠️ 그 머신에 push 안 한 변경이 남아있을 수 있어요 — 한 번 확인하셨나요?** 받아올까요?" (경고는 한 줄, 사용자 작업 차단은 안 함)
- **같은 머신에서 이어가기** (`MACHINE == 현재`): "이 컴퓨터에서 마지막으로 stock-team을 작업하셨어요. 그대로 이어갈까요?"
- **여러 활성 프로젝트** (`IN_FLIGHT_COUNT > 1`): "LATEST는 stock-team인데, honi-team(어제 Air에서)도 in-flight 상태예요. 어느 거?" 옵션 제시

사용자가 "응" / "다른 거" / "내가 프로젝트 지정할게" 중 선택할 수 있게 `AskUserQuestion`. 한 가지일 때(LATEST 외 선택지가 마땅치 않을 때)는 그냥 진행해도 됨.

### 3단계: 프로젝트 준비 (clone or pull)

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/pull_project.sh" <project> <repo_url> <branch>
```

이 스크립트가 처리하는 것:
- 표준 위치 `~/<프로젝트명>` 에 디렉토리가 있는지 확인
- 없으면 `git clone <repo_url> ~/<프로젝트명>`
- 있으면 `cd ~/<프로젝트명> && git fetch && git pull --ff-only`
- 로컬에 commit되지 않은 변경이 있으면 **중단** (덮어쓰지 않음) — 사용자에게 알리고 어떻게 할지 묻기
- 마지막에 프로젝트 경로 출력 → Claude가 이걸 받아서 후속 작업

### 4단계: HANDOFF.md 읽고 브리핑

`<프로젝트경로>/HANDOFF.md`를 Read 도구로 읽어서 사용자에게 정성껏 브리핑:

```
📂 stock-team — MacBook-Pro에서 3시간 전 작업
📍 ~/stock-team (main, abc123d)

🎯 지금 할 일:
<HANDOFF.md의 "다음 컴퓨터에서 바로 할 일" 중 첫 항목>

📋 진행중 TODO:
<체크되지 않은 항목들 — [ ] 항목>

✅ 완료한 것 (참고):
<체크된 항목들 — [x] 항목 중 최근 것 2~3개>

❓ 미해결 질문:
<있으면>

🗒️ 마지막 메모:
<있으면 "메모/결정사항" 섹션 마지막 entry>
```

### 5단계: TODO를 TaskCreate로 자동 등록

브리핑 직후 `TaskCreate` 도구가 있으면 HANDOFF.md의 미완료 TODO를 작업 목록으로 등록. 사용자가 "응 그대로 시작" 한마디로 바로 일 들어갈 수 있게.

### 6단계: 사용자 응답 대기

"이거 그대로 시작할까요, 아니면 다른 거 먼저 할까요?"

이후 사용자가 작업을 시작하면 후속 Bash 호출에서 항상 `cd <프로젝트경로> && ...` 형태로 그 디렉토리 안에서 작동. (Bash tool은 매 호출 cwd가 reset 되므로 명시 필수.)

---

## "다른 프로젝트 받을래" 케이스

사용자가 LATEST 말고 다른 프로젝트를 원하면:

```bash
bash ~/.claude/skills/받기/scripts/fetch_latest.sh --list
```

INDEX.md에서 최근 10개 row를 보여줌. 사용자가 선택하면 같은 흐름으로 진행.

또는 사용자가 "honi-team 받아줘" 처럼 명시하면, INDEX.md에서 해당 프로젝트의 가장 최근 entry를 찾아 사용. `fetch_latest.sh --project honi-team` 같이 호출:

```bash
bash ~/.claude/skills/받기/scripts/fetch_latest.sh --project honi-team
```

---

## 받기 실패/예외 케이스

| 상황 | 처리 |
|---|---|
| jk-handoff repo가 첫 머신에서는 아직 캐시 없음 | `fetch_latest.sh`가 자동 clone — 사용자 추가 작업 없음 |
| LATEST.json이 null (아직 넘긴 적 없음) | "먼저 다른 컴퓨터에서 /넘기기 하세요" 안내 후 종료 |
| 프로젝트 repo가 private이고 gh 인증 안 됨 | `gh auth login` 안내 |
| 로컬 변경이 있어 pull 불가 | 사용자에게 알리고 "먼저 /넘기기 할까요, 아니면 stash 할까요?" 묻기. 자동 처리 X |
| 사용자가 받기 대상을 잘못 지정 | INDEX.md 보여주고 다시 선택받기 |

---

## 안전 규칙

- **로컬 변경 절대 덮어쓰지 않음** — pull --ff-only만 사용, 충돌은 사용자에게 위임
- **자동 merge/rebase 금지**
- **clone 위치는 항상 `~/<프로젝트명>`** — 다른 위치를 쓰던 사용자가 헷갈리지 않게. 사용자가 명시적으로 다른 위치 원하면 그때만 변경
- **인덱스 repo 자체는 read-only로 다룸** — 받기 스킬은 jk-handoff에 push 안 함 (오직 넘기기만 push)

---

## 사용 예시

**시나리오 1**: 새 컴퓨터에서 처음 받기
```
JK: 받기
Claude: → fetch_latest.sh 실행
        → "stock-team을 3시간 전 MacBook-Pro에서 작업하셨네요.
           이 머신에는 아직 없음. ~/stock-team 으로 clone 할까요?" + AskUserQuestion
JK: 응
Claude: → pull_project.sh 실행 → ~/stock-team 에 clone 완료
        → HANDOFF.md 읽고 브리핑
        → TODO 5개 TaskCreate로 등록
        → "첫 번째: OE 엔진 v2 백테스트 결과 검증. 시작할까요?"
```

**시나리오 2**: 같은 머신에서 며칠 만에 돌아옴
```
JK: 어제 뭐 하다 말았지
Claude: → fetch_latest.sh → MACHINE이 현재와 일치
        → "이 컴퓨터에서 마지막으로 honi-team을 작업하셨어요 (이틀 전)"
        → ~/honi-team 으로 cd, git pull --ff-only
        → HANDOFF.md 읽고 브리핑
```
