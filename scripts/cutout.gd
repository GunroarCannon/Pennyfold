## Lives inside a SubViewport and paints one cut-out picture (see Paint).
class_name Cutout
extends Node2D

var kind := ""
var params: Dictionary = {}
var canvas_size := Vector2(256, 256)


func _draw() -> void:
	Paint.paint(self, kind, params, canvas_size)
