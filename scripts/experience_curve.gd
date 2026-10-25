class_name ExperienceCurve
extends RefCounted

# mcl_experience/init.lua: level_to_xp, xp_to_bar and set_level.
static func total(level: int) -> int:
	if level <= 0: return 0
	if level <= 16: return level*level+6*level
	if level <= 31: return floori(2.5*level*level-40.5*level+360)
	return floori(4.5*level*level-162.5*level+2220)

static func level(xp: float) -> int:
	var low: int = 0; var high: int = 1
	while total(high) <= xp and high < 100000000: high *= 2
	while low+1 < high:
		var middle: int = (low+high)/2
		if total(middle) <= xp: low = middle
		else: high = middle
	return low

static func progress(xp: float) -> float:
	var current: int = level(xp)
	return clampf((xp-total(current))/float(total(current+1)-total(current)),0,1)

static func spend(xp: float, levels: int) -> float:
	var next: int = maxi(0,level(xp)-levels)
	return floorf(total(next)+progress(xp)*(total(next+1)-total(next)))
