extends Node

signal health_changed(current: int, maximum: int)
signal gold_changed(new_gold: int)
signal inventory_changed(slots: Array)
signal objective_added(index: int)
signal objective_completed(index: int)

var gold: int = -500
var inventory: Array[Dictionary] = []
var objectives: Array[Dictionary] = []

const MAX_SLOTS: int = 16
const HOTBAR_SIZE: int = 4

func _ready() -> void:
	add_objective("Derrotar as galinhas")
	add_objective("Explorar a área")

func set_health(current: int, maximum: int) -> void:
	health_changed.emit(current, maximum)

func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)

func clear_debt() -> void:
	# Wipe any outstanding debt (negative gold) back to zero.
	if gold < 0:
		gold = 0
		gold_changed.emit(gold)

func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true

func add_item(item_name: String, icon_path: String) -> bool:
	if inventory.size() >= MAX_SLOTS:
		return false
	inventory.append({"name": item_name, "icon_path": icon_path})
	inventory_changed.emit(inventory)
	return true

func remove_item(index: int) -> void:
	if index >= 0 and index < inventory.size():
		inventory.remove_at(index)
		inventory_changed.emit(inventory)

func add_objective(text: String) -> void:
	objectives.append({"text": text, "completed": false})
	objective_added.emit(objectives.size() - 1)

func complete_objective(index: int) -> void:
	if index >= 0 and index < objectives.size():
		objectives[index]["completed"] = true
		objective_completed.emit(index)
