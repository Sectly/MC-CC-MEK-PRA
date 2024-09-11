-- // MC-CC-MEK-PRA V0.0.1
-- // Author: Sectly (https://github.com/Sectly)
-- // Paid Re-Actor, An ComputerCraft Program That Gives You An Easy To Read And Use GUI To Control And Monitor An Mekanism Fission Reactor

local cobalt = dofile("/cobalt/init.lua")

local NETWORK = {
    REACTOR = peripheral.find("fissionReactorLogicAdapter"),
    TURBINE = peripheral.find("turbineValve"),
}

local GLOBAL = {
    STATE = 0; -- // Current State

    DATA = { -- // Live Data From Connected Peripherals
        ON_SIGNAL = redstone.getInput("top"),

		REACTOR = {
            ONLINE = NETWORK.REACTOR.getStatus(),
            BURN_RATE = NETWORK.REACTOR.getBurnRate(),
            MAX_BURN_RATE = NETWORK.REACTOR.getMaxBurnRate(),
            TEMPERATURE = NETWORK.REACTOR.getTemperature(),
            DAMAGE = NETWORK.REACTOR.getDamagePercent(),
            COOLANT = NETWORK.REACTOR.getCoolantFilledPercentage(),
            WASTE = NETWORK.REACTOR.getWasteFilledPercentage(),
            FUEL_LEVEL = NETWORK.REACTOR.getFuelFilledPercentage(),
        };

        TURBINE = {
            ENERGY = NETWORK.TURBINE.getEnergyFilledPercentage(),
        }
    };

    CONFIG = { -- // Config File, On First Startup You Will See An Step-By-Step Guided Config Screen (Stored In pra/config.json)
        IS_SETUP = false; -- // Is Setup Check (Don't Touch This)
        LOCKED = false; -- // On Emergency Lock The System, Can Only Be Unlocked Via Screen Using The Lock/Unlock Button (Don't Touch This)

        REACTOR = {
            MAXIMUM_TEMPERATURE = {
                VALUE = 745;
                SOLID = true;
                INFO = "The Maximum Temperature, If It Goes Past This An Automatic SCRAM (Emergency) Will Be Called."
            };
            MINIMUM_HEALTH = {
                VALUE = 0.10;
                SOLID = false;
                INFO = "The Minimum Health, If It Goes Below This An Automatic SCRAM (Emergency) Will Be Called."
            };
            MINIMUM_COOLANT = {
                VALUE = 0.95;
                SOLID = false;
                INFO = "The Minimum Coolant Level, If It Goes Below This An Automatic SCRAM (Emergency) Will Be Called."
            };
            MINIMUM_FUEL_LEVEL = {
                VALUE = 0.10;
                SOLID = false;
                INFO = "The Minimum Fuel Level, If It Goes Below This An Automatic Stop Will Be Called."
            };
            WASTE_LEVEL_LIMIT = {
                VALUE = 0.90;
                SOLID = false;
                INFO = "The Waste Level Limit, If It Goes Above This An Automatic Stop Will Be Called."
            };
        };

        TURBINE = {
            TURBINE_ENERGY_LEVEL_LIMIT = {
                VALUE = 0.90;
                SOLID = false;
                INFO = "The Turbine Energy Level Limit, If It Goes Above This An Automatic Stop Will Be Called."
            };
        };
    }
}

