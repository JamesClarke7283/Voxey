class_name PotionCatalog
extends RefCounted

# Recipe data adapted from Mineclonia mcl_potions (GPL-3.0); see docs/licenses.
const DEFINITIONS = {"water":{"color":"8091ff","duration":0,"potent":false,"extended":false,"level":1},"awkward":{"color":"8091ff","duration":0,"potent":false,"extended":false,"level":2,"effect":"awkward"},"mundane":{"color":"8091ff","duration":0,"potent":false,"extended":false,"level":2,"effect":"mundane"},"thick":{"color":"8091ff","duration":0,"potent":false,"extended":false,"level":2,"effect":"thick"},"healing":{"color":"f6493a","duration":0,"potent":true,"extended":false,"level":2,"effect":"healing"},"harming":{"color":"a07669","duration":0,"potent":true,"extended":false,"level":2,"effect":"harming"},"night_vision":{"color":"c8f356","duration":180,"potent":false,"extended":true,"level":2,"effect":"night_vision"},"swiftness":{"color":"5ae9fe","duration":180,"potent":true,"extended":true,"level":2,"effect":"swiftness"},"slowness":{"color":"8bb3de","duration":90,"potent":true,"extended":true,"level":4,"effect":"slowness"},"leaping":{"color":"fafd8e","duration":180,"potent":true,"extended":true,"level":2,"effect":"leaping"},"withering":{"color":"6d5c50","duration":45,"potent":true,"extended":true,"level":2,"effect":"withering"},"poison":{"color":"86a25b","duration":45,"potent":true,"extended":true,"level":2,"effect":"poison"},"regeneration":{"color":"cb54ba","duration":45,"potent":true,"extended":true,"level":2,"effect":"regeneration"},"invisibility":{"color":"f7fdfc","duration":180,"potent":false,"extended":true,"level":2,"effect":"invisibility"},"water_breathing":{"color":"98dac1","duration":180,"potent":false,"extended":true,"level":2,"effect":"water_breathing"},"fire_resistance":{"color":"fd970e","duration":180,"potent":false,"extended":true,"level":2,"effect":"fire_resistance"},"strength":{"color":"f8c800","duration":180,"potent":true,"extended":true,"level":2,"effect":"strength"},"weakness":{"color":"4a4e49","duration":180,"potent":true,"extended":true,"level":2,"effect":"weakness"},"slow_falling":{"color":"eed1ba","duration":180,"potent":false,"extended":true,"level":2,"effect":"slow_falling"},"turtle_master":{"color":"8473dd","duration":20,"potent":true,"extended":true,"level":2,"effect":"turtle_master"},"luck":{"color":"59c500","duration":180,"potent":true,"extended":true,"level":2,"effect":"luck"},"bad_luck":{"color":"c9aa56","duration":180,"potent":true,"extended":true,"level":2,"effect":"bad_luck"},"ominous":{"color":"325749","duration":6000,"potent":true,"extended":false,"level":2,"effect":"bad_omen"},"infestation":{"color":"899b8a","duration":180,"potent":false,"extended":true,"level":2,"effect":"infested"},"oozing":{"color":"a5fda9","duration":180,"potent":false,"extended":true,"level":2,"effect":"oozing"},"weaving":{"color":"75675a","duration":180,"potent":false,"extended":true,"level":2,"effect":"weaving"},"wind_charged":{"color":"bcc8ff","duration":180,"potent":false,"extended":true,"level":2,"effect":"wind_charged"}}
const ITEMS = {
	808:{"potion":"water","form":"drink","variant":"normal"},
	2048:{"potion":"water","form":"splash","variant":"normal"},
	2049:{"potion":"water","form":"lingering","variant":"normal"},
	2050:{"potion":"awkward","form":"drink","variant":"normal"},
	2051:{"potion":"awkward","form":"splash","variant":"normal"},
	2052:{"potion":"awkward","form":"lingering","variant":"normal"},
	2053:{"potion":"mundane","form":"drink","variant":"normal"},
	2054:{"potion":"mundane","form":"splash","variant":"normal"},
	2055:{"potion":"mundane","form":"lingering","variant":"normal"},
	2056:{"potion":"thick","form":"drink","variant":"normal"},
	2057:{"potion":"thick","form":"splash","variant":"normal"},
	2058:{"potion":"thick","form":"lingering","variant":"normal"},
	855:{"potion":"healing","form":"drink","variant":"normal"},
	2059:{"potion":"healing","form":"drink","variant":"strong"},
	2060:{"potion":"healing","form":"splash","variant":"normal"},
	2061:{"potion":"healing","form":"splash","variant":"strong"},
	2062:{"potion":"healing","form":"lingering","variant":"normal"},
	2063:{"potion":"healing","form":"lingering","variant":"strong"},
	842:{"potion":"healing","form":"arrow","variant":"normal"},
	2064:{"potion":"healing","form":"arrow","variant":"strong"},
	2065:{"potion":"harming","form":"drink","variant":"normal"},
	2066:{"potion":"harming","form":"drink","variant":"strong"},
	2067:{"potion":"harming","form":"splash","variant":"normal"},
	2068:{"potion":"harming","form":"splash","variant":"strong"},
	2069:{"potion":"harming","form":"lingering","variant":"normal"},
	2070:{"potion":"harming","form":"lingering","variant":"strong"},
	843:{"potion":"harming","form":"arrow","variant":"normal"},
	2071:{"potion":"harming","form":"arrow","variant":"strong"},
	859:{"potion":"night_vision","form":"drink","variant":"normal"},
	2072:{"potion":"night_vision","form":"drink","variant":"extended"},
	2073:{"potion":"night_vision","form":"splash","variant":"normal"},
	2074:{"potion":"night_vision","form":"splash","variant":"extended"},
	2075:{"potion":"night_vision","form":"lingering","variant":"normal"},
	2076:{"potion":"night_vision","form":"lingering","variant":"extended"},
	844:{"potion":"night_vision","form":"arrow","variant":"normal"},
	2077:{"potion":"night_vision","form":"arrow","variant":"extended"},
	856:{"potion":"swiftness","form":"drink","variant":"normal"},
	2078:{"potion":"swiftness","form":"drink","variant":"extended"},
	2079:{"potion":"swiftness","form":"drink","variant":"strong"},
	2080:{"potion":"swiftness","form":"splash","variant":"normal"},
	2081:{"potion":"swiftness","form":"splash","variant":"extended"},
	2082:{"potion":"swiftness","form":"splash","variant":"strong"},
	2083:{"potion":"swiftness","form":"lingering","variant":"normal"},
	2084:{"potion":"swiftness","form":"lingering","variant":"extended"},
	2085:{"potion":"swiftness","form":"lingering","variant":"strong"},
	845:{"potion":"swiftness","form":"arrow","variant":"normal"},
	2086:{"potion":"swiftness","form":"arrow","variant":"extended"},
	2087:{"potion":"swiftness","form":"arrow","variant":"strong"},
	2088:{"potion":"slowness","form":"drink","variant":"normal"},
	2089:{"potion":"slowness","form":"drink","variant":"extended"},
	2090:{"potion":"slowness","form":"drink","variant":"strong"},
	2091:{"potion":"slowness","form":"splash","variant":"normal"},
	2092:{"potion":"slowness","form":"splash","variant":"extended"},
	2093:{"potion":"slowness","form":"splash","variant":"strong"},
	2094:{"potion":"slowness","form":"lingering","variant":"normal"},
	2095:{"potion":"slowness","form":"lingering","variant":"extended"},
	2096:{"potion":"slowness","form":"lingering","variant":"strong"},
	846:{"potion":"slowness","form":"arrow","variant":"normal"},
	2097:{"potion":"slowness","form":"arrow","variant":"extended"},
	2098:{"potion":"slowness","form":"arrow","variant":"strong"},
	2099:{"potion":"leaping","form":"drink","variant":"normal"},
	2100:{"potion":"leaping","form":"drink","variant":"extended"},
	2101:{"potion":"leaping","form":"drink","variant":"strong"},
	2102:{"potion":"leaping","form":"splash","variant":"normal"},
	2103:{"potion":"leaping","form":"splash","variant":"extended"},
	2104:{"potion":"leaping","form":"splash","variant":"strong"},
	2105:{"potion":"leaping","form":"lingering","variant":"normal"},
	2106:{"potion":"leaping","form":"lingering","variant":"extended"},
	2107:{"potion":"leaping","form":"lingering","variant":"strong"},
	847:{"potion":"leaping","form":"arrow","variant":"normal"},
	2108:{"potion":"leaping","form":"arrow","variant":"extended"},
	2109:{"potion":"leaping","form":"arrow","variant":"strong"},
	2110:{"potion":"withering","form":"drink","variant":"normal"},
	2111:{"potion":"withering","form":"drink","variant":"extended"},
	2112:{"potion":"withering","form":"drink","variant":"strong"},
	2113:{"potion":"withering","form":"splash","variant":"normal"},
	2114:{"potion":"withering","form":"splash","variant":"extended"},
	2115:{"potion":"withering","form":"splash","variant":"strong"},
	2116:{"potion":"withering","form":"lingering","variant":"normal"},
	2117:{"potion":"withering","form":"lingering","variant":"extended"},
	2118:{"potion":"withering","form":"lingering","variant":"strong"},
	2119:{"potion":"withering","form":"arrow","variant":"normal"},
	2120:{"potion":"withering","form":"arrow","variant":"extended"},
	2121:{"potion":"withering","form":"arrow","variant":"strong"},
	2122:{"potion":"poison","form":"drink","variant":"normal"},
	2123:{"potion":"poison","form":"drink","variant":"extended"},
	2124:{"potion":"poison","form":"drink","variant":"strong"},
	2125:{"potion":"poison","form":"splash","variant":"normal"},
	2126:{"potion":"poison","form":"splash","variant":"extended"},
	2127:{"potion":"poison","form":"splash","variant":"strong"},
	2128:{"potion":"poison","form":"lingering","variant":"normal"},
	2129:{"potion":"poison","form":"lingering","variant":"extended"},
	2130:{"potion":"poison","form":"lingering","variant":"strong"},
	848:{"potion":"poison","form":"arrow","variant":"normal"},
	2131:{"potion":"poison","form":"arrow","variant":"extended"},
	2132:{"potion":"poison","form":"arrow","variant":"strong"},
	2133:{"potion":"regeneration","form":"drink","variant":"normal"},
	2134:{"potion":"regeneration","form":"drink","variant":"extended"},
	2135:{"potion":"regeneration","form":"drink","variant":"strong"},
	2136:{"potion":"regeneration","form":"splash","variant":"normal"},
	2137:{"potion":"regeneration","form":"splash","variant":"extended"},
	2138:{"potion":"regeneration","form":"splash","variant":"strong"},
	2139:{"potion":"regeneration","form":"lingering","variant":"normal"},
	2140:{"potion":"regeneration","form":"lingering","variant":"extended"},
	2141:{"potion":"regeneration","form":"lingering","variant":"strong"},
	849:{"potion":"regeneration","form":"arrow","variant":"normal"},
	2142:{"potion":"regeneration","form":"arrow","variant":"extended"},
	2143:{"potion":"regeneration","form":"arrow","variant":"strong"},
	2144:{"potion":"invisibility","form":"drink","variant":"normal"},
	2145:{"potion":"invisibility","form":"drink","variant":"extended"},
	2146:{"potion":"invisibility","form":"splash","variant":"normal"},
	2147:{"potion":"invisibility","form":"splash","variant":"extended"},
	2148:{"potion":"invisibility","form":"lingering","variant":"normal"},
	2149:{"potion":"invisibility","form":"lingering","variant":"extended"},
	852:{"potion":"invisibility","form":"arrow","variant":"normal"},
	2150:{"potion":"invisibility","form":"arrow","variant":"extended"},
	860:{"potion":"water_breathing","form":"drink","variant":"normal"},
	2151:{"potion":"water_breathing","form":"drink","variant":"extended"},
	2152:{"potion":"water_breathing","form":"splash","variant":"normal"},
	2153:{"potion":"water_breathing","form":"splash","variant":"extended"},
	2154:{"potion":"water_breathing","form":"lingering","variant":"normal"},
	2155:{"potion":"water_breathing","form":"lingering","variant":"extended"},
	853:{"potion":"water_breathing","form":"arrow","variant":"normal"},
	2156:{"potion":"water_breathing","form":"arrow","variant":"extended"},
	857:{"potion":"fire_resistance","form":"drink","variant":"normal"},
	2157:{"potion":"fire_resistance","form":"drink","variant":"extended"},
	2158:{"potion":"fire_resistance","form":"splash","variant":"normal"},
	2159:{"potion":"fire_resistance","form":"splash","variant":"extended"},
	2160:{"potion":"fire_resistance","form":"lingering","variant":"normal"},
	2161:{"potion":"fire_resistance","form":"lingering","variant":"extended"},
	854:{"potion":"fire_resistance","form":"arrow","variant":"normal"},
	2162:{"potion":"fire_resistance","form":"arrow","variant":"extended"},
	858:{"potion":"strength","form":"drink","variant":"normal"},
	2163:{"potion":"strength","form":"drink","variant":"extended"},
	2164:{"potion":"strength","form":"drink","variant":"strong"},
	2165:{"potion":"strength","form":"splash","variant":"normal"},
	2166:{"potion":"strength","form":"splash","variant":"extended"},
	2167:{"potion":"strength","form":"splash","variant":"strong"},
	2168:{"potion":"strength","form":"lingering","variant":"normal"},
	2169:{"potion":"strength","form":"lingering","variant":"extended"},
	2170:{"potion":"strength","form":"lingering","variant":"strong"},
	850:{"potion":"strength","form":"arrow","variant":"normal"},
	2171:{"potion":"strength","form":"arrow","variant":"extended"},
	2172:{"potion":"strength","form":"arrow","variant":"strong"},
	2173:{"potion":"weakness","form":"drink","variant":"normal"},
	2174:{"potion":"weakness","form":"drink","variant":"extended"},
	2175:{"potion":"weakness","form":"drink","variant":"strong"},
	2176:{"potion":"weakness","form":"splash","variant":"normal"},
	2177:{"potion":"weakness","form":"splash","variant":"extended"},
	2178:{"potion":"weakness","form":"splash","variant":"strong"},
	2179:{"potion":"weakness","form":"lingering","variant":"normal"},
	2180:{"potion":"weakness","form":"lingering","variant":"extended"},
	2181:{"potion":"weakness","form":"lingering","variant":"strong"},
	851:{"potion":"weakness","form":"arrow","variant":"normal"},
	2182:{"potion":"weakness","form":"arrow","variant":"extended"},
	2183:{"potion":"weakness","form":"arrow","variant":"strong"},
	2184:{"potion":"slow_falling","form":"drink","variant":"normal"},
	2185:{"potion":"slow_falling","form":"drink","variant":"extended"},
	2186:{"potion":"slow_falling","form":"splash","variant":"normal"},
	2187:{"potion":"slow_falling","form":"splash","variant":"extended"},
	2188:{"potion":"slow_falling","form":"lingering","variant":"normal"},
	2189:{"potion":"slow_falling","form":"lingering","variant":"extended"},
	2190:{"potion":"slow_falling","form":"arrow","variant":"normal"},
	2191:{"potion":"slow_falling","form":"arrow","variant":"extended"},
	2192:{"potion":"turtle_master","form":"drink","variant":"normal"},
	2193:{"potion":"turtle_master","form":"drink","variant":"extended"},
	2194:{"potion":"turtle_master","form":"drink","variant":"strong"},
	2195:{"potion":"turtle_master","form":"splash","variant":"normal"},
	2196:{"potion":"turtle_master","form":"splash","variant":"extended"},
	2197:{"potion":"turtle_master","form":"splash","variant":"strong"},
	2198:{"potion":"turtle_master","form":"lingering","variant":"normal"},
	2199:{"potion":"turtle_master","form":"lingering","variant":"extended"},
	2200:{"potion":"turtle_master","form":"lingering","variant":"strong"},
	2201:{"potion":"turtle_master","form":"arrow","variant":"normal"},
	2202:{"potion":"turtle_master","form":"arrow","variant":"extended"},
	2203:{"potion":"turtle_master","form":"arrow","variant":"strong"},
	2204:{"potion":"luck","form":"drink","variant":"normal"},
	2205:{"potion":"luck","form":"drink","variant":"extended"},
	2206:{"potion":"luck","form":"drink","variant":"strong"},
	2207:{"potion":"luck","form":"splash","variant":"normal"},
	2208:{"potion":"luck","form":"splash","variant":"extended"},
	2209:{"potion":"luck","form":"splash","variant":"strong"},
	2210:{"potion":"luck","form":"lingering","variant":"normal"},
	2211:{"potion":"luck","form":"lingering","variant":"extended"},
	2212:{"potion":"luck","form":"lingering","variant":"strong"},
	2213:{"potion":"luck","form":"arrow","variant":"normal"},
	2214:{"potion":"luck","form":"arrow","variant":"extended"},
	2215:{"potion":"luck","form":"arrow","variant":"strong"},
	2216:{"potion":"bad_luck","form":"drink","variant":"normal"},
	2217:{"potion":"bad_luck","form":"drink","variant":"extended"},
	2218:{"potion":"bad_luck","form":"drink","variant":"strong"},
	2219:{"potion":"bad_luck","form":"splash","variant":"normal"},
	2220:{"potion":"bad_luck","form":"splash","variant":"extended"},
	2221:{"potion":"bad_luck","form":"splash","variant":"strong"},
	2222:{"potion":"bad_luck","form":"lingering","variant":"normal"},
	2223:{"potion":"bad_luck","form":"lingering","variant":"extended"},
	2224:{"potion":"bad_luck","form":"lingering","variant":"strong"},
	2225:{"potion":"bad_luck","form":"arrow","variant":"normal"},
	2226:{"potion":"bad_luck","form":"arrow","variant":"extended"},
	2227:{"potion":"bad_luck","form":"arrow","variant":"strong"},
	2228:{"potion":"ominous","form":"drink","variant":"normal"},
	2229:{"potion":"ominous","form":"drink","variant":"strong"},
	2230:{"potion":"infestation","form":"drink","variant":"normal"},
	2231:{"potion":"infestation","form":"drink","variant":"extended"},
	2232:{"potion":"infestation","form":"splash","variant":"normal"},
	2233:{"potion":"infestation","form":"splash","variant":"extended"},
	2234:{"potion":"infestation","form":"lingering","variant":"normal"},
	2235:{"potion":"infestation","form":"lingering","variant":"extended"},
	2236:{"potion":"infestation","form":"arrow","variant":"normal"},
	2237:{"potion":"infestation","form":"arrow","variant":"extended"},
	2238:{"potion":"oozing","form":"drink","variant":"normal"},
	2239:{"potion":"oozing","form":"drink","variant":"extended"},
	2240:{"potion":"oozing","form":"splash","variant":"normal"},
	2241:{"potion":"oozing","form":"splash","variant":"extended"},
	2242:{"potion":"oozing","form":"lingering","variant":"normal"},
	2243:{"potion":"oozing","form":"lingering","variant":"extended"},
	2244:{"potion":"oozing","form":"arrow","variant":"normal"},
	2245:{"potion":"oozing","form":"arrow","variant":"extended"},
	2246:{"potion":"weaving","form":"drink","variant":"normal"},
	2247:{"potion":"weaving","form":"drink","variant":"extended"},
	2248:{"potion":"weaving","form":"splash","variant":"normal"},
	2249:{"potion":"weaving","form":"splash","variant":"extended"},
	2250:{"potion":"weaving","form":"lingering","variant":"normal"},
	2251:{"potion":"weaving","form":"lingering","variant":"extended"},
	2252:{"potion":"weaving","form":"arrow","variant":"normal"},
	2253:{"potion":"weaving","form":"arrow","variant":"extended"},
	2254:{"potion":"wind_charged","form":"drink","variant":"normal"},
	2255:{"potion":"wind_charged","form":"drink","variant":"extended"},
	2256:{"potion":"wind_charged","form":"splash","variant":"normal"},
	2257:{"potion":"wind_charged","form":"splash","variant":"extended"},
	2258:{"potion":"wind_charged","form":"lingering","variant":"normal"},
	2259:{"potion":"wind_charged","form":"lingering","variant":"extended"},
	2260:{"potion":"wind_charged","form":"arrow","variant":"normal"},
	2261:{"potion":"wind_charged","form":"arrow","variant":"extended"},
}

