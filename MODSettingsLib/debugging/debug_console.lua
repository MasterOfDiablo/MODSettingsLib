-- File: debugging/debug_console.lua
-- Author: MasterOfDiablo
-- Description: Provides an in-game debug console for executing commands and viewing logs.
-- Version: 1.0.0

local DebugConsole = {}
DebugConsole.__index = DebugConsole

-- Dependencies
local ErrorLogger = require("debugging/error_logger")
local SettingsManager = require("core/settings_manager")
local ProfilesManager = require("profiles/profiles_manager")

-- Constants
DebugConsole.CONSOLE_WINDOW_NAME = "MODSettingsLib_DebugConsoleWindow"

-- Control References
local consoleWindow
local inputBox
local outputArea

-- Initialization flag
local isInitialized = false

-- Logging
local function log(message)
    ErrorLogger:logInfo("[DebugConsole] " .. message)
end

-- Error handling
local function handleError(message)
    ErrorLogger:logError("[DebugConsole] " .. message)
    DebugConsole:printOutput("[ERROR] " .. message)
end

--[[
    Function: initialize
    Description: Initializes the debug console UI and event handlers.
]]
function DebugConsole:initialize()
    if isInitialized then
        return
    end

    -- Create the console window
    consoleWindow = WINDOW_MANAGER:CreateTopLevelWindow(DebugConsole.CONSOLE_WINDOW_NAME)
    consoleWindow:SetDimensions(600, 400)
    consoleWindow:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    consoleWindow:SetHidden(true)
    consoleWindow:SetMouseEnabled(true)
    consoleWindow:SetMovable(true)
    consoleWindow:SetClampedToScreen(true)
    consoleWindow:SetResizeHandleSize(0)
    consoleWindow:SetDrawLayer(DL_OVERLAY)
    consoleWindow:SetDrawTier(DT_HIGH)
    consoleWindow:SetHandler("OnMoveStop", function()
        -- Save window position if needed
    end)

    -- Create a backdrop
    local backdrop = WINDOW_MANAGER:CreateControl(nil, consoleWindow, CT_BACKDROP)
    backdrop:SetAnchor(TOPLEFT, consoleWindow, TOPLEFT, 0, 0)
    backdrop:SetAnchor(BOTTOMRIGHT, consoleWindow, BOTTOMRIGHT, 0, 0)
    backdrop:SetEdgeTexture("EsoUI/Art/Tooltips/tooltip_backdrop.dds", 8, 8)
    backdrop:SetCenterTexture("EsoUI/Art/Tooltips/tooltip_center.dds")
    backdrop:SetInsets(12, 12, 12, 12)
    backdrop:SetColor(0, 0, 0, 0.85)

    -- Create the output area (multi-line read-only edit box)
    outputArea = WINDOW_MANAGER:CreateControl(nil, consoleWindow, CT_EDITBOX)
    outputArea:SetAnchor(TOPLEFT, consoleWindow, TOPLEFT, 10, 10)
    outputArea:SetAnchor(BOTTOMRIGHT, consoleWindow, BOTTOMRIGHT, -10, -50)
    outputArea:SetFont("ZoFontWinH4")
    outputArea:SetMaxInputChars(0)  -- Unlimited
    outputArea:SetText("")
    outputArea:SetHandler("OnTextChanged", function()
        -- Prevent manual editing
        outputArea:SetText(outputArea:GetText())
    end)
    outputArea:SetEditEnabled(false)  -- Read-only

    -- Create the input box
    inputBox = WINDOW_MANAGER:CreateControl(nil, consoleWindow, CT_EDITBOX)
    inputBox:SetAnchor(BOTTOMLEFT, consoleWindow, BOTTOMLEFT, 10, -10)
    inputBox:SetAnchor(BOTTOMRIGHT, consoleWindow, BOTTOMRIGHT, -10, -10)
    inputBox:SetHeight(30)
    inputBox:SetFont("ZoFontWinH4")
    inputBox:SetMaxInputChars(0)  -- Unlimited
    inputBox:SetText("")
    inputBox:SetHandler("OnTextChanged", function()
        -- Handle real-time validation if needed
    end)
    inputBox:SetHandler("OnEnterPressed", function(control)
        local command = control:GetText()
        control:SetText("")
        DebugConsole:executeCommand(command)
    end)

    -- Create a close button
    local closeButton = WINDOW_MANAGER:CreateControl(nil, consoleWindow, CT_BUTTON)
    closeButton:SetAnchor(TOPRIGHT, consoleWindow, TOPRIGHT, -10, 10)
    closeButton:SetDimensions(30, 30)
    closeButton:SetText("X")
    closeButton:SetNormalFont("ZoFontWinH4")
    closeButton:SetHandler("OnClicked", function()
        consoleWindow:SetHidden(true)
    end)

    -- Register slash command to toggle the debug console
    SLASH_COMMANDS["/msldebug"] = function()
        if consoleWindow:IsHidden() then
            consoleWindow:SetHidden(false)
            DebugConsole:printOutput("Debug Console Opened.")
        else
            consoleWindow:SetHidden(true)
            DebugConsole:printOutput("Debug Console Closed.")
        end
    end

    isInitialized = true
    log("Debug console initialized.")
end

