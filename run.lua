-- // MC-CC-MEK-PRA V0.1.4
-- // Author: Sectly (https://github.com/Sectly)
-- // Paid Re-Actor, An ComputerCraft Program That Gives You An Easy To Read And Use GUI To Control And Monitor An Mekanism Fission Reactor
-- // License: MIT, This Script And All Other Parts Of This Program Is Under The MIT License There Should Be A Copy Included In Your Download Else See: https://github.com/Sectly/MC-CC-MEK-PRA/blob/main/LICENSE

local NETWORK = {
	REACTOR = peripheral.find("fissionReactorLogicAdapter") or nil,
	TURBINE = peripheral.find("turbineValve") or nil,
}

local GLOBAL = {
	STATE = 0, -- // Current State

	DATA = { -- // Live Data From Connected Peripherals
		NOT_CONNECTED = true,

		ON_SIGNAL = redstone.getInput("top") or false,

		REACTOR = {
			ONLINE = 0,
			BURN_RATE = 0,
			MAX_BURN_RATE = 0,
			TEMPERATURE = 0,
			DAMAGE = 0,
			COOLANT = 0,
			WASTE = 0,
			FUEL_LEVEL = 0,
		},

		TURBINE = {
			ENERGY = 0,
		},
	},

	CONFIG = { -- // Config File, On First Startup You Will See An Step-By-Step Guided Config Screen (Stored In pra/config.json)
		IS_SETUP = false, -- // Is Setup Check (Don't Touch This)
		LOCKED = false, -- // On Emergency Lock The System, Can Only Be Unlocked Via Screen Using The Lock/Unlock Button (Don't Touch This)

		REACTOR = {
			MAXIMUM_TEMPERATURE = {
				VALUE = 745,
				SOLID = true,
				INFO = "The Maximum Temperature, If It Goes Past This An Automatic SCRAM (Emergency) Will Be Called.",
			},
			MINIMUM_HEALTH = {
				VALUE = 0.15,
				SOLID = false,
				INFO = "The Minimum Health, If It Goes Below This An Automatic SCRAM (Emergency) Will Be Called.",
			},
			MINIMUM_COOLANT = {
				VALUE = 0.95,
				SOLID = false,
				INFO = "The Minimum Coolant Level, If It Goes Below This An Automatic SCRAM (Emergency) Will Be Called.",
			},
			MINIMUM_FUEL_LEVEL = {
				VALUE = 0.10,
				SOLID = false,
				INFO = "The Minimum Fuel Level, If It Goes Below This An Automatic Stop Will Be Called.",
			},
			WASTE_LEVEL_LIMIT = {
				VALUE = 85,
				SOLID = false,
				INFO = "The Waste Level Limit, If It Goes Above This An Automatic Stop Will Be Called.",
			},
		},

		TURBINE = {
			TURBINE_ENERGY_LEVEL_LIMIT = {
				VALUE = 0.90,
				SOLID = false,
				INFO = "The Turbine Energy Level Limit, If It Goes Above This An Automatic Stop Will Be Called.",
			},
		},
	},
}

-- // List Of States
local STATES = {
	BOOTING = 0,
	RUNNING = 1,
	STOPPED = 2,
	EMERGENCY = 3,
	ERROR = 4,
}

-- // List Of Checks
local CHECKS = {}

local function AddCheck(Name, CheckFunction)
	table.insert(CHECKS, function()
		local Success, Check_Met, Value, Emergency = pcall(CheckFunction)

		if Success then
			return Check_Met, string.format("%s (%s)", Name, Value), Emergency
		else
			return false, Name, Emergency
		end
	end)
end

-- // Save File To Computer
local function SaveFile(Data, FileName)
	local Directory = fs.getDir(FileName)

	if not fs.exists(Directory) then
		fs.makeDir(Directory)
	end

	local File = fs.open(FileName, "w")

	if File then
		local JSONData = textutils.serializeJSON(Data)

		File.write(JSONData)
		File.close()
	else
		print("Error: Could not save file " .. FileName)
	end
end

