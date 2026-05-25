# jk-skills

> JK의 글로벌 Claude Code 스킬 모음. **Claude Code marketplace로 배포** — 어느 맥에서든 2줄로 설치.

## 들어있는 스킬

| 스킬 | 트리거 | 동작 |
|---|---|---|
| **넘기기** | "넘기기", "저장", "백업", "동기화" | 현재 작업 상태 HANDOFF.md로 패키징 → GitHub push → `jk-handoff` 인덱스에 머신 이력 누적 |
| **받기** | "받기", "이어가기", "다른 컴퓨터에서 왔어" | `jk-handoff` 인덱스 조회 → 가장 최근 작업 자동 안내 → clone/pull → 브리핑 |

두 스킬이 같이 돌면서 **"어느 컴퓨터에서 뭘 하다 멈췄는지"** 가 머신 간에 보존됩니다.
실제 작업 메타데이터는 별도 private repo [`jk-handoff`](https://github.com/JaeKwon6448/jk-handoff)에 누적됩니다.

## 새 맥에서 설치

### 사전 (1회)

```bash
brew install gh && gh auth login
```

`gh` 인증은 jk-handoff(private repo) 접근에 필요합니다.

### Claude Code에서 (3줄)

```
claude plugin marketplace add JaeKwon6448/jk-skills
claude plugin install handoff-save@jk-skills
claude plugin install handoff-receive@jk-skills
```

> plugin name은 영문(`handoff-save` / `handoff-receive`)이지만, **자연어 트리거는 한글 그대로** — 어느 프로젝트에서든 `"넘기기"`, `"받기"`로 작동합니다. (Claude Code의 plugin cache 경로가 ASCII만 지원해서 식별자만 영문화)

## 업데이트

```
claude plugin update handoff-save@jk-skills
claude plugin update handoff-receive@jk-skills
```

## 제거

```
claude plugin uninstall handoff-save@jk-skills
claude plugin uninstall handoff-receive@jk-skills
claude plugin marketplace remove jk-skills
```

## 설치 후 디렉토리

```
~/.claude/plugins/cache/jk-skills/handoff-save/1.1.0/
~/.claude/plugins/cache/jk-skills/handoff-receive/1.1.0/
~/.cache/jk-handoff/                          ← 인덱스 캐시 (첫 받기 시 자동 생성)
```

## v1.1.0 변경점 — 멀티-프로젝트 꼬임 방지

- **`IN_FLIGHT.json`** 신규: jk-handoff 인덱스에 멀티-프로젝트 상태 추적 (LATEST 1건 + 모든 활성 프로젝트 상태)
- **받기 시 머신 경고**: LATEST 머신과 현재 머신이 다르면 "이전 머신에 미저장 변경 있을 수 있음" 안내
- **`status_all.sh` 신규**: 알려진 활성 프로젝트들의 git 상태 한꺼번에 스캔. 머신 옮기기 전에 미저장 작업 한눈에 확인
- **plugin name과 SKILL.md name 모두 ASCII로 통일** (`handoff-save`, `handoff-receive`). 자연어 트리거는 description의 한글 키워드("넘기기", "받기" 등)로 매칭

## 직접 개발/수정하려면

이 repo를 로컬에 clone해서 작업:

```bash
git clone https://github.com/JaeKwon6448/jk-skills ~/jk-skills
# 스크립트 수정 후
cd ~/jk-skills && git push
# 다른 머신에서: /plugin update <name>@jk-skills
```

## 관련 repo

- [JaeKwon6448/jk-handoff](https://github.com/JaeKwon6448/jk-handoff) (private) — 작업 이력 인덱스
