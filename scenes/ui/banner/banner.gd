extends HBoxContainer

@export var version_lbl: Label

func _ready() -> void:
	version_lbl.text = "Build %s" % Global.app_version

func _on_quit_btn_pressed() -> void:
	Global.quit_game()