-- // Read File On Computer
local function ReadFile(FileName)
	if not fs.exists(FileName) then
		print("Error: The file " .. FileName .. " does not exist!")

		return nil
	end

	local File = fs.open(FileName, "r")

	if File then
		local JSONData = File.readAll()

		File.close()

		return textutils.unserializeJSON(JSONData)
	else
		print("Error: Could not open file " .. FileName)

		return nil
	end
end

-- // Check If All Checks Are Met
local FailedChecks = {}

-- Helper function to check if a specific violation exists in FailedChecks
local function isViolated(checkName)
	for _, check in ipairs(FailedChecks) do
		if string.match(string.lower(check.Name), string.lower(checkName)) then
			return true
		end
	end
	return false
end

local function AllChecksMet()
	local DidACheckFail = false

	for Num, Check in ipairs(CHECKS) do
		local OK, Name, Emergency = Check()

		if not OK then
			DidACheckFail = true

			if #FailedChecks <= 50 then
				if #FailedChecks <= 0 then
					table.insert(FailedChecks, {
						Name = Name,
					})
				elseif not isViolated(Name) then
					table.insert(FailedChecks, {
						Name = Name,
					})
				end
			end

			if Emergency then
				GLOBAL.STATE = STATES.EMERGENCY
			else
				GLOBAL.STATE = STATES.STOPPED
			end

			pcall(NETWORK.REACTOR.scram)
		end
	end

	if #FailedChecks > 0 then
		return false,
			#FailedChecks > 0
				and (GLOBAL.STATE == STATES.EMERGENCY or GLOBAL.STATE == STATES.STOPPED)
				and GLOBAL.DATA.ON_SIGNAL
				and not DidACheckFail
	end

	return GLOBAL.STATE ~= STATES.RUNNING or GLOBAL.DATA.REACTOR.ONLINE
end

-- // Update Data
local function UpdateData()
	if not (NETWORK and NETWORK.REACTOR and NETWORK.TURBINE) then
		NETWORK = {
			REACTOR = peripheral.find("fissionReactorLogicAdapter") or nil,
			TURBINE = peripheral.find("turbineValve") or nil,
		}
	end

	if NETWORK and NETWORK.REACTOR and NETWORK.TURBINE then
		GLOBAL.DATA = {
			NOT_CONNECTED = false,

			ON_SIGNAL = redstone.getInput("top") or false,

			REACTOR = {
				ONLINE = NETWORK.REACTOR.getStatus(),
				BURN_RATE = NETWORK.REACTOR.getBurnRate(),
				MAX_BURN_RATE = NETWORK.REACTOR.getMaxBurnRate(),
				TEMPERATURE = NETWORK.REACTOR.getTemperature(),
				DAMAGE = NETWORK.REACTOR.getDamagePercent(),
				COOLANT = NETWORK.REACTOR.getCoolantFilledPercentage(),
				WASTE = NETWORK.REACTOR.getWasteFilledPercentage(),
				FUEL_LEVEL = NETWORK.REACTOR.getFuelFilledPercentage(),
			},

			TURBINE = {
				ENERGY = NETWORK.TURBINE.getEnergyFilledPercentage(),
			},
		}
	else
		GLOBAL.DATA = {
			NOT_CONNECTED = true,

			ON_SIGNAL = false,

			REACTOR = {
				ONLINE = false,
				BURN_RATE = -1,
				MAX_BURN_RATE = -1,
				TEMPERATURE = -1,
				DAMAGE = -1,
				COOLANT = -1,
				WASTE = -1,
				FUEL_LEVEL = -1,
			},

			TURBINE = {
				ENERGY = -1,
			},
		}
	end
end

