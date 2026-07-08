local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local OreFolder = ReplicatedStorage.Ores
local Database = require(ReplicatedStorage.OreEverythingDatabase)
local ContextActionService = game:GetService("ContextActionService")


local priority = Database.GetPriorityList()
local overrides = Database.GetOverrides()

local UsedPositions = {}

local GCounts = {}

local PerlinOverride = {}
local HiddenStructures = {}

local function PositionKey(x,y,z)
	return x..","..y..","..z
end
--use this by appending an entry, using the positionkey as a name and the name of the thing there as the value
--to check if the thing exists, look at value. if it's nil, it hasnt been generated, and if it's air, it has but was broken
--thanks for that, berezaa
--my code before involved checking the actual world for the blocks and using names to store coordinates
--this is so much better than my hacky ass idea before, though i must admire my creativity in the face of ignorance
--lmfao

local randomseed1 = math.random(-10e5, 10e5)
local randomseed2 = math.random(-10e5, 10e5)
local randomseed3 = math.random(-10e5, 10e5)

function newSeeds()
	randomseed1 = math.random(-10e5, 10e5)
	randomseed2 = math.random(-10e5, 10e5)
	randomseed3 = math.random(-10e5, 10e5)
end

local VectorsGen = { --generates less blocks to save processing power when generating caves
	Vector3.new(-1,0,0),
	Vector3.new(1,0,0),
	Vector3.new(0,-1,0),
	Vector3.new(0,1,0),
	Vector3.new(0,0,1),
	Vector3.new(0,0,-1),
}

local VectorsMine = { --generates more blocks when just mining with pick
	Vector3.new(-1,0,0),
	Vector3.new(1,0,0),
	Vector3.new(0,-1,0),
	Vector3.new(0,1,0),
	Vector3.new(0,0,1),
	Vector3.new(0,0,-1),
	Vector3.new(0,2,0),
	Vector3.new(-1,0,-1),
	Vector3.new(1,0,1),
	Vector3.new(-1,0,1),
	Vector3.new(1,0,-1)
}

function Converterinone(pos) --convert functions to translate block positions into real stud positions
	return pos * 6
end
function RevConverterinone(pos)
	return pos / 6
end

function Converterintwo(pos) --y starts at 1
	local posConv = 0	
	pos = pos-1
	posConv = pos*6
	posConv = -posConv
	posConv = posConv+1
	return posConv
end
function RevConverterintwo(pos) --y starts at 1
	pos = pos-1
	pos = -pos
	pos = pos/6
	pos = pos+1
	return pos
end

local NoiseOverride = ServerStorage.GenerateWhenMined.EmptySpace:GetChildren()
for i, child in pairs(NoiseOverride) do
	PerlinOverride[PositionKey(RevConverterinone(child.Position.X),RevConverterintwo(child.Position.Y),RevConverterinone(child.Position.Z))] = 1
end
--coordinate list of manually generated caves, grabbed from models in serverstorage to make creating new ones easier

local HStructs = ServerStorage.GenerateWhenMined.HiddenStructures:GetChildren()
for i, child in pairs(HStructs) do
	local vector = child.PrimaryPart.Position
	HiddenStructures[PositionKey(RevConverterinone(vector.X),RevConverterintwo(vector.Y),RevConverterinone(vector.Z))] = child
end
--coordinate list of custom models to spawn in custom generated caves



local colorsandlevels = {
	{-2,  -1,   Color3.fromRGB(153, 153, 153)},
	{0,   80,   Color3.fromRGB(93, 90, 90)},
	{80, 200,   Color3.fromRGB(118, 105, 52)},
	{200, 400,  Color3.fromRGB(77, 108, 46)},
	{400, 600,  Color3.fromRGB(71, 106, 111)},
	{600, 800,  Color3.fromRGB(100, 70, 130)},
	{800, 1000, Color3.fromRGB(118, 13, 15)},
}

local maxcolordepth = 1000 --edge case handler for when it goes below tweening range