static func find(potion: String, form: String = "drink", variant: String = "normal") -> int:
	for id in ITEMS:
		var item: Dictionary = ITEMS[id]
		if item.potion == potion and item.form == form and item.variant == variant: return id
	return 0

static func is_bottle(id: int) -> bool:
	return ITEMS.has(id) and ITEMS[id].form != "arrow"

static func brew(input: int, ingredient: int) -> int:
	if not is_bottle(input): return 0
	var item: Dictionary = ITEMS[input]
	var name: String = item.potion; var form: String = item.form; var variant: String = item.variant
	if ingredient == Nodes.GUNPOWDER and form == "drink": return find(name,"splash",variant)
	if ingredient == VillageContent.DRAGON_BREATH and form == "splash": return find(name,"lingering",variant)
	var awkward: Dictionary = {VillageContent.GLISTERING_MELON:"healing",VillageContent.GOLDEN_CARROT:"night_vision",Nodes.SUGAR:"swiftness",Nodes.MAGMA_CREAM:"fire_resistance",Nodes.BLAZE_POWDER:"strength",VillageContent.PUFFERFISH:"water_breathing",Nodes.GHAST_TEAR:"regeneration",VillageContent.SPIDER_EYE:"poison",VillageContent.RABBIT_FOOT:"leaping",VillageContent.PHANTOM_MEMBRANE:"slow_falling",Nodes.STONE:"infestation",VillageContent.SLIME_BLOCK:"oozing",VillageContent.COBWEB:"weaving",VillageContent.BREEZE_ROD:"wind_charged",VillageContent.TURTLE_HELMET:"turtle_master"}
	if name == "water":
		if ingredient == VillageContent.NETHER_WART_ITEM: return find("awkward",form)
		if ingredient == VillageContent.FERMENTED_SPIDER_EYE: return find("weakness",form)
		if ingredient == VillageContent.GLOWSTONE_DUST: return find("thick",form)
		if ingredient in [VillageContent.GLISTERING_MELON,Nodes.SUGAR,Nodes.MAGMA_CREAM,Nodes.BLAZE_POWDER,Nodes.REDSTONE_WIRE,Nodes.GHAST_TEAR,VillageContent.SPIDER_EYE,VillageContent.RABBIT_FOOT]: return find("mundane",form)
		return 0
	if name == "awkward" and awkward.has(ingredient): return find(awkward[ingredient],form)
	if name == "mundane" and ingredient == VillageContent.FERMENTED_SPIDER_EYE: return find("weakness",form)
	if ingredient == VillageContent.FERMENTED_SPIDER_EYE:
		var inverse: Dictionary = {"healing":"harming","poison":"harming","swiftness":"slowness","leaping":"slowness","night_vision":"invisibility","luck":"bad_luck"}
		if inverse.has(name):
			var output: int = find(inverse[name],form,variant)
			return output if output != 0 else find(inverse[name],form)
	if ingredient == Nodes.REDSTONE_WIRE and variant != "extended": return find(name,form,"extended")
	if ingredient == VillageContent.GLOWSTONE_DUST and variant != "strong": return find(name,form,"strong")
	return 0

