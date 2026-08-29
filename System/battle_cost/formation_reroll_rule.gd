class_name FormationRerollRule
extends RefCounted

## 兵營「變換隊形」花費(金錢)——重抽形狀=整個連通形狀重骰(可能完全不同),影響較大所以
## 比重抽佔位貴;重抽佔位=形狀輪廓不變,只是換一格當佔位格(旋轉軸心)。見
## BattleCostController.reroll_shape()/reroll_anchor()。
const SHAPE_REROLL_COST := 100
const ANCHOR_REROLL_COST := 50


## 已編入小隊(PartyStore.grid.is_placed())的角色不能變換隊形——PartyEditGrid.place() 存進
## 網格的形狀是放置當下的快照(見 party_edit_availability_layer.gd 的 _drop_data()),不是
## 即時參照 Character.battle_cost,這裡如果還讓玩家改動 battle_cost(重抽形狀/重抽佔位/
## 旋轉都算),網格記錄的佔用格子會跟角色實際形狀對不上,變成兩邊資料兜不起來的 BUG。要
## 變換隊形得先在小隊編成畫面把這個人移出小隊。傳授/隊長訓練沒有這個限制,只有這裡的
## 佔位形狀變動會直接影響戰場佔用格,所以另立一支規則,不跟其他兵營項目共用同一套判斷。
static func can_reroll(character: Character) -> bool:
	return PartyStore.grid == null or not PartyStore.grid.is_placed(character)
