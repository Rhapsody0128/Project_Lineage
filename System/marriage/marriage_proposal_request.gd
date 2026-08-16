class_name MarriageProposalRequest
extends RefCounted

## SceneHandoffStore 的 payload 型別,搭配 Scenes/Marriage/marriage_proposal.gd 用——取代
## 原本 ProposalStore 各自獨立的 pending_self_character/pending_target_character/
## pending_mode 三個欄位,改成一個小型資料類別,不用為此另開一支 Autoload。

const MAILBOX_KEY := "marriage_proposal"

var self_character: Character
var target_character: Character
var mode: GameEnums.ProposalMode


func _init(p_self_character: Character, p_target_character: Character, p_mode: GameEnums.ProposalMode) -> void:
	self_character = p_self_character
	target_character = p_target_character
	mode = p_mode
