# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright (C) 2010-2014 celeron55, Perttu Ahola <celeron55@gmail.com>
# Adapted from Luanti RemoteClient::{GotBlock,SentBlock,SetBlockNotSent}
# in src/server/clientiface.cpp. See docs/networking-luanti.md for attribution.
class_name NetworkBlockSync
extends RefCounted

# An acknowledgement only completes the exact revision still being sent.
# Invalidation removes it from both sets, just as in Luanti. Serial numbers
# also distinguish an old acknowledgement from a later retry of that revision.
var sending: Dictionary = {}
var sent: Dictionary = {}
var serial: int = 0

func invalidate(column: Vector2i) -> void:
	sending.erase(column)
	sent.erase(column)

func begin(column: Vector2i, revision: int, now: int) -> int:
	serial += 1
	sending[column] = {"serial":serial,"revision":revision,"time":now}
	return serial

func acknowledge(column: Vector2i, token: int, revision: int) -> bool:
	var flight: Dictionary = sending.get(column,{})
	if flight.is_empty() or flight.serial != token or flight.revision != revision: return false
	sending.erase(column)
	sent[column] = revision
	return true

func expire(now: int, timeout: int = 3000) -> void:
	for column in sending.keys():
		if now-int(sending[column].time) >= timeout: sending.erase(column)

func needed(column: Vector2i, revision: int) -> bool:
	return not sending.has(column) and int(sent.get(column,-1)) != revision
