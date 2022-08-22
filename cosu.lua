--[[ +++ Configurable +++ ]]
local cosuConf = {}
cosuConf.tKeyboard = {
    ["up"]          = keys.up,
    ["down"]        = keys.down,
    ["left"]        = keys.left,
    ["right"]       = keys.right,
    ["tab"]         = keys.tab,
    ["delete"]      = keys.delete,
    ["backspace"]   = keys.backspace,
    ["enter"]       = keys.enter,

    ["F_Help"]      = keys.f1,
    ["F_SpChar"]    = keys.f7,
    ["F_Run"]       = keys.f5,
    ["F_NewShell"]  = keys.f4,
    ["CTRL"] = {
        { "NewFile", keys.n },
        { "SaveAs", { keys.s, keys.leftShift } },
        { "Save", keys.s },
    }
}
cosuConf.bCursorIsBlock = false
cosuConf.cAccentColor = colors.blue
cosuConf.bDoubleClickButton = false
cosuConf.nTabSpace = 4 --[[ Normaly 4 spaces. ]]
cosuConf.bJumpAtEndToBegin = true
cosuConf.bShadows = true
cosuConf.tPalette = {
    true,
    ["black"]     = 0x171421,
    ["blue"]      = 0x2A7BDE,
    ["brown"]     = 0xA2734C,
    ["cyan"]      = 0x2AA1B3,
    ["gray"]      = 0x5E5C64,
    ["green"]     = 0x26A269,
    ["lightBlue"] = 0x33C7DE,
    ["lightGray"] = 0xD0CFCC,
    ["lime"]      = 0x33D17A,
    ["magenta"]   = 0xC061CB,
    ["orange"]    = 0xE9AD0C,
    ["pink"]      = 0xF66151,
    ["purple"]    = 0xA347BA,
    ["red"]       = 0xC01C28,
    ["white"]     = 0xFFFFFF,
    ["yellow"]    = 0xF3F03E
}
--[[ Color palette for .lua files ]]
local colorMatch = { }
colorMatch["popupBG"]=colors.lightGray
colorMatch["popupFrame"]=colors.gray
colorMatch["popupFont"]=colors.black
colorMatch["cAccentText"]=colors.lightGray
if term.isColor() then
    colorMatch["bg"] = colors.black
    colorMatch["bracket"] = colors.lightGray
    colorMatch["comment"] = colors.gray
    colorMatch["func"] = colors.orange
    colorMatch["keyword"] = colors.red
    colorMatch["number"] = colors.magenta
    colorMatch["operator"] = colors.cyan
    colorMatch["string"] = colors.green
    colorMatch["special"] = colors.yellow
    colorMatch["text"] = colors.white
    colorMatch["positive"] = colors.lime
    colorMatch["negative"] = colors.red
else
    cosuConf.cAccentColor = colors.gray
    colorMatch["bg"] = colors.black
    colorMatch["bracket"] = colors.gray
    colorMatch["comment"] = colors.gray
    colorMatch["func"] = colors.white
    colorMatch["keyword"] = colors.white
    colorMatch["number"] = colors.lightGray
    colorMatch["operator"] = colors.lightGray
    colorMatch["string"] = colors.lightGray
    colorMatch["special"] = colors.white
    colorMatch["text"] = colors.white
    colorMatch["positive"] = colors.white
    colorMatch["negative"] = colors.lightGray
end


--[[ +++ Program variables (no touching!) +++ ]]
local nTerm=term.current()
local term=nTerm
local loadAPIVirtual
local tMultibleStrings = {0,0}
--[[ .lua syntax ]]
local tKeywords = {
    ["and"] = true,
    ["break"] = true,
    ["do"] = true,
    ["else"] = true,
    ["elseif"] = true,
    ["end"] = true,
    ["for"] = true,
    ["function"] = true,
    ["if"] = true,
    ["in"] = true,
    ["local"] = true,
    ["nil"] = true,
    ["not"] = true,
    ["or"] = true,
    ["repeat"] = true,
    ["require"] = true,
    ["return"] = true,
    ["then"] = true,
    ["until"] = true,
    ["while"] = true,
}
local tPatterns = {
    { "^%-%-.*", colorMatch["comment"] },
    { "^\"\"", colorMatch["string"] },
    { "^\".-[^\\]\"", colorMatch["string"] },
    { "^\'\'", colorMatch["string"] },
    { "^\'.-[^\\]\'", colorMatch["string"] },
    { "^%[%[%]%]", colorMatch["string"] },
    { "^%[%[.-[^\\]%]%]", colorMatch["string"] },
    { "^[\127\162\163\165\169\174\182\181\177\183\186\188\189\190\215\247@]+", colorMatch["special"] },
    { "^[%d][xA-Fa-f.%d#]+", colorMatch["number"] },
    { "^[%d]+", colorMatch["number"] },
    { "^[,{}%[%]%(%)]", colorMatch["bracket"] },
    { "^[!%/\\:~<>=%*%+%-%%]+", colorMatch["operator"] },
    { "^true", colorMatch["number"] },
    { "^false", colorMatch["number"] },
    { "^[%w_%.]+", function(match, after, _, nLine)
        if tKeywords[match] then
            return colorMatch["keyword"]
        elseif after:sub(2,2) == "(" then
            return colorMatch["func"]
        end
        return colorMatch["text"]
    end },
    { "^[^%w_]", colorMatch["text"] }
}
local sGithub = {
    ["api"]="https://api.github.com/repos/1turtle/consult/releases/latest",
    ["latest"]="https://github.com/1Turtle/consult/releases/latest/download/cosu.lua"
}
local sVersion = "1.4.3"
local bPreview = false
local tArgs = { ... }
local init = function() return end
local sPath = ""
local tAutoCompleteList = { }
local tContent = { }
local tCursor = { ['x']=1,['y']=1,["lastX"]=1,["lastY"]=1,["autoListY"]=0, ["selectedItem"]=1, ["selectedSubDropdown"]={} }
local mode = "insert" --[[ "insert";"insertAuto";"toolbar","menu"; ]]
local tScroll = { ['x']=0,['y']=0 }
local tActiveKeys = {}
local w,h = term.getSize()
local virtualEnviroment = _ENV
local tPopup = {}
local bReadOnly = false
local running = true
local bSaved = true
local category = { }
local tWidgets = { }
local draw = { }
local bLvlOS = (lOS and LevelOS and lUtils)
local input = { handle = {}, insertAuto = {}, insert = {}, toolbar = {}, menu = {} }
local blits = {[1]='0',[2]='1',[4]='2',[8]='3',[16]='4',[32]='5',[64]='6',[128]='7',[256]='8',[512]='9',[1024]='a',[2048]='b',[4096]='c',[8192]='d',[16384]='e',[32768]='f' }
local blitInvert = {['0']=1,['1']=2,['2']=4,['3']=8,['4']=16,['5']=32,['7']=128,['8']=256,['9']=512,['a']=1024,['b']=2048,['c']=4096,['d']=8192,['e']=16384,['f']=32768 }


