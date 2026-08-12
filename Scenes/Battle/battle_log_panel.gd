class_name BattleLogPanel
extends RichTextLabel

# =========================================================
# 戰鬥紀錄面板:只負責把文字訊息附加到面板上並自動捲到最新一行。
# =========================================================

func log_msg(msg: String) -> void:
	append_text(msg + "\n")
	scroll_to_line(get_line_count() - 1)


func clear_log() -> void:
	clear()
