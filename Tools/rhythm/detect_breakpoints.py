#!/usr/bin/env python3
"""斷點(樂句/段落分界)離線分析工具。

這是設計者手動執行一次的離線輔助工具,不是遊戲執行期程式碼(定位比照
Scenes/RhythmGame/rhythm_record_view.gd 之於正式流程——產生初稿用),分析
Sound/Base/BGM/ 底下的建築 BGM,把每首歌在節奏小遊戲測試視窗
([0, RhythmChart.CHART_DURATION_SEC] 秒,見下方 CHART_DURATION_SEC 常數,必須跟
System/rhythm/rhythm_chart.gd 的同名常數保持一致)內偵測到的段落邊界時間點,直接寫回
System/rhythm/charts/<BUILDING>.json 的頂層 "break_points" key(跟 "regular"/"variation"
同層,不分變體——見 System/rhythm/rhythm_chart_store.gd 的
load_break_points()/save_break_points())。

預設不會覆蓋已經有斷點資料的建築(視為設計者已經用遊戲內「斷點設定」模式
[Scenes/RhythmGame/rhythm_breakpoint_editor_view.gd] 手動定案過),要強制重跑要加
--force。分析結果只是初稿,設計者仍可以再用「斷點設定」模式微調。

環境需求(這台機器目前沒有裝,需要使用者自行處理):
    pip install librosa numpy soundfile
librosa 讀 mp3 常透過 audioread 後端,系統需要另外安裝 ffmpeg 並加進 PATH,否則載入
mp3 會失敗。

用法:
    python Tools/rhythm/detect_breakpoints.py                # 掃全部建築,略過已有斷點的
    python Tools/rhythm/detect_breakpoints.py --building FARM
    python Tools/rhythm/detect_breakpoints.py --force         # 全部重新分析、覆蓋既有斷點
    python Tools/rhythm/detect_breakpoints.py --segment-seconds 8 --dry-run
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np

try:
    import librosa
except ImportError:
    print(
        "缺少 librosa,請先安裝環境:pip install librosa numpy soundfile\n"
        "(mp3 解碼可能還需要系統另外安裝 ffmpeg 並加進 PATH)",
        file=sys.stderr,
    )
    raise

PROJECT_ROOT = Path(__file__).resolve().parents[2]
BGM_DIR = PROJECT_ROOT / "Sound" / "Base" / "BGM"
CHART_DIR = PROJECT_ROOT / "System" / "rhythm" / "charts"

## 必須跟 System/rhythm/rhythm_chart.gd 的 RhythmChart.CHART_DURATION_SEC 保持一致——
## 斷點只在這個測試視窗內有意義,GDScript 端目前沒有機制可以讓這支獨立的 Python 腳本直接
## 讀到同一個常數,改動時兩邊要一起改。
CHART_DURATION_SEC = 60.0

## 相鄰兩個偵測到的段落邊界間隔小於這個秒數視為雜訊,合併成一個(只保留較早的一個)。
MIN_BOUNDARY_GAP_SEC = 2.0

HOP_LENGTH = 512


def detect_break_points(audio_path: Path, segment_seconds: float) -> list[float]:
    """對單一 BGM 檔案跑結構分段,回傳排序後、已濾掉太接近彼此的段落邊界時間點列表
    (不含 0 秒與音檔結尾,只有中間的分界點)。

    做法:抓拍點 → 拍點同步和聲(chroma)特徵 → 用自相似矩陣做階層式分群
    (librosa.segment.agglomerative)切出 k 段,k 依 segment_seconds 概略換算 → 分群邊界
    (拍點索引)換算回秒數。這是初稿等級的分段,調不好可以調 --segment-seconds 或改用
    「斷點設定」模式手動微調,不追求完全準確。
    """
    y, sr = librosa.load(str(audio_path), sr=None, mono=True, duration=CHART_DURATION_SEC)
    duration = librosa.get_duration(y=y, sr=sr)
    if duration <= MIN_BOUNDARY_GAP_SEC:
        return []

    tempo, beat_frames = librosa.beat.beat_track(y=y, sr=sr, hop_length=HOP_LENGTH)
    if len(beat_frames) < 4:
        return []

    chroma = librosa.feature.chroma_cqt(y=y, sr=sr, hop_length=HOP_LENGTH)
    chroma_sync = librosa.util.sync(chroma, beat_frames, aggregate=np.median)

    segment_count = max(2, round(duration / segment_seconds))
    segment_count = min(segment_count, chroma_sync.shape[1])
    if segment_count < 2:
        return []

    boundary_beats = librosa.segment.agglomerative(chroma_sync, segment_count)
    boundary_frames = beat_frames[boundary_beats]
    boundary_times = librosa.frames_to_time(boundary_frames, sr=sr, hop_length=HOP_LENGTH)

    interior = sorted(t for t in boundary_times if 0.0 < t < duration)

    merged: list[float] = []
    for t in interior:
        if merged and t - merged[-1] < MIN_BOUNDARY_GAP_SEC:
            continue
        merged.append(float(t))
    return merged


def _load_chart_json(building_key: str) -> dict:
    path = CHART_DIR / f"{building_key}.json"
    if not path.exists():
        return {}
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def _save_chart_json(building_key: str, data: dict) -> None:
    CHART_DIR.mkdir(parents=True, exist_ok=True)
    path = CHART_DIR / f"{building_key}.json"
    with path.open("w", encoding="utf-8") as f:
        json.dump(data, f, indent="\t", ensure_ascii=False)


def process_building(building_key: str, segment_seconds: float, force: bool, dry_run: bool) -> None:
    audio_path = BGM_DIR / f"{building_key}.mp3"
    if not audio_path.exists():
        print(f"[跳過] {building_key}:找不到 BGM 素材 {audio_path}")
        return

    data = _load_chart_json(building_key)
    existing = data.get("break_points") or []
    if existing and not force:
        print(f"[跳過] {building_key}:已有 {len(existing)} 個斷點(加 --force 可覆蓋)")
        return

    break_points = detect_break_points(audio_path, segment_seconds)
    print(f"[完成] {building_key}:偵測到 {len(break_points)} 個斷點 -> {break_points}")

    if dry_run:
        return

    data["break_points"] = break_points
    _save_chart_json(building_key, data)


def main() -> None:
    parser = argparse.ArgumentParser(description="離線分析 BGM,產生節奏小遊戲的斷點初稿")
    parser.add_argument("--building", action="append", help="只跑指定建築(GameEnums.BuildingType 大寫拼法,例如 FARM),可重複指定;不帶則跑全部")
    parser.add_argument("--force", action="store_true", help="覆蓋已有斷點資料的建築")
    parser.add_argument("--segment-seconds", type=float, default=6.0, help="每段大約幾秒(用來概略換算分段數量),預設 6 秒")
    parser.add_argument("--dry-run", action="store_true", help="只印出偵測結果,不寫檔")
    args = parser.parse_args()

    if args.building:
        building_keys = [name.upper() for name in args.building]
    else:
        building_keys = sorted(p.stem for p in BGM_DIR.glob("*.mp3"))

    if not building_keys:
        print(f"找不到任何 BGM 素材({BGM_DIR})")
        return

    for building_key in building_keys:
        process_building(building_key, args.segment_seconds, args.force, args.dry_run)


if __name__ == "__main__":
    main()
