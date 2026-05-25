---
name: 전달
description: 권재일님이 분석/리포트를 특정 팀의 에이전트에게 핸드오프하는 스킬. 트리거 시 (1) 팀·에이전트 선택 (2) 받은 에이전트의 TODO 리스트(TaskCreate)에 즉시 추가 (3) "지금 바로 처리할지, 현재 작업 마치고 할지" 사용자에게 묻기 (4) 답변에 따라 즉시 인터럽트 또는 대기. 트리거: "전달", "버핏에게 알려줘", "Lynch한테 보내", "X에게 전달", `/전달`.
---

# 전달 — 인터럽트 핸드오프 스킬 (v3)

## 핵심 동작

권재일님이 *"전달"* 하면 4단계로 처리:

1. **팀·에이전트 선택** (AskUserQuestion)
2. **파일·의도 자동 확정** (모호 시 질문)
3. **TODO 적재 3중**: TaskCreate(in-session) + 큐 파일(persistent) + INBOX(이력)
4. **타이밍 질문**: 지금 바로 / 현재 작업 마치고 / 큐에만 두고 나중에

이 스킬의 본질은 **"에이전트가 현재 작업 중일 때 새 지시를 받으면 TODO에 적재하고 사용자에게 우선순위를 묻는다"** 는 인터럽트 프로토콜이다.

---

## 실행 순서

### 1단계 — 어느 팀에 전달?

`AskUserQuestion` (사용자 메시지에 팀명이 명시되었으면 묻지 않음):

- **질문**: "어느 팀에 전달할까요?"
- **header**: "전달 대상 팀"
- **multiSelect**: false
- **옵션**:
  - `stock-team` — 한국 주식 투자팀
  - `honi-team` — 병훈 학습 코치팀
  - `둘 다` — 양쪽 동시 전달

### 2단계 — 어느 에이전트에게? (multiSelect)

선택된 팀에 따라 에이전트 옵션 표시. **description은 현재 컨텍스트 기준으로 "왜 이 사람이 적합한지" 한 줄로 적어 의사결정을 돕는다.**

**stock-team 에이전트 ID 매핑** (큐 파일명 = persona 파일명):
| 별명 | agent_id |
|---|---|
| Buffett (PM) | `portfolio-manager` |
| Graham | `fundamental-analyst` |
| Livermore | `technical-analyst` |
| Soros | `news-analyst` |
| Dalio | `macro-analyst` |
| Taleb | `risk-manager` |
| Lynch | `portfolio-tracker` |
| 학주 | `hakju` |
| 방천 | `bangcheon` |
| 상준 | `sangjun` |
| 지호 | `jiho` |
| 영익 | `youngik` |

**honi-team 옵션**: 코치 / 국어 / 영어 / 수학 / 과학 / 사회 / 한국사 / 전원

### 3단계 — 전달할 파일 자동 확정

**우선순위**:
1. 사용자 메시지에 파일 경로 명시 → 사용
2. 직전 작업 턴에서 Write/Edit로 만든 가장 최근 `reports/YYYY-MM-DD/*.md` 또는 `outputs/*.md`
3. `find <team_root>/reports/$(date +%Y-%m-%d) -name "*.md" -mmin -120`
4. INBOX.md의 가장 최근 `[UNREAD]` 항목

후보 0개 또는 2개+ 면 `AskUserQuestion`으로 확인.

### 4단계 — 의뢰 의도 추출

직전 대화에서 자동 추출. 카테고리:
- **분석/검토** (default) — 페르소나 관점 평가
- **비교/벤치마크** — 기존 자산과 비교
- **기록만** — 큐 적재 없이 INBOX 이력만
- **긴급** — 큐 적재 + Telegram (스크립트 있을 때)

명시 없으면 분석/검토 기본값, 사실 알림. 모호하면 AskUserQuestion.

### 5단계 — 3중 적재 (모두 동시 실행)

각 선택된 에이전트마다:

#### 5-1. TaskCreate (in-session TODO — 가장 중요)

