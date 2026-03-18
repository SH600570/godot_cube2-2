#!/usr/bin/env gdscript

# 简单测试脚本
print("Testing Cube2x2 and CubePiece classes...")

# 测试 CubePiece
var piece = preload("res://scripts/CubePiece.gd").new()
print("CubePiece created successfully")
print("Logic pos: " + str(piece.logic_pos))

# 测试 Cube2x2
var cube = preload("res://scripts/Cube2x2.gd").new()
print("Cube2x2 created successfully")
print("Pieces array: " + str(cube.pieces))

print("All tests passed!")
