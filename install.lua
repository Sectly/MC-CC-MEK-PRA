-- // MC-CC-MEK-PRA V0.1.4
-- // Author: Sectly (https://github.com/Sectly)
-- // Paid Re-Actor, An ComputerCraft Program That Gives You An Easy To Read And Use GUI To Control And Monitor An Mekanism Fission Reactor
-- // License: MIT, This Script And All Other Parts Of This Program Is Under The MIT License There Should Be A Copy Included In Your Download Else See: https://github.com/Sectly/MC-CC-MEK-PRA/blob/main/LICENSE

print("Thinking...")

local git = "https://raw.githubusercontent.com/Sectly/MC-CC-MEK-PRA/main/git.lua"

function clone(url, dir)
	if fs.exists(dir) then
		fs.delete(dir)
	end

	shell.run("wget", "run", git, url, dir)
end

clone("https://github.com/Sectly/MC-CC-MEK-PRA", "pra")

shell.run("clear")
textutils.slowPrint("Downloaded Paid Re-Actor to /pra")
textutils.slowPrint("Creating startup file...")

local file = fs.open("/startup.lua", "w")

if file then
	file.write('shell.run("/pra/run.lua")')
	file.close()
else
    print("Error: Could not create startup script.")

	return nil
end

textutils.slowPrint("Attempting to run /pra/run.lua...")

sleep(1)

shell.run("clear")
shell.run("/pra/run.lua")

-- // MC-CC-MEK-PRA V0.1.4
-- // Author: Sectly (https://github.com/Sectly)