-- Function to display reactor status
local function drawReactorStatus(state, locked)
	term.setCursorPos(2, 2)
	term.setBackgroundColor(colors.gray)
	term.setTextColor(colors.white)
	term.clearLine()

	if GLOBAL.DATA.NOT_CONNECTED then
		term.setTextColor(colors.orange)
		term.write("Reactor Status: NOT CONNECTED")
	elseif state == STATES.RUNNING then
		term.setTextColor(colors.green)
		term.write("Reactor Status: ONLINE")
	elseif state == STATES.EMERGENCY then
		term.setTextColor(colors.red)
		term.write("Reactor Status: SCRAM (Emergency)")
	elseif state == STATES.ERROR then
		term.setTextColor(colors.red)
		term.write("Reactor Status: ERROR")
	elseif state == STATES.BOOTING then
		term.setTextColor(colors.red)
		term.write("Reactor Status: BOOTING")
	elseif locked then
		term.setTextColor(colors.red)
		term.write("Reactor Status: LOCKED")
	elseif GLOBAL.CONFIG.IS_SETUP == false then
		term.setTextColor(colors.orange)
		term.write("Reactor Status: SETUP REQUIRED")
	else
		term.setTextColor(colors.red)
		term.write("Reactor Status: OFFLINE")
	end

	term.setTextColor(colors.white)
	term.write(" | Paid Re-Actor V0.1.4 By: Sectly")
end

-- Function to display reactor data
local function drawReactorData(data)
	if not (NETWORK and NETWORK.REACTOR and NETWORK.TURBINE) or GLOBAL.DATA.NOT_CONNECTED then
		return nil
	end

	-- Temperature
	term.setCursorPos(2, 4)
	term.setBackgroundColor(colors.black)
	term.setTextColor(colors.white)
	term.write("Temperature: " .. math.floor(data.REACTOR.TEMPERATURE) .. "K")

	if isViolated("REACTOR TEMPERATURE") then
		term.setTextColor(colors.yellow)
		term.write(" (Violated)")
	end

	-- Coolant Level
	term.setCursorPos(2, 6)
	term.setTextColor(colors.white)
	term.write("Coolant Level: " .. math.floor(data.REACTOR.COOLANT * 100) .. "%")

	if isViolated("REACTOR COOLANT LEVEL") then
		term.setTextColor(colors.yellow)
		term.write(" (Violated)")
	end

	-- Fuel Level
	term.setCursorPos(2, 8)
	term.setTextColor(colors.white)
	term.write("Fuel Level: " .. math.floor(data.REACTOR.FUEL_LEVEL * 100) .. "%")

	if isViolated("REACTOR FUEL LEVEL") then
		term.setTextColor(colors.yellow)
		term.write(" (Violated)")
	end

	-- Waste Level
	term.setCursorPos(2, 10)
	term.setTextColor(colors.white)
	term.write("Waste Level: " .. math.floor(data.REACTOR.WASTE * 100) .. "%")

	if isViolated("REACTOR WASTE LEVEL") then
		term.setTextColor(colors.yellow)
		term.write(" (Violated)")
	end

	-- Turbine Energy Level
	term.setCursorPos(2, 12)
	term.setTextColor(colors.white)
	term.write("Turbine Energy: " .. math.floor(data.TURBINE.ENERGY * 100) .. "%")

	if isViolated("TURBINE ENERGY LEVEL") then
		term.setTextColor(colors.yellow)
		term.write(" (Violated)")
	end
end

-- Function to display errors/warnings
local function drawErrors(failedChecks, UpdateCallback)
	if #failedChecks > 0 then
		if UpdateCallback then
			pcall(UpdateCallback)
		end

		term.setCursorPos(2, 14)
		term.setBackgroundColor(colors.red)
		term.setTextColor(colors.white)
		term.clearLine()
		term.write("ERROR: Reactor Condition(s) Violated!")
	else
		if GLOBAL.DATA.NOT_CONNECTED then
			if UpdateCallback then
				pcall(UpdateCallback)
			end

			term.setCursorPos(2, 14)
			term.setBackgroundColor(colors.red)
			term.setTextColor(colors.white)
			term.clearLine()
			term.write("ERROR: Reactor And/Or Turbine Not Found On Network!")

			term.setCursorPos(2, 16)
			term.setBackgroundColor(colors.red)
			term.setTextColor(colors.white)
			term.clearLine()
			term.write("NOTE: System Will Auto-Reboot Once Issue Has Been Fixed!")
		else
			term.setCursorPos(2, 14)
			term.clearLine()
		end
	end
end

local function UpdateScreen()
	local data = GLOBAL.DATA
	local failedChecks = FailedChecks or {}

	term.clear()
	drawReactorStatus(GLOBAL.STATE, GLOBAL.CONFIG.LOCKED)
	drawReactorData(data)
	drawErrors(failedChecks, UpdateScreen)
