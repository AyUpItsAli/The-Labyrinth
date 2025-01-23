extends Node

func log_start(message: String) -> void:
	log_message(message, "yellow")

func log_info(message: String) -> void:
	log_message(message, "cyan")

func log_success(message: String) -> void:
	log_message(message, "green")

func log_closure(message: String) -> void:
	log_message(message, "red")

func log_message(message: String, color: String) -> void:
	print_rich("[color=%s]%s[/color]" % [color, message.replace("[", "[lb]")])

func log_error(message: String) -> void:
	printerr(message)
