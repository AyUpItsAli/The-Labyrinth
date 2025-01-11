extends Node

func log_start(message: String) -> void:
	print_rich("[color=yellow]%s[/color]" % message)

func log_info(message: String) -> void:
	print_rich("[color=cyan]%s[/color]" % message)

func log_complete(message: String) -> void:
	print_rich("[color=green]%s[/color]" % message)

func log_end(message: String) -> void:
	print_rich("[color=red]%s[/color]" % message)

func log_error(message: String) -> void:
	printerr(message)