end

local function LockSystem()
	print(" ")
	print("SYSTEM LOCKED. Enter 'unlock' to unlock the system.")
	print("It only locks up after an SCRAM, Please double check the reactor before starting it again.")
	print(" ")

	while true do
		local input = read()
		if input == "unlock" then
			GLOBAL.CONFIG.LOCKED = false
			pcall(NETWORK.REACTOR.scram)
			GLOBAL.STATE = STATES.STOPPED
			SaveFile(GLOBAL.CONFIG, "pra/config.json")
			print("System unlocked, Rebooting...")
			sleep(1)
			os.reboot()
			break
		else
			print("Invalid command. System remains locked.")
		end
	end
end

function ValidateConnection()
	NETWORK = {
		REACTOR = peripheral.find("fissionReactorLogicAdapter") or nil,
		TURBINE = peripheral.find("turbineValve") or nil,
	}

	if not (NETWORK and NETWORK.REACTOR and NETWORK.TURBINE) then
		GLOBAL.DATA.NOT_CONNECTED = true
	end

	if GLOBAL.DATA.NOT_CONNECTED then
		GLOBAL.STATE = STATES.ERROR

		ShouldStart = false

		pcall(UpdateScreen)

		while true do
			pcall(UpdateData)

			if (NETWORK and NETWORK.REACTOR) then
				pcall(NETWORK.REACTOR.scram)
			end

			sleep(5)

			if (NETWORK and NETWORK.REACTOR and NETWORK.TURBINE) and not GLOBAL.DATA.NOT_CONNECTED then
				os.reboot()
			else
				sleep()
			end
		end
	end
end

-- // Always Active Once Setup Step Is Done
local function DefaultLoop()
	local ShouldStart = false

	if not pcall(UpdateData) then
		GLOBAL.STATE = STATES.ERROR

		ShouldStart = false
	end

	pcall(UpdateScreen)

	ValidateConnection()

	pcall(UpdateScreen)

	pcall(function()
		if GLOBAL.DATA.ON_SIGNAL then
			ShouldStart = true
		else
			pcall(NETWORK.REACTOR.scram)

			GLOBAL.STATE = STATES.STOPPED
		end

		if GLOBAL.DATA.REACTOR.ONLINE then
			GLOBAL.STATE = STATES.RUNNING
		else
			GLOBAL.STATE = STATES.STOPPED
		end

		if not GLOBAL.DATA.TURBINE.ENERGY then
			ShouldStart = false

			GLOBAL.STATE = STATES.ERROR
		end

		local EverythingOk, TryRefeshing = AllChecksMet()

		if not EverythingOk then
			if GLOBAL.STATE == STATES.RUNNING then
				GLOBAL.STATE = STATES.STOPPED
			end

			ShouldStart = false

			pcall(NETWORK.REACTOR.scram)
		end

		if TryRefeshing then
			ShouldStart = false

			pcall(NETWORK.REACTOR.scram)
			GLOBAL.STATE = STATES.STOPPED

			print("Violating Ended. Refreshing system, Rebooting...")
			sleep(1)
			os.reboot()
		end
	end)

	ValidateConnection()

	if GLOBAL.STATE == STATES.EMERGENCY then
		ShouldStart = false

		GLOBAL.CONFIG.LOCKED = true

		SaveFile(GLOBAL.CONFIG, "pra/config.json")

		redstone.setOutput("left", true)
	else
		redstone.setOutput("left", false)
	end

	if GLOBAL.STATE == STATES.ERROR then
		ShouldStart = false

		while true do
			print(" ")
			print("ERROR. Seems something ain't right, Double check everything then reboot system.")
			print("Type 'reboot' to reboot system.")
			print(" ")

			local input = read()

			if input == "reboot" then
				print("Rebooting...")

				sleep(3)

				os.reboot()
			end
		end
	end

	ValidateConnection()

	if ShouldStart then
		pcall(NETWORK.REACTOR.activate)

		GLOBAL.STATE = STATES.RUNNING
	end

	pcall(UpdateScreen)

	if GLOBAL.CONFIG.LOCKED then
		ValidateConnection()

		pcall(NETWORK.REACTOR.scram)

		LockSystem()
	end

	pcall(UpdateScreen)

	ValidateConnection()

	if
		#FailedChecks > 0
		and (GLOBAL.STATE ~= STATES.ERROR and GLOBAL.STATE ~= STATES.EMERGENCY and GLOBAL.STATE ~= STATES.STOPPED)
	then
		pcall(NETWORK.REACTOR.scram)
		GLOBAL.STATE = STATES.STOPPED
		print("Phantom State Ended. Refreshing system, Rebooting...")
		sleep(1)
		os.reboot()
	end

	sleep()

	return DefaultLoop()
