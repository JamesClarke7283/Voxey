extends RefCounted

# Death messages (`mcl_death_messages`) and the damage-reason flags
# (`mcl_damage.types`). Both tables are transcriptions, so the checks are: every
# source entry produces something, the variants that declare extra text differ
# from the base, the flag lookups answer with the source's own values, and the
# audit separates the causes Voxey already matches from the ones it does not.
#
# The module is pure and mutates nothing, so this group needs no fixture hygiene
# and no player or world state; every check runs against the tables directly.

static func _mismatch(report: Dictionary, cause: String) -> Dictionary:
	for entry in report.mismatched:
		if str(entry.cause) == cause: return entry
	return {}

static func run(suite: Object, game: Node3D) -> void:
	var messages: Dictionary = DeathMessages.MESSAGES
	var declared: Dictionary = DeathMessages.DECLARED
	var victim: String = DeathMessages.VICTIM

	# --- the two tables are the source's -------------------------------------
	# `mcl_damage.types` declares 33 reasons (CORE/mcl_damage/init.lua:6-38) and
	# `mcl_death_messages.messages` 31 entries (HUD/mcl_death_messages/init.lua:7-141).
	suite.check(declared.size() == 33,"the flag table carries the source's 33 damage reasons")
	suite.check(messages.size() == 31,"the message table carries the source's 31 reason entries")
	suite.check(DeathMessages.causes().size() == declared.size(),"causes() reports every reason the flag table covers")
	var uncovered: Array = []
	for reason in declared:
		if not messages.has(reason): uncovered.append(str(reason))
	uncovered.sort()
	suite.check(uncovered == ["environment","light"],"only environment and light have no message entry, which is why the source keeps a fallback")
	var undeclared: Array = []
	for reason in messages:
		if not declared.has(reason): undeclared.append(str(reason))
	suite.check(undeclared.is_empty(),"every reason with a message is a declared damage reason")

	# --- every reason produces a message -------------------------------------
	for reason in messages:
		var text: String = DeathMessages.message(reason)
		suite.check(not text.is_empty(),"the source declares a message for "+str(reason))
		suite.check(not text.contains("@"),"the message for "+str(reason)+" substitutes every placeholder it uses")
		suite.check(DeathMessages.known(reason),"the message table's reason is a declared flag-table reason: "+str(reason))
		if messages[reason].has("plain"):
			suite.check(text.begins_with(victim),"the plain message for "+str(reason)+" opens with the victim")
		else:
			# A killer-only entry with nothing named. The source's fallback is its
			# translation key (init.lua:180-182), which this project cannot render —
			# so the screen names the cause in prose instead, and the assertion is
			# that it is prose: no key, no placeholder, and the victim named. The
			# source's key is still produced for a reason the table does not cover.
			suite.check(text.begins_with(victim) and not text.begins_with(DeathMessages.FALLBACK_PREFIX) and not text.contains("@"),"a killer-only entry names the cause in prose without a killer: "+str(reason))
	suite.check(DeathMessages.message("no_such_reason_at_all").begins_with(DeathMessages.FALLBACK_PREFIX),"an unknown reason still produces the source's own fallback key")
	for reason in declared:
		var text: String = DeathMessages.message(reason)
		suite.check(not text.is_empty(),"every declared reason produces a message, fallback included: "+str(reason))
		suite.check(not text.contains("@"),"the message for "+str(reason)+" leaves no placeholder behind")
	# The source's fallback is its own translation key and the name
	# (init.lua:180-182), reproduced verbatim rather than replaced with made-up text.
	suite.check(DeathMessages.message("environment") == "mcl_death_messages.messages.environment "+victim,"an entry-less reason falls back to the source's translation key")
	suite.check(DeathMessages.message("unheard_of") == "mcl_death_messages.messages.unheard_of "+victim,"an unknown reason uses the same fallback")

	# --- the exact wording the source declares -------------------------------
	# A sample across plain, killer/item and the two entries that say `escape`.
	suite.check(DeathMessages.message("in_wall") == victim+" suffocated in a wall","in_wall keeps the source's plain wording")
	suite.check(DeathMessages.message("out_of_world") == victim+" fell out of the world","out_of_world keeps the source's plain wording")
	suite.check(DeathMessages.message("starve") == victim+" starved to death","starve keeps the source's plain wording")
	suite.check(DeathMessages.message("fall") == victim+" hit the ground too hard","fall keeps the source's plain wording")
	suite.check(DeathMessages.message("drown") == victim+" drowned","drown keeps the source's plain wording")
	suite.check(DeathMessages.message("sweet_berry") == victim+" was poked to death by a sweet berry bush","sweet_berry keeps the source's plain wording")
	suite.check(DeathMessages.message("mob","Zombie") == victim+" was slain by Zombie","the mob killer variant names the killer")
	suite.check(DeathMessages.message("mob","Zombie","Diamond Sword") == victim+" was slain by Zombie using [Diamond Sword]","the item variant brackets the item as the source does")
	suite.check(DeathMessages.message("mob","") == DeathMessages.message("mob"),"an empty killer leaves the message alone")
	suite.check(DeathMessages.message("mob","","Diamond Sword") == DeathMessages.message("mob"),"an item without a killer cannot fire, as the source's dispatch requires a source first")
	# `magic` declares all four texts, and its killer variant is not its plain one.
	suite.check(DeathMessages.message("magic") == victim+" was killed by magic","magic keeps the source's plain wording")
	suite.check(DeathMessages.message("magic","Witch") == victim+" was killed by Witch using magic","magic keeps the source's killer wording")
	suite.check(DeathMessages.message("magic","Witch","Splash Potion") == victim+" was killed by Witch using [Splash Potion]","magic keeps the source's item wording")
	suite.check(DeathMessages.message("wither_skull","Skeleton") == victim+" was shot by a skull from Skeleton","wither_skull has both a plain and a killer wording")
	suite.check(DeathMessages.message("trident","Drowned","Trident") == victim+" was impaled by Drowned with [Trident]","trident's item variant reads 'with' rather than 'using'")
	# `fireworks` is the source's only item-only entry, so it has no killer text.
	suite.check(DeathMessages.message("fireworks","") == victim+" went off with a bang","an item-only entry falls back to its plain text")
	# The source declares `escape` for wither and anvil (init.lua:76, :84) and its
	# dispatch reads `assist` alone (init.lua:168-172), so both are unreachable.
	suite.check(messages["wither"].has("escape") and not messages["wither"].has("assist"),"wither's variant is declared as escape, which the source never reads")
	suite.check(messages["anvil"].has("escape") and not messages["anvil"].has("assist"),"anvil's variant is declared as escape too")
	suite.check(messages["in_wall"].has("assist"),"the assist text is transcribed for the reasons that declare it")

	# --- the variants differ from the base ------------------------------------
	# Every entry that declares a killer or item text must actually read
	# differently from the text a reasonless death produces.
	var killer_variants: int = 0
	var item_variants: int = 0
	for reason in messages:
		var entry: Dictionary = messages[reason]
		var base: String = DeathMessages.message(reason)
		var named: String = DeathMessages.message(reason,"Witch")
		if entry.has("killer"):
			killer_variants += 1
			suite.check(named != base and named.contains("Witch"),"the killer variant of "+str(reason)+" differs from its base text")
		if entry.has("item"):
			item_variants += 1
			var armed: String = DeathMessages.message(reason,"Witch","Diamond Sword")
			suite.check(armed != base and armed.contains("[Diamond Sword]"),"the item variant of "+str(reason)+" differs from its base text")
			suite.check(armed != named,"the item variant of "+str(reason)+" differs from its killer variant")
	# Counted from the table itself, not asserted as a literal.
	suite.check(killer_variants == 11,"eleven reasons declare a killer variant")
	suite.check(item_variants == 10,"ten reasons declare an item variant")

	# --- the flag table -------------------------------------------------------
	var none: Dictionary = {"bypasses_armor":false,"is_fire":false,"is_projectile":false,"is_explosion":false,"bypasses_totem":false,"bypasses_magic":false}
	suite.check(DeathMessages.flags("cactus") == none,"a reason the source declares bare carries six false flags")
	suite.check(DeathMessages.flags("unheard_of") == none,"an unknown reason carries six false flags rather than nothing")
	var incomplete: Array = []
	for reason in declared:
		var flags: Dictionary = DeathMessages.flags(reason)
		for name in DeathMessages.FLAG_NAMES:
			if not flags.has(name): incomplete.append(str(reason))
	suite.check(incomplete.is_empty(),"every flag dictionary carries all six flags")
	suite.check(DeathMessages.flags("in_wall") == {"bypasses_armor":true,"is_fire":false,"is_projectile":false,"is_explosion":false,"bypasses_totem":false,"bypasses_magic":false},"in_wall bypasses armor and nothing else")
	suite.check(DeathMessages.flags("fall") == {"bypasses_armor":true,"is_fire":false,"is_projectile":false,"is_explosion":false,"bypasses_totem":false,"bypasses_magic":false},"fall bypasses armor and nothing else")
	suite.check(DeathMessages.flags("out_of_world").bypasses_totem,"out_of_world carries the source's bypasses_totem")
	suite.check(DeathMessages.flags("out_of_world") == {"bypasses_armor":true,"is_fire":false,"is_projectile":false,"is_explosion":false,"bypasses_totem":true,"bypasses_magic":true},"out_of_world is the reason that bypasses armor, magic and a totem")
	suite.check(DeathMessages.flags("starve").bypasses_magic and DeathMessages.flags("starve").bypasses_armor,"starve carries the source's bypasses_magic and bypasses_armor")
	suite.check(DeathMessages.flags("arrow").is_projectile,"arrow is the source's projectile reason")
	suite.check(not DeathMessages.flags("mob").bypasses_armor and not DeathMessages.flags("anvil").bypasses_armor,"mob and anvil declare nothing, so their hits go through armor")
	suite.check(DeathMessages.flags("on_fire").is_fire and DeathMessages.flags("fireball").is_fire and not DeathMessages.flags("in_fire").bypasses_armor,"on_fire is fire that bypasses armor while in_fire is fire that does not")
	suite.check(DeathMessages.flags("explosion").is_explosion and DeathMessages.flags("wither_skull").is_explosion,"explosion and wither_skull are the source's explosion reasons")
	suite.check(DeathMessages.flags("magic").bypasses_armor and not DeathMessages.flags("magic").bypasses_magic,"magic bypasses armor but not the potion rules the source guards with bypasses_magic")
	suite.check(DeathMessages.flags("void").bypasses_totem and DeathMessages.flags("void").bypasses_magic,"Voxey's void resolves to the source's out_of_world flags")
	suite.check(DeathMessages.flags("projectile").is_projectile,"Voxey's projectile resolves to the source's arrow flags")
	# The flag table reaches the source's names, and the aliases Voxey needs.
	suite.check(DeathMessages.known("out_of_world") and DeathMessages.known("void"),"the void is the source's out_of_world")
	suite.check(DeathMessages.known("arrow") and DeathMessages.known("projectile"),"Voxey's projectile cause resolves to the source's arrow")
	suite.check(DeathMessages.known("environment") and DeathMessages.known("light") and DeathMessages.known("trident"),"the source's entryless reasons are still known reasons")
	suite.check(not DeathMessages.known("void_magic") and not DeathMessages.known("no_such_reason") and not DeathMessages.known(""),"a cause the source's table has no entry for is not known")
	# `fire` **does** resolve now: Voxey passes one cause where the source splits
	# three, and it aliases the plainest of them so the screen and the flags agree.
	suite.check(DeathMessages.known("fire"),"Voxey's merged fire cause resolves to the source's in_fire")

	# --- the audit against Voxey's causes -------------------------------------
	var report: Dictionary = DeathMessages.audit(DeathMessages.VOXEY_CAUSES)
	for required in ["void","starve","fall","in_wall","freeze","hot_floor","sweet_berry","explosion","thorns","magic","mob","projectile","anvil","falling_node","generic"]:
		suite.check(report.known.has(required),required+" is recognised as one of the source's damage reasons")
	suite.check(report.known.has("fire"),"Voxey's fire cause resolves to the source's in_fire, so it is recognised")
	suite.check(report.unknown.is_empty(),"every cause Voxey passes resolves to a source reason")
	suite.check(report.known.size() + report.unknown.size() == DeathMessages.VOXEY_CAUSES.size(),"every cause the audit is handed is placed in known or unknown")
	for entry in report.mismatched:
		suite.check(report.known.has(str(entry.cause)),"a mismatched cause is also a recognised one: "+str(entry.cause))
		print("death_message mismatch: ",entry.cause," Voxey=",entry.voxey," source=",entry.source)
	print("death_message audit: causes with no source entry: ",report.unknown)

	# The mismatches are the real finding: Voxey decides mitigation per call, and
	# `bypass_armor` skips the totem (player.gd:952), so every armor-bypassing
	# cause bypasses a totem while the source sets that flag for out_of_world alone.
	suite.check(_mismatch(report,"void").is_empty(),"void matches the source exactly, flags and all")
	suite.check(_mismatch(report,"sweet_berry").is_empty(),"sweet_berry matches the source")
	suite.check(_mismatch(report,"mob").is_empty() and _mismatch(report,"anvil").is_empty() and _mismatch(report,"falling_node").is_empty(),"the ordinary hits match the source")
	suite.check(_mismatch(report,"projectile").is_empty() and _mismatch(report,"explosion").is_empty(),"Voxey's projectile and explosion causes match the source's classification")
	var plain: Dictionary = _mismatch(report,"generic")
	suite.check(not plain.is_empty() and plain.source.bypasses_armor and not plain.voxey.bypasses_armor,"the source's generic bypasses armor while Voxey's default cause does not")
	var starve: Dictionary = _mismatch(report,"starve")
	suite.check(not starve.is_empty() and starve.voxey.bypasses_totem and not starve.source.bypasses_totem,"starve bypasses a totem in Voxey but not in the source")
	var dropped: Dictionary = _mismatch(report,"fall")
	suite.check(not dropped.is_empty() and dropped.voxey.bypasses_totem,"a fall bypasses a totem in Voxey, which the source does not set")
	var wall: Dictionary = _mismatch(report,"in_wall")
	suite.check(not wall.is_empty() and wall.voxey.bypasses_armor and wall.source.bypasses_armor,"in_wall bypasses armor in both, so only the totem differs")
	var floor: Dictionary = _mismatch(report,"hot_floor")
	suite.check(not floor.is_empty() and floor.source.is_fire and not floor.voxey.is_fire,"hot_floor is fire in the source but not classified as fire in Voxey")
	var magic: Dictionary = _mismatch(report,"magic")
	suite.check(not magic.is_empty() and magic.source.bypasses_armor and not magic.voxey.bypasses_armor,"the source's magic bypasses armor while Voxey's magic goes through it")
	suite.check(not _mismatch(report,"thorns").is_empty(),"Voxey's thorns hit bypasses armor and a totem, which the source's thorns entry does not")
	# A cause with no source entry is reported as unknown and never as a mismatch.
	var outside: Dictionary = DeathMessages.audit(["no_such_reason_at_all"])
	suite.check(outside.known.is_empty() and outside.mismatched.is_empty() and outside.unknown == ["no_such_reason_at_all"],"a cause outside the source's table is unknown, not mismatched")
	var empty: Dictionary = DeathMessages.audit([])
	suite.check(empty.known.is_empty() and empty.unknown.is_empty() and empty.mismatched.is_empty(),"an empty cause list audits clean")
	# --- every cause Voxey actually passes renders readable text ---------------
	# The source's last resort is a **translation key**, which a project with no
	# translator would show as `mcl_death_messages.messages.arrow The player` on the
	# death screen. Every cause the call sites pass must resolve to prose.
	var causes: Array = ["anvil","arrow","cactus","charged_explosion","cramming","drown",
		"explosion","fall","falling_node","fire","fireball","freeze","generic","hot_floor",
		"in_wall","lava","lightning","magic","mob","player","projectile","spit","starve",
		"sweet_berry","thorns","trident","void","wither"]
	var readable: bool = true
	for cause in causes:
		var text: String = DeathMessages.message(cause)
		if text.is_empty() or text.begins_with("mcl_death_messages."): readable = false
	suite.check(readable,"every cause Voxey passes renders prose rather than a translation key")
	# The aliased causes resolve to the source's own reason, which is what keeps the
	# flags and the message in agreement.
	suite.check(DeathMessages.message("void") == DeathMessages.message("out_of_world"),"void aliases the source's out_of_world")
	suite.check(DeathMessages.message("projectile") == DeathMessages.message("arrow"),"projectile aliases the source's arrow")
	suite.check(DeathMessages.message("charged_explosion") == DeathMessages.message("explosion"),"a charged explosion is the source's explosion reason")
	suite.check(DeathMessages.known("fire") and DeathMessages.known("lightning"),"the two causes whose Voxey name differs from the source's are still known")
	# The killer and item forms still win when they are available.
	suite.check(DeathMessages.message("arrow","Skeleton") == "The player was shot by Skeleton","a named killer produces the source's killer form")
	suite.check("bow" in DeathMessages.message("arrow","Skeleton","bow"),"a named item produces the source's item form")