function tweenColor3(colorA, colorB, percent) --averages color by depth via HSV to preserve color quality
	local aHue, aSaturation, aValue = Color3.toHSV(colorA)
	local bHue, bSaturation, bValue = Color3.toHSV(colorB)
	return Color3.fromHSV(
		aHue + (bHue-aHue)*percent,
		aSaturation + (bSaturation-aSaturation)*percent,
		aValue + (bValue-aValue)*percent
	)
end

function ColorFinder(depthy)
	local returncolor = Color3.new(1, 1, 1) --default is stark white so i can see if there's an error
	if depthy >= maxcolordepth then
		returncolor = Color3.fromRGB(118, 13, 15) --return final color if below limit
	else
		for index, value in ipairs(colorsandlevels) do 
			if depthy < value[2] and depthy >= value[1] then
				local percent = ( depthy - value[1] ) / ( value[2] - value[1] )
				returncolor = tweenColor3(colorsandlevels[index-1][3], value[3], percent)
				break
			end
		end
	end
	return returncolor
end

function OreStrengthen(depth, oreType)
	local durability = 25 + ( depth^1.5 )
	if depth > 101 then
		durability = durability + ( ( depth-100 )^1.6 )
	end
	if depth > 201 then
		durability = durability + ( ( ( depth-200 )^1.8 ) / 4 )
	end
	if depth > 401 then
		durability = durability + ( ( depth-400 )^1.9 )
	end
	if depth > 801 then
		durability = durability + ( ( depth-800 )^2.3 )
	end
	if depth > 1201 then
		durability = durability + ( ( depth-1200 )^3 ) --adds more durability to rocks the deeper you go, scales faster deeper
	end
	durability = math.floor( ( durability * Database.GetOreData(oreType, "Multiplier") ) + Database.GetOreData(oreType, "Durability") )
	return durability
end --god what a glow-up. this thing was like 40 lines long before and now look at it. so clean

function GetRarityFromDepth(depth, first, mid, second, chance1, chance2)
	local rarityval = 0
	if depth >= first and depth <= mid then
		local newdepth = depth - first
		local newmid = mid - first
		rarityval = ( newdepth / newmid ) * chance1 --sneaky simple math
	elseif depth > mid and depth <= second then
		local newdepth = depth - mid
		local newsecond = second - mid --not sneaky bad math but whatever it works and it's accurate
		rarityval = ( ( ( 1 - ( newdepth / newsecond ) ) * chance1 ) * ( ( chance1 - chance2 ) / chance1 ) ) + chance2
	elseif depth < first then --catch cases to avoid math if at all possible
		rarityval = 0
	elseif depth > second then
		rarityval = chance2
	end
	return rarityval
end

local raritiescache = {}

--every ore is listed in the raritiescache entry in order of priority
--each ore's chance is calculated as a percentage of the remaining space in the cache entry
--this way i can loop through the cache entry with only one random number to get the ore to be generated
--this may result in larger memory overhead but it's not that big and it won't be infinite
--i mean it COULD be but. it won't be
function LayerRarityMaker(depthy)
	local array = {}
	local spaceLeft = 1000000
	local spaceTaken = 0
	for index, value in ipairs(priority) do
		local rarityval = GetRarityFromDepth(depthy, Database.GetOreData(value, "Depth"),
											 Database.GetOreData(value, "BestDepth"),Database.GetOreData(value, "SecondBestDepth"),
											 Database.GetOreData(value, "Rarity"),Database.GetOreData(value, "SecondBestChance"))
		if rarityval ~= 0 then
			rarityval = math.ceil((rarityval/1000000)*spaceLeft)
			spaceTaken += rarityval
			spaceLeft -= rarityval
			local arrayentry = {spaceTaken, value}
			table.insert(array, arrayentry)
		end
	end
	if raritiescache[tostring(depthy)] == nil then
		raritiescache[tostring(depthy)] = array
	end
	return array
end

