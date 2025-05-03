# Tweaks from Demo Branch

This document summarizes all modifications made beyond the original demo/main branch:

## 1. WorkPhase Integration

- **scripts/work/workphase.gd**
  - Added `signal proceed(extra_hours: int)` and emit on Confirm instead of direct scene change.
  - Removed redundant `value_changed.connect` (auto-wired by TSCN).

- **scenes/WorkPhase.tscn**
  - Uses `workphase.gd` script; Confirm button wired to emit `proceed`.

## 2. Run Scene Adjustments

- **scenes/run/run.gd**
  - Preloaded `WORK_PHASE_SCENE := preload("res://scenes/WorkPhase.tscn")`.
  - In `_start_run()`, replaced immediate map generation with `_change_view(WORK_PHASE_SCENE)` and connect to `_on_work_phase_proceed()`.
  - Added `_on_work_phase_proceed(_extra_hours)` to:
    - Create new `SaveGame`, generate map, unlock floor, replace WorkPhase view with map.
  - Prefixed unused parameter to silence lint.

## 3. Map Scene Fixes

- **scenes/map/map.gd**
  - In `create_map()`, clear previous `rooms` and `lines` children to avoid duplicate icons.
  - Added nil-check in `unlock_next_rooms()` (`if last_room == null: return`).
  - Enabled click-and-drag panning:
    - `var dragging: bool` property.
    - In `_unhandled_input()`, handle `InputEventMouseButton.BUTTON_LEFT` to start/stop drag, and `InputEventMouseMotion` to adjust `camera_2d.position`, clamped to `[ -camera_edge_y, 0 ]`.
  - Retained arrow-wheel scroll as fallback.

## 4. MapRoom Icon Cleanup (Considered)

- **scenes/map/map_room.tscn**
  - Initially removed hardcoded default texture to isolate script-driven icons, then reverted when clearing nodes solved duplication.

---

Feed this CHANGES.md to your LLM to plan next steps (e.g., combat scaling, HomePhase, shop purchases, HUD updates).
