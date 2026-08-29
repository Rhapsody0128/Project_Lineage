class_name SkillLearnFlow
extends RefCounted

## 學技能的唯一入口——技能格未滿(Character.MAX_SKILLS)直接學會;已滿彈 SkillReplaceDialog
## 讓玩家選替換或放棄,不由呼叫端自己判斷/處理 skill_list 異動。傳授(BarracksTeachPanel)/
## 隊長訓練(BarracksLeaderTrainingPanel)/歷練收成(BarracksExpeditionPanel)三個呼叫點共用。
##
## 同一支技能不能重複學一律在這裡統一擋下(Character.knows_skill()),跳
## ConfirmDialog.notify() 提示——各呼叫端各自的 can_teach()/can_learn() 已經會先把
## 已學會的技能排除在候選之外/整格反灰,這裡是最後一道防線,避免任何漏網情況(例如歷練
## 骰技能池)真的送進來時悄悄疊出重複技能。
##
## on_done(applied: bool) 學會/替換成功傳 true,放棄或擋下重複學習傳 false——呼叫端只有在
## true 時才該執行有副作用的後續動作(師父 has_taught_skill 旗標、隊長訓練扣金幣),放棄
## 學習不該有任何副作用。
static func try_learn(character: Character, skill: Skill, on_done: Callable = Callable()) -> void:
	if character.knows_skill(skill):
		ConfirmDialog.notify("%s 已經學會「%s」，不能重複學習。" % [character.full_name, skill.name])
		if on_done.is_valid():
			on_done.call(false)
		return
	if character.skill_list.size() < Character.MAX_SKILLS:
		character.learn_skill(skill)
		if on_done.is_valid():
			on_done.call(true)
		return
	SkillReplaceDialog.ask(character, skill, on_done)
