extends Node

func disable_line_edit(line_edit: LineEdit) -> void:
	line_edit.set_editable(false)
	line_edit.set_focus_mode(Control.FOCUS_CLICK)
	line_edit.set_mouse_filter(Control.MOUSE_FILTER_IGNORE)
	line_edit.set_selecting_enabled(false)

func enable_line_edit(line_edit: LineEdit) -> void:
	line_edit.set_editable(true)
	line_edit.set_focus_mode(Control.FOCUS_ALL)
	line_edit.set_mouse_filter(Control.MOUSE_FILTER_STOP)
	line_edit.set_selecting_enabled(true)