end

-- // Setup Screen
local function DoSetup()
	shell.run("clear")
	print("Welcome To The Paid Re-Actor V0.1.4 Setup Wizard.")

	print("")

	-- // Ask for Maximum Temperature
	print("Set The Maximum Temperature For The Reactor (Default: 745):")
	local maxTemp = tonumber(read())
	if not maxTemp then
		maxTemp = 745
	end

	-- // Ask for Minimum Health
	print("Set The Minimum Health Percentage (Default: 0.15):")
	local minHealth = tonumber(read())
	if not minHealth then
		minHealth = 0.15
	end

	-- // Ask for Minimum Coolant Level
	print("Set The Minimum Coolant Percentage (Default: 0.95):")
	local minCoolant = tonumber(read())
	if not minCoolant then
		minCoolant = 0.95
	end

	-- // Ask for Minimum Fuel Level
	print("Set The Minimum Fuel Level Percentage (Default: 0.10):")
	local minFuel = tonumber(read())
	if not minFuel then
		minFuel = 0.10
	end

	-- // Ask for Waste Level Limit
	print("Set The Waste Level Limit Percentage (Default: 0.85):")
	local wasteLimit = tonumber(read())
	if not wasteLimit then
		wasteLimit = 0.85
	end

	-- // Ask for Turbine Energy Level Limit
	print("Set The Turbine Energy Level Limit Percentage (Default: 0.90):")
	local turbineLimit = tonumber(read())
	if not turbineLimit then
		turbineLimit = 0.90
	end

	-- // Create and store the configuration
	GLOBAL.CONFIG.REACTOR.MAXIMUM_TEMPERATURE.VALUE = maxTemp
	GLOBAL.CONFIG.REACTOR.MINIMUM_HEALTH.VALUE = minHealth
	GLOBAL.CONFIG.REACTOR.MINIMUM_COOLANT.VALUE = minCoolant
	GLOBAL.CONFIG.REACTOR.MINIMUM_FUEL_LEVEL.VALUE = minFuel
	GLOBAL.CONFIG.REACTOR.WASTE_LEVEL_LIMIT.VALUE = wasteLimit
	GLOBAL.CONFIG.TURBINE.TURBINE_ENERGY_LEVEL_LIMIT.VALUE = turbineLimit

	GLOBAL.CONFIG.IS_SETUP = true

	-- // Save configuration
	SaveFile(GLOBAL.CONFIG, "pra/config.json")
	print("")
	print("Setup complete! Configuration saved.")

	sleep()

	print("Rebooting...")

	sleep(3)

	os.reboot()
end

-- // Mirror Output
function MirrorToMonitor(monitor)
	local originalTerm = term.current() -- Store the original terminal

	local mirroredTerm = {}

	-- Copy all terminal functions (write, setCursorPos, etc.)
	for key, func in pairs(originalTerm) do
		mirroredTerm[key] = func
	end

	-- Override write to send to both terminal and monitor
	mirroredTerm.write = function(text)
		originalTerm.write(text)
		monitor.write(text)
	end

	mirroredTerm.blit = function(text, textColor, backgroundColor)
		originalTerm.blit(text, textColor, backgroundColor)
		monitor.blit(text, textColor, backgroundColor)
	end

	mirroredTerm.clear = function()
		originalTerm.clear()
		monitor.clear()
	end

	mirroredTerm.setCursorPos = function(x, y)
		originalTerm.setCursorPos(x, y)
		monitor.setCursorPos(x, y)
	end

	mirroredTerm.clearLine = function()
		originalTerm.clearLine()
		monitor.clearLine()
	end

	mirroredTerm.setTextColor = function(color)
		originalTerm.setTextColor(color)
		monitor.setTextColor(color)
	end

	mirroredTerm.setBackgroundColor = function(color)
		originalTerm.setBackgroundColor(color)
		monitor.setBackgroundColor(color)
	end

	mirroredTerm.scroll = function(n)
		originalTerm.scroll(n)
		monitor.scroll(n)
	end

	-- Redirect the terminal to the mirrored terminal
	term.redirect(mirroredTerm)
