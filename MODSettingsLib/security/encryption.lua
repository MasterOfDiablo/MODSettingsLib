-- File: MODSettingsLib.lua
-- Author: MasterOfDiablo
-- Description: Main entry point for MODSettingsLib, initializing core modules and UI.
-- Version: 1.0.0

-- Core Modules
local SettingsStorage = require("core/settings_storage")
local SettingsCallbacks = require("core/settings_callbacks")
local SettingsManager = require("core/settings_manager")
local ProfilesManager = require("profiles/profiles_manager")

-- UI Modules
local SettingsUI = require("ui.MODSettingsLib_SettingsUI")

-- Initialization
function MODSettingsLib_OnAddOnLoaded(event, addonName)
    if addonName ~= "MODSettingsLib" then return end

    -- Initialize core modules
    SettingsStorage:initialize()
    SettingsCallbacks:initialize()
    SettingsManager:initialize()
    ProfilesManager:initialize()

    -- Initialize UI
    SettingsUI:setup()

    -- Unregister event to avoid re-initialization
    EVENT_MANAGER:UnregisterForEvent("MODSettingsLib", EVENT_ADD_ON_LOADED)
end

-- Register for the ADD_ON_LOADED event
EVENT_MANAGER:RegisterForEvent("MODSettingsLib", EVENT_ADD_ON_LOADED, MODSettingsLib_OnAddOnLoaded)
