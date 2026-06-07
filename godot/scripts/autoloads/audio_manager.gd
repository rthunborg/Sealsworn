extends Node

var master_bus_name: StringName = &"Master"

func set_master_volume_db(volume_db: float) -> void:
	var bus_index: int = AudioServer.get_bus_index(String(master_bus_name))
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, volume_db)


func mute_master(is_muted: bool) -> void:
	var bus_index: int = AudioServer.get_bus_index(String(master_bus_name))
	if bus_index >= 0:
		AudioServer.set_bus_mute(bus_index, is_muted)

