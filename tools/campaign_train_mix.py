#!/usr/bin/env python3
"""Rebalances the campaign so multi-train levels are a treat every fifth level.

Multi-train levels whose id is not a multiple of five become single-train levels: the
train is rebuilt the way single-train levels are authored (each collector of the
authored solution, in order, contributes its capacity of its colour), the route is a
long single-lane route borrowed from an existing single-train level, and the pacing
values are those of single-train levels of the same era. Level 30 (single) swaps
bodies with level 31 (two trains) so every fifth level from 10 on has several trains.

Run from the repo root:  python3 tools/campaign_train_mix.py
Idempotent: levels already in the target mix are left alone.
"""
import json
import shutil
from pathlib import Path

GAME = Path(__file__).resolve().parent.parent / "game"
CAMPAIGN = GAME / "data" / "campaign.json"
ROUTES = GAME / "data" / "routes"
KEEP_BODY = ("id", "map_seed", "theme")
MIN_ROUTE_LENGTH = 37.0
FIRST_SOURCE_LEVEL = 11


def route_path(level_id: int) -> Path:
    return ROUTES / f"route_{level_id:03d}.json"


def lanes(level: dict) -> int:
    return int(level.get("train_count", 1))


def swap_bodies(levels: list, a: int, b: int) -> None:
    """Exchanges the designs of levels a and b, keeping each one's id and look."""
    la, lb = levels[a - 1], levels[b - 1]
    keep_a = {k: la[k] for k in KEEP_BODY}
    keep_b = {k: lb[k] for k in KEEP_BODY}
    levels[a - 1], levels[b - 1] = dict(lb, **keep_a), dict(la, **keep_b)
    tmp = route_path(a).with_suffix(".tmp")
    shutil.move(route_path(a), tmp)
    shutil.move(route_path(b), route_path(a))
    shutil.move(tmp, route_path(b))


def solution_train(level: dict) -> list:
    """Wagon colours in the order the authored solution's collectors take them."""
    train = []
    for collector_id in level["design"]["solution"]:
        collector = level["parking"][collector_id]
        train += [collector["color"]] * int(collector.get("capacity", level["collector_capacity"]))
    return train


def main() -> None:
    data = json.loads(CAMPAIGN.read_text(encoding="utf-8"))
    levels = data["levels"]
    if lanes(levels[29]) == 1 and lanes(levels[30]) > 1:
        swap_bodies(levels, 30, 31)
    sources = [lv["id"] for lv in levels
               if lanes(lv) == 1 and lv["track_length"] >= MIN_ROUTE_LENGTH and lv["id"] >= FIRST_SOURCE_LEVEL]
    source_routes = {sid: route_path(sid).read_text(encoding="utf-8") for sid in sources}
    converted = 0
    for level in levels:
        if lanes(level) == 1 or level["id"] % 5 == 0:
            continue
        source_id = sources[converted % len(sources)]
        route = json.loads(source_routes[source_id])
        route["routes"] = route["routes"][:1]
        route_path(level["id"]).write_text(json.dumps(route), encoding="utf-8")
        late = level["id"] > 50
        level["train_count"] = 1
        level.pop("wagon_streams", None)
        level["train"] = solution_train(level)
        level["track_length"] = route["routes"][0]["length"]
        level["approach_speed"] = 1.036 if late else 1.0
        level["recoil_per_unit"] = 1.334
        level["loading_fraction"] = 0.687 if late else 0.675
        level["layout"] = levels[source_id - 1]["layout"]
        level["shape"] = levels[source_id - 1]["shape"]
        converted += 1
    CAMPAIGN.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
    multi = [lv["id"] for lv in levels if lanes(lv) > 1]
    print(f"converted {converted} levels; multi-train levels now: {multi}")


if __name__ == "__main__":
    main()
