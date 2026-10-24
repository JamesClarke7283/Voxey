# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright (C) 2010-2013 celeron55, Perttu Ahola <celeron55@gmail.com>
# GDScript adaptation of Luanti's SmoothTranslator in src/client/content_cao.cpp.
# See docs/networking-luanti.md and LICENSES/LGPL-2.1-or-later.txt.
class_name NetworkMotion
extends RefCounted

const TELEPORT_DISTANCE = 12.0
var previous := Vector3.ZERO
var current := Vector3.ZERO
var target := Vector3.ZERO
var previous_yaw: float = 0.0
var current_yaw: float = 0.0
var target_yaw: float = 0.0
var interval: float = 0.0
var elapsed: float = 0.0
var end_position: bool = true
var initialized: bool = false

func reset(at: Vector3, yaw: float = 0.0) -> void:
	previous = at; current = at; target = at
	previous_yaw = yaw; current_yaw = yaw; target_yaw = yaw
	interval = 0.0; elapsed = 0.0; end_position = true; initialized = true

func update(at: Vector3, yaw: float = 0.0, update_interval: float = -1.0) -> void:
	if not at.is_finite() or not is_finite(yaw): return
	if not initialized or current.distance_to(at) > TELEPORT_DISTANCE:
		reset(at,yaw)
		return
	end_position = at.is_equal_approx(target)
	previous = current; target = at
	previous_yaw = current_yaw; target_yaw = yaw
	if update_interval > 0.0:
		interval = update_interval
	elif interval < 0.001 or interval > 1.0:
		interval = elapsed
	else:
		interval = interval*0.9+elapsed*0.1
	elapsed = 0.0

func advance(delta: float) -> void:
	if not initialized: return
	elapsed += delta
	var ratio: float = elapsed/interval if interval > 0.001 else 1.0
	# Luanti deliberately trails a little and bounds extrapolation to half a step.
	ratio = minf(ratio*0.8,1.0 if end_position else 1.5)
	current = previous+(target-previous)*ratio
	current_yaw = previous_yaw+wrapf(target_yaw-previous_yaw,-PI,PI)*ratio
