#!/usr/bin/env python3
"""analyze_diff.py — 두 HANDOFF.md snapshot 비교.

목적: 받기 시 "이 머신을 마지막으로 떠난 후 무엇이 바뀌었나" 자연어 brief.

사용법:
  python3 analyze_diff.py <prev_snapshot.md> <curr_snapshot.md>

prev = 현재 머신의 마지막 snapshot (없으면 None)
curr = LATEST snapshot (다른 머신에서 방금 넘긴 것)

prev가 None이면 "이 머신에서는 이 프로젝트 처음 받기" 모드 — curr만 요약.

출력: 사람 가독 자연어 brief (stdout).
"""

from __future__ import annotations
import re
import sys
from pathlib import Path


# HANDOFF.md 섹션 헤더 → 우리가 추적할 키
SECTIONS = {
    "지금 무엇을 하고 있었나": "current_work",
    "작업목록 (TODO)": "todos",
    "다음 컴퓨터에서 바로 할 일": "next_steps",
    "미해결 질문": "open_questions",
    "메모 / 결정사항": "notes",
}


def parse_sections(text: str) -> dict[str, str]:
    """## 헤더로 구분된 섹션들을 dict로."""
    out: dict[str, str] = {}
    current_key: str | None = None
    buf: list[str] = []
    for line in text.splitlines():
        # ## 헤더 (이모지 포함 가능)
        m = re.match(r"^##\s+(?:[^\w\s]+\s+)?(.+?)\s*$", line)
        if m:
            if current_key:
                out[current_key] = "\n".join(buf).strip()
            heading = m.group(1).strip()
            current_key = None
            for label, key in SECTIONS.items():
                if label in heading:
                    current_key = key
                    break
            buf = []
        elif current_key:
            buf.append(line)
    if current_key:
        out[current_key] = "\n".join(buf).strip()
    return out


def parse_todos(section_text: str) -> tuple[set[str], set[str]]:
    """체크박스 항목 추출 → (완료, 미완료) 텍스트 집합.

    완료 = `- [x]` / `- [X]` / `* [x]`
    미완료 = `- [ ]` / `* [ ]`
    텍스트는 chk box 다음 부분 trim.
    """
    done: set[str] = set()
    todo: set[str] = set()
    for line in section_text.splitlines():
        m = re.match(r"^\s*[-*]\s*\[([xX ])\]\s+(.+?)\s*$", line)
        if not m:
            continue
        marker, text = m.group(1), m.group(2).strip()
        if marker.lower() == "x":
            done.add(text)
        else:
            todo.add(text)
    return done, todo


def parse_bullets(section_text: str) -> set[str]:
    """일반 bullet 항목 추출 (TODO 아닌 일반 리스트용)."""
    items: set[str] = set()
    for line in section_text.splitlines():
        m = re.match(r"^\s*[-*]\s+(?!\[)(.+?)\s*$", line)
        if m:
            items.add(m.group(1).strip())
    return items


def short(s: str, n: int = 80) -> str:
    s = s.strip()
    return s if len(s) <= n else s[: n - 1] + "…"


def render_first_run(curr_path: Path, curr_sections: dict[str, str]) -> str:
    """prev 없을 때 — curr 요약만."""
    lines = []
    lines.append("📂 이 머신에서는 이 프로젝트 첫 받기입니다.")
    lines.append("")
    if cw := curr_sections.get("current_work"):
        lines.append("🎯 지금 무엇을:")
        lines.append("  " + short(cw, 120))
        lines.append("")
    if ns := curr_sections.get("next_steps"):
        lines.append("▶️ 다음 할 일:")
        for line in ns.splitlines()[:5]:
            line = line.strip()
            if line:
                lines.append("  " + short(line, 100))
        lines.append("")
    _, todos = parse_todos(curr_sections.get("todos", ""))
    if todos:
        lines.append(f"📋 진행중 TODO {len(todos)}개:")
        for t in list(todos)[:5]:
            lines.append("  - " + short(t, 100))
        lines.append("")
    if oq := curr_sections.get("open_questions"):
        oq_items = parse_bullets(oq) | {
            t for _, ts in [parse_todos(oq)] for t in ts
        }
        if oq_items:
            lines.append(f"❓ 미해결 질문 {len(oq_items)}개:")
            for q in list(oq_items)[:3]:
                lines.append("  - " + short(q, 100))
    return "\n".join(lines)


