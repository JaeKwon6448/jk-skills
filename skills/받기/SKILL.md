---
name: 받기
description: 다른 컴퓨터에서 작업하던 것을 이어받는 스킬. JK의 인덱스 repo `jk-handoff`의 `LATEST.json`을 조회해서 가장 최근 작업 프로젝트가 무엇인지·어느 머신에서 작업했는지 확인하고, 해당 프로젝트를 자동 clone 또는 pull한 뒤 `HANDOFF.md`를 읽어 "지금 무엇부터 시작하면 되는지" 사용자에게 브리핑한다. "받기", "받아오기", "이어가기", "다른 컴퓨터에서 왔어", "어제 어디까지 했지", "다시 시작", "resume", "continue work" 같은 표현이 나오면 즉시 트리거. 슬래시 `/받기`, `/이어가기`도 받음. **반대 방향(현재 작업을 GitHub로 내보내기)은 별도 [넘기기] 스킬을 사용한다 — "저장", "백업", "넘겨" 등은 받기가 아니라 넘기기로.**
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
bash ~/.claude/skills/받기/scripts/fetch_latest.sh
```

출력 형식 (JSON + 사람 가독 요약):
```
PROJECT=stock-team
REPO=https://github.com/JaeKwon6448/stock-team.git
BRANCH=main
COMMIT=abc123def...
COMMIT_SHORT=abc123d
MACHINE=MacBook-Pro
TIMESTAMP=2026-05-25 23:55 KST
SUMMARY=OE 엔진 v2 매수 신호 튜닝
```

플러스 최근 5개 history 표.

### 2단계: 사용자에게 안내 + 확인

LATEST가 비어있으면 (아직 넘긴 적 없음) → "아직 jk-handoff에 기록된 작업이 없어요. 먼저 다른 컴퓨터에서 `/넘기기` 하셔야 해요." 안내 후 종료.

LATEST가 있으면 — **현재 머신과 비교**해서 다른 머신에서 온 작업인지 같은 머신에서 이어가는 건지 분기:

- **다른 머신에서 온 경우** (`MACHINE != 현재 hostname`): "stock-team을 3시간 전 MacBook-Pro에서 작업하셨네요. 받아올까요?"
- **같은 머신에서 이어가기** (`MACHINE == 현재`): "이 컴퓨터에서 마지막으로 stock-team을 작업하셨어요. 그대로 이어갈까요?"

사용자가 "응" / "다른 거" / "내가 프로젝트 지정할게" 중 선택할 수 있게 `AskUserQuestion`. 한 가지일 때(LATEST 외 선택지가 마땅치 않을 때)는 그냥 진행해도 됨.

### 3단계: 프로젝트 준비 (clone or pull)

```bash
bash ~/.claude/skills/받기/scripts/pull_project.sh <project> <repo_url> <branch>
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
