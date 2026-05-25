---
name: 넘기기
description: 현재 프로젝트의 작업 상태(코드 + 작업목록 + 다음 할일)를 GitHub에 저장하고, 동시에 `jk-handoff` 인덱스 repo에 "어느 컴퓨터에서 무엇을 작업했는지" 이력을 누적하는 스킬. "넘기기", "저장", "백업", "동기화", "한 번 정리해", "save state", "handoff" 같은 표현이 나오면 즉시 트리거. 슬래시 `/넘기기`, `/handoff`도 받음. 핵심은 단순 git push가 아니라 "내가 지금 뭘 하고 있었는지"를 패키징해서 GitHub로 옮기는 것. **반대 방향(다른 컴퓨터에서 받아오는 것)은 별도 [받기] 스킬을 사용한다 — 사용자가 "받기", "이어가기", "다른 컴퓨터에서 왔어" 등을 말하면 받기 스킬로 라우팅하고 이 스킬은 호출하지 말 것.**
---

# 넘기기 — 작업 상태를 GitHub로 저장

## 이 스킬의 목적

JK는 여러 컴퓨터에서 같은 프로젝트(`~/stock-team`, `~/honi-team` 등)를 오가며 작업한다.
`git push`만으로는 **"내가 지금 뭘 하고 있었는지"**, **"어느 머신에서 작업했는지"** 가 옮겨가지 않는다.

이 스킬은:
1. 그 컨텍스트를 `HANDOFF.md` 한 장으로 패키징 → 프로젝트 repo에 push
2. **별도 인덱스 repo `jk-handoff`** 에 "누가-언제-어디서-어떤-commit" 메타데이터를 누적

받기는 별도 스킬(`받기`)이 담당. 이 스킬은 **내보내기 한 방향만** 책임진다.

## 인덱스 repo 구조 (참고)

`https://github.com/JaeKwon6448/jk-handoff` (private)

```
LATEST.json          가장 최근 작업 1건. 받기 스킬이 첫 번째로 보는 곳
INDEX.md             전체 타임라인 (최신이 맨 위)
projects/<프로젝트>.md  프로젝트별 누적 이력
```

이 인덱스 갱신은 `scripts/update_index.sh`가 자동으로 처리하므로, Claude가 직접 손댈 일은 거의 없다.

---

## 2가지 모드

| 사용자가 말하면 | 모드 |
|---|---|
| "넘겨", "저장", "백업", "동기화", "정리해", "save", "handoff" | **save** |
| "지금 어디까지", "상태", "status", "확인만" | **status** |

`이어가기`, `받기` 류 발화는 이 스킬이 아니라 [받기] 스킬로. 사용자가 모호하게 말하면 `AskUserQuestion`으로 "저장하시려는 거예요, 받아오시려는 거예요?" 한 번만 확인.

---

## SAVE 모드 — 현재 상태를 GitHub에 저장

### 단계

1. **프로젝트 확인**: `pwd`. git 저장소가 아니면 사용자에게 확인 후 `git init` + `gh repo create --private`.

2. **HANDOFF.md 생성/업데이트** — `assets/HANDOFF_TEMPLATE.md` 참조.
   **반드시 사용자에게 핵심 항목을 물어본 뒤 채운다** (자동 추측 금지, 그게 이 파일의 존재 이유):
   - "지금 무엇을 하고 있었나?" (1-2문장)
   - "다음 컴퓨터에서 첫 번째로 할 일은?"
   - 진행중/완료 TODO
   - 미해결 질문이 있다면

   대화 컨텍스트에서 이미 명확한 항목은 굳이 다시 묻지 말고 채우되, "이렇게 적었는데 맞나요?" 한 번 확인.

3. **자동 채울 메타데이터** (사용자에게 묻지 않음):
   - 작성 시각: `date "+%Y-%m-%d %H:%M %Z"`
   - 머신 정보: `scutil --get ComputerName` (macOS) 또는 `hostname`
   - 브랜치: `git branch --show-current`
   - 최근 변경 파일: `git status --short`
   - 최근 commit 3개: `git log --oneline -3`

4. **이미 있는 HANDOFF.md는 보존**: "메모/결정사항" 섹션은 append만, 다른 섹션만 새 내용으로 교체.

5. **커밋 + 푸시 + 인덱스 갱신**:
   ```bash
   bash ~/.claude/skills/넘기기/scripts/save.sh "한 줄 요약"
   ```
   이 스크립트가 처리하는 것:
   - `git add HANDOFF.md` + 변경된 tracked 파일들 + commit + push
   - 자동으로 `update_index.sh` 호출해서 `jk-handoff` repo 갱신
   - 커밋 메시지는 `chore(handoff): <한 줄 요약>` 형태, `--no-verify` 금지

   "한 줄 요약"은 사용자에게 묻지 말고 대화 맥락에서 뽑아 전달. (예: "OE 엔진 v2 매수 신호 튜닝 진행 중")

6. **요약 출력**: 푸시된 commit URL, 인덱스 INDEX.md URL, 변경 파일 수 안내.

### 사용자에게 묻지 말아야 할 것

- 커밋해도 되는지 (스킬 호출 시점에 이미 동의된 것)
- 푸시해도 되는지 (마찬가지)
- 무슨 commit 메시지를 쓸지 (대화 맥락에서 알아서)

물어야 할 것은 **HANDOFF.md 본문 내용**뿐.

---

## STATUS 모드 — 저장하지 않고 확인만

```bash
bash ~/.claude/skills/넘기기/scripts/status.sh
```

출력:
- 마지막 HANDOFF.md (있으면) 작성 시각
- 현재 변경 파일 (`git status --short`)
- 원격과의 차이 (ahead/behind)

이후 "저장하시려면 `/넘기기` 하라"고 안내.

---

## 다중 프로젝트 처리

사용자가 "오늘 작업한 거 다 저장해" 같이 말하면 — 알려진 활성 프로젝트(메모리: `stock-team`, `honi-team`)를 순회하며 각각 save 실행. 변경 없으면 건너뛰고 한 줄씩 보고:

```
✅ stock-team — HANDOFF 갱신, 3 파일 커밋, 인덱스 갱신 완료
⏭️ honi-team — 변경 없음, 건너뜀
```

---

## 안전 규칙

- **`--no-verify` 절대 금지** (pre-commit hook 우회 안 함)
- **`git push --force` 절대 금지** (사용자가 명시적으로 요청해도 한 번 더 확인)
- **`.env`, credentials 류 파일 자동 add 금지** — `git add -A` 대신 `git add -u` (tracked만) 사용
- **공개 repo면 secrets 노출 경고** — HANDOFF.md에 토큰/키 안 적기
- **인덱스 repo(`jk-handoff`)는 항상 private 유지** — `gh repo view` 로 visibility 확인 가능
- **메모리 디렉토리(`~/.claude/projects/.../memory/`)는 이 스킬이 건드리지 않음** — 별도 관심사이며 머신마다 경로가 달라짐