```
TaskCreate({
  subject: "[전달] <에이전트 별명>: <짧은 제목>",
  description: "원본: <파일 절대 경로>\n의뢰 의도: <intent>\n출처: 권재일님 /전달 스킬\n응답 저장 권장 경로: <reports/YYYY-MM-DD/<agent_id>_response_<topic>.md>",
  activeForm: "<에이전트 별명> 의뢰 처리 중"
})
```

이렇게 적재하면 **현재 Claude 세션의 가시적 TODO 리스트에 항목이 즉시 뜬다.** Buffett(또는 현재 voice)이 작업 중이라도 이 항목을 놓치지 않는다.

#### 5-2. 큐 파일 (persistent — 다음 세션 보호용)

```bash
cd <team_root> && bash scripts/queue_add.sh \
  <agent_id> "<제목>" "<리포트 path>" "<intent>" "<extra_notes>"
```

#### 5-3. INBOX 이력 (audit trail)

```bash
cd <team_root> && bash scripts/inbox_add.sh \
  "<제목>" "<리포트 path>" "권재일님 /전달 스킬" "<intent>" "<참여 에이전트들>"
```

(이미 INBOX에 있으면 중복 추가 X, 대신 `dispatched_to` 필드 갱신)

### 6단계 — 사용자에게 1차 보고 (전달 완료)

```
✅ 전달 완료

📥 받은 에이전트: <별명들>
📄 원본: <원본 파일 경로>
📋 TODO 리스트 추가됨 (현재 세션 + 큐 파일 + INBOX 이력)
```

### 7단계 — 타이밍 질문 (인터럽트 프로토콜 핵심)

`AskUserQuestion`:

- **질문**: "받은 지시를 언제 처리할까요?"
- **header**: "처리 타이밍"
- **multiSelect**: false
- **옵션**:
  - `지금 바로 처리` — 현재 작업 일시 중단, 새 지시 즉시 시작
  - `현재 작업 마치고 처리` — 현재 작업 완료 후 자동으로 새 지시 시작 (TODO 리스트가 보장)
  - `큐에만 두고 다음 호출 시 처리` — 이번 세션에서는 손대지 않음

### 8단계 — 답변에 따른 처리

#### `지금 바로 처리`:
1. 현재 진행 중이던 TaskCreate 항목들이 있으면 `TaskUpdate(status="pending")`로 일시 중지
2. 새 전달 항목 `TaskUpdate(status="in_progress")`로 시작
3. 즉시 페르소나 전환 (해당 에이전트의 .claude/agents/<id>.md 룰 흡수) + 파일 정독 + 응답 작성 + 응답 파일 저장
4. 완료 후 `TaskUpdate(status="completed")` + 큐 파일에서 해당 항목을 `[PENDING]` → `[DONE]`으로 변경 + `response` 필드 추가
5. 사용자에게 결론 한 줄 + 응답 파일 경로 보고
6. 일시 중지된 원래 작업으로 복귀할지 묻기 또는 자동 복귀

#### `현재 작업 마치고 처리`:
1. 새 전달 항목은 `pending` 상태 유지
2. 현재 작업 계속 진행
3. 현재 작업의 마지막 TaskUpdate(completed) 시점에 Claude는 **자동으로 다음 pending 항목**(전달받은 것)을 확인해 처리 시작
4. 사용자에게는 한 줄 알림: *"현재 작업 마치고 [전달 항목] 처리하겠습니다"*

#### `큐에만 두고 다음 호출 시 처리`:
1. 큐 파일·INBOX·TaskCreate에 적재된 상태 그대로 유지
2. 사용자에게 알림: *"큐에 적재했습니다. 다음에 <에이전트 별명> 호출하시면 자동 처리됩니다"*
3. 이번 세션에서는 더 진행하지 않음

---

## 다중 에이전트 처리 시 인터럽트 룰

복수 에이전트 선택 (예: Buffett + Lynch + Taleb)한 경우:

