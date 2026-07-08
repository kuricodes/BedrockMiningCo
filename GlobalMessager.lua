--[[
This script, to describe it briefly, allows all the running servers in the game to share a single synced multiplier number.
When a player does something cool, like getting their millionth dollar or unboxing a super rare skin,
this script is invoked to tell all players in all servers that it happened, and raise the global multiplier.
The events have diminishing returns, with the multiplier never being able to go above 5x- in essence it's
way way way easier to get it to 2x versus getting it to 3x.
Over time the multiplier ticks down by 0.01 every two and a half minutes.
The way that the number is synced is through messagingservice and datastore access, with datastore reading cut down
to the absolute minimum possible- once on server start and then once every ten minutes after that.
Since the ticking down is predictable, all new servers calculate it independently using only the last value that was
written to the datastore, and the time at which that value was written. Because of this, even if there hasn't been
an update to the multiplier in a while, new servers will calculate the same number as all the other ones that exist
]]--

--SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local MessagingService = game:GetService("MessagingService")
local HttpService = game:GetService("HttpService")

--STUFF I NEED
local DataStore = game:GetService("DataStoreService"):GetDataStore("MilestoneSanityVal")
local ChatService = require(game:GetService("ServerScriptService"):WaitForChild("ChatServiceRunner").ChatService)

local OutboundEvent = ReplicatedStorage.MilestoneEvent
local MilestoneEvent = script.Parent.MilestoneEventServer

local remote = Instance.new("RemoteEvent", game.ReplicatedStorage)
remote.Name = "ServerMessage"

local SkinDB = require(ReplicatedStorage.SkinEverythingDatabase)
local pridirectory = SkinDB.GetDirectories()[1]
local secdirectory = SkinDB.GetDirectories()[2]
local SkinsArray = SkinDB.GetDirectories()[3]
local SetsArray = SkinDB.GetDirectories()[4]
local Rarities = SkinDB.Rarities

--CONVENIENT FUNCTIONS

local function shallowCopy(original) --copies a table/array/dict whatever
	local copy = {}
	for key, value in pairs(original) do
		copy[key] = value
	end
	return copy
end

local round = function(num) --rounds num down to 2 decimal places
	return math.floor(num * 100) / 100
end

--ARRAY RESOURCES

local defaultMessage = {
	playerName = "Replace Me",
	messageType = "MagicButton",
	valueType = 1,
	value = 10,
	skinX = 0,
	skinY = 0,
}

colors = {
	Basic = Color3.fromRGB(255,255,255),   --basic
	Gold = Color3.fromRGB(255, 255, 20),  --gold
	Boostium = Color3.fromRGB(0, 244, 130),   --Boostium
	Money = Color3.fromRGB(230, 220, 10),  --money
}

local MessageArray = {
	SkinUnbox =         {" just unboxed a ", colors.Basic},
	SetComplete =       {" just completed their ", colors.Gold},
	MagicButton =       {" just pressed the Magic Button!", colors.Basic},
	Boostium =          {" just mined some Boostium!", colors.Boostium},
	AdminAbuse =        {" just increased the ore price multiplier via admin abuse!", colors.Gold},
	Purchase =          {" just bought a booster increase for everyone!", colors.Boostium},
	Million =           {" just earned their millionth coin!", colors.Money},
	Billion =           {" just earned their billionth coin!", colors.Money},
	Trillion =          {" just earned their trillionth coin!", colors.Money},
	Quadrillion =       {" just earned their quadrillionth coin!", colors.Gold},
	Quintillion =       {" just earned their quintillionth coin!", colors.Gold},
	Septillion =        {" just earned their septillionth coin!", colors.Gold},
	Decillion =         {" just earned their decillionth coin!", colors.Gold},
	Quattuordecillion = {" just earned their quattuordecillionth coin!", colors.Gold},
}

--SCRIPT STARTS HERE

