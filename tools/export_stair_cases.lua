-- Run the local Mineclonia corner resolver against every neighbor combination.
-- The reference cornerstair.lua explicitly licenses this algorithm under CC0.
local source = arg[1] or '/home/impulse/.minetest/games/mineclonia/mods/ITEMS/mcl_stairs/cornerstair.lua'
local file = assert(io.open(source,'r')); local code = file:read('*a'); file:close()
code = code:gsub('local function get_shape_result%(pos%)','function voxey_stair_shape_result(pos)',1)
mcl_stairs = {}
local nodes = {}
core = {
 registered_nodes = {base={stairs={'base','outer','inner'}},air={}},
 get_meta = function() return {get_string=function() return '' end} end,
 get_node = function(p) return nodes[p.x..','..p.z] or {name='air',param2=0} end,
}
assert(load(code,'@'..source))()
local function param(facing,upper) return upper and 20+({[0]=0,3,2,1})[facing] or facing end
local function geometry(node)
 local upper = node.param2 >= 20
 local facing = upper and ({[20]=0,[21]=3,[22]=2,[23]=1})[node.param2] or node.param2
 local bits = 0
 for y=0,1 do for z=0,1 do for x=0,1 do
  local filled = y==0 or (node.name=='base' and z==1) or (node.name=='outer' and x==0 and z==1) or (node.name=='inner' and (x==0 or z==1))
  if filled then
   local px,py,pz = upper and 1-x or x, upper and 1-y or y, z
   for _=1,facing do px,pz=pz,1-px end
   bits = bits | (1 << (px+pz*2+py*4))
  end
 end end end
 return bits
end
local cases = {}
local positions = {'0,1','1,0','0,-1','-1,0'}
for upper=0,1 do for facing=0,3 do for encoded=0,624 do
 nodes = {['0,0']={name='base',param2=param(facing,upper==1)}}
 local value = encoded
 for i=1,4 do
  local digit = value % 5; value = math.floor(value/5)
  if digit>0 then nodes[positions[i]]={name='base',param2=param(digit-1,upper==1)} end
 end
 cases[#cases+1]=geometry(voxey_stair_shape_result({x=0,y=0,z=0}).new_node)
end end end
io.write('['..table.concat(cases,',')..']\n')