function LayerRarityGetter(depthy) --this gets the rarity table for the requested layer
	if raritiescache[tostring(depthy)] ~= nil then --if one doesn't exist, it creates one
		return raritiescache[tostring(depthy)]
	else
		LayerRarityMaker(depthy)
		return raritiescache[tostring(depthy)]
	end
	--return LayerRarityMaker(depthy) --temporarily removing the cache system
end

function OreRandomChancifier(x, y, z, circdepth, reroll)
	local returnval = "Rock"                  --default case. if everything fails it will remain as "Rock"
	if overrides["x"..x] ~= nil and overrides["x"..x]["y"..y] ~= nil and overrides["x"..x]["y"..y]["z"..z] ~= nil then
		returnval = overrides["x"..x]["y"..y]["z"..z]
	else
		local randomval = math.random(1, 1000000)
		local rarities = LayerRarityGetter(circdepth)
		for index, value in rarities do
			if randomval <= value[1] then --finds the range for each ore that the number falls in
				returnval = value[2] --returns the name of the ore
				break
			end
		end
	end
	if reroll and returnval == "Rock" then
		print("recursing")
		return OreRandomChancifier(x, y, z, circdepth, false) --if player has reroll ability then recurse with reroll off
	else
		print("returned value "..returnval)
		return returnval
	end
end



function Generateblock(posx, posy, posz, Override, PresetOre, CaveInfo, reroll) --perlin noise cave gen code heavily influenced by azure mines
	local isCave = false --thanks berezaa idk where i'd be without you
	local posvector = Vector3.new(Converterinone(posx), Converterintwo(posy), Converterinone(posz))
	local returnval = false
	local positionkey = PositionKey(posx,posy,posz)
	if (UsedPositions[positionkey] == nil or Override == true) and posy > 0 then
		local Noise = math.noise((posx/14)+randomseed1,(posy/10)+randomseed2,(posz/14)+randomseed3) --returns one number value between -1 and 1
																									--based on 3d perlin noise grid
		local CompactPos = Vector3.new(posx,posy,posz)
		if PerlinOverride[positionkey] == 1 or (posy > 4 and ((Noise <= 0.8 and Noise >= 0.57) or (Noise <= -0.57 and Noise >= -0.8))) then
			--if level is below 2 and the noise is in a certain range between positive and negative
			
			if HiddenStructures[positionkey] ~= nil then
				HiddenStructures[positionkey]:Clone().Parent = game.Workspace.mineshaft --should load in the structure
			end
			
			isCave = true --if the perlin noise 3d space is within the threshhold, it *is* a cave

			UsedPositions[positionkey] = false

			if Override ~= "Branch" and Override ~= "BranchProtect" then

				if CaveInfo == nil then --doesnt exist on initial generation, only triggers on recurse
					CaveInfo = {}
					CaveInfo.Origin = Vector3.new(posx,posy,posz)
				end				

				local Origin = positionkey
				GCounts[Origin] = 0
				for i,Vec in pairs(VectorsGen) do
					local NewPos = CompactPos + Vec
					if UsedPositions[PositionKey(NewPos.x,NewPos.y,NewPos.z)] == nil then
						GCounts[Origin] = GCounts[Origin] + 1
						Generateblock(NewPos.x,NewPos.y,NewPos.z,"Branch",Origin,CaveInfo)
					end
				end
			else
				local Origin = PresetOre
				for i,Vec in pairs(VectorsGen) do
					local NewPos = CompactPos + Vec
					if UsedPositions[PositionKey(NewPos.x,NewPos.y,NewPos.z)] == nil then
						GCounts[Origin] = GCounts[Origin] + 1
						if GCounts[Origin] % 250 == 0 then -- wait every hundred
							wait()
						end
						local Code = "Branch"
						local Returnvalu, Ore, Cave = Generateblock(NewPos.x,NewPos.y,NewPos.z,Code,Origin,CaveInfo)
						if Cave then
							isCave = true
						end
					end
				end	
			end
		else--if it isn't a cave
			local Unbreakable = false
			--begin experimental thing
			local circdepth = math.ceil(((game.Workspace.DepthMeasureCube.Position-posvector).Magnitude)/6)-33
			--end experimental thing
			local Oretype = OreRandomChancifier(posx, posy, posz, circdepth, reroll)
			if posy <= 3 and ( posx >= 22  or posx <= -22 or posz >= 22 or posz <= -22 ) then --edge case for top outside
				Unbreakable=true
				Oretype = "Rock"
			end
			local newblock = Database.GetOreData(Oretype, "Model"):Clone()
			local OreAttributes = ServerStorage.OreAttributeTemplate:GetChildren()
			for index, value in ipairs(OreAttributes) do
				local newthing = value:Clone()
				newthing.Parent = newblock
			end
			local durab = OreStrengthen(circdepth, Oretype)
			newblock.Durability.Value = durab
			newblock.DurabilityInitial.Value = durab
			newblock.PosX.Value = posx
			newblock.PosY.Value = posy
			newblock.PosZ.Value = posz
			newblock.Level.Value = Database.GetOreData(Oretype, "Level")
			--UsedPositions[PositionKey(posx, posy, posz)] = Oretype (removed to save data)
			UsedPositions[positionkey] = true
			if Unbreakable then
				newblock.Stone.Material = Enum.Material.Basalt
				newblock.Breakable:Destroy() --changes material to make it distinct, then makes it unbreakable
				Oretype = "Unbreakable"
				local unbroken = Instance.new("BoolValue")
				unbroken.Value = true
				unbroken.Name = "Unbreakable"
				unbroken.Parent = newblock
			end
			if newblock:FindFirstChild("ColorOverride") == nil then
				newblock.Stone.Color = ColorFinder(circdepth)
			end
			if Oretype == "ChestCryst" or Oretype == "ChestGold" then
				returnval = true --just to make sure that there is always a block behind the non-solid ones. recurses generator
			end
			newblock:PivotTo(CFrame.new(Converterinone(posx), Converterintwo(posy), Converterinone(posz)))
			--newblock.Name = "x"..posx.."y"..posy.."z"..posz
			newblock.Name = Oretype
			newblock.Type.Value = Oretype
			newblock.Parent = game.Workspace.mineshaft
			if returnval then 
				for i,Vec in pairs(VectorsGen) do
					local NewPos = CompactPos + Vec
					if UsedPositions[PositionKey(NewPos.x,NewPos.y,NewPos.z)] == nil then
						Generateblock(NewPos.x,NewPos.y,NewPos.z,false,nil,nil)
					end
				end
			end
			returnval = false
			return {returnval, Oretype, isCave}
		end
	end
	return {returnval, nil, isCave}