local function getMessage(ID, player, X, Y)
	local returnMessage = "Nothing yet"
	local returnColor = colors[1]
	if ID == "SkinUnbox" then --special case to build skin unbox message
		local skin = SkinsArray[X][Y]
		local Name = skin.Name
		local Rarity = Rarities[skin.Rarity]
		returnMessage = player..MessageArray.SkinUnbox[1]..Rarity.Name:upper().." ["..Name.."]!"
		returnColor = Rarity.Color --each rarity in the skin database has its own color
	elseif ID == "SetComplete" then
		local Set = SetsArray[X]
		local Name = Set.Name
		returnMessage = player..MessageArray.SetComplete[1]..Name.." set and has recieved a GOLDEN version!"
		returnColor = MessageArray.SetComplete[2]
	else
		returnMessage = player..MessageArray[ID][1]
		returnColor = MessageArray[ID][2]
	end
	return {message = returnMessage, color = returnColor}
end

local function SendSystemMessageToAllSpeakers(player, id, x, y)
	local msg = getMessage(id, player, x, y)
	remote:FireAllClients(msg.message, msg.color, Enum.Font.GothamSemibold, Enum.FontSize.Size10)
end

local topic = "MultiplierEvent" --for the global events

local function GetMultFromPoints(value)
	return round( 1 + ( ( 4 * value ) / ( value + 1500 ) ) )
end

local function GetPointsFromMultMin(value)
	return math.floor( -( ( 1500 * ( value - 1 ) ) / ( value - 5 ) ) ) --the minimum possible amount of points for the multiplier value
end
local function GetPointsFromMultMiddle(value)
	local MinValue = ( -( 1500 * ( value - 1 ) ) / ( value - 5 ) )
	local MidValue = ( -( ( 1500 * ( value - 0.99 ) ) / ( value - 4.99 ) ) + MinValue ) / 2
	return math.floor(MidValue)
end --the middle possible number of points for each multiplier value


--STORE MULTIPLIER AS POINTS VALUE. JUST BIND MULTIPLIER TO POINTS CHANGE

--[[
To explain further, the way that the points are stored is in two parts
First, the main part is an integer value in serverstorage. this is formatted in a way i refer to as "points"
It can go up forever with no limit as players make it go up
The second one is a number in replicated storage that is a more "readable" face to the backend points count
It is calculated on a curve from 1 to 5, the higher the points the closer it gets to 5
It never meets or exceeds 5 though.
By default if i reference the number I'm referring to the serverstorage points amount
]]--

local MultPoints = ServerStorage.MultPoints
local MultRep = ReplicatedStorage.Multiplier
MultPoints.Changed:Connect(function(Value)
	MultRep.Value = GetMultFromPoints(Value)
end)

local function TickReduce(mult, amount)
	mult = math.clamp(mult - ( 0.01 * amount ), 1, 10) --it cant be more than 5 normally but im gonna increase it for events and stuff
	return math.ceil(GetPointsFromMultMiddle(mult))
end

local function ValueIfCyclesSinceTime(LastValue, LastTime) --run this event on server start. insert datastore value
	local CyclesElapsed = math.floor( ( os.time() - LastTime ) / 150) --number of times 2.5 minutes have passed
	return TickReduce(GetMultFromPoints(LastValue), CyclesElapsed) --sets point multiplier value to adjusted value
end

local MessageConnection

local function subscribe()
	local subscribeConnection
	while true do
		local subscribeSuccess, connection = pcall(function()
			print("attempting to subscribe")
			return MessagingService:SubscribeAsync(topic, function(message)
				print("recieving global message")
				local timesent = message.Sent
				local data = message.Data
				SendSystemMessageToAllSpeakers(data.playerName, data.messageType, data.skinX, data.skinY)
				if( data.valueType == 1 ) then
					MultPoints.Value = MultPoints.Value + data.value
				elseif( data.valueType == 2 ) then
					MultPoints.Value = GetPointsFromMultMiddle(data.value)
				end
			end)
		end)
		if subscribeSuccess then
			print("subscribed")
			MessageConnection = connection
			break
		else
			SendSystemMessageToAllSpeakers("Global Multiplier connection failed. Retrying in 30 seconds...")
			wait(30)
		end
	end