--[[
    Function: printOutput
    Description: Appends a message to the output area.
    Parameters:
        - message (string): The message to display.
]]
function DebugConsole:printOutput(message)
    local currentText = outputArea:GetText()
    local newText = currentText .. message .. "\n"
    outputArea:SetText(newText)
    -- Scroll to the bottom
    outputArea:ScrollToEnd()
end

--[[
    Function: executeCommand
    Description: Parses and executes a debugging command.
    Parameters:
        - command (string): The command entered by the user.
]]
function DebugConsole:executeCommand(command)
    DebugConsole:printOutput("> " .. command)
    local args = {}
    for word in string.gmatch(command, "%S+") do
        table.insert(args, word)
    end
    local cmd = table.remove(args, 1)
    if not cmd then
        DebugConsole:printOutput("No command entered.")
        return
    end

    if cmd == "help" then
        DebugConsole:printOutput("Available Commands:")
        DebugConsole:printOutput("  help - Show this help message.")
        DebugConsole:printOutput("  listsettings - List all registered settings.")
        DebugConsole:printOutput("  listprofiles - List all profiles.")
        DebugConsole:printOutput("  getsetting <modName>.<settingKey> - Get the value of a setting.")
        DebugConsole:printOutput("  setsetting <modName>.<settingKey> <value> - Set the value of a setting.")
        DebugConsole:printOutput("  exportsettings - Export all settings to a file.")
        DebugConsole:printOutput("  importsettings <filePath> - Import settings from a file.")
        DebugConsole:printOutput("  reload - Reload MODSettingsLib.")
    elseif cmd == "listsettings" then
        local settings = SettingsManager:getAllSettings()
        for key, value in pairs(settings) do
            DebugConsole:printOutput(string.format("%s = %s", key, tostring(value)))
        end
    elseif cmd == "listprofiles" then
        local profiles = ProfilesManager:getAllProfiles()
        for _, profileName in ipairs(profiles) do
            local activeMarker = (profileName == ProfilesManager:getActiveProfile()) and " (Active)" or ""
            DebugConsole:printOutput(profileName .. activeMarker)
        end
    elseif cmd == "getsetting" then
        local settingKey = table.remove(args, 1)
        if not settingKey then
            DebugConsole:printOutput("Usage: getsetting <modName>.<settingKey>")
            return
        end
        local modName, key = string.match(settingKey, "^(.-)%.([^%.]+)$")
        if not modName or not key then
            DebugConsole:printOutput("Invalid setting key format. Use <modName>.<settingKey>")
            return
        end
        local value = SettingsManager:getSetting(modName, key)
        DebugConsole:printOutput(string.format("%s = %s", settingKey, tostring(value)))
    elseif cmd == "setsetting" then
        local settingKey = table.remove(args, 1)
        local value = table.concat(args, " ")
        if not settingKey or not value then
            DebugConsole:printOutput("Usage: setsetting <modName>.<settingKey> <value>")
            return
        end
        local modName, key = string.match(settingKey, "^(.-)%.([^%.]+)$")
        if not modName or not key then
            DebugConsole:printOutput("Invalid setting key format. Use <modName>.<settingKey>")
            return
        end
        -- Attempt to convert value to appropriate type
        local settingMetadata = SettingsManager:getSettingMetadata(modName, key)
        if not settingMetadata then
            DebugConsole:printOutput("Setting not found: " .. settingKey)
            return
        end
        local typedValue
        if settingMetadata.settingType == "boolean" then
            typedValue = (value:lower() == "true")
        elseif settingMetadata.settingType == "number" then
            typedValue = tonumber(value)
            if not typedValue then
                DebugConsole:printOutput("Invalid number: " .. value)
                return
            end
        else
            typedValue = value
        end
        SettingsManager:setSetting(modName, key, typedValue)
        DebugConsole:printOutput(string.format("Setting '%s' updated to %s.", settingKey, tostring(typedValue)))
    elseif cmd == "exportsettings" then
        -- Define export file path
        local exportPath = "MODSettingsLib_Export.json"
        local settingsData = SettingsManager:getAllSettings()
        local success, err = pcall(function()
            SettingsStorage:saveToFile(settingsData, exportPath)
        end)
        if success then
            DebugConsole:printOutput("Settings exported to " .. exportPath)
        else
            DebugConsole:printOutput("Failed to export settings: " .. tostring(err))
        end
    elseif cmd == "importsettings" then
        local filePath = table.remove(args, 1)
        if not filePath then
            DebugConsole:printOutput("Usage: importsettings <filePath>")
            return
        end
        local success, settingsData = pcall(function()
            return SettingsStorage:loadFromFile(filePath)
        end)
        if success and settingsData then
            SettingsManager:importSettings(settingsData)
            DebugConsole:printOutput("Settings imported from " .. filePath)
        else
            DebugConsole:printOutput("Failed to import settings from " .. filePath)
        end
    elseif cmd == "reload" then
        -- Reload the addon (requires ESO's API)
        ReloadUI()
    else
        DebugConsole:printOutput("Unknown command: " .. cmd)
    end
end

--[[
    Function: setup
    Description: Sets up the debug console.
]]
function DebugConsole:setup()
    self:initialize()
    log("Debug console setup completed.")
end

-- Initialize the DebugConsole module
DebugConsole:setup()

return DebugConsole
