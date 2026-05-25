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

### Claude Code에서 (2줄)

```
/plugin marketplace add JaeKwon6448/jk-skills
/plugin install 넘기기@jk-skills
/plugin install 받기@jk-skills
```

설치 즉시 두 스킬이 활성화되며, 어느 프로젝트에서든 자연어 트리거(`"받기"`, `"넘기기"`)로 작동합니다.

## 업데이트

```
/plugin update 넘기기@jk-skills
/plugin update 받기@jk-skills
```

또는 새 버전이 push되면 Claude Code가 알아서 알림.

## 제거

```
/plugin uninstall 넘기기@jk-skills
/plugin uninstall 받기@jk-skills
/plugin marketplace remove jk-skills
```

## 설치 후 디렉토리

```
~/.claude/plugins/cache/jk-skills/넘기기/1.0.0/
~/.claude/plugins/cache/jk-skills/받기/1.0.0/
~/.cache/jk-handoff/                          ← 인덱스 캐시 (첫 받기 시 자동 생성)
```

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
