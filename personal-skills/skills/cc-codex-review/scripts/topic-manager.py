#!/usr/bin/env python3
"""topic-manager.py - CC-Codex 话题生命周期管理工具

用法:
    python topic-manager.py <command> <project_root> [args...]

Commands:
    topic-create <root> <title> [type]     创建新话题
    topic-read <root>                      读取活跃话题元数据+摘要
    topic-update <root> <field> <value>    更新话题字段
    topic-complete <root>                  完成话题，清除指针
    topic-list <root>                      列出所有话题
    auto-cleanup <root> [minutes]          检测清理过期话题（默认120分钟）
    status <root>                          输出状态摘要

所有 stdout 输出为 JSON，错误走 stderr。
"""

import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Union

DATA_DIR = ".cc-codex"
ACTIVE_FILE = "active.json"
TOPICS_DIR = "topics"
MAX_ROUNDS = 5

VALID_TYPES = [
    "code-implementation",
    "architecture-design",
    "bug-analysis",
    "technical-decision",
    "open-discussion",
]

VALID_STATUSES = ["active", "completed", "abandoned"]

TERMINATION_REASONS = [
    "consensus",
    "user_stopped",
    "max_rounds",
    "abandoned",
    "budget_exhausted",
]

SUMMARY_TEMPLATE = """# {title}

## 基本信息
- 类型: {topic_type}
- 状态: 进行中
- 当前轮次: 0/{max_rounds}

## 当前结论
（尚未开始讨论）

## 未决分歧
（无）

## 关键证据与上下文
（待收集）

## 已确认的决策
（无）
"""


def err(msg: str) -> None:
    print(msg, file=sys.stderr)


def out(data: Union[dict, list]) -> None:
    print(json.dumps(data, ensure_ascii=False, indent=2))


def atomic_write_json(path: Path, data: dict) -> None:
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    os.replace(str(tmp), str(path))


def atomic_write_text(path: Path, text: str) -> None:
    tmp = path.with_suffix(".tmp")
    tmp.write_text(text, encoding="utf-8")
    os.replace(str(tmp), str(path))


def slugify(text: str) -> str:
    text = text.lower().strip()
    text = re.sub(r"[^\w\s-]", "", text)
    text = re.sub(r"[\s_]+", "-", text)
    text = re.sub(r"-+", "-", text)
    return text[:40].strip("-")


def now_iso() -> str:
    return datetime.now().strftime("%Y-%m-%dT%H:%M:%S")


def data_root(project_root: str) -> Path:
    return Path(project_root) / DATA_DIR


def active_path(project_root: str) -> Path:
    return data_root(project_root) / ACTIVE_FILE


def topics_root(project_root: str) -> Path:
    return data_root(project_root) / TOPICS_DIR


