-- Execute the local data registration file with a capture-only API.
-- This does not load a world, write the source checkout or run game callbacks.
local root = arg[1] or '/home/impulse/.minetest/games/mineclonia'
local captured = {}
core = {register_ore = function(def) captured[#captured+1] = def end,
 settings = {get_bool = function(_, _, default) return default end}}
mcl_vars = {mg_overworld_min=-128,mg_overworld_min_old=-62,mg_overworld_max=30927,mg_nether_min=-29067,mg_nether_max=-28939,superflat=false}
mcl_worlds = {layer_to_y=function(layer) return layer-62 end}
dofile(root..'/mods/MAPGEN/mcl_biomes/ores.lua')
local function encode(value)
 if type(value)=='table' then
  local output={}
  if #value>0 then
   for _, child in ipairs(value) do output[#output+1]=encode(child) end
   return '['..table.concat(output,',')..']'
  end
  local keys={}; for key in pairs(value) do keys[#keys+1]=key end; table.sort(keys)
  for _, key in ipairs(keys) do output[#output+1]=string.format('%q',key)..':'..encode(value[key]) end
  return '{'..table.concat(output,',')..'}'
 elseif type(value)=='string' then return string.format('%q',value)
 else return tostring(value) end
end
print(encode(captured))