--[[ +++ Other functions +++ ]]
local function autocomplete()
    tAutoCompleteList = { }
    if type(tContent[tCursor.y]) == "nil" then return end
    local sCurrentChar = tContent[tCursor.y]:sub(tCursor.x,tCursor.x)
    if not (sCurrentChar == ' ' or sCurrentChar == '') then return end
    local nStartPos = string.find((tContent[tCursor.y]):sub(1,tCursor.x-1), "[a-zA-Z0-9_%.:]+$")
    if nStartPos then
        tAutoCompleteList = textutils.complete(tContent[tCursor.y]:sub(nStartPos, tCursor.x-1), virtualEnviroment)
    end
    return (#tAutoCompleteList > 0)
end

local string = string
function string.rep(str, num)
    local tmp = ""
    for i = 1, num do
        tmp = tmp .. str
    end
    return tmp
end

local function checkAutoComplete()
    if not bReadOnly and settings.get("edit.autocomplete") and (mode == "insert" or mode == "insertAuto") then
        if autocomplete() and tCursor.lastY == tCursor.y then
            mode = "insertAuto"
        else
            mode = "insert"
            tCursor.autoListY = 0
        end
    end
end

local function splitStr(str)
    local tStrings = {}
    for i=1,#str/(w/1.5) do
        tStrings[#tStrings+1] = str:sub(1,w/1.5)
        str = str:sub(w/1.5+1)
    end
    tStrings[#tStrings+1] = str
    return table.unpack(tStrings)
end

local function formatText(sText,nLength,nColumns)
    --[[ splitting ]]
    local tSubText = {}
    for i=1,#sText/nLength do
        tSubText[#tSubText+1] = sText:sub(1,nLength)
        sText = sText:sub(nLength+1)
    end
    tSubText[#tSubText+1] = sText
    --[[ remove column overflow ]]
    sText = {}
    for i=1,nColumns do
        sText[i]=tSubText[i]
    end
    sText[#sText] = sText[#sText]:sub(1,nLength-3).."..."
    return table.unpack(sText)
end

local function cToStr(cFG, cBG)
    return "{&"..(blits[cFG] or ' ')..(blits[cBG] or ' ')
end

local function fLen(text)
    local len = 0
    if text:find('{&') then
        for word in string.gmatch(text, '([^{&]+)') do
            len = len+#word:sub(3)
        end
    else
        return #text
    end
    return len
end

local function swapColors()
    if not cosuConf.tPalette[1] then return end
    for color, code in pairs(cosuConf.tPalette) do
        if type(color) == "string" then
            local tmp = colors.packRGB(term.getPaletteColor(colors[color]))
            term.setPaletteColor(colors[color], code)
            cosuConf.tPalette[color] = tmp
        end
    end
end

local function levelLaunch(path,title)
    local gW,gH = lOS.wAll.getSize()
    local x,y = LevelOS.self.window.win.getPosition()
    local win = lOS.execute(
        path,
        "windowed",
        x+(x+w+1<gW and 2 or 0),
        y+(y+h+1<gH and 2 or 0),
        51,
        19,
        true
    )
    win.icon = {'\138', "9"}
    if title then
        win.title = title
    end
end

--[[ +++ Popup handler +++ ]]
local update,info,help,file,error,options,exit,specialChar,openLink,openShell,openPopup

function openPopup(pop)
    if bLvlOS then
        -- Get length of longest text line
        local nLongestMsg = 7
        if pop.text then
            for _,tMsgs in pairs(pop.text) do
                for _,sMsg in pairs(tMsgs) do
                    if #sMsg > nLongestMsg then
                        nLongestMsg = #sMsg
                    end
                end
            end
        end
        -- Convert content
        local str = ""
        local height = 1
        if pop.text then
            for _,line in pairs(pop.text) do
                for _,msg in pairs(line) do
                    str = str..msg.."\n"
                    height=height+1
                end
                str = str..("-"):rep(nLongestMsg).."\n"
                height=height+3
            end
        end
        -- Convert buttons
        local buttons = {}
        for _,tBtn in pairs(pop.button) do
            table.insert(buttons, tBtn.label)
        end
        if #buttons == 0 then
            buttons = {"Ok"}
        end
        local result = {false}
        while not result[1] do
            draw.handler()
            result = {lUtils.popup(pop.name, str, nLongestMsg+2, height, buttons, pop.label, pop.link)}
            if result[1] then
                if result[2] then
                    if pop.button[result[2]].func then
                        pop.button[result[2]].func(pop)
                    end
                end
            end
        end
    else
        table.insert(tPopup, 1, pop)
        tCursor.selectedItem = 1
    end
end

function update(event, ...)
    if event == "close" then
        for index,pop in pairs(tPopup) do
            if pop.name == "Update CONSULT" then
                table.remove(tPopup, index)
            end
        end
    elseif event == "check" then
        --[[ Check updates ]]
        if http then
            local gitAPI=http.get(sGithub.api)
            if gitAPI and gitAPI.getResponseCode()==200 then
                local tGitContent = textutils.unserialiseJSON(gitAPI.readAll())
                if tGitContent.tag_name ~= sVersion then
                    gitAPI.close()
                    return true,tGitContent.tag_name,tGitContent.body
                end
                gitAPI.close()
            end
        end
        return false
    elseif event == "now" then
        --[[ GET UPDATE ]]
        local gitAPI=http.get(sGithub.latest)
        if gitAPI.getResponseCode()==200 then
            local tGitContent = gitAPI.readAll()
            local file
            if bLvlOS then
                file = fs.open( fs.combine(fs.getDir(shell.getRunningProgram()),"cosu.lua"),'w')
            else
                file = fs.open(shell.getRunningProgram(),'w')
            end 
            file.flush()
            file.write(tGitContent)
            file.close()
        end
        gitAPI.close()
        --[[ Update popup ]]
        if bLvlOS then
            lOS.notification("CONSULT", "Updated sucessfully! Restart cosu.", shell.getRunningProgram(), 3)
        else
            for index,pop in pairs(tPopup) do
                if pop.name == "Update CONSULT" then
                    tPopup[index].size = {
                        ['x'] = nil,
                        ['y'] = nil
                    }
                    tPopup[index].button = {
                        { ['x']=42, ['y']=9, ["label"]="Thanks", ["status"]=false, ["func"]=function() update("close") end }
                    }
                    tPopup[index].text={
                        {
                            "UPDATE COMPLETE",
                        },{
                            "Congratulations! The program just got updated!",
                            "Restart Consult to make changes take effect.",
                            "Check out the changelog on Github.",
                            "(see 'About' page under the 'Info' category for",
                            " the link to the developers Github.)"
                        }
                    }
                end
            end
        end
    elseif event == "create" then
        local bAvailable,sNewVersion,sChangelog = update("check")
        --[[ Update available ]]
        if bAvailable then
            local tChangelog = {formatText(sChangelog,47,3)}
            openPopup({
                ["status"] = true,
                ["name"] = "Update CONSULT",
                ["size"] = {
                    ['x'] = nil,
                    ['y'] = nil
                },
                ["text"] = {
                    {
                        "UPDATE AVAILABLE",
                    },{
                        "v"..sVersion.." --> v"..sNewVersion.."  | Do you want to proceed?",
                        "",
                        table.unpack(tChangelog)
                    }
                },
                ["button"] = {
                    { ['x']=42, ['y']=6+#tChangelog, ["label"]="Update", ["status"]=false, ["func"]=function() update("now") end },
                    { ['x']=39, ['y']=6+#tChangelog, ["label"]="No", ["status"]=false, ["func"]=function() update("close") end }
                }
            })
        end
    end
end

function openLink(event, ...)
    if event == "close" then
        for index,pop in pairs(tPopup) do
            if pop.name == "Link" then
                table.remove(tPopup, index)
            end
        end
    elseif event == "create" then
        local link = tostring(({...})[1])
        link = link:sub(2,#link-1)
        if fs.isDir(link) and not bLvlOS then return end
        if link == "" or link == "..." or link == "." or not fs.exists(link) or link:find('ö') or link:find('ä') or link:find('ü') then return end
        local line = "Open the following "..(fs.isDir(link) and "directory" or "file").."?"
        local slink = link
        if #slink >= #line then
            slink = ".."..slink:sub(-(#line-3))
        end
        openPopup({
            ["status"] = true,
            ["name"] = "Link",
            ["link"] = link,
            ["size"] = {
                ['x'] = nil,['y'] = nil
            },
            ["text"] = {
                {
                    line,
                    cToStr(' ', colorMatch.bg)..(' '):rep(#line)
                }
            },
            ["label"] = {
                {
                    content = cToStr(colorMatch.special,colorMatch.bg)..slink,
                    x=math.floor((#line-#slink)/2+0.5),y=2,
                }
            },
            ["button"] = {
                { ['x']=#line-3, ['y']=4, ["label"]="Open", ["status"]=false, ["func"]=function(pop)
                    local link = pop.link
                    openLink("close")
                    if bLvlOS then
                        if fs.isDir(link) and fs.exists("Program_Files/LevelOS/Explorer/main.lua") then
                            levelLaunch("Program_Files/LevelOS/Explorer/main.lua "..link)
                        else
                            levelLaunch(shell.getRunningProgram().." "..link)
                        end
                        tActiveKeys["CTRL"] = false
                    elseif multishell then
                        if fs.isDir(link) then
                            multishell.launch(_ENV, shell.resolveProgram("shell"))
                        else
                            multishell.launch(_ENV, shell.getRunningProgram(), link)
                        end
                        tActiveKeys["CTRL"] = false
                    end
                end},
                { ['x']=#line-6, ['y']=4, ["label"]="No", ["status"]=false, ["func"]=function() openLink("close") end }
            }
        })
    end
end

function info(event, ...)
    if event == "close" then
        for index,pop in pairs(tPopup) do
            if pop.name == "About CONSULT" then
                table.remove(tPopup, index)
            end
        end
    elseif event == "create" then
        openPopup({
            ["status"] = true,
            ["name"] = "About CONSULT",
            ["size"] = {
                ['x'] = nil,
                ['y'] = nil
            },
            ["text"] = {
                {
                    "CONSULT (short cosu) | a Text editor",
                },{
                    "  Available under the MIT License.",
                    "      (c) 2022, Sammy L. Koch",
                    " Source: github.com/1Turtle/consult",
                    "           Version: "..sVersion
                }
            },
            ["button"] = {
                { ['x']=31, ['y']=8, ["label"]="Thanks", ["status"]=false, ["func"]=function() info("close") end }
            }
        })
    end
end

function help(event, ...)
    if event == "close" then
        for index,pop in pairs(tPopup) do
            if pop.name:sub(1,9) == "Help Page" then
                table.remove(tPopup, index)
            end
        end
    elseif event == "change" then
        local nPage = ({...})[1]
        local nCurP = ({...})[2]
        local nMax = ({...})[3]
        if bLvlOS then
            if nPage > 0 and nCurP < nMax then
                nCurP = nCurP+1
            elseif nPage < 0 and nCurP > 1 then
                nCurP = nCurP-1
            end
            help("create", nCurP)
        else
            if nPage > 0 and tPopup[1].page < #tPopup[1].data then
                tPopup[1].page = tPopup[1].page+1
                tPopup[1].text = tPopup[1].data[tPopup[1].page]
            elseif nPage < 0 and tPopup[1].page > 1 then
                tPopup[1].page = tPopup[1].page-1
                tPopup[1].text = tPopup[1].data[tPopup[1].page]
            end
        end
    elseif event == "create" then
        local nPage = ({...})[1]
        if not nPage then nPage = 1 end
        local popup = {
            ["status"] = true,
            ["name"] = "Help Page",
            ["size"] = {
                ['x'] = nil,
                ['y'] = nil
            },
            ["data"] = {
                {
                    {
                        "Text editor (for dummies) | (1/4)",
                    },{
                        "* Navigate cursor with [ARROW] keys or    ",
                        "  by clicking with the mouse.",
                        "* [MOUSE-WHEEL] scrolls up/down.",
                        "* To type text, use your keyboard. :)",
                        "* Remove char from the LEFT of your",
                        "  cursor with [BACKSPACE] & from ..."
                    }
                },{
                    {
                        "Text editor (for dummies) | (2/4)",
                    },{
                        "  the RIGHT of your cursor with [DELETE]. ",
                        "* To place ("..tostring(cosuConf.nTabSpace)..") spaces, use [TAB].",
                        "* Autocorrect is on by default,",
                        "  when shown, press [TAB] to apply &",
                        "  navigate with [ARROW] keys.",
                        "  (Can be Toggled via system settings.)"
                    }
                },{
                    {
                        "Navigationbar/Popups | (3/4)",
                    },{
                        "* Click on category to show dropdown.",
                        "* LEFT/RIGHT [ARROW] keys change category.",
                        "* UP/DOWN [ARROW] keys choose",
                        "  item from dropdown.","",""
                    }
                },{
                    {
                        "Navigationbar/Popups | (4/4)",
                    },{
                        "* Choose widget with [ARROW] keys",
                        "  (UP/DOWN works like LEFT/RIGHT.)        ",
                        "* Button: Press [ENTER] to execute.",
                        "* Textbox: Type to enter input.", "",""
                    }
                }      
            },
            ["page"] = nPage,
            ["text"] = { },
            ["button"] = {
                { ['x']=10, ['y']=10, ["label"]="Next", ["status"]=false, ["func"]=function(self) help("change",1, self.page, #self.data) end },
                { ['x']=39, ['y']=10, ["label"]="Done", ["status"]=false, ["func"]=function() help("close") end },
                { ['x']=1, ['y']=10, ["label"]="Previous", ["status"]=false, ["func"]=function(self) help("change",-1, self.page, #self.data) end }
            }
        }
        popup.text = popup.data[nPage]
        openPopup(popup)
    end
end

function file(event, ...)
    local tArgs = { ... }
    if event == "close" then
        for index,pop in pairs(tPopup) do
            if pop.name:sub(1,7) == "File - " then
                table.remove(tPopup, index)
            end
        end
    elseif event == "replace" then
        openPopup({
            ["status"] = true,
            ["name"] = "File - Replace",
            ["size"] = {
                ['x'] = nil,
                ['y'] = nil
            },
            ["text"] = {
                { "File already Exists! Replace it?" }
            },
            ["tmp"]=tArgs[1],
            ["button"] = {
                { ['x']=26, ['y']=3, ["label"]="No", ["status"]=false, ["func"]=function() file("close") file("create", "save as") end },
                { ['x']=29, ['y']=3, ["label"]="Yes", ["status"]=false, ["func"]=function(self) local tmp=self.tmp file("close") file("create", "save", tmp, "force") end }
            }
        })
    elseif event == "saved" then
        local nLength = 13
        if #sPath+3 > 13 then nLength = #sPath+3 end
        local pop = {
            ["status"] = true,
            ["name"] = "File - Saved",
            ["size"] = {
                ['x'] = nil,
                ['y'] = nil
            },
            ["text"] = {
                { "File saved as", "\'"..sPath.."\'." }
            },
            ["button"] = {
                { ['x']=nLength-1, ['y']=4, ["label"]="Ok", ["status"]=false, ["func"]=function() file("close") end },
                { ['x']=nLength-6, ['y']=4, ["label"]="Exit", ["status"]=false, ["func"]=function() file("close") exit("create") end }
            }
        }
        if bLvlOS then
            lOS.notification("CONSULT", "Saved file as \'"..sPath..'\'', shell.getRunningProgram(), 3)
        else
            table.insert(tPopup, 1, pop)
        end

        local sPathName = sPath:reverse()
        local nLastSlashPos = sPathName:find('/')
        if nLastSlashPos then
            sPathName = sPathName:sub(nLastSlashPos):reverse()
        else
            sPathName = sPathName:reverse()
        end
        if bLvlOS then
            LevelOS.setTitle("CONSULT - "..sPathName)
        elseif multishell then
            multishell.setTitle(multishell.getCurrent(), "cosu-["..sPathName.."]")
        end
    elseif event == "create" then
        if tArgs[1] == "save" then
            local tmpPath = sPath
            if type(tArgs[2])=="string" then
                tmpPath = tArgs[2]
            end
            if fs.exists(tmpPath) and tmpPath~=sPath and tArgs[3]~="force" then
                file("replace", tmpPath)
                return
            end
            local f = fs.open(tmpPath, 'w')
            if f then
                for _,sLine in pairs(tContent) do
                    f.writeLine(sLine)
                end
                f.close()
                bSaved = true
                sPath = tmpPath
                file("saved")
            else
                file("create", "save as", "error")
            end
        elseif tArgs[1] == "save as" then
            local tMsg = {}
            if tArgs[2]=="error" then
                tMsg = {"Invalid path!"}
            end
            table.insert(tPopup, 1, {
                ["status"] = true,
                ["name"] = "File - GetName",
                ["size"] = {
                    ['x'] = nil,
                    ['y'] = nil
                },
                ["text"] = {
                    { table.unpack(tMsg),"Enter new path:","" }
                },
                ["textBox"] = {
                    { ['x']=1, ['y']=2+#tMsg, ["input"]=sPath }
                },
                ["button"] = {
                    { ['x']=6, ['y']=4+#tMsg, ["label"]="Abort", ["status"]=false, ["func"]=function() file("close") end },
                    { ['x']=12, ['y']=4+#tMsg, ["label"]="Done", ["status"]=false, ["func"]=function() local tmp=tPopup[1].textBox[1].input file("close") file("create", "save", tmp) end }
                }
            })

        elseif tArgs[1] == "new" then
            if bLvlOS then
                levelLaunch(shell.getRunningProgram(), "CONSULT")
                category.reset()
            elseif multishell then
                local tabId = multishell.launch(_ENV, shell.getRunningProgram())
                multishell.setTitle(tabId, "cosu")
                multishell.setFocus(tabId)
                category.reset()
            else
                if bSaved or tArgs[2] == "force" then
                    tContent = { "" }
                    tCursor.x,tCursor.y = 1,1
                    tScroll = { ['x']=0,['y']=0 }
                    return
                end
                openPopup({
                    ["status"] = true,
                    ["name"] = "File - New",
                    ["size"] = {
                        ['x'] = nil,
                        ['y'] = nil
                    },
                    ["text"] = {
                        { "Create new project,", "without saving the current one?" }
                    },
                    ["button"] = {
                        { ['x']=25, ['y']=4, ["label"]="No", ["status"]=false, ["func"]=function() file("close") end },
                        { ['x']=28, ['y']=4, ["label"]="Yes", ["status"]=false, ["func"]=function() file("close") file("create", "new", "force") end }
                    }
                })
            end
        end
    elseif event == "execute" then
        local sDir = '/'..fs.getDir(shell.getRunningProgram())..'/'
        local sCurID = tostring( (not bLvlOS and type(multishell)~="nil") and multishell.getCurrent() or "" )
        local f = fs.open(sDir..".tmp"..sCurID, 'w')
        f.flush()
        f.write("local function c() ")
        for _,sLine in pairs(tContent) do
            f.writeLine(sLine)
        end
        f.write("end local path=\""..sDir..".tmp"..sCurID.."\"")
        f.write([[ local o,e=pcall(c)
        if not o then
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.red)
            print(e)
            term.setTextColor(colors.white)
        end print("Press any key to exit") sleep(0.05) os.pullEvent("key") ]])
        f.close()

        if bLvlOS then
            levelLaunch(sDir..".tmp"..sCurID, "CONSULT - [running]")
        elseif multishell then
            local nID = multishell.launch(_ENV, sDir..".tmp"..sCurID, ...)
            multishell.setTitle(nID, "cosu-[run"..nID.."]")
            multishell.setFocus(nID)
        else
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.white)
            term.clear()
            term.setCursorPos(1,1)
            shell.run(sDir..".tmp"..sCurID)
        end
    end
end

function error(event, name, ...)
    if event == "close" then
        for index,pop in pairs(tPopup) do
            if pop.name:find("Error") then
                if pop.name == "Error" then
                    sPath = pop.textBox[1].input
                end
                table.remove(tPopup, index)
            end
        end
    elseif event == "create" then
        local tArgs = { ... }
        --[[ Local get size ]]
        local nXCounter = 0
        local nLongestMsg = 7
        for _,tMsgs in pairs(tArgs) do
            for _,sMsg in pairs(tMsgs) do
                if #sMsg > nLongestMsg then
                    nLongestMsg = #sMsg
                end
                nXCounter = nXCounter+1
            end
            nXCounter = nXCounter+1
        end

        openPopup({
            ["status"] = true,
            ["name"] = "Error - "..name,
            ["size"] = {
                ['x'] = nil,
                ['y'] = nil
            },
            ["text"] = tArgs,
            ["button"] = {
                { ['x']=nLongestMsg-1, ['y']=nXCounter+1, ["label"]="Ok", ["status"]=false, ["func"]=function() error("close") end }
            }
        })
    end
end

function options(event, ...)
    local tSubArgs = { ... }
    local sDir = fs.getDir(shell.getRunningProgram())..'/'
    if event == "close" then
        for index,pop in pairs(tPopup) do
            if pop.name:sub(1,10) == "Options - " then
                table.remove(tPopup, index)
            end
        end
    elseif event == "set" then
        local sConfigName,newValue = tSubArgs[1],tSubArgs[2]
        if type(newValue) == "table" then
            for key,value in pairs(newValue) do
                cosuConf[sConfigName][key] = value
            end
        else
            cosuConf[sConfigName] = newValue
        end
    elseif event == "load" then 
        if fs.exists(sDir..".cosu.conf") then
            local configFunc, err = loadfile(sDir..".cosu.conf")
            if not configFunc then
                error("create", "options", {"Fatal error in config file!"}, {"> "..err})
            else
                local tWrongValues = {}
                local bMissingValues = false
                local bSuccess = xpcall(
                        configFunc,
                        function(err)
                            err = {splitStr(err)}
                            error("create", "options", {"Error in config file!"}, err)
                        end
                    )
                if bSuccess then
                    local newConfigs = configFunc()
                    for sConfigName,value in pairs(cosuConf) do
                        local newValue = newConfigs[sConfigName]
                        if type(newValue) == type(value) then
                            options("set", sConfigName, newValue)
                        elseif type(newValue) == "function" then
                            if type(newValue())==type(value) then
                                options("set", sConfigName, newValue())
                            else
                                tWrongValues[#tWrongValues+1] = "\'"..sConfigName.. "\' expected \'"..type(value)..'\''
                            end
                        elseif type(newValue) == "nil" then
                            bMissingValues = true
                        else
                            tWrongValues[#tWrongValues+1] = "\'"..sConfigName.. "\' expected \'"..type(value)..'\''
                        end
                    end
                end
                if bMissingValues then
                    options("add missing")
                end
                if #tWrongValues > 0 and not sPath:find(".cosu.conf") then
                    error("create", "options",
                        {"The following values are wrong in",
                        '\''..sDir..".cosu.conf\':"},
                        {table.unpack(tWrongValues)}
                    )
                end
            end
        end
    elseif event == "add missing" then
        local f = fs.open(sDir..".cosu.conf", 'w')
        f.write( "return "..textutils.serialize(cosuConf) )
        f.close()
    elseif event == "create" then
        if not fs.exists(sDir..".cosu.conf") then
            local f = fs.open(sDir..".cosu.conf", 'w')
            f.write( "return "..textutils.serialize(cosuConf) )
            f.close()
        end

        if bLvlOS then
            levelLaunch(shell.getRunningProgram().." "..sDir..".cosu.conf", "CONSULT - [options]")
        elseif multishell then
            local tabId = multishell.launch(_ENV,
                shell.getRunningProgram(),
                sDir..".cosu.conf"
            )
            multishell.setTitle(tabId, "cosu-[options]")
        else
            if bSaved or tSubArgs[1] == "force" then
                tContent = { }
                tArgs  = { sDir..".cosu.conf" }
                init()
                tCursor.x,tCursor.y = 1,1
                tScroll = { ['x']=0,['y']=0 }
                return
            end
            openPopup({
                ["status"] = true,
                ["name"] = "Options - Ask",
                ["size"] = {
                    ['x'] = nil,
                    ['y'] = nil
                },
                ["text"] = {
                    { "Edit Options,", "WITHOUT SAVING project?" }
                },
                ["button"] = {
                    { ['x']=15, ['y']=4, ["label"]="Back", ["status"]=false, ["func"]=function() options("close") end },
                    { ['x']=20, ['y']=4, ["label"]="Edit", ["status"]=false, ["func"]=function() options("close") options("create", "force") end }
                }
            })
        end
    end
end

function exit(event, ...)
    if event == "close" then
        for index,pop in pairs(tPopup) do
            if pop.name == "Warning" then
                table.remove(tPopup, index)
            end
        end
    elseif event == "JUST DO IT" then
        running = (-1)
        return
    elseif event == "create" then
        if bSaved then
            running = false
            return
        end
        openPopup({
            ["status"] = true,
            ["name"] = "Warning",
            ["size"] = {
                ['x'] = nil,
                ['y'] = nil
            },
            ["text"] = {
                { "Do you really want to exit,", "without saving?" }
            },
            ["button"] = {
                { ['x']=21, ['y']=4, ["label"]="No", ["status"]=false, ["func"]=function() exit("close") end },
                { ['x']=24, ['y']=4, ["label"]="Exit", ["status"]=false, ["func"]=function() exit("JUST DO IT") end }
            }
        })
    end
end

--[[ Placeholder for new options :) ]]

function specialChar(event, ...)
    if event == "close" then
        for index,pop in pairs(tPopup) do
            if pop.name == "Special Chars" then
                table.remove(tPopup, index)
            end
        end
    elseif event == "create" then
        local tNewPopup = {
            ["blockControlls"]=true,
            ["closeAtNoFokus"] = function(self)
                local icon = self.list[1].content[self.list[1].selected]
                for type,widget in  pairs(tWidgets) do
                    if widget.name == "specialChar" then
                        if icon ~= type then
                            tWidgets[icon] = widget
                            tWidgets[type] = nil
                            break
                        end
                    end
                end
                input.insert.char(icon)
            end,
            ["key"]=function(self, id,_)
                local worked = false
                if self.list[1].type == "sidebyside" then
                    if id == cosuConf.tKeyboard.up and (self.list[1].selected-self.list[1].size.x-1) > 0 then
                        self.list[1].selected = self.list[1].selected-self.list[1].size.x-1
                        worked = true
                    elseif id == cosuConf.tKeyboard.down and (self.list[1].selected+(self.list[1].size.x+1)) < self.list[1].size.max then
                        self.list[1].selected = self.list[1].selected+(self.list[1].size.x+1)
                        worked = true
                    end
                end
                if id == cosuConf.tKeyboard.left and self.list[1].selected>1 then
                    self.list[1].selected = self.list[1].selected-1
                    worked = true
                elseif id == cosuConf.tKeyboard.right and self.list[1].selected<self.list[1].size.max then
                    self.list[1].selected = self.list[1].selected+1
                    worked = true
                end
                if not worked then
                    if id ~= cosuConf.tKeyboard.enter then
                        specialChar("close")
                    end
                end
            end,
            ["status"] = true,
            ["name"] = "Special Chars",
            ['x']=w-17,['y']=2,
            ["size"] = {
                ['x'] = 15,
                ['y'] = 7,
                ["max"] = 9
            },
            ["list"] = {
                {
                    ["type"]="sidebyside",
                    ["scrolled"]=1,
                    ['x']=1,['y']=1,
                    ["size"] = {
                        ['x'] = 14,
                        ['y'] = 7
                    },
                    ["selected"]=3,
                    ["content"]={ }
                }
            },
            ["button"] = {
                { ['x']=1, ['y']=1, ["label"]="", ["status"]=false, ["func"]=function(self) self:closeAtNoFokus() specialChar("close") end },
            }
        }
        local nSelected = 0
        for type,widget in  pairs(tWidgets) do
            if widget.name == "specialChar" then
                nSelected = string.byte(type)
                break
            end
        end
        for i=0,32 do
            if nSelected == i then
                tNewPopup.list[1].selected = #tNewPopup.list[1].content+1
            end
            tNewPopup.list[1].content[#tNewPopup.list[1].content+1] = string.char(i)
        end for i=127,191 do
            if nSelected == i then
                tNewPopup.list[1].selected = #tNewPopup.list[1].content+1
            end
            tNewPopup.list[1].content[#tNewPopup.list[1].content+1] = string.char(i)
        end for _,i in pairs({198,208,216,222,230,247,254}) do
            if nSelected == i then
                tNewPopup.list[1].selected = #tNewPopup.list[1].content+1
            end
            tNewPopup.list[1].content[#tNewPopup.list[1].content+1] = string.char(i)
        end
        tNewPopup.list[1].size.max = #tNewPopup.list[1].content
        openPopup(tNewPopup)
    end
end

function openShell()
    if bLvlOS then
        levelLaunch("shell")
    else
        if shell.openTab then
            local nTask = shell.openTab("shell")
            if nTask then shell.switchTab(nTask) end
            category.reset()
        else error("create", "multishell", {"The Multishell API is required,","to run a shell in a new tab!","(only available for advanced-PCs!)"})
        end
    end
end


local nDropdownLength = 1
local tToolbar = {
    {["name"]="File",["content"]={{
        ["Run file"]=function() file("execute") end,
        ["New file"]=function() file("create", "new") end},{
        ["Save"]=function() file("create", "save") end,
        ["Save as ..."]=function() file("create", "save as") end},{
        ["Options"]=function() options("create") end,
        ["Exit"]=function() exit("create") end
    }}},
    --[[{["name"]="Edit",["content"]={{
        ["Mark"]=function() tMarker.start={tCursor.x,tCursor.y} end,
        ["Copy"]=function() end,
        ["Paste"]=function() end,
        ["Search"]=function() end
    }}},]]
    {["name"]="Info",["content"]={{
        ["About"]=function() info("create") end,
        ["Help"]=function() help("create") end}
    }}
}
tWidgets = {
    ["\002"] = {
        ["name"]="specialChar",
        ["color"]=term.isColor() and colors.lime or colors.white,
        ["func"]=function() specialChar("create") end,
        ["shourtcut"]=cosuConf.tKeyboard.F_SpChar
    },
    [">_"] = {
        ["name"]="openShell",
        ["color"]=term.isColor() and colors.yellow or colors.white,
        ["func"]=openShell,
        ["shourtcut"]=cosuConf.tKeyboard.F_NewShell
    }
}

function category.reset()
    tCursor.selectedItem = 1
    for _,category in pairs(tToolbar) do
        category.status = false
    end
    if #tAutoCompleteList > 0 then
        mode = "insertAuto"
    else
        mode = "insert"
    end
end

function category.getCurrentIndex()
    local nLength = 0
    for index,category in pairs(tToolbar) do
        if category.status then
            return index,nLength
        else
            nLength = nLength+#category.name+2
        end
    end
    return 0,0
end

function category.items(nCategoryIndex, bExecute, bCountBreaksToo)
    local nItemCount,nLargest = 0,0
    for _,tItemHolder in pairs(tToolbar[nCategoryIndex].content) do
        if bCountBreaksToo then nItemCount = nItemCount + 1 end
        for sItemName,item in pairs(tItemHolder) do
            nItemCount = nItemCount + 1
            if #sItemName > nLargest then
                nLargest = #sItemName
            end
            if bExecute and tCursor.selectedItem == nItemCount then
                if type(item) == "function" then
                    category.reset()
                    item()
                end
            end
        end
    end
    return nItemCount, nLargest
end

function category.openByChar(char)
    category.reset()
    for _,category in pairs(tToolbar) do
        if category.name:sub(1,#char):lower() == char then
            category.status = true
            mode = "toolbar"
        end
    end
end

local bBigProgress = false
local function inProgress(bStatus, isBig)
    term.setCursorBlink(not bStatus)
    bBigProgress = (isBig == true)
end

function loadAPIVirtual(sLine)
    local sVar,sAPI,sSubVar = "","",""
    local typeOfLoad="require"
    local _,nEnd = sLine:find("require")
    if type(nEnd)=="nil" then
        _,nEnd = sLine:find("os.loadAPI")
        typeOfLoad="os.loadAPI"
    end if type(nEnd)=="nil" then
        _,nEnd = sLine:find("peripheral.find")
        typeOfLoad="peripheral.find"
    end if type(nEnd)=="nil" then
        _,nEnd = sLine:find("peripheral.wrap")
        typeOfLoad="peripheral.wrap"
    end if type(nEnd)=="nil" then
        return
    end

    local _,nVarEnd = sLine:find('=')
    if nEnd and nVarEnd then
        --[[ Get API's path ]]
        nEnd = nEnd+1
        local start = 0
        for i=nEnd, #sLine do
            if sLine:sub(i,i) ~= ' ' and sLine:sub(i,i) ~= '(' and sLine:sub(i,i) ~= '\"' and sLine:sub(i,i) ~= '\'' then
                if start == 0 then start = i end
            elseif start ~= 0 then
                sAPI = sLine:sub(start, i-1)
                break
            end
        end
        --[[ Get defiend name ]]
        start = 0
        for i=nVarEnd-1,1,-1 do
            if sLine:sub(i,i) ~= ' ' then
                if start == 0 then start = i end
            elseif start ~= 0 then
                sVar = sLine:sub(i+1, start)
                break
            end
        end
        --[[ Get sub variable ]]
        start = 0
        local _,beginn = sLine:find(sAPI)
        if type(beginn)=="nil" then return end
        for i=beginn,#sLine do
            if start == 0 and sLine:sub(i,i) == '.' then
                start = i+1
            elseif start ~= 0 and (sLine:sub(i+1,i+1) == ' ' or i==#sLine) then
                sSubVar = sLine:sub(start, i)
                break
            end
        end
        virtualEnviroment[sVar] = { }
    end
    local ok,out
    if typeOfLoad=="require" then
        ok,out = pcall(require,sAPI)
    elseif typeOfLoad=="os.loadAPI" then
        if fs.exists(sAPI) and not fs.isDir(sAPI) then
            local file = fs.open(sAPI,'r')
            local content = file.readAll()
            file.close()
            content = "local require=function() end\n"..content
            ok,out = pcall(loadstring(content))
        else
            ok=false
        end
    elseif typeOfLoad=="peripheral.find" then
        ok,out = pcall(peripheral.find, sAPI)
    elseif typeOfLoad=="peripheral.wrap" then
        ok,out = pcall(peripheral.wrap, sAPI)
    end
    if ok and type(out)=="table" then
        for var,value in pairs(out) do
            if type(sSubVar)=="string" and #sSubVar>1 then
                if var==sSubVar then
                    virtualEnviroment[sVar] = value
                    return
                end
            else
                virtualEnviroment[sVar][var] = value
            end
        end
    end
end


--[[ +++ Draw functions +++ ]]
local buf = {
    ["b"]={},
    ["f"]={},
    ["t"]={}
}
local fTerm={
    ["setCursorPos"]=nTerm.setCursorPos,
    ["getCursorPos"]=nTerm.getCursorPos,
    ["setBackgroundColor"]=nTerm.setBackgroundColor,
    ["getBackgroundColor"]=nTerm.getBackgroundColor,
    ["setTextColor"]=nTerm.setTextColor,
    ["getTextColor"]=nTerm.getTextColor,
    ["setCursorBlink"]=nTerm.setCursorBlink,
    ["clear"]=function()
        local nW,nH=nTerm.getSize()
        
        local sB=(blits[nTerm.getBackgroundColor()]):rep(nW)
        local sF=(blits[nTerm.getTextColor()]):rep(nW)
        local sT=(' '):rep(nW)
        
        for i=1,nH do
            buf.b[i]=sB
            buf.f[i]=sF
            buf.t[i]=sT
        end
    end,
    ["clearLine"]=function()
        local nW,_=nTerm.getSize()
        local _,nY=nTerm.getCursorPos()
        local sB=(blits[nTerm.getBackgroundColor()]):rep(nW)
        local sF=(blits[nTerm.getTextColor()]):rep(nW)
        local sT=(' '):rep(nW)
        
        buf.b[nY]=sB
        buf.f[nY]=sF
        buf.t[nY]=sT
    end,
    ["write"]=function(str)
        str = tostring(str)
        local nX,nY=nTerm.getCursorPos()
        nTerm.setCursorPos(nX+#str,nY)
        local cBg=blits[nTerm.getBackgroundColor()]:rep(#str)
        local cFg=blits[nTerm.getTextColor()]:rep(#str)
        if nY < 0 or nY > h then return end
        if nX < 1 then
            str = str:sub(2-nX)
            cBg = cBg:sub(2-nX)
            cFg = cFg:sub(2-nX)
            nX = 1
        end
        buf.b[nY]=buf.b[nY]:sub(1,nX-1).. cBg ..buf.b[nY]:sub(nX+#str)
        buf.f[nY]=buf.f[nY]:sub(1,nX-1).. cFg ..buf.f[nY]:sub(nX+#str)
        buf.t[nY]=buf.t[nY]:sub(1,nX-1).. str ..buf.t[nY]:sub(nX+#str)
    end,
    ["render"]=function()
        local nX,nY=nTerm.getCursorPos()
        for i=1,#buf.t do
            nTerm.setCursorPos(1,i)
            nTerm.blit(buf.t[i],buf.f[i],buf.b[i])
        end
        nTerm.setCursorPos(nX,nY)
    end
} fTerm.clear()
function draw.highlighted(sLine, nIndex)
    while #sLine > 0 do
        for _,v in pairs(tPatterns) do
            local sMatch = sLine:match(v[1])
            if sMatch then
                --[[ Set color ]]
                if type(v[2]) == "number" then
                    term.setTextColor(v[2])
                elseif type(v[2]) == "function" then
                    term.setTextColor(v[2](sMatch, sLine:sub(#sMatch), nIndex-tScroll.y, tContent[nIndex]))
                end
                --[[ Write match from line ]]
                term.write(sMatch)
                sLine = string.sub(sLine, #sMatch+1)
                break
            end
        end
    end
end

function draw.content()
    term.setBackgroundColor(colorMatch["bg"])
    for y=1,(h-2) do
        local sLine = tContent[y+tScroll.y]
        term.setCursorPos(1, y+1)
        if type(sLine) ~= "string" then
            term.setTextColor(colors.gray)
            term.write( ("\127"):rep(w) )
        elseif #sLine < 1 then
            term.clearLine()
        else
            local sSubLine = sLine:sub(tScroll.x+1, w+tScroll.x)
            if sSubLine:find('\"') or sSubLine:find('\'') then
                sSubLine = sLine:sub(tScroll.x+1)
            end
            sSubLine = sSubLine .. (" "):rep(w-#sSubLine)
            draw.highlighted(sSubLine, y+tScroll.y)
        end
    end
end

function draw.switchFGBG(cFG, cBG)
    if type(cFG) == "nil" and type(cBG) == "nil" then
        local cFG, cBG = term.getTextColor(), term.getBackgroundColor()
            term.setTextColor(cBG)
            term.setBackgroundColor(cFG)
    else
        term.setTextColor(cFG)
        term.setBackgroundColor(cBG)
    end
end

function draw.autocomplete()
    --[[ Setup size ]]
    local nW, nH = 3, (h-2)/4
    if #tAutoCompleteList-tCursor.autoListY < nH then
        nH = #tAutoCompleteList-tCursor.autoListY
    end
    for i=1,nH do
        local sLine = tAutoCompleteList[i+tCursor.autoListY]
        if #sLine+1 > nW then nW = #sLine+1 end
    end
    --[[ Draw ]]
    draw.switchFGBG(colors.white, colors.gray)
    for i=1,nH do 
        local sLine = tostring(tAutoCompleteList[i+tCursor.autoListY])
        term.setCursorPos(tCursor.x-tScroll.x,tCursor.y-tScroll.y+i)
        if sLine:find('%(') then
            sLine = sLine..')'
        end
        term.write(sLine..(" "):rep(nW-#sLine))
        term.setTextColor(colors.lightGray)
    end
end

function draw.cursor()
    term.setCursorPos(tCursor.x-tScroll.x, tCursor.y-tScroll.y+1)
    if cosuConf.bCursorIsBlock then
        draw.switchFGBG(colorMatch["bg"], colorMatch["text"])
        local char = tContent[tCursor.y]:sub(tCursor.x,tCursor.x)
        if #tAutoCompleteList > 0 then
            char = tAutoCompleteList[tCursor.autoListY+1]:sub(1,1)
        elseif #char == 0 then char = " " end
        term.write(char)
    else
        term.setTextColor(colorMatch["text"])
        term.setCursorBlink(true)
    end
end

function draw.dropdownBG(nW,nH, nX, nY, tLineBreaks)
    --[[ Set size ]]
    local nPopX, nPopY = nX, nY
    if type(nX) == "nil" then nPopX = (w/2)-(nW+2)/2+1
    end if type(nY) == "nil" then nPopY = (h/2)-(nH+2)/2+1
    end
    --[[ Draw main ]]
    draw.switchFGBG(colorMatch["popupFrame"], colorMatch["popupBG"])
    for y=1,nH do
        term.setCursorPos(nPopX, nPopY+y)
        local sLeft, sFiller, sRight = "\149", " ", "\149"
        if y == 1 then
            --[[ Top border ]]
            sLeft="\151"  sFiller="\131"  sRight="\148"
        elseif y == nH then
            --[[ Buttom border ]]
            sLeft="\138"  sFiller="\143"  sRight="\133"
            draw.switchFGBG()
        end
        term.write( sLeft..(sFiller):rep(nW) )
        if y ~= nH then draw.switchFGBG() end
        term.write(sRight)
        draw.switchFGBG()
    end
    --[[ Draw line breaks ]]
    if type(tLineBreaks) ~= "table" then return end
    for i=1,#tLineBreaks do
        term.setCursorPos(nPopX, nPopY+tLineBreaks[i]+1)
        term.write("\157".. ("\140"):rep(nW) )
        draw.switchFGBG()
        term.write("\145")
        draw.switchFGBG()
    end
    --[[ Shadow ]]
    if cosuConf.bShadows then
        draw.switchFGBG(colorMatch.popupFrame, colorMatch.bg)
        local char = ''
        for i=1,nH do
            term.setCursorPos(nPopX+nW+2,nPopY+1+i)
            char = (type(tContent[nY+i+tScroll.y])=="string") and '\127' or ' '
            term.write(char)
        end
        char = (type(tContent[nY+nH+tScroll.y])=="string") and '\127' or ' '
        for i=1,nW+1 do
            term.setCursorPos(nPopX+i,nPopY+nH+1)
            term.write(char)
        end
    end
end

function draw.fText(text)
    local tx,bg = term.getTextColor(),term.getBackgroundColor()
    if text:find('{&') then
        for word in string.gmatch(text, '([^{&]+)') do
            term.setTextColor(blitInvert[word:sub(1,1):lower()] or tx)
            term.setBackgroundColor(blitInvert[word:sub(2,2):lower()] or bg)
            term.write(word:sub(3))
        end
    else
        draw.switchFGBG(tx,bg)
        term.setTextColor(tx)
        term.write(text)
    end
end

function draw.popup(popup,index)
    if not popup.status then return end
    --[[ Get size ]]
    local size = { ['w']=popup.size.x or 0, ['h']=popup.size.y or 1 }
    if type(popup.size.y) == "nil" or type(popup.size.x) == "nil" then
        if type(popup.text)=="table" then
            for _,tBlock in pairs(popup.text) do
                for _,sLine in pairs(tBlock) do
                    size.h = size.h + 1
                    local len = fLen(sLine)
                    if len > size.w then
                        size.w = len
                    end
                end
                size.h = size.h + 1
            end
        elseif type(popup.textBox)=="table" then
            size.h = 3
            size.w = #popup.textBox.input
        end
        tPopup[index].size.x = size.w
        tPopup[index].size.y = size.h
    end
    --[[ Define X & Y pos, if not present ]]    
    if type(popup.x or popup.y) == "nil" then
        popup.x = math.floor((w/2)-(size.w/2))
        popup.y = math.floor((h/2)-(size.h/2))
    end
    --[[ Border/BG ]]
    draw.switchFGBG(colorMatch["popupFrame"], colorMatch["popupBG"])
    draw.dropdownBG(size.w,size.h+2, popup.x,popup.y-1,{})
    draw.switchFGBG(colorMatch["popupFont"], colorMatch["popupBG"])
    --[[ Text (& Line breaks) ]]
    local sBuffer = ("\140"):rep(size.w)
    local lCount = 0
    if type(popup.text)=="table" then
        for _,tBlock in pairs(popup.text) do
            for _,sLine in pairs(tBlock) do
                lCount = lCount + 1
                term.setCursorPos(popup.x+1, popup.y+lCount)
                draw.fText(sLine)
                draw.switchFGBG(colorMatch["popupFont"], colorMatch["popupBG"])
            end
            lCount = lCount + 1
            term.setCursorPos(popup.x+1, popup.y+lCount)
            term.write(sBuffer)
        end
    end
    --[[ Button(s) ]]
    local nItems = 0
    if type(popup.textBox) == "table" then
        nItems = #popup.textBox
    end
    draw.switchFGBG(colorMatch["special"], cosuConf.cAccentColor)
    if type(popup.button) == "table" then
        for nIndex,tB in pairs(popup.button) do
            term.setCursorPos(popup.x+tB.x,popup.y+tB.y)
            if tB.status or nIndex+nItems == tCursor.selectedItem then draw.switchFGBG() end
            term.write(tB.label)
            if tB.status or nIndex+nItems == tCursor.selectedItem then draw.switchFGBG() end
        end
    end
    --[[ TextBox ]]
    if type(popup.textBox) == "table" then
        draw.switchFGBG(colorMatch["special"], cosuConf.cAccentColor)
        for nIndex,tTB in pairs(popup.textBox) do
            term.setCursorPos(popup.x+tTB.x,popup.y+tTB.y)
            if tTB.status or nIndex == tCursor.selectedItem then draw.switchFGBG() end
            term.write((" "):rep(size.w-tTB.x+1))
            term.setCursorPos(popup.x+tTB.x,popup.y+tTB.y)
            term.write(tTB.input:sub(-size.w-tTB.x+1))
            if tTB.status or nIndex == tCursor.selectedItem then draw.switchFGBG() end
        end
        inProgress((tCursor.selectedItem > #popup.button))
    end
    --[[ List ]]
    if type(popup.list)=="table" then
        for _,list in pairs(popup.list) do
            local nPosX,nPosY=0,0
            draw.switchFGBG(colorMatch.text,colorMatch.popupFrame)
            --if tTB.status or nIndex == tCursor.selectedItem then draw.switchFGBG() end
            for y=1,list.size.y do
                term.setCursorPos(popup.x+list.x, popup.y+y+list.y-1)
                term.write((' '):rep(list.size.x+1))
            end
            for i,item in pairs(list.content) do
                if i>=list.scrolled then
                    if list.type == "sidebyside" then
                        term.setCursorPos(popup.x+list.x+nPosX, popup.y+list.y+nPosY)
                        draw.switchFGBG(
                            (i==list.selected) and colorMatch.special   or colorMatch.text,
                            (i==list.selected) and colorMatch.popupFont or colorMatch.popupFrame
                        )
                        term.write(item)
                        nPosX = nPosX+#item
                        if nPosX>list.size.x then
                            nPosY = nPosY+1
                            nPosX = 0
                        end
                    elseif list.type == "listed" then
                        term.setCursorPos(popup.x+list.x, popup.y+list.y+nPosY)
                        draw.switchFGBG(
                            (i==list.selected) and colorMatch.special   or colorMatch.text,
                            (i==list.selected) and colorMatch.popupFont or colorMatch.popupFrame
                        )
                        term.write(item..(' '):rep((list.size.x+1)-#item))
                        nPosY = nPosY+1
                        if nPosY>=list.size.y then
                            break
                        end
                    end
                end
            end
        end
    end
    --[[ Label ]]
    if type(popup.label)=="table" then
        for _,label in pairs(popup.label) do
            term.setCursorPos(popup.x+label.x, popup.y+label.y)
            local str = label.content
            if type(str) == "function" then str = str() end
            str = tostring(str)
            if type(label.fg)=="number" then
                str = "{&"..blits[label.fg or colorMatch.popupFont]..blits[label.bg or colorMatch.popupBG]..str
            end
            draw.fText(str)
        end
    end
end

function draw.dropdown(tList, nX, nY)
    --[[ Set size / breakdown ]]
    local tLineBreaks = {}
    local nW,nH = 0,0
    for i=1,#tList do
        for k,_ in pairs(tList[i]) do
            if #k+1 > nW then nW = #k+1 end
            nH = nH + 1
        end
        nH = nH + 1
        tLineBreaks[#tLineBreaks+1] = nH
    end tLineBreaks[#tLineBreaks] = nil
    --[[ Draw ]]
    draw.dropdownBG(nW, nH+1, nX, nY-1, tLineBreaks)
    draw.switchFGBG(colors.black, colors.lightGray)
    local nHOffset = 0
    nDropdownLength = 0
    for i=1,#tList do
        for k,v in pairs(tList[i]) do
            nHOffset = nHOffset+1
            nDropdownLength = nDropdownLength+1
            term.setCursorPos(nX+1, i+nHOffset+nY-1)
            local cBG = colorMatch["popupBG"]
            if nDropdownLength == tCursor.selectedItem then cBG = colorMatch["special"] end
            draw.switchFGBG(colors.black, cBG)
            term.write(k..(" "):rep(nW-#k-1))
            local sLastChar = " "
            term.write(sLastChar)
        end
    end
end

function draw.preview()
    local len,begin = w-2,1
    for _,tool in pairs(tToolbar) do
        len = len-(#tool.name+2)
        begin = begin+(#tool.name+2)
    end
    for name,_ in pairs(tWidgets) do
        len = len-(#name+1)
    end
    local str = ("visit consult.madefor.cc"):upper()
    if (#str+2) < len then
        term.setCursorPos(begin-1+(len-(#str+2))/2,1)
        draw.switchFGBG(cosuConf.cAccentColor, colorMatch.bg)
        term.write('\133')
        draw.switchFGBG(colorMatch.text, colorMatch.bg)
        term.write(str)
        draw.switchFGBG(cosuConf.cAccentColor, colorMatch.bg)
        term.write('\138')
    elseif (#str+2) < w then
        term.setCursorPos(w+1-(#str+2),h-1)
        term.setBackgroundColor(colorMatch.bg)
        term.setTextColor(colorMatch.special)
        term.write('[')
        term.setTextColor(colorMatch.keyword)
        term.write(str)
        term.setTextColor(colorMatch.special)
        term.write(']')
    end
end

function draw.toolbar()
    term.setCursorPos(1,1)
    term.setBackgroundColor(cosuConf.cAccentColor)
    term.clearLine()
    for _,contentCategory in pairs(tToolbar) do
        --[[ Last X pos / Set BG color ]]
        local nX,_ = term.getCursorPos()
        local cBGColor = cosuConf.cAccentColor
        if contentCategory.status then cBGColor = colors.gray end
        --[[ Draw categorys ]]
        if tActiveKeys[keys.leftAlt] then
            draw.switchFGBG(cBGColor, colorMatch["special"])
        else
            draw.switchFGBG(colorMatch["special"], cBGColor)
        end
        term.write(contentCategory.name:sub(1,1))
        draw.switchFGBG(colorMatch["special"], cBGColor)
        term.write(contentCategory.name:sub(2))
        term.setBackgroundColor(cosuConf.cAccentColor)
        term.write("  ")
        --[[ Setup pos ]]
        contentCategory.pos=nX-1
        contentCategory.length=#contentCategory.name+1
        --[[ Draw dropdown ]]
        if contentCategory.status then
            draw.dropdown(contentCategory.content, nX, 2)
            term.setCursorPos(nX+#contentCategory.name+2, 1)
        end
    end
    --[[ Widgets ]]
    local nLen = 1
    term.setCursorPos(w,1)
    draw.switchFGBG(cosuConf.cAccentColor, colorMatch.bg)
    term.write('\138')
    for name,meta in pairs(tWidgets) do
        draw.switchFGBG(meta.color, colorMatch.bg)
        term.setCursorPos(w-(nLen+#tostring(name)),1)
        nLen = nLen+#tostring(name)+1
        term.write(' '..name)
    end
    term.setCursorPos(w-nLen+1,1)
    draw.switchFGBG(cosuConf.cAccentColor, colorMatch.bg)
    term.write('\133')
end

local tInfobar = {
    { --[[ Left side ]]
        function()
            local sShowPath=sPath
            if sPath == "" then
                sShowPath="/*.lua"
            end
            if #sShowPath > w then
                sShowPath = sShowPath:sub(-w+1)
            elseif #sShowPath > w/2 then
                sShowPath = sShowPath:sub(-math.floor(w/2))
            end
            return cToStr(colorMatch.special,colorMatch.bg).." "..sShowPath..cToStr(colorMatch.bg,cosuConf.cAccentColor)..'\151'
        end
    },{ --[[ Right side ]]
    function() return cToStr(colorMatch.cAccentText).."Col "..cToStr(colorMatch.text)..tCursor.x.." "end,
    function() return cToStr(colorMatch.cAccentText).."Ln "..cToStr(colorMatch.text)..tCursor.y..cToStr(colorMatch.cAccentText).."," end,
    function()
            --[[ Calculate size ]]
            local size,sizeType = 0,""
            for _,v in pairs(tContent) do
                size = size+#v+1
            end
            --[[ Size in kB/Byte as string ]]
            if math.floor(size/1000) == 0 then
                size = tostring(size-1)
                sizeType = "Byte"
            else
                local sNumber = tostring((size-1)/1000)
                local nX = sNumber:find("%.")
                if nX then sNumber = sNumber:sub(1,nX+2) end
                size = sNumber
                sizeType = "kB"
            end
            return cToStr(colorMatch.special).."["..cToStr(colorMatch.text)..size..cToStr(colorMatch.cAccentText)..sizeType..cToStr(colorMatch.special).."]"
        end,
    }
}
function draw.infobar()
    local nX = 1
    term.setCursorPos(nX,h)
    term.setBackgroundColor(cosuConf.cAccentColor)
    term.clearLine()
    for _,info in pairs(tInfobar[1]) do
        term.setCursorPos(nX,h)
        draw.fText(info())
        nX = term.getCursorPos()+1
    end
        
    local nSubX = w+2
    for _,content in pairs(tInfobar[2]) do
        local line = content()
        nSubX = nSubX-fLen(line)-1
        if nSubX < nX then break end
        term.setCursorPos(nSubX,h)
        draw.fText(line)
    end
end

function draw.handler()
    term.setCursorBlink(false)
    term=fTerm

    draw.content()
    --[[ bars ]]
    draw.toolbar()
    draw.infobar()
    --[[ Draw popup if exists ]]
    for i=#tPopup,1,-1 do
        draw.popup(tPopup[i],i)
    end

    if bPreview then
        draw.preview()
    end

    term=nTerm
    fTerm.render()
    term.setCursorBlink(true)
end


--[[ +++ Input functions +++ ]]
function input.insert.cursorVertical(sWay, bJump)
    if sWay == "up" then
        if tCursor.y > 1 then
            if #tContent[tCursor.y-1] >= tCursor.lastX then
                tCursor.x = tCursor.lastX
            else
                tCursor.x = #tContent[tCursor.y-1]+1
                if tCursor.x < 1 then tCursor.x = 1 end
            end
            if tCursor.y-tScroll.y+1 < 3 or bJump  then
                tScroll.y = tScroll.y - 1
            end
            tCursor.y = tCursor.y - 1
        end
    elseif sWay == "down" then
        if tCursor.y+1 <= #tContent then
            if #tContent[tCursor.y+1] >= tCursor.lastX then
                tCursor.x = tCursor.lastX
            else
                tCursor.x = #tContent[tCursor.y+1]+1
                if tCursor.x < 1 then tCursor.x = 1 end
            end
            if tCursor.y-tScroll.y+1 > h-2 or bJump then
                tScroll.y = tScroll.y + 1
            end
            tCursor.y = tCursor.y + 1
        end
    end
end

function input.insert.cursorHorizontal(sWay, bJump)
    if sWay == "left" then
        if tCursor.x > 1 then
            repeat
                tCursor.x = tCursor.x - 1
                tCursor.lastX = tCursor.x
                if tCursor.x-tScroll.x+1 < 1 then
                    tScroll.x = tScroll.x - 1
                end
            until not bJump or tCursor.x <= 1 or tContent[tCursor.y]:sub(tCursor.x-1,tCursor.x-1):match('[ %(%)%.]')
        elseif tCursor.x == 1 and tCursor.y ~= 1 then
            tCursor.y = tCursor.y - 1
            tCursor.x = #tContent[tCursor.y] + 1
            tCursor.lastX = tCursor.x
            if tCursor.x < 1 then tCursor.x = 1 end
            if tCursor.y-tScroll.y < 1 then
                tScroll.y = tScroll.y - 1
            end
        end
    elseif sWay == "right" then
        if tCursor.x <= #tContent[tCursor.y] then
            repeat
                tCursor.x = tCursor.x + 1
                tCursor.lastX = tCursor.x
                if tCursor.x-tScroll.x+1 >= w then
                    tScroll.x = tScroll.x + 1
                end
            until not bJump or tCursor.x >= #tContent[tCursor.y] or tContent[tCursor.y]:sub(tCursor.x-1,tCursor.x-1):match('[ %(%)%.]')
        elseif tCursor.y < #tContent then
            tCursor.x = 1
            tCursor.lastX = tCursor.x
            tCursor.y = tCursor.y + 1
            if tCursor.y-tScroll.y > h-2 then
                tScroll.y = tScroll.y + 1
            end
        end
    end
end

function input.insert.char(sChar,bCloseBrackets)
    if type(sChar)~="string" then
        return
    end
    local sSubChar=sChar:sub(#sChar,#sChar)
    if bCloseBrackets then
        if sSubChar=='(' then
            sSubChar=')'
        elseif sSubChar=='[' then
            sSubChar=']'
        elseif sSubChar=='{' then
            sSubChar='}'
        else
            sSubChar=''
        end
        sChar=sChar..sSubChar
    end
    if tCursor.y-tScroll.y+1 < 1 then
        tScroll.y = tCursor.y - math.floor(h/2)
    end
    local sLine = tContent[tCursor.y]
    if sChar == "\000" then
        sChar = '?'
    end
    if type(tContent[tCursor.y])=="nil" then tContent[tCursor.y]="" end
    tContent[tCursor.y] = string.sub(sLine, 1, tCursor.x - 1) .. sChar .. string.sub(sLine, tCursor.x)
    for i=1,#sChar do
        input.insert.cursorHorizontal("right")
    end
    if bCloseBrackets then
        for i=1,#sSubChar do
            input.insert.cursorHorizontal("left")
        end
    end
    bSaved = false
end

function input.insert.cursorDelete()
    if #tContent > tCursor.y and tCursor.x > #tContent[tCursor.y] then
        tContent[tCursor.y] = tContent[tCursor.y] .. tContent[tCursor.y+1]
        table.remove(tContent,tCursor.y+1)
    else
        local sLine = tContent[tCursor.y]
        if type(sLine) == "nil" then sLine = "" end 
        tContent[tCursor.y] = string.sub(sLine, 1, tCursor.x-1) .. string.sub(sLine, tCursor.x+1)
    end
    bSaved = false
end

function input.insert.cursorBackspace()
    if not (tCursor.y == 1 and tCursor.x == 1) then
        local lastY = tCursor.y
        local sLine = tContent[tCursor.y]
        if sLine:sub(tCursor.x-cosuConf.nTabSpace, tCursor.x-1) == (' '):rep(cosuConf.nTabSpace) then
            tContent[tCursor.y] = string.sub(sLine, 1, tCursor.x-cosuConf.nTabSpace-1) .. string.sub(sLine, tCursor.x)
            for i=1,cosuConf.nTabSpace-1 do
                input.insert.cursorHorizontal("left")
            end
        elseif tCursor.x > 1 then
            tContent[tCursor.y] = string.sub(sLine, 1, tCursor.x - 2) .. string.sub(sLine, tCursor.x)
        end
        input.insert.cursorHorizontal("left")
        if lastY ~= tCursor.y then
            if tCursor.y > #tContent-3 then tScroll.y = tScroll.y end
            tContent[tCursor.y] = tContent[tCursor.y] .. tContent[tCursor.y+1]
            table.remove(tContent,tCursor.y+1)
        end
        bSaved = false
    end
end

function input.insert.cursorEnter()
    local sLine = tContent[tCursor.y]
    local sSpaces = ""
    if type(sLine) == "nil" then sLine = "" end
    local nCounter = 0
    for i=1,#sLine do
        if sLine:sub(i,i)~=" " then
            break
        end
        nCounter=nCounter+1
    end
    sSpaces = ((' '):rep(cosuConf.nTabSpace)):rep(math.floor(nCounter/4))
    tContent[tCursor.y] = sLine:sub(1, tCursor.x-1)
    table.insert(tContent, tCursor.y+1, sSpaces..sLine:sub(tCursor.x))
    input.insert.cursorVertical("down")
    tCursor.x = #sSpaces+1
    bSaved = false
end

function input.insert.mouseClick(nButton, nX, nY)
    if nButton == 1 then
        if nY == 1 then
            input.toolbar.mouseClick(nButton, nX, nY)
        elseif nY < h then
            mode = "insert"
            category.reset()
            tCursor.y = nY + tScroll.y-1
            if tCursor.y > #tContent then tCursor.y = #tContent end
            tCursor.x = nX + tScroll.x
            if tCursor.x > #tContent[tCursor.y] then tCursor.x = #tContent[tCursor.y]+1 end
            tCursor.lastX = tCursor.x

            if tActiveKeys["CTRL"] then
                local line = tContent[tCursor.y+tScroll.y]
                if line:find('\"') or line:find('\'') then
                    local nXStart,nXEnd
                    for i=tCursor.x+tScroll.x,1,-1 do
                        if line:sub(i,i) == '\"' or line:sub(i,i) == '\'' then
                            nXStart = i
                            break
                        end
                    end
                    for i=tCursor.x+tScroll.x,#line,1 do
                        if line:sub(i,i) == '\"' or line:sub(i,i) == '\'' then
                            nXEnd = i
                            break
                        end
                    end
                    if nXStart and nXEnd then
                        openLink("create", line:sub(nXStart,nXEnd))
                    end
                end
            end
        end
    end
end

function input.menu.cursorEnter()
    if #tPopup > 0 then
        local nItems = 0
        if type(tPopup[1].textBox) == "table" then
            nItems = #tPopup[1].textBox
        end
        if type(tPopup[1].button) == "table" then
            for nIndex,tB in pairs(tPopup[1].button) do
                if tCursor.selectedItem == nItems+nIndex then
                    if type(tB.func) == "function" then
                        tB.func(tPopup[1], tB)
                    end
                    break
                end
            end
        end
        return
    end
end

function input.menu.char(sChar)
    if #tPopup > 0 and type(tPopup[1].textBox) == "table" then
        for nIndex,tTB in pairs(tPopup[1].textBox) do
            if tCursor.selectedItem == nIndex then
                if sChar == "\000" then
                    sChar = '?'
                end
                tTB.input = tTB.input..sChar
                break
            end
        end
        return
    end
end

function input.menu.cursorBackspace()
    if #tPopup > 0 and type(tPopup[1].textBox) == "table" then
        for nIndex,tTB in pairs(tPopup[1].textBox) do
            if tCursor.selectedItem == nIndex then
                tTB.input = tTB.input:sub(1,#tTB.input-1)
                break
            end
        end
        return
    end
end

function input.menu.cursorHorizontal(sWay)   
    local nItems = 0
    if tPopup[1].blockControlls then return end
    if type(tPopup[1].textBox) == "table" then
        nItems = #tPopup[1].textBox
    end
    local nLen = #(tPopup[1].button or "")
    if sWay == "left" then
        if tCursor.selectedItem > 1 then
            tCursor.selectedItem = tCursor.selectedItem-1
        elseif cosuConf.bJumpAtEndToBegin then
            tCursor.selectedItem = nLen+nItems
        end
    elseif sWay == "right" then
        if tCursor.selectedItem < nLen+nItems then
            tCursor.selectedItem = tCursor.selectedItem+1
        elseif cosuConf.bJumpAtEndToBegin then
            tCursor.selectedItem = 1
        end
    end
end

function input.menu.cursorVertical(sWay)
    if sWay == "up" then
        input.menu.cursorHorizontal("left")
    elseif sWay == "down" then
        input.menu.cursorHorizontal("right")
    end
end

function input.menu.mouseScroll(nScroll)
    if nScroll < 0 then
        input.menu.cursorHorizontal("left")
    elseif nScroll > 0 then
        input.menu.cursorHorizontal("right")
    end
end

function input.menu.key(nID,bPressed)
    if type(tPopup[1])=="table" and type(tPopup[1].key)=="function" then
        tPopup[1]:key(nID,bPressed)
    end
end

function input.menu.mouseClick(nButton, nX, nY)
    if nButton == 1 then
        --[[ Button ]]
        local nItems = 0
        if type(tPopup[1].textBox) == "table" then
            nItems = #tPopup[1].textBox
        end
        if type(tPopup[1].button) == "table" then
            for nIndex,tB in pairs(tPopup[1].button) do
                if nX >= tPopup[1].x+tB.x and nX < tPopup[1].x+tB.x+#tB.label and nY == tPopup[1].y+tB.y then
                    if (cosuConf.bDoubleClickButton and tCursor.selectedItem==nIndex+nItems) or not cosuConf.bDoubleClickButton then
                        tB.func(tPopup[1], tB)
                    end
                    tCursor.selectedItem = nIndex+nItems
                    return
                end
            end
        end
        --[[ TextBox ]]
        if type(tPopup[1].textBox) == "table" then
            for nIndex,tTB in pairs(tPopup[1].textBox) do
                if nX >= tPopup[1].x+tTB.x and nX < tPopup[1].x+tTB.x+tPopup[1].size.x and nY == tPopup[1].y+tTB.y then
                   tCursor.selectedItem = nIndex
               end
            end
        end
        --[[ List ]]
        if type(tPopup[1].list)=="table" then
            for _,list in pairs(tPopup[1].list) do
                if nX >= tPopup[1].x+list.x and nX <= tPopup[1].x+list.x+list.size.x then
                    if nY >= tPopup[1].y+list.y and nY < tPopup[1].y+list.y+list.size.y then
                        local nSubX,nSubY = nX-(tPopup[1].x-1+list.x), nY-(tPopup[1].y-1+list.y)
                        if list.type == "sidebyside" then
                            list.selected = nSubX + (nSubY-1)*(list.size.x+1)
                        elseif list.type == "listed" and nSubY>=1 and nSubY<=#list.content then
                            list.selected = nSubY
                        end
                        if list.changed then
                            list.changed(tPopup[1], list)
                        end
                    end
                end
            end
        end
        --[[ Close? ]]
        if tPopup[1].closeAtNoFokus then
            if nX < tPopup[1].x or nX >= tPopup[1].x+2+tPopup[1].size.x
            or nY < tPopup[1].y or nY >= tPopup[1].y+2+tPopup[1].size.y then
                if type(tPopup[1].closeAtNoFokus)=="function" then
                    tPopup[1]:closeAtNoFokus(1)
                end
                tPopup[1] = nil
            end
        end
    end
end

function input.toolbar.cursorEnter()
    local nCategoy = category.getCurrentIndex()
    if nCategoy > 0 then
        category.items(nCategoy, true)
    end
end

function input.toolbar.cursorHorizontal(sWay)
    local bSelected
    for k,_ in pairs(tToolbar) do
        if tToolbar[k].status then
            bSelected = k
        end
    end
    tCursor.selectedItem = 1
    tToolbar[bSelected].status = false
    if sWay == "left" then
        if bSelected > 1 then
            tToolbar[bSelected-1].status = true
        elseif cosuConf.bJumpAtEndToBegin then
            tToolbar[#tToolbar].status = true
        end
    elseif sWay == "right" then
        if bSelected < #tToolbar then
            tToolbar[bSelected+1].status = true
        elseif cosuConf.bJumpAtEndToBegin then
            tToolbar[1].status = true
        end
    end
end

function input.toolbar.cursorVertical(sWay)
    local nCategoy = category.getCurrentIndex()
    if nCategoy > 0 then 
        local nItems = category.items(nCategoy)
        if sWay == "up" then
            if tCursor.selectedItem > 1 then
                tCursor.selectedItem = tCursor.selectedItem-1
            else
                tCursor.selectedItem = nItems
            end
        elseif sWay == "down" then
            if tCursor.selectedItem < nItems then
                tCursor.selectedItem = tCursor.selectedItem+1
            else
                tCursor.selectedItem = 1
            end
        end
    end
end

function input.toolbar.mouseScroll(nScroll)
    local nCategoy = category.getCurrentIndex()
    if nCategoy > 0 then 
        local nLength = category.items(nCategoy)
        if ((tCursor.selectedItem > 1 and nScroll == (-1)) or (tCursor.selectedItem < nLength and nScroll == 1)) then
            tCursor.selectedItem = tCursor.selectedItem + nScroll
        --[[else
            if tCursor.selectedItem >= nLength then
                tCursor.selectedItem = 1
            else
                tCursor.selectedItem = nLength
            end]]
        end
    end
end

function input.toolbar.mouseClick(nButton, nX, nY)
    if nY == 1 then
        local isUsed = false
        for _,contentCategory in pairs(tToolbar) do
            if (nButton == 1 and nX >= contentCategory.pos and nX <= contentCategory.pos+contentCategory.length) then
                tCursor.selectedItem = 1
                contentCategory.status = not contentCategory.status
                if contentCategory.status then isUsed = true end
            else
                contentCategory.status = false
            end
        end
        local nLen = 0
        for sName,fWidget in pairs(tWidgets) do
            local nBegin = w-(nLen+#tostring(sName))
            if nX>=nBegin and nX<nBegin+#sName then
                if type(fWidget)=="table" and type(fWidget.func)=="function" then fWidget.func() end
                break
            end
            nLen = nLen+#tostring(sName)+1
        end
        if isUsed then mode = "toolbar"
        else mode = "insert" end
    else
        local nCategory,xPos = category.getCurrentIndex()
        if nCategory > 0 then
            local nItems,nLength = category.items(nCategory, _, true)
            if nX >= xPos and nX <= xPos+nLength then
                if nY < nItems+3 then
                    local nItemCount = 0
                    for _,tItemHolder in pairs(tToolbar[nCategory].content) do
                        nItemCount = nItemCount+1
                        for _,item in pairs(tItemHolder) do
                            nItemCount = nItemCount + 1
                            if nY-1 == nItemCount then
                                category.reset()
                                item()
                            end
                        end
                    end
                else
                    category.reset()
                end
            else
                category.reset()
            end
            return
        end
        input.insert.mouseClick(nButton, nX, nY)
    end
end

function input.insertAuto.cursorVertical(sWay)
    if sWay == "up" then
        if tCursor.autoListY > 0 then
            tCursor.autoListY = tCursor.autoListY - 1
        else
            input.insert.cursorVertical("up")
        end
    elseif sWay == "down" then
        if tCursor.autoListY < #tAutoCompleteList-1 then
            tCursor.autoListY = tCursor.autoListY + 1
        else
            input.insert.cursorVertical("down")
        end
    end
end

function input.insertAuto.cursorHorizontal(sWay)
    input.insert.cursorHorizontal(sWay)
end

function input.insertAuto.char(sChar)
    input.insert.char(sChar)
end

function input.insertAuto.cursorDelete()
    input.insert.cursorDelete()
end

function input.insertAuto.cursorBackspace()
    input.insert.cursorBackspace()
end

function input.insertAuto.cursorEnter()
    input.insert.cursorEnter()
end

function input.insertAuto.mouseScroll(nScroll)
    local sWay = "up"
    if nScroll == 1 then sWay = "down" end
    input.insertAuto.cursorVertical(sWay, false)
end

function input.insertAuto.mouseClick(nButton, nX, nY)
    if nButton == 1 then
        if nX >= tCursor.x-tScroll.x and nY >= tCursor.y-tScroll.y+1 then
            local height = #tAutoCompleteList
            if #tAutoCompleteList-tCursor.autoListY < height then
                height = #tAutoCompleteList-tCursor.autoListY
            end
            local longestLine = 3
            for i=1,height do
                local currentLine = #tAutoCompleteList[i+tCursor.autoListY]
                if currentLine > longestLine then
                    longestLine = currentLine
                end
            end
            if nX <= tCursor.x-tScroll.x+longestLine-1 and nY <= tCursor.y-tScroll.y+height then
                input.insert.char(tAutoCompleteList[(nY-tCursor.y-tScroll.y)+tCursor.autoListY])
            else
                input.insert.mouseClick(nButton, nX, nY)
            end
        else
            input.insert.mouseClick(nButton, nX, nY)
        end
    else
        input.insert.mouseClick(nButton, nX, nY)
    end
end

function input.insert.mouseScroll(nScroll)
    if ((tScroll.y > 0 and nScroll == (-1)) or (tScroll.y+h-2 <= #tContent-1 and nScroll == 1)) then
        tScroll.y = tScroll.y + nScroll
    end
end

function input.handle.insert(event)
    tActiveKeys[event[2]] = (event[1] == "key")
    if event[2] == keys.leftAlt then
        tActiveKeys[keys.leftAlt] = (event[1] == "key")
        return
    end if event[2] == keys.leftCtrl or event[2] == keys.rightCtrl then
        tActiveKeys["CTRL"] = (event[1] == "key")
        return
    end
    if event[1] == "key" then
        if event[2] == keys.f5 and bLvlOS and not event[4] then
            os.queueEvent("key", {event[2], event[3], true})
            return
        end
        if type(input.menu.key)=="function" then
            input.menu.key(event[2],event[3])
        end
        -- For CraftOS-PC
        if tActiveKeys[keys.leftAlt] and mode ~= "menu" then
            local sKey = keys.getName(event[2])
            if #sKey == 1 then
                category.openByChar(sKey)
                return
            end
        end

        if event[2] == cosuConf.tKeyboard.up and type(input[mode].cursorVertical) == "function" then
            input[mode].cursorVertical("up", tActiveKeys["CTRL"])
        elseif event[2] == cosuConf.tKeyboard.down and type(input[mode].cursorVertical) == "function" then
            input[mode].cursorVertical("down", tActiveKeys["CTRL"])
        elseif event[2] == cosuConf.tKeyboard.left and type(input[mode].cursorHorizontal) == "function" then
            input[mode].cursorHorizontal("left", tActiveKeys["CTRL"])
        elseif event[2] == cosuConf.tKeyboard.right and type(input[mode].cursorHorizontal) == "function" then
            input[mode].cursorHorizontal("right", tActiveKeys["CTRL"])
        elseif event[2] == cosuConf.tKeyboard.tab then
            if type(input[mode].tab) == "function" then
                input[mode].tab()
            elseif mode == "insert" then
                input[mode].char((' '):rep(cosuConf.nTabSpace))
            elseif mode == "insertAuto" and tAutoCompleteList[tCursor.autoListY+1] then
                input.insert.char(tAutoCompleteList[tCursor.autoListY+1],true)
                tCursor.autoListY = 0
            end
        elseif event[2] == cosuConf.tKeyboard.delete and type(input[mode].cursorDelete) == "function" then
            input[mode].cursorDelete()
        elseif event[2] == cosuConf.tKeyboard.backspace and type(input[mode].cursorBackspace) == "function" then
            input[mode].cursorBackspace()
        elseif event[2] == cosuConf.tKeyboard.enter and type(input[mode].cursorEnter) == "function" then
            input[mode].cursorEnter()
        
        elseif event[2] == cosuConf.tKeyboard.F_Help and mode ~= "menu" then
            help("create")
        elseif event[2] == cosuConf.tKeyboard.F_Run then
            file("execute")
        else
            -- CTRL combinations
            if tActiveKeys["CTRL"] then
                local sExecute = ""
                for _,key in pairs(cosuConf.tKeyboard.CTRL) do
                    if type(key[2])=="number" and tActiveKeys[key[2]] then
                        sExecute = key[1]
                        break
                    elseif type(key[2])=="table" then
                        sExecute = key[1]
                        for _,subkey in pairs(key[2]) do
                            if not tActiveKeys[subkey] then
                                sExecute = ""
                                break
                            end
                        end
                        if #sExecute > 0 then break end
                    end
                end
                if sExecute == "NewFile" then       file("create", "new")
                elseif sExecute == "SaveAs" then    file("create", "save as")
                elseif sExecute == "Save" then      file("create", "save")
                end
                tActiveKeys["CTRL"] = false
            end
            -- Widgets
            for _,widget in pairs(tWidgets) do
                if widget.shourtcut == event[2] and type(widget.func) == "function" then
                    widget.func()
                end
            end
        end

        if tCursor.x-tScroll.x < 1 or tCursor.x-tScroll.x > w then
            tScroll.x = tCursor.x - w + 2
            if tScroll.x < 1 then tScroll.x = 0 end
        end
    end
end

function input.handle.mouse(event)
    if event[1] == "mouse_click" then
        if type(input[mode].mouseClick) == "function" then
            input[mode].mouseClick(event[2], event[3], event[4])
        end
    elseif event[1] == "mouse_scroll" and type(input[mode].mouseScroll) == "function" then
        input[mode].mouseScroll(event[2])
    end
end

function init()
    --[[ Check args ]]
    if #tArgs > 0 then
        local arg = tArgs[1]
        if tArgs[1] == "--preview" or tArgs[1] == "-p" then
            bPreview = true
            arg = tArgs[2]
        elseif tArgs[2] == "--preview" or tArgs[2] == "-p" then
            bPreview = true
        end
        --[[ Collect file informations ]]
        if arg then
            sPath = shell.resolve(arg)
            bReadOnly = fs.isReadOnly(sPath)
            if fs.exists(sPath) then
                if fs.isDir(sPath) then
                    printError("Cannot consult a directory.")
                    return false
                end
                local file = fs.open(sPath, 'r')
                local sLine = file.readLine()
                while sLine do
                    tContent[#tContent+1] = sLine
                    sLine = file.readLine()
                end
                file.close()
            else
                table.insert(tContent, "")
                if sPath:sub(#sPath-3) ~= ".lua" then
                    sPath = sPath..".lua"
                end
            end
        else
            table.insert(tContent, "")
        end
    else
        table.insert(tContent, "")
    end
    --[[ Options ]]
    if #tContent == 0 then
        table.insert(tContent, "")
    end
    options("load")
    swapColors()
    if bLvlOS then
        local title = "CONSULT - "..fs.getName(sPath)
        if tContent[1] == "" then
            title = "CONSULT"
        end
        LevelOS.setTitle(title)
        LevelOS.self.window.icon = {'\138', "9"}
    elseif multishell then
        multishell.setTitle(multishell.getCurrent(), "[cosu]-"..sPath)
    end
    return true
end

local function main()
    --[[ Input ]]
    local event = { os.pullEventRaw() }

    tCursor.lastY = tCursor.y
    inProgress(true)

    --[[ Set mode ]]
    if #tPopup > 0 then
        mode = "menu"
    elseif mode ~= "toolbar" and #tAutoCompleteList > 0 then
        mode = "insertAuto"
    elseif mode ~= "toolbar" then
        mode = "insert"
    end

    if event[1] == "char" then
        -- For CCEmuX
        if tActiveKeys[keys.leftAlt] and mode ~= "menu" then
            category.openByChar(event[2])
        else
            if mode == "toolbar" then
                category.reset()
            end
            if type(input[mode].char) == "function" then
                input[mode].char(event[2])
            end
        end
    elseif event[1]:find("key") then
        input.handle.insert(event)
    elseif event[1]=="paste" then
        input.insert.char(event[2])
    elseif event[1]:find("mouse") then
        input.handle.mouse(event)
    elseif event[1] == "term_resize" then
        sleep()
        w,h = term.getSize()
        fTerm.clear()
    elseif event[1] == "terminate" then
        running = 0
    end

    draw.handler()
    checkAutoComplete()

    if mode ~= "menu" and (mode == "insert" or mode == "insertAuto") then
        if mode == "insertAuto" then
            if  type(tAutoCompleteList)=="table" and #tAutoCompleteList>0 and tAutoCompleteList[1]~="" then
                draw.autocomplete()
            end
        end
        draw.cursor()
        inProgress(false)
    else
        inProgress(true)
    end
end


--[[ +++ Actual start of the program LOL +++ ]]
if not init() then
    return false
end
draw.handler()
parallel.waitForAny(
    function()
        while running == true do
            main()
        end
    end,
    --[[ BG tasks ]]
    function()
        --[[ Check updates ]]
        if update("check") then
            for i,category in pairs(tToolbar) do
                if category.name == "Info" then
                    tToolbar[i].content[1]["Update"]=function() update("create") end
                    tWidgets['\019'] = {
                        ["name"]="update",
                        ['color']=term.isColor() and colors.red or colors.lightGray,
                        ["func"]=function() update("create") end,
                        ["shourtcut"]=-1
                    }
                end
            end
        end
        while running==true do
            for _,sLine in pairs(tContent) do
                        if sLine:find("require") or sLine:find("os.loadAPI") or sLine:find("peripheral") then
                            loadAPIVirtual(sLine)
                        end
            end
            if #tContent > 100 then
                        sleep(4)
            else sleep(0.5)
            end
        end
    end
)


--[[ Clear mess ]]
local sDir = '/'..fs.getDir(shell.getRunningProgram())..'/'
local sCurID = tostring( (not bLvlOS and type(multishell)~="nil") and multishell.getCurrent() or "" )
fs.delete(sDir..".tmp"..sCurID)
swapColors()
term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
shell.run("clear")

--[[ Msg if something went wrong  ]]
if type(running) == "number" then
    if not bSaved then
        local type = "closed"
        if running == 0 then
           type = "terminated"
        end
        term.write("Program was "..type.." without saving")
        if fs.getName(sPath) ~= "root" and fs.getName(sPath) ~= ""  then
            print() print("\""..fs.getName(sPath).."\"!")
        else
            print(" file!")
        end
        sleep(0.5)
    end
end
