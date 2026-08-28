class_name WarTruceRule
extends RefCounted

## 停戰判定相關規則,見 war_world_time_events.gd 的 _run_truce_checks() 逐場 War 呼叫。

## 停戰機率隨平均疲憊內插的上限,避免疲憊再高也「必然」停戰(spec 明確要求機率式)。
const MAX_TRUCE_CHANCE := 0.7

## 停戰後 WarTension 保留比例——spec 範例 92(戰前)→65(停戰後)≈0.706,取整為 0.7。
const TRUCE_TENSION_RETENTION_RATIO := 0.7


## average(exhaustion_a, exhaustion_b):20 → 極低、90 → 封頂的極高機率。
static func truce_probability(avg_exhaustion: float) -> float:
	var t := clampf(inverse_lerp(20.0, 90.0, avg_exhaustion), 0.0, 1.0)
	return lerp(0.02, MAX_TRUCE_CHANCE, t)


static func post_truce_tension(current_tension: float) -> float:
	return current_tension * TRUCE_TENSION_RETENTION_RATIO