static func effects(id: int) -> Array:
	if not ITEMS.has(id): return []
	var item: Dictionary = ITEMS[id]; var def: Dictionary = DEFINITIONS[item.potion]
	if item.potion in ["water","awkward","mundane","thick"]: return []
	var level: int = def.level if item.variant == "strong" else 1
	var duration: float = def.duration
	if item.variant == "extended": duration *= 8.0/3.0
	if item.variant == "strong" and item.potion != "ominous": duration /= 4.5 if item.potion == "slowness" else 2.0
	if item.form == "arrow": duration *= 0.125
	if item.form == "lingering": duration *= 0.25
	if item.potion == "turtle_master": return [{"effect":"resistance","level":level+2,"duration":duration},{"effect":"slowness","level":2*level+2,"duration":duration}]
	return [{"effect":def.get("effect",item.potion),"level":level,"duration":duration}]

static func description(id: int) -> String:
	var lines: PackedStringArray = []
	for effect in effects(id):
		lines.append("%s %d%s"%[String(effect.effect).replace("_"," ").capitalize(),effect.level," · %d:%02d"%[int(effect.duration)/60,int(effect.duration)%60] if effect.duration > 0 else " · instant"])
	return "\n".join(lines) if not lines.is_empty() else "No status effects"

static func recipes(inv: Inventory) -> void:
	inv._recipe("Trident",VillageContent.TRIDENT,1,[Nodes.IRON,Nodes.IRON,Nodes.IRON,0,Nodes.DIAMOND,0,0,Nodes.STICK,0],3,"table")
	inv._recipe("Mace",VillageContent.MACE,1,[VillageContent.HEAVY_CORE,VillageContent.BREEZE_ROD],1)
	inv._shapeless("Fermented spider eye",VillageContent.FERMENTED_SPIDER_EYE,1,[VillageContent.SPIDER_EYE,Nodes.BROWN_MUSHROOM,Nodes.SUGAR])
	inv._recipe("Glowstone dust",VillageContent.GLOWSTONE_DUST,4,[Nodes.GLOWSTONE],1)
	inv._recipe("Glowstone from dust",Nodes.GLOWSTONE,1,[VillageContent.GLOWSTONE_DUST,VillageContent.GLOWSTONE_DUST,VillageContent.GLOWSTONE_DUST,VillageContent.GLOWSTONE_DUST],2)
	inv._recipe("Slime block",VillageContent.SLIME_BLOCK,1,[Nodes.SLIME_BALL,Nodes.SLIME_BALL,Nodes.SLIME_BALL,Nodes.SLIME_BALL,Nodes.SLIME_BALL,Nodes.SLIME_BALL,Nodes.SLIME_BALL,Nodes.SLIME_BALL,Nodes.SLIME_BALL],3,"table")
	inv._recipe("Slime balls",Nodes.SLIME_BALL,9,[VillageContent.SLIME_BLOCK],1)
	inv._recipe("Cobweb",VillageContent.COBWEB,1,[Nodes.STRING,0,Nodes.STRING,0,Nodes.STRING,0,Nodes.STRING,0,Nodes.STRING],3,"table")
	inv._recipe("Turtle shell",VillageContent.TURTLE_HELMET,1,[VillageContent.TURTLE_SCUTE,VillageContent.TURTLE_SCUTE,VillageContent.TURTLE_SCUTE,VillageContent.TURTLE_SCUTE,0,VillageContent.TURTLE_SCUTE],3,"table")
	for id in ITEMS:
		var item: Dictionary = ITEMS[id]
		if item.form != "lingering": continue
		var arrow: int = find(item.potion,"arrow",item.variant)
		if arrow: inv._recipe(Nodes.title(arrow),arrow,8,[Nodes.ARROW_ITEM,Nodes.ARROW_ITEM,Nodes.ARROW_ITEM,Nodes.ARROW_ITEM,id,Nodes.ARROW_ITEM,Nodes.ARROW_ITEM,Nodes.ARROW_ITEM,Nodes.ARROW_ITEM],3,"table")