def render_diff(prev_sections: dict[str, str], curr_sections: dict[str, str]) -> str:
    """prev vs curr 비교 brief."""
    lines = []
    lines.append("🔄 이 머신을 마지막으로 떠난 후 변화:")
    lines.append("")

    # 1) "지금 무엇을" 변화
    prev_cw = prev_sections.get("current_work", "").strip()
    curr_cw = curr_sections.get("current_work", "").strip()
    if prev_cw != curr_cw:
        lines.append("🎯 작업 초점이 바뀌었습니다:")
        lines.append("  이전: " + short(prev_cw or "(비어있음)", 100))
        lines.append("  현재: " + short(curr_cw or "(비어있음)", 100))
        lines.append("")
    else:
        lines.append("🎯 작업 초점 동일: " + short(curr_cw or "(비어있음)", 100))
        lines.append("")

    # 2) TODO 변화
    prev_done, prev_todo = parse_todos(prev_sections.get("todos", ""))
    curr_done, curr_todo = parse_todos(curr_sections.get("todos", ""))

    completed = (prev_todo & curr_done) | (
        prev_todo - curr_todo - curr_done
    )  # 이전엔 미완료, 지금은 완료 또는 사라짐(가정: 완료로 간주 안 함; 분리해서 처리)
    newly_completed = prev_todo & curr_done
    newly_added = curr_todo - prev_todo - prev_done
    still_pending = prev_todo & curr_todo
    removed = (prev_todo | prev_done) - curr_todo - curr_done

    if newly_completed:
        lines.append(f"✅ 완료된 TODO {len(newly_completed)}개:")
        for t in list(newly_completed)[:5]:
            lines.append("  - " + short(t, 100))
        lines.append("")
    if newly_added:
        lines.append(f"➕ 새로 추가된 TODO {len(newly_added)}개:")
        for t in list(newly_added)[:5]:
            lines.append("  - " + short(t, 100))
        lines.append("")
    if still_pending:
        lines.append(f"⏳ 그대로 남은 TODO {len(still_pending)}개:")
        for t in list(still_pending)[:5]:
            lines.append("  - " + short(t, 100))
        lines.append("")
    if removed:
        lines.append(f"🗑️ 제거된 항목 {len(removed)}개 (취소/병합으로 추정):")
        for t in list(removed)[:3]:
            lines.append("  - " + short(t, 100))
        lines.append("")

    # 3) 미해결 질문 추적 (반복 = 미루는 질문, 신호)
    prev_q = parse_bullets(prev_sections.get("open_questions", ""))
    curr_q = parse_bullets(curr_sections.get("open_questions", ""))
    repeated = prev_q & curr_q
    new_q = curr_q - prev_q
    resolved_q = prev_q - curr_q
    if repeated:
        lines.append(f"⚠️ 계속 남은 미해결 질문 {len(repeated)}개 (이번엔 처리?):")
        for q in list(repeated)[:3]:
            lines.append("  - " + short(q, 100))
        lines.append("")
    if new_q:
        lines.append(f"❓ 신규 미해결 질문 {len(new_q)}개:")
        for q in list(new_q)[:3]:
            lines.append("  - " + short(q, 100))
        lines.append("")
    if resolved_q:
        lines.append(f"✓ 해결된 질문 {len(resolved_q)}개")

    # 4) 다음 할 일 (변화 여부만)
    if prev_sections.get("next_steps") != curr_sections.get("next_steps"):
        lines.append("▶️ '다음 할 일' 갱신됨 — 현재:")
        for line in (curr_sections.get("next_steps") or "").splitlines()[:5]:
            line = line.strip()
            if line:
                lines.append("  " + short(line, 100))

    return "\n".join(lines)


def main():
    if len(sys.argv) < 3:
        print("사용법: analyze_diff.py <prev_snapshot.md|NONE> <curr_snapshot.md>",
              file=sys.stderr)
        sys.exit(2)

    prev_arg, curr_arg = sys.argv[1], sys.argv[2]
    curr_path = Path(curr_arg)
    if not curr_path.exists():
        print(f"❌ curr snapshot 없음: {curr_path}", file=sys.stderr)
        sys.exit(3)

    curr_text = curr_path.read_text(encoding="utf-8")
    curr_sections = parse_sections(curr_text)

    if prev_arg in ("NONE", "-", ""):
        print(render_first_run(curr_path, curr_sections))
        return

    prev_path = Path(prev_arg)
    if not prev_path.exists():
        print(render_first_run(curr_path, curr_sections))
        return

    prev_text = prev_path.read_text(encoding="utf-8")
    prev_sections = parse_sections(prev_text)
    print(render_diff(prev_sections, curr_sections))


if __name__ == "__main__":
    main()
