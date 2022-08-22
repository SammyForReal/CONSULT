if not (lOS and LevelOS and lUtils) then
    error("This launcher is only available for LevelOS!")
end

-- Setup splashscreen window
local nX,nY = LevelOS.self.window.win.getPosition()
local nW,nH = 32,12
local nNativeW,nNativeH = lOS.wAll.getSize()
LevelOS.setWin(math.floor(nNativeW/2-16),math.floor(nNativeH/2-6), nW,nH, "borderless")

-- Variables
local ccstrs = require("cc.strings")
local sPath = fs.getDir(shell.getRunningProgram())
local sGithub = {
    ["api"]="https://api.github.com/repos/1turtle/consult/releases/latest",
    ["latest"]="https://github.com/1Turtle/consult/releases/latest/download/cosu.lua"
}
local sVersion

---Searches for the current version of consult in the header
---@param path string Path to consult
---@return string version Current version
local function getVersion(path)
    local ver = ""
    local f = fs.open(path, 'r')
    for i=1,155 do
      local line = f.readLine()
      if line:find("sVersion") then
        ver = loadstring(line.." return sVersion")()
        break
      end
    end
    f.close()
    return ver
end

---Renders a limg file (very basic)
---@param path any
---@return boolean
local function image(path)
    local x,y = term.getCursorPos()
    local f = fs.open(path, 'r')
    local img = textutils.unserialise(f.readAll())
    f.close()
    if type(img) ~= "table" then return false end

    -- Render bimg file
    for _,line in pairs(img[1]) do
        term.setCursorPos(x,y)
        term.blit(line[1], line[2], line[3])
        y = y+1
    end

    return true
end

---Draws the UI once.
---@param sPath string Path to installation (where images are stored)
local function UI(sPath)
    term.setBackgroundColor(colors.blue)
    term.setTextColor(colors.white)
    term.clear()

    -- Title
    term.setCursorPos(2,3)
    if not image(fs.combine(sPath,"title.limg")) then
        term.write("CONSULT")
    end

    -- Logo
    paintutils.drawFilledBox(nW-5,2,nW-1,6,colors.white)
    term.setCursorPos(nW-4,3)
    image(fs.combine(sPath,"icon.limg"))

    -- Version
    sVersion = getVersion(fs.combine(sPath,"cosu.lua"))
    if not sVersion then
        sVersion = "v0.0.0"
    end
    term.setCursorPos(nW-#sVersion,nH)
    term.setBackgroundColor(colors.blue)
    term.write(sVersion)
end

local function statusMsg(msg)
    msg = tostring(msg)
    term.setCursorPos(2,nH-1)
    term.setTextColor(colors.lightGray)
    term.clearLine()
    term.write(msg)
end

---Checks for aupdate
local function update()
    local bSkip = false
    -- Update
    parallel.waitForAll(
        function()
            statusMsg("Check for Updates")
            for i=1,3 do
                if not bSkip then sleep(0.75) end
                term.write('.')
            end
        end,
        function()
            local newV
            if http then
                -- Check
                local gitAPI=http.get(sGithub.api)
                if gitAPI and gitAPI.getResponseCode()==200 then
                    local tGitContent = textutils.unserialiseJSON(gitAPI.readAll())
                    if tGitContent.tag_name ~= sVersion then
                        newV = tGitContent.tag_name
                    end
                    gitAPI.close()
                else
                    bSkip = true
                    statusMsg("Reached gitAPI limit; Skipping.")
                end
                -- Get
                if newV then
                    bSkip = true
                    sleep()
                    statusMsg("Updating to: "..newV)
                    sleep(0.2)
                
                    local gitAPI=http.get(sGithub.latest)
                    if gitAPI and gitAPI.getResponseCode()==200 then
                        local tGitContent = gitAPI.readAll()
                        local file = fs.open(fs.combine(sPath,"cosu.lua"),'w')
                        file.flush()
                        file.write(tGitContent)
                        file.close()
                        gitAPI.close()
                        statusMsg("Done updating!")
                        term.setCursorPos(nW-#newV,nH)
                        term.setTextColor(colors.white)
                        term.write(newV)
                        sleep(0.75)
                    end
                end
            end
            skip = true
        end
    )
end

local function errPop(msg)
    local tmp = ccstrs.wrap(msg, 51-7)
    local msg = ""
    for i=1,#tmp do
        msg = msg..tostring(tmp[i])..'\n'
    end
    lUtils.popup("Fatal Error", msg, 51-6,#tmp+6, {"Ok"}, true)
end

---------------------------------------------------
UI(sPath)

-- Setup Args
local tArgs = { ... }
if #tArgs == 0 or tArgs[1] == "" then
    update()
end

-- Running program (and send error)
LevelOS.setWin(math.floor(nNativeW/2-25),math.floor(nNativeH/2-9), 51,19, "windowed")
local func,msg = loadfile(fs.combine(sPath, "cosu.lua"), "t", _ENV)
if not func then errPop(msg) end
local success,unexpectedMsg = pcall(func, table.unpack(tArgs))
if not success then errPop(unexpectedMsg) end