end

local be = script.Parent.generateblock

function MakeBlocks(theposx, theposy, theposz, reroll)
	if theposy > 1 then
		for x = -1, 1 do
			for z = -1, 1 do
				Generateblock(theposx+x, theposy-1, theposz+z, false, nil, nil, reroll)
			end
		end
	end
	for x = -1, 1 do
		for z = -1, 1 do
			Generateblock(theposx+x, theposy, theposz+z, false, nil, nil, reroll)
		end
	end
	for x = -1, 1 do
		for z = -1, 1 do
			Generateblock(theposx+x, theposy+1, theposz+z, false, nil, nil, reroll)
		end
	end
end--uses some weird for loops but it protects against blocks being generated above surface so i dont care

function be.OnInvoke(theposx, theposy, theposz, reroll)
	MakeBlocks(theposx, theposy, theposz, reroll)
end

local br = game.Workspace.resetshaft --script executes upon shaft reset
br.Event:connect(function()
	table.clear(UsedPositions)
	newSeeds()
	for x = -4, 4 do
		for z = -4, 4 do
			if Generateblock(x, 1, z) then
				MakeBlocks(x, 1, z)
			end
		end
	end
	
end)

newSeeds() --generates the first blocks to start the server off
for x = -4, 4 do
	for z = -4, 4 do
		if Generateblock(x, 1, z) then
			MakeBlocks(x, 1, z)
		end
	end
end