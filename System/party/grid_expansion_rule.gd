class_name GridExpansionRule
extends RefCounted

## 兵營「戰場擴充」花費(科研點數,依已解鎖格數等差遞增:5、10、15、20……鼓勵玩家循序
## 漸進而不是一次全開)。DEFAULT_UNLOCKED_COUNT 是 PartyEditGrid 預設的 4x4(見該檔案
## _init()),超過這個數量之後每多一格才開始漲價。
const COST_STEP := 5
const DEFAULT_UNLOCKED_COUNT := 16


static func cost_for_next_cell(currently_unlocked_count: int) -> int:
	return COST_STEP * (maxi(0, currently_unlocked_count - DEFAULT_UNLOCKED_COUNT) + 1)