end

--NOW SUBSCRIBE TO THE TOPIC
subscribe()

local sanityValue = {0, 643252}

local function datastoreFunction(value) --input increment amount in points
	local success, updatedName, keyInfo = pcall(function()
		return DataStore:UpdateAsync("PointsPlusTime", function(currentValue, keyInfo) 
			print("The value being written to the datastore is "..value.." at the os clock time of "..os.time())
			return {MultPoints.Value+value, os.time()}
		end)
	end)
end

local function datastoreFunctionMult(value) --input increment amount in frontend multiplier amount
	local success, updatedName, keyInfo = pcall(function()
		return DataStore:UpdateAsync("PointsPlusTime", function(currentValue, keyInfo) 
			return {GetPointsFromMultMin(value), os.time()}
		end)
	end)
end

local function SendMessage(dataAttached) --sends out the global message signal, attempts 3 times max
	
	if dataAttached.valueType == 1 then
		datastoreFunction(dataAttached.value)
	elseif dataAttached.valueType == 2 then
		datastoreFunctionMult(dataAttached.value)
	end
	print("datastore set, attempting to send global message")
	local publishSuccess, publishResult = pcall(function()
		print("Attempt 1")
		MessagingService:PublishAsync(topic, dataAttached)
	end)
	if not publishSuccess then
		local publishSuccess2, publishResult2 = pcall(function()
			print("Attempt 2")
			MessagingService:PublishAsync(topic, dataAttached)
		end)
		if not publishSuccess2 then
			local publishSuccess3, publishResult3 = pcall(function()
				print("Attempt 3")
				MessagingService:PublishAsync(topic, dataAttached)
			end)
			if not publishSuccess3 then
				print("Message sending failed after 3 attempts.")
			end
		end
	end
end

local function readDatastore() --calls datastore up to 3 times
	local success, sanityValues = pcall(function()
		return DataStore:GetAsync("PointsPlusTime")
	end)
	if success then
		print("DataStore read successfully.")
		if(sanityValues == nil) then
			sanityValues = {0, 1654653091} --0 points at the time of coding as a fallback value
		end
	else
		print("DataStore read failed.")
		sanityValues = {0, 1654653091} --0 points at the time of coding as a fallback value
	end
	return sanityValues
end

local Players = game:GetService("Players")

local debounce = true

MilestoneEvent.Event:Connect(function(message)
	if not debounce then
		while debounce == false do
			wait() --hacky but it'll do
		end
	end
	debounce = false
	SendMessage(message)
	debounce = true
end)

local function ReadDatastoreValueAndSet(Sanity)
	local Values = readDatastore()
	local SetValue = Values[1] --the value in points (as opposed to the actual decimal multiplier value)
	local SetTime = Values[2] --the time the value was set (unix)
	local adjusted = ValueIfCyclesSinceTime(SetValue, SetTime)
	if not Sanity then
		MultPoints.Value = adjusted --this part is run on server start
		print(MultPoints.Value)
	else
		local diff = math.abs(GetMultFromPoints(MultPoints.Value) - GetMultFromPoints(adjusted))
		if( diff > 0.02 ) then
			MultPoints.Value = adjusted
			--adjusts value to new calculated one if the multiplier difference is more than 0.01 off in either direction
			--since anything beyond a 0.01 margin of error can only be because the server missed a message
			--this part should be run every few minutes to make sure it didn't miss anything
		end
	end
end

ReadDatastoreValueAndSet(false)

local Coro = coroutine.wrap(function()
	local sanitycheck = 1
	while wait(150) do --two and a half minutes
		MultPoints.Value = TickReduce(GetMultFromPoints(MultPoints.Value), 1) --this reduces the number miltiplier by 0.01
		if sanitycheck == 4 then
			ReadDatastoreValueAndSet(true) --runs the sanity check every fourth cycle
			sanitycheck = 1           --so the datastore gets read every ten minutes
		else
			sanitycheck+= 1
		end
		print(MultPoints.Value)
	end
end)
Coro()