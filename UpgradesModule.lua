--Place to centralize all upgrade price functions, for the sake of simplifying the process of adding upgrades,
--expanding existing systems, and making more granular adjustments without it being a pain in the ass

local module = {}

--max upgrade levels are now built into the system so i dont need to use my hacky ass system from before

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local msdb = require(ReplicatedStorage.MilestoneDatabase)
local Shrt = require(ReplicatedStorage.NumberShortModule)
local DecShrt = Shrt.DecimalNumberShortener

module.numberOfSingletons = function(profiledata)
	local iterator = 0
	for index, value in pairs(profiledata.Upgrades.Singles) do
		if typeof(value) == "boolean" then
			iterator += 1
		elseif typeof(value) == "number" then
			iterator += value
		end
	end
	return iterator
end

module.numberOfOwnedSingletons = function(profiledata)
	local iterator = 0
	for index, value in pairs(profiledata.Upgrades.Singles) do
		if typeof(value) == "boolean" then
			if value then
				iterator += 1
			end
		elseif typeof(value) == "number" then
			iterator += value
		end
	end
	return iterator
end

module.upgradesTable = {
	ascension = {
		APCostRed = {
			Name = "Cost Scaling Reduction",
			Description = "All non-research costs are raised to the power of this number. This massively reduces the speed at which upgrades' cost scales over time.",
			Max = "None",
			Prereqs = "None",
			Cost = function(data)
				local level
				if typeof(data) == "number" then level = data
				else level = data.Ascension.APCostRed + 1 end
				--allows a function to input a level number to get the cost
				local costs = {
					5,
					25,
					50,
					100,
					250,
					500,
					1000,
					2500,
					5000,
					10000,
				}
				if level >= 1 and level <= 10 then
					return costs[level]
				else
					return 10^(level-6)
				end
			end,
			Value = function(profiledata, readable)
				local level = profiledata.Ascension.APCostRed
				local retval = 1 * (0.95 ^ level)
				if readable then
					if level == 0 then
						return {"^1.0", "^0.95"}
					else
						local retval2 = retval*0.95
						retval2 = string.format("%.3f", tostring(retval2.Value))
						if level == 1 then
							return {"^0.95", "^"..retval2}
						else
							retval = string.format("%.3f", tostring(retval.Value))
							return {"^"..retval, "^"..retval2}
						end
					end
				else
					return retval
				end
			end,
		},
		
		APSellPrice = { --INTEGRATED
			Name = "Income Multiplier",
			Description = "Multiplies the value of everything you sell to the Forge.",
			Max = "None",
			Prereqs = {"APCostRed"},
			Cost = function(data)
				local level
				if typeof(data) == "number" then level = data
				else level = data.Ascension.APSellPrice + 1 end
				local cost = level % 9
				if cost == 0 then
					cost = 9
				end
				cost *= 10^math.floor((level-1)/9)
				return cost
			end,
			Value = function(profiledata, readable)
				local value = 2^profiledata.Ascension.APSellPrice
				if readable then
					return {"x"..Shrt.BigNumberShortener(value), "x"..Shrt.BigNumberShortener(value*2)}
				else
					return value
				end
			end,
		},
		
		APDamage = { --INTEGRATED
			Name = "Damage Multiplier",
			Description = "Multiplies the damage dealt by your pickaxe.",
			Max = "None",
			Prereqs = {"APCostRed"},
			Cost = function(data)
				local level
				if typeof(data) == "number" then level = data
				else level = data.Ascension.APDamage + 1 end
				local multiplier = math.floor(level / 10)
				multiplier = 5^multiplier
				return math.floor(level*multiplier)
			end,
			Value = function(profiledata, readable)
				local value = 3^profiledata.Ascension.APDamage
				if readable then
					return {"x"..Shrt.BigNumberShortener(value), "x"..Shrt.BigNumberShortener(value*3)}
				else
					return value
				end
			end,
		},
		APFortune = {
			Name = "Fortune",
			Description = "The chance to yield extra ores when mining.",
			Max = "None",
			Prereqs = {"APSellPrice"},
			Cost = function(data)
				local level
				if typeof(data) == "number" then level = data
				else level = data.Ascension.APFortune + 1 end
				local multiplier = math.floor(level / 10)
				multiplier = 5^multiplier
				return math.floor((level*5)*multiplier)
			end,
			Value = function(profiledata, readable)
				local value = 1 + 0.25*profiledata.Ascension.APFortune
				if readable then
					return {Shrt.BigNumberShortener((value)*100).."%", Shrt.BigNumberShortener((value+0.25)*100).."%"}
				else
					return value
				end
			end,
		},
		APAnchor = {
			Name = "Teleportation Anchor",
			Description = "Leave behind a metastable quantum echo at your current position, which you can then return to at any time.",
			Max = 3,
			Prereqs = {"APFortune", "APSpeedExchange"},
			Cost = function(data)
				local level
				if typeof(data) == "number" then level = data
				else level = data.Ascension.APAnchor + 1 end
				local costs = {
					200,
					2500,
					10000
				}
				if level > 0 and level <= 3 then
					return costs[level]
				else
					return costs[3]
				end
			end,
			Value = function(profiledata, readable)
				local level = profiledata.Ascension.APAnchor
				local cooldownvals = {480, 360, 300}
				local value
				if level == 0 then
					value = 99999
				else
					value = cooldownvals[level]
				end
				if readable then
					if level == 0 then
						return {"Unavailable", "8 Minutes"}
					elseif level == 1 then
						return {"8 Minutes", "6 Minutes"}
					elseif level == 2 then
						return {"6 Minutes", "5 Minutes"}
					elseif level == 3 then
						return {"5 Minutes", "Maxxed"}
					else
						return {"something is broken", "something is broken"}
					end
				else
					return value
				end
			end,
		},
		APDynamite = {
			Name = "explosios thingy",
			Description = "does nothing",
			Max = 3,
			Prereqs = {"APCostRed"},
			Cost = function(data)
				local level
				if typeof(data) == "number" then level = data
				else level = data.Ascension.APDynamite + 1 end
				local costs = {
					75,
					1000,
					50000
				}
				if level > 0 and level <= 3 then
					return costs[level]
				else
					return costs[3] --backup
				end
			end,
			Value = function(profiledata, readable)
				local level = profiledata.Ascension.APDynamite
				local damagevals = {10, 25, 100}
				local value
				if level == 0 then
					value = 0
				else
					value = damagevals[level]
				end
				if readable then
					if level == 0 then
						return {"Unavailable", "10 Swings"}
					elseif level == 1 then
						return {"10 Swings", "25 Swings"}
					elseif level == 2 then
						return {"25 Swings", "100 Swings"}
					elseif level == 3 then
						return {"100 Swings", "Maxxed"}
					else
						return {"something is broken", "something is broken"}
					end
				else
					return value
				end
			end,
		},
		APReroll = { --INTEGRATED
			Name = "Lucky Charm",
			Description = "You are more likely to find ores in the mineshaft.",
			Max = 1,
			Prereqs = {"APFortune"},
			Cost = function(data)
				return 25000
			end,
			Value = function(profiledata, readable)
				local level = profiledata.Ascension.APReroll
				if readable then
					return ("+1 Reroll")
				else
					return level
				end
			end,
		},
		APSpeedExchange = {
			Name = "Ancient Exchange",
			Description = "Your pickaxe deals 10x damage, in exchange for cutting your swing speed by 2/3rds.",
			Max = 1,
			Prereqs = {"APDynamite"},
			Cost = function(data)
				return 20000
			end,
			Value = function(profiledata, readable)
				local level = profiledata.Ascension.APSpeedExchange
				if readable then
					return ("+Damage, -Speed")
				else
					return level
				end
			end,
		},
		APDoubleTap = {
			Name = "Aetherial Miner",
			Description = "Each swing of your pickaxe is accompanied by a second, ghostly swing on another nearby ore.",
			Max = 1,
			Prereqs = {"APSpeedExchange"},
			Cost = function(data)
				return 70000
			end,
			Value = function(profiledata, readable)
				local level = profiledata.Ascension.APDoubleTap
				if readable then
					return ("+1 Aether Swing")
				else
					return level
				end
			end,
		},
	},
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~SINGLES~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	singles = {
		LightOfMyMine = { --INTEGRATED
			Name = "The Light of My Mine",
			Description = "Doubles the radius of your lantern.",
			Cost = function()
				return 50000
			end,
			Value = function(profiledata, readable)
				if readable then
					return "x2 Lantern Radius"
				elseif profiledata.Upgrades.Singles.LightOfMyMine then
					return 2
				else
					return 1
				end
			end,
		},

		KnowledgeIsPower = { --INTEGRATED
			Name = "Knowledge Is Power",
			Description = "+1 flat pickaxe damage for each Lab upgrade purchased, applied before any multipliers.",
			Cost = function()
				return 150000
			end,
			Value = function(profiledata, readable)
				local iterator = -3
				for index, value in pairs(profiledata.Upgrades.General) do
					if index ~= "Teleporter" then
						iterator += value
					end
				end
				if readable then
					return "+"..Shrt.BigNumberShortener(iterator).." Damage"
				elseif profiledata.Upgrades.Singles.KnowledgeIsPower then
					return iterator
				else
					return 0
				end
			end,
		},

		FloatLikeAButterfly = { --INTEGRATED
			Name = "Float Like A Butterfly",
			Description = "Increases your character's walkspeed by 1.25x.",
			Cost = function()
				return 5000000
			end,
			Value = function(profiledata, readable)
				if readable then
					return "x1.25 Walkspeed"
				elseif profiledata.Upgrades.Singles.FloatLikeAButterfly then
					return 1.25
				else
					return 1
				end
			end,
		},

		IntLikeABee = { --INTEGRATED
			Name = "Int Like A Bee",
			Description = "+50 damage per pickaxe swing for each research purchased, applied before any multipliers.",
			Cost = function()
				return 800000
			end,
			Value = function(profiledata, readable)
				if profiledata.Upgrades.Singles.IntLikeABee then
					if readable then
						return "+"..Shrt.BigNumberShortener(50*module.numberOfOwnedSingletons(profiledata)).." Damage"
					else
						return 50 * module.numberOfOwnedSingletons(profiledata)
					end
				else
					if readable then
						return "+"..Shrt.BigNumberShortener(50*(module.numberOfOwnedSingletons(profiledata)+1)).." Damage"
					else
						return 0
					end
				end
			end,
		},
		
		CajolingStones = { --INTEGRATED
			Name = "Cajoling Stones",
			Description = "Stones take up half as much space in your backpack.",
			Cost = function()
				return 7500000
			end,
			Value = function(profiledata, readable)
				if readable then
					return "x0.5 Rock Weight"
				elseif profiledata.Upgrades.Singles.CajolingStones then
					return true
				else
					return false
				end
			end,
		},

		SizeMatters = { --INTEGRATED
			Name = "Size Matters",
			Description = "Levels in backpack size also apply to pickaxe damage at no extra cost.",
			Cost = function()
				return 100000000 --one hundred million
			end,
			Value = function(profiledata, readable)
				if readable then
					return "+"..profiledata.Upgrades.General.Backpack.." Levels"
				elseif profiledata.Upgrades.Singles.SizeMatters then
					return profiledata.Upgrades.General.Backpack
				else
					return 0
				end
			end,
		},

		KuiperEffect = { --INTEGRATED
			Name = "The Kuiper Effect",
			Description = "+5 free levels of pickaxe speed for each research purchased, at no extra cost.",
			Cost = function()
				return 500
			end,
			Value = function(profiledata, readable)
				if profiledata.Upgrades.Singles.KuiperEffect then
					if readable then
						return "+"..5*module.numberOfOwnedSingletons(profiledata).." Levels"
					else
						return 5 * module.numberOfOwnedSingletons(profiledata)
					end
				else
					if readable then
						return "+"..5*(module.numberOfOwnedSingletons(profiledata)+1).." Levels"
					else
						return 0
					end
				end
			end,
		},

	},
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~FORGE~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	forge = {
		t1 = {
			Crusher = {
				Name = "Plate Crusher",
				Description = "The crusher's piston smashes ores into tiny bits so they can be separated from the rock, multiplying the ore's value.",
				LayoutOrder =  1,
				CameraPos = CFrame.new(223, 79, -82)*CFrame.Angles(math.rad(25), math.rad(180), 0),
				--ModelName = "t1Crusher",
				--Model = ReplicatedStorage.ForgeMachines.t1Crusher,
				Cost = function(profiledata)
					local cost = 0
					local level = profiledata.Upgrades.Forge.Crusher
					local multiplier = ( math.floor(level / 10) - 1 )
					if multiplier < 0 then
						multiplier = 0
					end
					multiplier = 8 ^ multiplier
					if level == 0 then
						cost = 1200
					else
						cost = 500 + ( multiplier * ( 100 + ( 5 * ( level ^ 1.3 ) ) ) )
					end
					return cost
				end,
				Max = "None",
				Value = function(profiledata, readable, nextLv)
					local level = profiledata.Upgrades.Forge.Crusher
					if nextLv then
						level += 1
					end
					local value = 0
					if level <= 10 then
						value = 1 + ( 0.1 * level )
					else
						value = 1.5 + ( 0.05 * level )
					end
					if readable ~= nil and readable then
						return "x"..DecShrt(value)
					else
						return value
					end
				end,
			},
			Screen = {
				Name = "Vibrating Screen",
				Description = "The screen separates ore pieces by size, adding a flat amount to each ore's value before any other calculations.",
				LayoutOrder =  2,
				CameraPos = CFrame.new(223, 79, -82)*CFrame.Angles(math.rad(25), math.rad(180), 0),
				--ModelName = "t1Screen",
				--Model = ReplicatedStorage.ForgeMachines.t1Screen,
				Cost = function(profiledata)
					local level = profiledata.Upgrades.Forge.Screen
					local cost = 0
					local multiplier = ( math.floor(level / 5) - 2 )
					if multiplier < 0 then
						multiplier = 0
					end
					multiplier = 10^multiplier
					cost = math.floor((2000*(level+1))*multiplier)
					return cost
				end,
				Max = 50,
				Value = function(profiledata, readable, nextLv)
					local level = profiledata.Upgrades.Forge.Screen
					if nextLv then
						level += 1
					end
					if readable ~= nil and readable then
						if level > 50 and nextLv then
							return "MAX"
						else
							return "+$"..Shrt.BigNumberShortener(level)
						end
					else
						return level
					end
				end,
			},
			FloatPool = {
				Name = "Flotation Pool",
				Description = "By separating crushed materials by buoyancy, there is a chance that an extra rock is added to your sell total for each non-rock item in your backpack.",
				LayoutOrder =  3,
				CameraPos = CFrame.new(223, 79, -82)*CFrame.Angles(math.rad(25), math.rad(180), 0),
				--ModelName = "t1FloatPool",
				--Model = ReplicatedStorage.ForgeMachines.t1FloatPool,
				Cost = function(profiledata)
					local level = profiledata.Upgrades.Forge.FloatPool
					local cost = 0
					local multiplier = math.floor(level / 5)
					multiplier = 5^multiplier
					cost = math.floor((2500*(level+1))*multiplier)
					return cost
				end,
				Max = 25,
				Value = function(profiledata, readable, nextLv)
					local level = profiledata.Upgrades.Forge.FloatPool
					if nextLv then
						level += 1
					end
					local value = level * 4
					if readable ~= nil and readable then
						if level > 25 and nextLv then
							return "MAX"
						else
							return Shrt.BigNumberShortener(level).."%"
						end
						
					else
						return value
					end
				end,
			},
		},
		t2 = {
			Separator = {
				Name = "Magnetic Separator",
				Description = "A large electromagnetic plate separates ores, giving each t2+ ore a chance to create an additional ore of equal or lesser value.",
				LayoutOrder =  1,
				CameraPos = CFrame.new(223, 79, -82)*CFrame.Angles(math.rad(25), math.rad(180), 0),
				--ModelName = "t2Separator",
				--Model = ReplicatedStorage.ForgeMachines.t2Separator,
				Cost = function(profiledata)
					local cost = 0
					local level = profiledata.Upgrades.Forge.Separator
					local multiplier1 = math.floor(level / 20)
					if multiplier1 < 0 then multiplier1 = 0 end
					multiplier1 = 100 ^ multiplier1
					local multiplier2 = 1.5 ^ level
					cost = 100000 * multiplier1 * multiplier2
					--100k, 150k, 225k, 337k, 506k
					--level 20 costs 222m. level 21 costs 22.2b
					return cost
				end,
				Max = "None",
				Value = function(profiledata, readable, nextLv)
					local level = profiledata.Upgrades.Forge.Separator
					if nextLv then
						level += 1
					end
					local value = level * 5
					if readable ~= nil and readable then
						return Shrt.BigNumberShortener(value).."%"
					else
						return value
					end
				end,
			},
			BlastFurnace = {
				Name = "Blast Furnace",
				Description = "A furnace whose airflow is above atmospheric pressure, this multiplies the value of all t2+ ore.",
				LayoutOrder =  2,
				CameraPos = CFrame.new(223, 79, -82)*CFrame.Angles(math.rad(25), math.rad(180), 0),
				--ModelName = "t2Separator",
				--Model = ReplicatedStorage.ForgeMachines.t2Separator,
				Cost = function(profiledata)
					local cost = 0
					local level = profiledata.Upgrades.Forge.BlastFurnace
					local multiplier1 = math.floor(level / 4)
					if multiplier1 < 0 then multiplier1 = 0 end
					multiplier1 = 4 ^ multiplier1
					cost = 25000 * (level+1) * multiplier1
					return cost
				end,
				Max = "None",
				Value = function(profiledata, readable, nextLv)
					local level = profiledata.Upgrades.Forge.BlastFurnace
					if nextLv then
						level += 1
					end
					local value = (level * 0.25) + 1
					if readable ~= nil and readable then
						return "x"..DecShrt(value)
					else
						return value
					end
				end,
			},
		},
	},
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~GENERAL~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	general = {
		PickLevel = {
			Name = "Pickaxe Level",
			Description = "The level of ores that your pickaxe can mine. Higher level ores gain access to more upgrade machines in The Forge, so mining them is more than worth it.",
			Category = "Tools",
			LayoutOrder =  1,
			Cost = function(profiledata)
				local level = profiledata.Upgrades.General.PickLevel
				local tabel = {
					100000,              --one hundred thousand
					10000000,            --ten million
					50000000000,         --fifty billion
					100000000000000000000--one hundred quintillion
				}
				return tabel[level]
			end,
			Max = 5,
			Value = function(profiledata, readable)
				if readable ~= nil and readable then
					return "Level "..profiledata.Upgrades.General.PickLevel
				else
					return profiledata.Upgrades.General.PickLevel
				end
			end,
		},
		
		Speed = {
			Name = "Pickaxe Speed",
			Description = "The speed at which your pickaxe swings. Without any other modifiers, the maximum value is 3.33 swings per second.",
			Category = "Tools",
			LayoutOrder =  3,
			Cost = function(profiledata)
				local level = profiledata.Upgrades.General.Speed
				local cost = 0
				if level <= 10.5 then
					cost = math.floor( ( 40 * level ) + 100 )
				elseif level >= 10.5 and level <= 26.5 then
					cost = math.floor( ( ( level - 8 ) ^ 3.1 ) + 525 )
				else
					cost = math.floor( ( ( level - 20.5 ) ^ 5 ) )
				end
				return cost
			end,
			Max = "None",
			Value = function(profiledata, readable)
				local level = profiledata.Upgrades.General.Speed
				level += module.upgradesTable.singles.KuiperEffect.Value(profiledata)
				local value = ( ( 0.96^level ) * (0.7/1) ) + 0.3
				value /= msdb.GetBonuses(profiledata.General.Level).PickSpeedMult
				if readable ~= nil and readable then
					local speedstring = string.format("%f", ( 1 / value ) )
					if string.len(speedstring) > 5 then
						speedstring = string.sub(speedstring,1,5)
					end
					return speedstring.."/s"
				else
					return value
				end
			end,
		},
		
		Damage = {
			Name = "Pickaxe Damage",
			Description = "The damage your pick does to ores every swing. There is no limit to this stat, so spend away.",
			Category = "Tools",
			LayoutOrder =  2,
			Cost = function(profiledata)
				local level = profiledata.Upgrades.General.Damage
				local cost = 0
				if level <= 25 then
					cost = math.floor( ( level ^ 2.2 ) + ( level + 4 ) )
				else
					cost = math.floor( ( level ^ 2.35 ) - 700 )
				end
				return cost
			end,
			Max = "None",
			Value = function(profiledata, readable)
				local level = profiledata.Upgrades.General.Damage
				level += module.upgradesTable.singles.SizeMatters.Value(profiledata)
				local value = 0
				if level <= 25 then
					value = math.ceil( ( ( level ^ 2.3 ) / 25 ) + ( level * 1.3 ) + 4 )
				else
					value = math.ceil( ( ( 0.3 * ( level ^ 2.4 ) ) / 7 ) + ( level * 4 ) - 95 )
				end
				value += module.upgradesTable.singles.KnowledgeIsPower.Value(profiledata)
				value += module.upgradesTable.singles.IntLikeABee.Value(profiledata)
				value *= msdb.GetBonuses(profiledata.General.Level).PickDamageMult
				value *= module.upgradesTable.ascension.APDamage.Value(profiledata)
				if readable ~= nil and readable then
					return Shrt.BigNumberShortener(value).." Per Hit"
				else
					return value
				end
			end,
		},
		
		----EQUIPMENT
		
		Backpack = {
			Name = "Backpack Size",
			Description = "The amount of ores you can carry in your backpack at once.",
			Category = "Equipment",
			LayoutOrder =  1,
			Cost = function(profiledata)
				local level = profiledata.Upgrades.General.Backpack
				local cost = 0
				cost = ( ( level + 1 ) ^ 2 ) + 50
				local levelsthing = math.ceil( ( level-19 ) / 10 )
				cost = math.floor( cost * ( 10 ^ levelsthing ) )
				return cost
			end,
			Max = "None",
			Value = function(profiledata, readable)
				local level = profiledata.Upgrades.General.Backpack
				local value = 0
				value = math.ceil( ( level * 2.5 ) + 10 )
				local bonuses = msdb.GetBonuses(profiledata.General.Level)
				value *= bonuses.BackpackMult
				value += bonuses.BackpackFlat
				value = math.ceil(value)
				if readable ~= nil and readable then
					return Shrt.BigNumberShortener(value).." Slots"
				else
					return value
				end
			end,
			GetInventoryValue = function(profiledata, inventory)
				local children = inventory:GetChildren()
				local number = 0
				for num, part in pairs(children) do
					if part.Name == "Rock" and profiledata.Upgrades.Singles.CajolingStones then
						number += math.ceil( part.Value / 2 ) --rocks take up half space if upgrade purchased
					else
						number += part.Value
					end
				end
				return number
			end,
		},
		
		Lantern = {
			Name = "Lantern Strength",
			Description = "Increases the radius of light around your character.",
			Category = "Equipment",
			LayoutOrder =  2,
			Cost = function(profiledata)
				local level = profiledata.Upgrades.General.Lantern
				return 250 * (2 ^ level)
			end,
			Max = 10,
			Value = function(profiledata, readable)
				local brightness = 0
				local brightnessVals = {
					1,--1
					0.9,--2
					0.8,--3
					0.7,--4
					0.6,--5
					0.5,--6
					0.45,--7
					0.4,--8
					0.35,--9
					0.3,--10
				}
				local level = profiledata.Upgrades.General.Lantern
				local value = level+5
				if level == 0 then
					value = 0
				end
				value *= module.upgradesTable.singles.LightOfMyMine.Value(profiledata)
				if level > 0 and level <= 10 then
					brightness = brightnessVals[level]
				else
					brightness = 0.3
				end
				if readable ~= nil and readable then
					return value.." Studs"
				else
					return {value, brightness}
				end
			end,
		},
	},
}

module.ascensionStuff = {
	totalSpentPoints = function(profiledata)
		local number = 0
		for _, value in pairs(module.upgradesTable.ascension) do
			local level = profiledata.Ascension[_]
			for i = level, 0, -1 do
				number += value.Cost(level)
			end
		end
	end,
	totalPoints = function(data)
		local ascensions
		if typeof(data) == "number" then ascensions = data
		else ascensions = data.General.Ascensions end
		if ascensions == 0 then
			return 0
		else
			return 10 * (2^(ascensions-1))
		end
	end,
}

module.SinglesByCost = {}
local throwawayArrayOne = {}
for _, value in pairs(module.upgradesTable.singles) do
	table.insert(throwawayArrayOne, value.Cost())
end
table.sort(throwawayArrayOne)
for _, value2 in ipairs(throwawayArrayOne) do
	for index, value in pairs(module.upgradesTable.singles) do
		if value.Cost() == value2 then
			table.insert(module.SinglesByCost, index)
		end
	end
end

return module