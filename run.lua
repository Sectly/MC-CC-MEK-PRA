-- // MC-CC-MEK-PRA V0.0.1
-- // Author: Sectly (https://github.com/Sectly)
-- // Paid Re-Actor, An ComputerCraft Program That Gives You An Easy To Read And Use GUI To Control And Monitor An Mekanism Fission Reactor

local Cobalt = dofile("/cobalt/init.lua")

local GLOBAL = {
    STATE = -1; -- // Current State

    DATA = { -- // Live Data From Connected Peripherals
        ON_SIGNAL = redstone.getInput("top"),

		REACTOR = {
            ONLINE = = reactor.getStatus(),
            BURN_RATE = reactor.getBurnRate(),
            MAX_BURN_RATE = reactor.getMaxBurnRate(),
            TEMPERATURE = reactor.getTemperature(),
            DAMAGE = reactor.getDamagePercent(),
            COOLANT = reactor.getCoolantFilledPercentage(),
            WASTE = reactor.getWasteFilledPercentage(),
            FUEL_LEVEL = reactor.getFuelFilledPercentage(),
        };

        TURBINE = {
            ENERGY = turbine.getEnergyFilledPercentage(),
        }
    };

    CONFIG = { -- // Config File, On First Startup You Will See An Step-By-Step Guided Config Screen (Stored In pra/config.json)
        IS_SETUP = false; -- // Is Setup Check (Don't Touch This)
        LOCKED = false; -- // On Emergency Lock The System, Can Only Be Unlocked Via Screen Using The Lock/Unlock Button (Don't Touch This)

        COMPUTER = {
            NAME = "Paid Re-Actor"; -- // Name To Display In Console And On Screen
            FORCE_LOCK_EXECUTION = true; -- // Prevent From Terminating The Program Or Exiting The GUI/Console
        }

        ALARM = {
            EMIT_REDSTONE_ON_EMERGENCY = true; -- // Emit An Redstone Signal When On Emergency State
        },

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
    BOOTING = -1;
	IDLE = 0;
	RUNNING = 1;
	STOPPED = 2;
	EMERGENCY = 3;
	ERROR = 4;
}

-- // List Of Checks
local CHECKS = {}

local function AddCheck(Name, CheckFunction)
	table.insert(CHECKS, function()
		local Success, Check_Met, Value, SCRAM_On_Fail = pcall(CheckFunction)

		if Success then
			return Check_Met, string.format("%s (%s)", Name, Value), SCRAM_On_Fail
		else
			return false, Name, SCRAM_On_Fail
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
local function AllChecksMet()
	for Num, Check in ipairs(CHECKS) do
		if not Check() then
			return false
		end
	end

	return STATE ~= STATES.RUNNING or GLOBAL.DATA.REACTOR.ONLINE;
end

-- // Update Data
local function UpdateData()
    GLOBAL.DATA = {
        ON_SIGNAL = redstone.getInput("top"),

        REACTOR = {
            ONLINE = = reactor.getStatus(),
            BURN_RATE = reactor.getBurnRate(),
            MAX_BURN_RATE = reactor.getMaxBurnRate(),
            TEMPERATURE = reactor.getTemperature(),
            DAMAGE = reactor.getDamagePercent(),
            COOLANT = reactor.getCoolantFilledPercentage(),
            WASTE = reactor.getWasteFilledPercentage(),
            FUEL_LEVEL = reactor.getFuelFilledPercentage(),
        };

        TURBINE = {
            ENERGY = turbine.getEnergyFilledPercentage(),
        }
    };
end

-- Function to mirror the terminal to both the screen and a 2x2 monitor setup
local function createMirroredTerminal()
    -- Get the monitor peripheral (assuming it's on the left side)
    local monitor = peripheral.find("monitor")
    
    if monitor then
        -- Clear the monitor and set up the text scale
        monitor.setTextScale(0.5)
        monitor.clear()

        -- Create a "multishell" to mirror the output to both terminal and monitor
        local originalTerm = term.current()  -- Store the original terminal (computer's terminal)

        local function redirectToBoth()
            local object = {}

            function object.write(text)
                originalTerm.write(text)
                monitor.write(text)
            end

            function object.clear()
                originalTerm.clear()
                monitor.clear()
            end

            function object.setCursorPos(x, y)
                originalTerm.setCursorPos(x, y)
                monitor.setCursorPos(x, y)
            end

            function object.getCursorPos()
                return originalTerm.getCursorPos()
            end

            function object.setTextColor(color)
                originalTerm.setTextColor(color)
                monitor.setTextColor(color)
            end

            function object.setBackgroundColor(color)
                originalTerm.setBackgroundColor(color)
                monitor.setBackgroundColor(color)
            end

            function object.clearLine()
                originalTerm.clearLine()
                monitor.clearLine()
            end

            function object.scroll(n)
                originalTerm.scroll(n)
                monitor.scroll(n)
            end

            return object
        end

        -- Redirect output to both the terminal and monitor
        term.redirect(redirectToBoth())
    else
        print("Error: No monitor found.")
    end
end

-- Function to draw the main screen on both terminal and monitor
local function DrawScreen()
    -- Draws the information to both terminal and monitor
    term.clear()
    term.setCursorPos(1, 1)

    if state == STATES.UNKNOWN then
        colored("ERROR RETRIEVING DATA", colors.red)
        return
    end

    -- Display reactor and lever status
    colored("REACTOR: ")
    colored(data.reactor_on and "ON " or "OFF", data.reactor_on and colors.green or colors.red)
    colored("  LEVER: ")
    colored(data.lever_on and "ON " or "OFF", data.lever_on and colors.green or colors.red)
    colored("  R. LIMIT: ")
    colored(string.format("%4.1f", data.reactor_burn_rate), colors.blue)
    colored("/", colors.lightGray)
    colored(string.format("%4.1f", data.reactor_max_burn_rate), colors.blue)

    term.setCursorPos(1, 3)

    -- Display reactor status
    colored("STATUS: ")
    if state == STATES.READY then
        colored("READY, flip lever to start", colors.blue)
    elseif state == STATES.RUNNING then
        colored("RUNNING, flip lever to stop", colors.green)
    elseif state == STATES.ESTOP and not all_rules_met() then
        colored("EMERGENCY STOP, safety rules violated", colors.red)
    elseif state == STATES.ESTOP then
        colored("EMERGENCY STOP, toggle lever to reset", colors.red)
    end
end

-- Function to update and display the safety rules
local function DrawRules()
    term.clear()
    for i, rule in ipairs(rules) do
        local ok, text = rule()
        term.setCursorPos(1, i + 1)
        if ok then
            colored("[  OK  ] ", colors.green)
            colored(text, colors.lightGray)
        else
            colored("[ FAIL ] ", colors.red)
            colored(text, colors.red)
        end
    end
end

-- Main loop to update the screen and rules
local function UpdateScreen()
    while true do
        DrawScreen()
        DrawRules()

        sleep(1)
    end
end

-- // Always Active Once Setup Step Is Done
local function DefaultLoop()
    UpdateData()

    sleep()

    return DefaultLoop()
end

-- // Setup Screen
local function DoSetup()
    -- Variables for storing the entered data
    local currentStep = 1
    local configSteps = {}
    local enteredValues = {}

    -- Default config settings (adjusted during setup)
    local defaultConfig = {
        REACTOR = {
            MAXIMUM_TEMPERATURE = { VALUE = 745, INFO = "Maximum temperature in Kelvin" },
            MINIMUM_HEALTH = { VALUE = 0.10, INFO = "Minimum reactor health (Percentage)" },
            MINIMUM_COOLANT = { VALUE = 0.95, INFO = "Minimum coolant level (Percentage)" },
            MINIMUM_FUEL_LEVEL = { VALUE = 0.10, INFO = "Minimum fuel level (Percentage)" },
            WASTE_LEVEL_LIMIT = { VALUE = 0.90, INFO = "Maximum waste level (Percentage)" },
        },
        TURBINE = {
            TURBINE_ENERGY_LEVEL_LIMIT = { VALUE = 0.90, INFO = "Maximum turbine energy level (Percentage)" }
        }
    }

    -- Function to save config file
    local function SaveConfig(config)
        SaveFile(config, "pra/config.json")
    end

    -- Function to draw the setup screen
    local function drawSetupScreen()
        cobalt.graphics.clear()
        cobalt.graphics.print("Reactor Configuration Setup", 5, 2)
        
        -- Display current step information
        local currentConfigStep = configSteps[currentStep]
        cobalt.graphics.print(currentConfigStep.INFO, 5, 5)
        
        -- Display entered value or prompt for entry
        local enteredValue = enteredValues[currentConfigStep.key] or ""
        cobalt.graphics.print("Enter value: " .. enteredValue, 5, 7)
        
        -- Navigation hints
        cobalt.graphics.print("Press * to confirm, # to go back", 5, 9)
    end

    -- Function to handle key input during setup
    local function handleKeyPress(key)
        local currentConfigStep = configSteps[currentStep]
        
        if key == "*" then
            -- Confirm the current value and move to the next step
            if enteredValues[currentConfigStep.key] then
                defaultConfig[currentConfigStep.category][currentConfigStep.key].VALUE = tonumber(enteredValues[currentConfigStep.key])
                currentStep = currentStep + 1
            end
            
            -- Check if all steps are completed
            if currentStep > #configSteps then
                SaveConfig(defaultConfig)
                print("Setup complete! Configuration saved.")

                -- Exit the setup process and continue with the main program
                return true  -- Exits the setup loop
            end
            
        elseif key == "#" then
            -- Backspace (remove last character)
            enteredValues[currentConfigStep.key] = enteredValues[currentConfigStep.key]:sub(1, -2)
        elseif tonumber(key) then
            -- Append digit to the entered value
            enteredValues[currentConfigStep.key] = (enteredValues[currentConfigStep.key] or "") .. key
        end
        
        -- Redraw the screen
        drawSetupScreen()
    end

    -- Initialize configuration steps
    local function initConfigSteps()
        configSteps = {
            { category = "REACTOR", key = "MAXIMUM_TEMPERATURE", INFO = "Set maximum reactor temperature (K)" },
            { category = "REACTOR", key = "MINIMUM_HEALTH", INFO = "Set minimum reactor health (%)" },
            { category = "REACTOR", key = "MINIMUM_COOLANT", INFO = "Set minimum coolant level (%)" },
            { category = "REACTOR", key = "MINIMUM_FUEL_LEVEL", INFO = "Set minimum fuel level (%)" },
            { category = "REACTOR", key = "WASTE_LEVEL_LIMIT", INFO = "Set maximum waste level (%)" },
            { category = "TURBINE", key = "TURBINE_ENERGY_LEVEL_LIMIT", INFO = "Set maximum turbine energy level (%)" }
        }
    end

    -- Start setup
    initConfigSteps()

    -- Main loop for handling input
    while true do
        cobalt.draw = drawSetupScreen
        cobalt.keypressed = handleKeyPress
        cobalt.initLoop()

        -- Exit setup once completed
        if handleKeyPress("*") == true then
            break
        end
    end

    print("Robooting...")

    sleep(3)

    os.reboot()
end

-- // On Load
local function Init()
    local Task = coroutine.create(DefaultLoop)
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

        sleep(1)

        coroutine.resume(Task)

        -- Initialize the mirrored terminal
        createMirroredTerminal()

        -- Start the main loop
        parallel.waitForAny(UpdateScreen, function()
            os.pullEventRaw("terminate")
        end)
    else
        DoSetup()
    end
end

shell.run("clear")
textutils.slowPrint("Booting...")

Init();