end

-- // On Load
local function Init()
	if not fs.exists("pra/config.json") then
		return DoSetup()
	end

	local ConfigFile = ReadFile("pra/config.json")

	if ConfigFile and ConfigFile ~= nil and ConfigFile.IS_SETUP then
		GLOBAL.CONFIG = ConfigFile or GLOBAL.CONFIG

		print("Config Valid, Adding Checks...")

		AddCheck("REACTOR TEMPERATURE", function()
			return GLOBAL.DATA.REACTOR.TEMPERATURE <= GLOBAL.CONFIG.REACTOR.MAXIMUM_TEMPERATURE.VALUE,
				string.format("%3dK", math.ceil(GLOBAL.DATA.REACTOR.TEMPERATURE)),
				true
		end)

		AddCheck("REACTOR HEALTH", function()
			return GLOBAL.DATA.REACTOR.DAMAGE <= GLOBAL.CONFIG.REACTOR.MINIMUM_HEALTH.VALUE,
				string.format("%3dK", math.ceil(GLOBAL.DATA.REACTOR.DAMAGE * 100)),
				true
		end)

		AddCheck("REACTOR COOLANT LEVEL", function()
			return GLOBAL.DATA.REACTOR.COOLANT >= GLOBAL.CONFIG.REACTOR.MINIMUM_COOLANT.VALUE,
				string.format("%3dK", math.ceil(GLOBAL.DATA.REACTOR.COOLANT * 100)),
				true
		end)

		AddCheck("REACTOR WASTE LEVEL", function()
			return GLOBAL.DATA.REACTOR.WASTE <= GLOBAL.CONFIG.REACTOR.WASTE_LEVEL_LIMIT.VALUE,
				string.format("%3dK", math.ceil(GLOBAL.DATA.REACTOR.WASTE * 100)),
				false
		end)

		AddCheck("REACTOR FUEL LEVEL", function()
			return GLOBAL.DATA.REACTOR.FUEL_LEVEL >= GLOBAL.CONFIG.REACTOR.MINIMUM_FUEL_LEVEL.VALUE,
				string.format("%3dK", math.ceil(GLOBAL.DATA.REACTOR.FUEL_LEVEL * 100)),
				false
		end)

		AddCheck("TURBINE ENERGY LEVEL", function()
			return GLOBAL.DATA.TURBINE.ENERGY <= GLOBAL.CONFIG.TURBINE.TURBINE_ENERGY_LEVEL_LIMIT.VALUE,
				string.format("%3dK", math.ceil(GLOBAL.DATA.TURBINE.ENERGY * 100)),
				false
		end)

		AddCheck("LOCK STATUS", function()
			local Text = "Unlocked!"

			if GLOBAL.CONFIG.LOCKED then
				Text = "Locked!"
			end

			return not GLOBAL.CONFIG.LOCKED, Text, true
		end)

		sleep()

		print("Starting...")

		pcall(UpdateData)

		sleep(3)

		shell.run("clear")

		if NETWORK and NETWORK.REACTOR and NETWORK.TURBINE then
			pcall(NETWORK.REACTOR.scram)
		end

		GLOBAL.STATE = STATES.STOPPED

		DefaultLoop()
	else
		DoSetup()
	end
end

local monitor = peripheral.wrap("right")
MirrorToMonitor(monitor)

shell.run("clear")
term.setBackgroundColor(colors.black)
term.setTextColor(colors.green)
textutils.slowPrint("Booting...")

Init()

-- // MC-CC-MEK-PRA V0.1.4
-- // Author: Sectly (https://github.com/Sectly)