- 5단계는 각 에이전트마다 따로 적재 (TaskCreate × 3, queue_add × 3, INBOX 1번)
- 7단계 타이밍 질문은 **공통으로 1회만**
- 8단계 `지금 바로`인 경우:
  - **Buffett(PM)이 포함되어 있으면**: Buffett 먼저 처리(다른 에이전트 응답을 종합해야 하므로 마지막), 나머지는 병렬 처리
  - **Buffett 없으면**: 모두 병렬 처리
- 처리 순서를 사용자에게 알림: *"Lynch + Taleb 병렬 처리 후 Buffett이 종합"*

---

## 팀 root 경로 매핑

| 팀명 | root | 큐 디렉토리 |
|---|---|---|
| `stock-team` | `/Users/jkwon14/stock-team` | `tasks/agent_queue/` |
| `honi-team` | `/Users/jkwon14/honi-team` | `tasks/agent_queue/` (없으면 셋업 권유) |

---

## 에지 케이스

- **파일 0개**: "전달할 파일이 없어요. 무엇을 분석할지 먼저 말씀해주세요" 알리고 종료
- **팀 root에 큐 디렉토리 없음**: 사용자에게 셋업 권유
- **'기록만' 의도**: 5단계 TaskCreate·queue_add 건너뛰고 INBOX만, 7단계 질문 건너뛰기
- **'긴급' 의도**: TaskCreate priority 표시 + Telegram 알림 + 7단계 default를 `지금 바로`로
- **사용자가 슬래시 `/전달` 호출**: 1단계부터 동일
- **같은 에이전트에게 이미 같은 주제 전달**: TaskCreate description에 "v2" 표기, 큐에는 `_v2` 접미사로 새 항목
- **타이밍 질문 답변이 `Other`로 자유 입력**: 사용자 의도 해석해서 가장 가까운 옵션으로 매핑

---

## 트리거 표현

스킬 자동 발동:
- 단독: "전달", "전달해줘", "전달해줄래"
- 에이전트 지목: "X에게 알려줘", "X한테 보내", "X에게 검토"
- 팀 지목: "stock-team으로 넘겨", "honi-team에 의뢰"
- 별명 단독: "버핏한테 이거", "Lynch한테", "Taleb한테", "코치한테"

**단**: *"버핏 의견 좀"* 같은 즉답 요청(파일 핸드오프 아님)은 스킬 안 띄움. 판단 기준: **직전·현재 턴에서 생성·분석된 파일을 가리키는가**.

---

## 시스템 다이어그램

```
사용자: "전달"
   ↓
[/전달 스킬]
   ↓
1. 어느 팀? ──────────── AskUserQuestion
2. 누구에게? (multi) ──── AskUserQuestion
3. 어떤 파일? ─────────── 자동 탐지 (모호 시 질문)
4. 어떤 의도? ─────────── 자동 추출 (모호 시 질문)
5. 3중 적재 (동시):
   ├─ TaskCreate (in-session TODO)
   ├─ queue_add.sh (persistent 파일)
   └─ inbox_add.sh (audit history)
6. "✅ 전달 완료" 알림
   ↓
7. 타이밍 질문 ────────── AskUserQuestion
   ├─ "지금 바로"          → 현재 작업 pause + 새 작업 즉시 시작
   ├─ "현재 작업 후"       → pending 유지, 현재 완료 시 자동 처리
   └─ "큐에만"             → 이번 세션 진행 X
   ↓
8. 선택에 따라 처리
   완료 시 → TaskUpdate(completed) + 큐 [DONE] + 응답 파일 저장
```

---

## 인박스/큐/TODO 3중 채널 관계

| 채널 | 가시성 | 시점 | 용도 |
|---|---|---|---|
| **TaskCreate (in-session)** | 현재 세션 사이드바 | 즉시 | 권재일님이 실시간으로 볼 수 있는 TODO 리스트 |
| **큐 파일 (tasks/agent_queue/<id>.md)** | 파일 시스템 | 영구 | 세션 종료 후에도 보존 — 다음 호출 시 보장 |
| **INBOX (reports/INBOX.md)** | 파일 시스템 | 영구 | 전체 핸드오프 audit trail |

세 채널이 동시에 갱신되어 어디서 보든 동일한 진실. 어느 하나가 누락되어도 다른 채널로 복구 가능.
