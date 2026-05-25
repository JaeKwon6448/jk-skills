# jk-skills

> JK의 글로벌 Claude Code 스킬 모음. 여러 맥에서 동일한 환경 유지.

## 들어있는 스킬

- **넘기기** — 현재 프로젝트 작업 상태를 GitHub에 저장 + `jk-handoff` 인덱스 repo에 머신 이력 누적
- **받기** — 다른 머신에서 작업하던 것을 한 줄로 이어받기 (clone/pull → HANDOFF.md 브리핑)

두 스킬이 같이 동작하면서 "어느 컴퓨터에서 뭘 하다 멈췄는지" 가 머신 간에 보존된다.
실제 작업 메타데이터는 별도 private repo `jk-handoff` 에 누적된다.

## 새 맥 1회 설치

사전: `brew install gh && gh auth login` (한 번)

그 다음 한 줄:

```bash
curl -fsSL https://raw.githubusercontent.com/JaeKwon6448/jk-skills/main/bootstrap.sh | bash
```

또는 동등하게:

```bash
gh repo clone JaeKwon6448/jk-skills ~/jk-skills && bash ~/jk-skills/bootstrap.sh
```

bootstrap이 하는 일:
1. git/gh/python3 설치 확인
2. gh 인증 확인
3. 이 repo를 `~/jk-skills/` 에 clone (또는 pull)
4. `~/jk-skills/skills/*` 를 `~/.claude/skills/` 에 **symlink** (수정 즉시 반영)
5. `jk-handoff` 인덱스 repo를 `~/.cache/jk-handoff/` 에 미리 clone (첫 받기 빠르게)

## 업데이트 (이미 설치된 맥)

```bash
cd ~/jk-skills && git pull
```

심볼릭 링크라 별도 재설치 불필요. 새 스킬이 추가됐을 때만:

```bash
bash ~/jk-skills/install.sh
```

(idempotent — 몇 번 돌려도 안전)

## 디렉토리 구조

```
~/jk-skills/          ← 이 repo (스킬 진실 소스)
├── skills/
│   ├── 넘기기/
│   └── 받기/
├── install.sh
├── bootstrap.sh
└── README.md

~/.claude/skills/      ← Claude Code가 보는 위치
├── 넘기기 → ~/jk-skills/skills/넘기기  (symlink)
└── 받기  → ~/jk-skills/skills/받기   (symlink)

~/.cache/jk-handoff/   ← 인덱스 repo 로컬 캐시 (자동 관리)
```

## 관련 repo

- [JaeKwon6448/jk-handoff](https://github.com/JaeKwon6448/jk-handoff) (private) — 작업 이력 인덱스