-- // List Of States
local STATES = {
    BOOTING = 0;
	RUNNING = 1;
	STOPPED = 2;
	EMERGENCY = 3;
	ERROR = 4;
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
        print("Error: The file "..FileName.." does not exist!")

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

local function AllChecksMet()
	for Num, Check in ipairs(CHECKS) do
        local OK, Name, Emergency = Check()

		if not OK then
			table.insert(FailedChecks, {
                Name = Name,
            })

            if Emergency then
                GLOBAL.STATE = STATES.EMERGENCY
            else
                GLOBAL.STATE = STATES.STOPPED
            end

            pcall(NETWORK.REACTOR.scram)
		end
	end

    if (#FailedChecks > 0) then
        return false
    end

	return GLOBAL.STATE ~= STATES.RUNNING or GLOBAL.DATA.REACTOR.ONLINE;
end

-- // Update Data
local function UpdateData()
    GLOBAL.DATA = {
        ON_SIGNAL = redstone.getInput("top"),

        REACTOR = {
            ONLINE = NETWORK.REACTOR.getStatus(),
            BURN_RATE = NETWORK.REACTOR.getBurnRate(),
            MAX_BURN_RATE = NETWORK.REACTOR.getMaxBurnRate(),
            TEMPERATURE = NETWORK.REACTOR.getTemperature(),
            DAMAGE = NETWORK.REACTOR.getDamagePercent(),
            COOLANT = NETWORK.REACTOR.getCoolantFilledPercentage(),
            WASTE = NETWORK.REACTOR.getWasteFilledPercentage(),
            FUEL_LEVEL = NETWORK.REACTOR.getFuelFilledPercentage(),
        };

        TURBINE = {
            ENERGY = NETWORK.TURBINE.getEnergyFilledPercentage(),
        }
    };
end

local function UpdateTerminal()
    function round(number)
        return math.floor(number + 0.5)
    end
    
    function drawValue(name, value, color, offset)
        cobalt.graphics.setColor("white")
        cobalt.graphics.print(name, 2 + offset, 16)
        cobalt.graphics.rect("line", 1 + offset, 1, 5, 13)
        cobalt.graphics.setColor(color)
    
        local length = round(value * 10);
        cobalt.graphics.rect("fill", 2 + offset, 13 - length, 2, length)
    end
    
    function cobalt.draw()
        drawValue("Fuel", NETWORK.REACTOR.getFuelFilledPercentage(), "green", 0)
        drawValue("Waste", NETWORK.REACTOR.getWasteFilledPercentage(), "orange", 7)
        drawValue("Water", NETWORK.REACTOR.getCoolantFilledPercentage(), "blue", 14)
        drawValue("Steam", NETWORK.REACTOR.getHeatedCoolantFilledPercentage(), "gray", 21)
    end
    
    cobalt.init();
end

local function colored(text, fg, bg)
	term.setTextColor(fg or colors.white)
	term.setBackgroundColor(bg or colors.black)
	term.write(text)
end

local function CreateSection(name, x, y, w, h)
	for row = 1, h do
		term.setCursorPos(x, y + row - 1)
		local char = (row == 1 or row == h) and "\127" or " "
		colored("\127" .. string.rep(char, w - 2) .. "\127", colors.gray)
	end

	term.setCursorPos(x + 2, y)
	colored(" " .. name .. " ")

	return window.create(term.current(), x + 2, y + 2, w - 4, h - 4)
end

local WINDOWS = {
    INFO = CreateSection("INFORMATION", 2, 2, term.getSize() - 2, 7),
    CHECKS = CreateSection("SAFETY RULES", 2, 10, term.getSize() - 2, 10),
}

local function UpdateScreen()
    local prev_term = term.redirect(WINDOWS.INFO)

	term.clear()
	term.setCursorPos(1, 1)

	if state == STATES.UNKNOWN then
		colored("ERROR RETRIEVING DATA", colors.red)
		return
	end

	colored("REACTOR: ")
	colored(GLOBAL.DATA.REACTOR.ONLINE and "ON " or "OFF", GLOBAL.DATA.REACTOR.ONLINE and colors.green or colors.red)
	colored("  STATUS: ")
	colored(GLOBAL.DATA.ON_SIGNAL and "ON " or "OFF", GLOBAL.DATA.ON_SIGNAL and colors.green or colors.red)
	colored("  R. LIMIT: ")
	colored(string.format("%4.1f", GLOBAL.DATA.REACTOR.BURN_RATE), colors.blue)
	colored("/", colors.lightGray)
	colored(string.format("%4.1f", GLOBAL.DATA.REACTOR.MAX_BURN_RATE), colors.blue)

	term.setCursorPos(1, 3)

	colored("STATUS: ")
	if GLOBAL.STATE == STATES.BOOTING or STATE == STATES.STOPPED then
		colored("READY, Lets Rock & Roll!", colors.blue)
	elseif GLOBAL.STATE == STATES.RUNNING then
		colored("RUNNING, All Good!", colors.green)
	elseif GLOBAL.STATE == STATES.EMERGENCY and not AllChecksMet then
		colored("EMERGENCY STOP, Safety Check Violated!", colors.red)
	elseif GLOBAL.STATE == STATES.EMERGENCY then
		colored("EMERGENCY STOP, Reset Required!", colors.red)
	end

	term.redirect(prev_term)

    local prev_term = term.redirect(WINDOWS.CHECKS)

	term.clear()

    local emergency_reasons = {}

	if GLOBAL.STATE ~= STATES.EMERGENCY then
		emergency_reasons = {}
	end

	for i, check in ipairs(CHECKS) do
		local ok, text = check()
		term.setCursorPos(1, i)
		if ok and not emergency_reasons[i] then
			colored("[  ✓  ] ", colors.green)
			colored(text, colors.lightGray)
		else
			colored("[ ❌ ] ", colors.red)
			colored(text, colors.red)
			emergency_reasons[i] = true
		end
	end

	term.redirect(prev_term)
end

local function LockSystem()
    print("SYSTEM LOCKED. Enter 'unlock' to unlock the system.")
    print("It only locks up after an SCRAM, Please double check the reactor before starting it again.")
    
    while true do
        local input = read()
        if input == "unlock" then
            GLOBAL.CONFIG.LOCKED = false
            pcall(NETWORK.REACTOR.scram)
            GLOBAL.STATE = STATES.STOPPED
            SaveFile(GLOBAL.CONFIG, "pra/config.json")
            print("System unlocked.")
            break
        else
            print("Invalid command. System remains locked.")
        end
    end
end

-- // Always Active Once Setup Step Is Done
local function DefaultLoop()
    if not pcall(UpdateData) then
        GLOBAL.STATE = STATES.ERROR
    end

    if GLOBAL.DATA.ON_SIGNAL then
        pcall(NETWORK.REACTOR.activate)

        GLOBAL.STATE = STATES.RUNNING
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
        GLOBAL.STATE = STATES.ERROR
    end

    if not AllChecksMet() then
        if GLOBAL.STATE == STATES.RUNNING then
            GLOBAL.STATE = STATES.STOPPED
        end

        pcall(NETWORK.REACTOR.scram)
    end

    if GLOBAL.STATE == STATES.EMERGENCY then
        GLOBAL.CONFIG.LOCKED = true

        SaveFile(GLOBAL.CONFIG, "pra/config.json")

        redstone.setOutput("left", true)
    else
        redstone.setOutput("left", false)
    end

    if GLOBAL.STATE == STATES.ERROR then
        print("ERROR. Seems something ain't right, Double check everything then reboot system.")
    
        while true do
            local input = read()
            print("ERROR. Seems something ain't right, Double check everything then reboot system.")
        end
    end

    if GLOBAL.CONFIG.LOCKED then
        pcall(NETWORK.REACTOR.scram)

        LockSystem()
    end

    --pcall(UpdateTerminal)
    pcall(UpdateScreen)

    sleep()

    return DefaultLoop()
end

-- // Setup Screen
local function DoSetup()
    shell.run("clear")
    print("Welcome To The Paid Re-Actor V0.0.1 Setup Wizard.")

    print("")

    -- // Ask for Maximum Temperature
    print("Set The Maximum Temperature For The Reactor (Default: 745):")
    local maxTemp = tonumber(read())
    if not maxTemp then maxTemp = 745 end

    -- // Ask for Minimum Health
    print("Set The Minimum Health Percentage (Default: 0.10):")
    local minHealth = tonumber(read())
    if not minHealth then minHealth = 0.10 end

    -- // Ask for Minimum Coolant Level
    print("Set The Minimum Coolant Percentage (Default: 0.95):")
    local minCoolant = tonumber(read())
    if not minCoolant then minCoolant = 0.95 end

    -- // Ask for Minimum Fuel Level
    print("Set The Minimum Fuel Level Percentage (Default: 0.10):")
    local minFuel = tonumber(read())
    if not minFuel then minFuel = 0.10 end

    -- // Ask for Waste Level Limit
    print("Set The Waste Level Limit Percentage (Default: 0.90):")
    local wasteLimit = tonumber(read())
    if not wasteLimit then wasteLimit = 0.90 end

    -- // Ask for Turbine Energy Level Limit
    print("Set The Turbine Energy Level Limit Percentage (Default: 0.90):")
    local turbineLimit = tonumber(read())
    if not turbineLimit then turbineLimit = 0.90 end

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
        return DoSetup();
    end

    local ConfigFile = ReadFile("pra/config.json")

    if ConfigFile and ConfigFile ~= nil and ConfigFile.IS_SETUP then
        GLOBAL.CONFIG = ConfigFile or GLOBAL.CONFIG;

        print("Config Valid, Adding Checks...")

        AddCheck("REACTOR TEMPERATURE", function()
	        return GLOBAL.DATA.REACTOR.TEMPERATURE <= GLOBAL.CONFIG.REACTOR.MAXIMUM_TEMPERATURE.VALUE, string.format("%3dK", math.ceil(GLOBAL.DATA.REACTOR.TEMPERATURE)), true
        end)

        AddCheck("REACTOR HEALTH", function()
	        return GLOBAL.DATA.REACTOR.DAMAGE <= GLOBAL.CONFIG.REACTOR.MINIMUM_HEALTH.VALUE, string.format("%3dK", math.ceil(GLOBAL.DATA.REACTOR.DAMAGE * 100)), true
        end)

        AddCheck("REACTOR COOLANT LEVEL", function()
	        return GLOBAL.DATA.REACTOR.COOLANT >= GLOBAL.CONFIG.REACTOR.MINIMUM_COOLANT.VALUE, string.format("%3dK", math.ceil(GLOBAL.DATA.REACTOR.COOLANT * 100)), true
        end)

        AddCheck("REACTOR WASTE LEVEL", function()
	        return GLOBAL.DATA.REACTOR.WASTE <= GLOBAL.CONFIG.REACTOR.WASTE_LEVEL_LIMIT.VALUE, string.format("%3dK", math.ceil(GLOBAL.DATA.REACTOR.WASTE * 100)), false
        end)

        AddCheck("REACTOR FUEL LEVEL", function()
	        return GLOBAL.DATA.REACTOR.FUEL_LEVEL >= GLOBAL.CONFIG.REACTOR.MINIMUM_FUEL_LEVEL.VALUE, string.format("%3dK", math.ceil(GLOBAL.DATA.REACTOR.FUEL_LEVEL * 100)), false
        end)

        AddCheck("TURBINE ENERGY LEVEL", function()
	        return GLOBAL.DATA.TURBINE.ENERGY >= GLOBAL.CONFIG.TURBINE.TURBINE_ENERGY_LEVEL_LIMIT.VALUE, string.format("%3dK", math.ceil(GLOBAL.DATA.TURBINE.ENERGY * 100)), false
        end)

        AddCheck("LOCK STATUS", function()
            local Text = "Unlocked!";

            if GLOBAL.CONFIG.LOCKED then
                Text = "Locked!";
            end

	        return not GLOBAL.CONFIG.LOCKED, Text, true
        end)

        sleep()

        print("Starting...")

        sleep(3)

        shell.run("clear")

        pcall(NETWORK.REACTOR.scram)
        GLOBAL.STATE = STATES.STOPPED

        DefaultLoop();
    else
        DoSetup()
    end
end

local monitor = peripheral.wrap("right")
MirrorToMonitor(monitor)

shell.run("clear")
textutils.slowPrint("Booting...")

Init();