def read_active(project_root: str) -> Optional[dict]:
    p = active_path(project_root)
    if p.is_file():
        try:
            return json.loads(p.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            return None
    return None


def find_topic_dir(project_root: str, topic_id: str) -> Optional[Path]:
    base = topics_root(project_root)
    if not base.is_dir():
        return None
    for d in base.iterdir():
        if d.is_dir() and d.name == topic_id:
            return d
    return None


def read_meta(topic_dir: Path) -> Optional[dict]:
    meta = topic_dir / "meta.json"
    if meta.is_file():
        try:
            return json.loads(meta.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            return None
    return None


def read_summary(topic_dir: Path) -> Optional[str]:
    summary = topic_dir / "summary.md"
    if summary.is_file():
        try:
            return summary.read_text(encoding="utf-8")
        except OSError:
            return None
    return None


# ============================================================
# Commands
# ============================================================


def cmd_topic_create(project_root: str, title: str, topic_type: str = "open-discussion") -> None:
    if topic_type not in VALID_TYPES:
        err(f"Invalid topic type: {topic_type}. Valid: {', '.join(VALID_TYPES)}")
        sys.exit(1)

    # Check for existing active topic
    active = read_active(project_root)
    if active:
        topic_dir = find_topic_dir(project_root, active["topic_id"])
        if topic_dir:
            meta = read_meta(topic_dir)
            if meta and meta.get("status") == "active":
                err(f"Already have an active topic: {active['topic_id']}")
                out({"error": "active_topic_exists", "topic_id": active["topic_id"],
                     "title": meta.get("title", "")})
                sys.exit(1)

    # Create topic directory
    ts = datetime.now().strftime("%Y%m%d-%H%M%S")
    slug = slugify(title)
    topic_id = f"{ts}-{slug}" if slug else ts

    base = topics_root(project_root)
    topic_dir = base / topic_id
    topic_dir.mkdir(parents=True, exist_ok=True)
    (topic_dir / "artifacts").mkdir(exist_ok=True)

    # Write meta.json
    meta = {
        "title": title,
        "type": topic_type,
        "status": "active",
        "session_id": None,
        "round": 0,
        "max_rounds": MAX_ROUNDS,
        "output_dir": None,
        "termination_reason": None,
        "created_at": now_iso(),
        "updated_at": now_iso(),
        "completed_at": None,
    }
    atomic_write_json(topic_dir / "meta.json", meta)

    # Write summary.md
    summary_text = SUMMARY_TEMPLATE.format(
        title=title, topic_type=topic_type, max_rounds=MAX_ROUNDS
    )
    atomic_write_text(topic_dir / "summary.md", summary_text)

    # Update active pointer
    data_root(project_root).mkdir(parents=True, exist_ok=True)
    atomic_write_json(active_path(project_root), {"topic_id": topic_id})

    out({"topic_id": topic_id, "title": title, "type": topic_type, "status": "active"})


def cmd_topic_read(project_root: str) -> None:
    active = read_active(project_root)
    if not active:
        out({"active": False})
        return

    topic_id = active["topic_id"]
    topic_dir = find_topic_dir(project_root, topic_id)
    if not topic_dir:
        out({"active": False, "error": "topic_dir_missing", "topic_id": topic_id})
        return

    meta = read_meta(topic_dir)
    if not meta:
        out({"active": False, "error": "meta_missing", "topic_id": topic_id})
        return

    summary = read_summary(topic_dir)
    result = {"active": True, "topic_id": topic_id, "meta": meta}
    if summary:
        result["summary"] = summary
    out(result)


def cmd_topic_update(project_root: str, field: str, value: str) -> None:
    active = read_active(project_root)
    if not active:
        err("No active topic")
        sys.exit(1)

    topic_dir = find_topic_dir(project_root, active["topic_id"])
    if not topic_dir:
        err(f"Topic directory not found: {active['topic_id']}")
        sys.exit(1)

    meta = read_meta(topic_dir)
    if not meta:
        err("Cannot read meta.json")
        sys.exit(1)

    # Field whitelist
    allowed_fields = {
        "title", "type", "status", "session_id", "round", "max_rounds",
        "output_dir", "termination_reason",
    }
    if field not in allowed_fields:
        err(f"Unknown field: {field}. Allowed: {', '.join(sorted(allowed_fields))}")
        sys.exit(1)

    # Type conversion for known fields
    if field in ("round", "max_rounds"):
        try:
            value = int(value)
        except ValueError:
            err(f"Invalid integer value for {field}: {value}")
            sys.exit(1)
    elif field in ("session_id", "output_dir", "termination_reason"):
        if value.lower() == "null":
            value = None

    # Validate specific fields
    if field == "type" and value not in VALID_TYPES:
        err(f"Invalid type: {value}")
        sys.exit(1)
    if field == "status" and value not in VALID_STATUSES:
        err(f"Invalid status: {value}")
        sys.exit(1)
    if field == "termination_reason" and value is not None and value not in TERMINATION_REASONS:
        err(f"Invalid termination_reason: {value}")
        sys.exit(1)

    meta[field] = value
    meta["updated_at"] = now_iso()
    atomic_write_json(topic_dir / "meta.json", meta)

    out({"topic_id": active["topic_id"], "updated": {field: value}})


def cmd_topic_complete(project_root: str) -> None:
    active = read_active(project_root)
    if not active:
        err("No active topic")
        sys.exit(1)

    topic_dir = find_topic_dir(project_root, active["topic_id"])
    if not topic_dir:
        err(f"Topic directory not found: {active['topic_id']}")
        sys.exit(1)

    meta = read_meta(topic_dir)
    if not meta:
        err("Cannot read meta.json")
        sys.exit(1)

    meta["status"] = "completed"
    meta["completed_at"] = now_iso()
    meta["updated_at"] = now_iso()
    if not meta.get("termination_reason"):
        meta["termination_reason"] = "consensus"
    atomic_write_json(topic_dir / "meta.json", meta)

    # Clear active pointer
    ap = active_path(project_root)
    if ap.is_file():
        ap.unlink()

    out({"topic_id": active["topic_id"], "status": "completed",
         "termination_reason": meta["termination_reason"]})


def cmd_topic_list(project_root: str) -> None:
    base = topics_root(project_root)
    if not base.is_dir():
        out([])
        return

    active = read_active(project_root)
    active_id = active["topic_id"] if active else None

    topics = []
    for d in sorted(base.iterdir(), reverse=True):
        if not d.is_dir():
            continue
        meta = read_meta(d)
        if meta:
            topics.append({
                "topic_id": d.name,
                "title": meta.get("title", ""),
                "type": meta.get("type", ""),
                "status": meta.get("status", ""),
                "round": meta.get("round", 0),
                "is_active": d.name == active_id,
                "created_at": meta.get("created_at", ""),
                "completed_at": meta.get("completed_at"),
            })
    out(topics)


def cmd_auto_cleanup(project_root: str, threshold_minutes: int = 120) -> None:
    active = read_active(project_root)
    if not active:
        out({"cleaned": False, "reason": "no_active_topic"})
        return

    topic_dir = find_topic_dir(project_root, active["topic_id"])
    if not topic_dir:
        # Stale pointer, remove it
        ap = active_path(project_root)
        if ap.is_file():
            ap.unlink()
        out({"cleaned": True, "reason": "stale_pointer", "topic_id": active["topic_id"]})
        return

    meta = read_meta(topic_dir)
    if not meta or meta.get("status") != "active":
        ap = active_path(project_root)
        if ap.is_file():
            ap.unlink()
        out({"cleaned": True, "reason": "not_active", "topic_id": active["topic_id"]})
        return

    # Check updated_at timestamp
    updated_str = meta.get("updated_at", "")
    if not updated_str:
        out({"cleaned": False, "reason": "no_timestamp"})
        return

    try:
        updated_dt = datetime.strptime(updated_str, "%Y-%m-%dT%H:%M:%S")
        elapsed_minutes = (datetime.now() - updated_dt).total_seconds() / 60
    except ValueError:
        out({"cleaned": False, "reason": "bad_timestamp"})
        return

    if elapsed_minutes >= threshold_minutes:
        meta["status"] = "abandoned"
        meta["termination_reason"] = "abandoned"
        meta["updated_at"] = now_iso()
        atomic_write_json(topic_dir / "meta.json", meta)

        ap = active_path(project_root)
        if ap.is_file():
            ap.unlink()

        out({
            "cleaned": True,
            "reason": "expired",
            "topic_id": active["topic_id"],
            "elapsed_minutes": int(elapsed_minutes),
        })
    else:
        out({
            "cleaned": False,
            "reason": "still_active",
            "topic_id": active["topic_id"],
            "elapsed_minutes": int(elapsed_minutes),
        })


def cmd_status(project_root: str) -> None:
    active = read_active(project_root)
    base = topics_root(project_root)

    result = {"active_topic": None, "total_topics": 0, "by_status": {}}

    if active:
        topic_dir = find_topic_dir(project_root, active["topic_id"])
        if topic_dir:
            meta = read_meta(topic_dir)
            if meta:
                result["active_topic"] = {
                    "topic_id": active["topic_id"],
                    "title": meta.get("title", ""),
                    "type": meta.get("type", ""),
                    "round": meta.get("round", 0),
                    "max_rounds": meta.get("max_rounds", MAX_ROUNDS),
                    "session_id": meta.get("session_id"),
                    "updated_at": meta.get("updated_at", ""),
                }

    if base.is_dir():
        counts = {}
        total = 0
        for d in base.iterdir():
            if not d.is_dir():
                continue
            meta = read_meta(d)
            if meta:
                total += 1
                s = meta.get("status", "unknown")
                counts[s] = counts.get(s, 0) + 1
        result["total_topics"] = total
        result["by_status"] = counts

    out(result)


# ============================================================
# Main dispatch
# ============================================================

def main() -> None:
    args = sys.argv[1:]

    if len(args) < 1:
        err("Usage: topic-manager.py <command> <project_root> [args...]")
        sys.exit(1)

    command = args[0]

    if command in ("--help", "-h"):
        print(__doc__)
        sys.exit(0)

    if len(args) < 2:
        err(f"Missing project_root for command: {command}")
        sys.exit(1)

    project_root = args[1]

    if command == "topic-create":
        if len(args) < 3:
            err("Usage: topic-manager.py topic-create <root> <title> [type]")
            sys.exit(1)
        title = args[2]
        topic_type = args[3] if len(args) > 3 else "open-discussion"
        cmd_topic_create(project_root, title, topic_type)

    elif command == "topic-read":
        cmd_topic_read(project_root)

    elif command == "topic-update":
        if len(args) < 4:
            err("Usage: topic-manager.py topic-update <root> <field> <value>")
            sys.exit(1)
        cmd_topic_update(project_root, args[2], args[3])

    elif command == "topic-complete":
        cmd_topic_complete(project_root)

    elif command == "topic-list":
        cmd_topic_list(project_root)

    elif command == "auto-cleanup":
        try:
            minutes = int(args[2]) if len(args) > 2 else 120
        except ValueError:
            err(f"Invalid minutes value: {args[2]}")
            sys.exit(1)
        cmd_auto_cleanup(project_root, minutes)

    elif command == "status":
        cmd_status(project_root)

    else:
        err(f"Unknown command: {command}")
        sys.exit(1)


if __name__ == "__main__":
    main()
