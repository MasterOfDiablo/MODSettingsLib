-- File: core/settings_manager.lua
-- Author: MasterOfDiablo
-- Description: Advanced core settings management for MODSettingsLib.
-- Version: 1.1.0

--[[
    The SettingsManager module provides comprehensive management of mod settings,
    including registration, retrieval, updating, validation, profiles integration,
    and extensive error handling. It fully integrates with settings_storage.lua,
    settings_callbacks.lua, security modules, and is designed to be robust and feature-rich.
]]
local SettingsManager = {}
SettingsManager.__index = SettingsManager

-- Dependencies
local SettingsStorage = require("core/settings_storage")
local SettingsCallbacks = require("core/settings_callbacks")
local ProfilesManager = require("profiles/profiles_manager")
local ErrorLogger = require("debugging/error_logger")

-- Internal tables
SettingsManager.registeredSettings = {}   -- Holds metadata for all registered settings
SettingsManager.settingsValues = {}       -- Holds current values of settings
SettingsManager.settingsDefaults = {}     -- Holds default values for settings
SettingsManager.settingsValidators = {}   -- Holds validator functions for settings
SettingsManager.settingsDescriptions = {} -- Holds descriptions for settings
SettingsManager.settingsOptions = {}      -- Holds additional options for settings
SettingsManager.settingsCategories = {}   -- Holds category information for settings
SettingsManager.settingsTypes = {}        -- Holds data types for settings
SettingsManager.settingsDependencies = {} -- Holds dependency information for settings

-- Profiles
SettingsManager.activeProfile = nil       -- Currently active profile

-- Logging
local function log(message)
    print("[SettingsManager] " .. message)
    ErrorLogger:logInfo("[SettingsManager] " .. message)
end

-- Error handling
local function handleError(message)
    print("[SettingsManager] ERROR: " .. message)
    ErrorLogger:logError("[SettingsManager] " .. message)
    error("[SettingsManager] " .. message)
end

--[[
    Function: registerSetting
    Description: Registers a new setting with detailed metadata.
    Parameters:
        - modName (string): The name of the mod registering the setting.
        - settingKey (string): The unique key for the setting.
        - defaultValue (any): The default value for the setting.
        - validator (function or string): A function or string representing the expected data type.
        - description (string): A description of the setting.
        - options (table): Additional options (e.g., min, max for numeric values).
        - category (string): Category under which the setting falls.
        - settingType (string): The data type of the setting (e.g., "number", "string", "boolean").
        - dependencies (table): Other settings that this setting depends on.
]]
function SettingsManager:registerSetting(modName, settingKey, defaultValue, validator, description, options, category, settingType, dependencies)
    -- Input validation
    assert(type(modName) == "string", "modName must be a string")
    assert(type(settingKey) == "string", "settingKey must be a string")
    local fullKey = modName .. "." .. settingKey

    if self.registeredSettings[fullKey] then
        handleError("Setting already registered: " .. fullKey)
    end

    -- Store metadata
    self.registeredSettings[fullKey] = true
    self.settingsDefaults[fullKey] = defaultValue
    self.settingsValues[fullKey] = defaultValue
    self.settingsDescriptions[fullKey] = description or ""
    self.settingsOptions[fullKey] = options or {}
    self.settingsCategories[fullKey] = category or "General"
    self.settingsTypes[fullKey] = settingType or type(defaultValue)
    self.settingsDependencies[fullKey] = dependencies or {}

    -- Validator handling
    if type(validator) == "function" then
        self.settingsValidators[fullKey] = validator
    elseif type(validator) == "string" then
        local expectedType = validator
        self.settingsValidators[fullKey] = function(value)
            return type(value) == expectedType
        end
    else
        self.settingsValidators[fullKey] = function(_) return true end
    end

    log("Registered setting: " .. fullKey)
end

--[[
    Function: setSetting
    Description: Sets the value of a registered setting with validation and dependency checks.
    Parameters:
        - modName (string): The name of the mod.
        - settingKey (string): The unique key for the setting.
        - value (any): The new value to set.
]]
function SettingsManager:setSetting(modName, settingKey, value)
    local fullKey = modName .. "." .. settingKey
    if not self.registeredSettings[fullKey] then
        handleError("Attempted to set unregistered setting: " .. fullKey)
    end

    -- Dependency check
    local dependencies = self.settingsDependencies[fullKey]
    for _, depKey in ipairs(dependencies) do
        if not self.settingsValues[depKey] then
            handleError("Missing dependency " .. depKey .. " for setting " .. fullKey)
        end
    end

    -- Validation
    local validator = self.settingsValidators[fullKey]
    if not validator(value) then
        handleError("Invalid value for setting " .. fullKey)
    end

    -- Update value
    self.settingsValues[fullKey] = value
    log("Setting updated: " .. fullKey .. " = " .. tostring(value))

    -- Trigger callbacks
    SettingsCallbacks:handleSettingChange(fullKey, value)

    -- Save settings
    SettingsStorage:save(self.settingsValues, self.activeProfile)
end

--[[
    Function: getSetting
    Description: Retrieves the value of a registered setting.
    Parameters:
        - modName (string): The name of the mod.
        - settingKey (string): The unique key for the setting.
    Returns: The current value of the setting.
]]
function SettingsManager:getSetting(modName, settingKey)
    local fullKey = modName .. "." .. settingKey
    if self.settingsValues[fullKey] ~= nil then
        return self.settingsValues[fullKey]
    else
        handleError("Setting not registered: " .. fullKey)
    end
end

--[[
    Function: resetSetting
    Description: Resets a setting to its default value.
    Parameters:
        - modName (string): The name of the mod.
        - settingKey (string): The unique key for the setting.
]]
function SettingsManager:resetSetting(modName, settingKey)
    local fullKey = modName .. "." .. settingKey
    if not self.registeredSettings[fullKey] then
        handleError("Attempted to reset unregistered setting: " .. fullKey)
    end

    local defaultValue = self.settingsDefaults[fullKey]
    self.settingsValues[fullKey] = defaultValue
    log("Setting reset to default: " .. fullKey)

    -- Trigger callbacks
    SettingsCallbacks:handleSettingChange(fullKey, defaultValue)

    -- Save settings
    SettingsStorage:save(self.settingsValues, self.activeProfile)
end

--[[
    Function: registerCallback
    Description: Registers a callback function for a setting.
    Parameters:
        - modName (string): The name of the mod.
        - settingKey (string): The unique key for the setting.
        - callback (function): The function to call when the setting changes.
        - priority (number): (Optional) The priority level of the callback.
        - condition (function): (Optional) A condition function for the callback.
]]
function SettingsManager:registerCallback(modName, settingKey, callback, priority, condition)
    local fullKey = modName .. "." .. settingKey
    if not self.registeredSettings[fullKey] then
        handleError("Attempted to register callback for unregistered setting: " .. fullKey)
    end

    SettingsCallbacks:registerCallback(fullKey, callback, priority, condition)
    log("Callback registered for setting: " .. fullKey)
end

--[[
    Function: saveSettings
    Description: Saves all settings to persistent storage, including profile data.
]]
function SettingsManager:saveSettings()
    -- Save settings values
    local success, err = pcall(function()
        SettingsStorage:save(self.settingsValues, self.activeProfile)
    end)
    if not success then
        handleError("Failed to save settings: " .. tostring(err))
    else
        log("Settings saved successfully.")
    end
end

--[[
    Function: loadSettings
    Description: Loads settings from persistent storage, merging with defaults.
]]
function SettingsManager:loadSettings()
    local success, loadedSettings = pcall(function()
        return SettingsStorage:load(self.activeProfile)
    end)
    if not success or not loadedSettings then
        handleError("Failed to load settings.")
    else
        -- Merge loaded settings with defaults
        for key, value in pairs(loadedSettings) do
            if self.registeredSettings[key] then
                self.settingsValues[key] = value
            else
                log("Ignoring unregistered setting in loaded data: " .. key)
            end
        end
        log("Settings loaded successfully.")
    end
end

--[[
    Function: setActiveProfile
    Description: Sets the active profile for settings.
    Parameters:
        - profileName (string): The name of the profile to activate.
]]
function SettingsManager:setActiveProfile(profileName)
    if not ProfilesManager:profileExists(profileName) then
        handleError("Profile does not exist: " .. profileName)
    end
    self.activeProfile = profileName
    self:loadSettings()
    log("Active profile set to: " .. profileName)
end

--[[
    Function: resetAllSettings
    Description: Resets all settings to their default values.
]]
function SettingsManager:resetAllSettings()
    for key, defaultValue in pairs(self.settingsDefaults) do
        self.settingsValues[key] = defaultValue
    end
    log("All settings have been reset to default values.")

    -- Trigger callbacks for all settings
    for key, _ in pairs(self.registeredSettings) do
        SettingsCallbacks:handleSettingChange(key, self.settingsValues[key])
    end

    -- Save settings
    self:saveSettings()
end

--[[
    Function: validateAllSettings
    Description: Validates all settings against their validators.
    Returns: True if all settings are valid, false otherwise.
]]
function SettingsManager:validateAllSettings()
    local allValid = true
    for key, validator in pairs(self.settingsValidators) do
        local value = self.settingsValues[key]
        if not validator(value) then
            log("Invalid value for setting: " .. key)
            allValid = false
        end
    end
    return allValid
end

--[[
    Function: exportSettings
    Description: Exports current settings to a table for sharing or backup.
    Returns: A table containing the current settings.
]]
function SettingsManager:exportSettings()
    local exportData = {}
    for key, value in pairs(self.settingsValues) do
        exportData[key] = value
    end
    log("Settings exported.")
    return exportData
end

--[[
    Function: importSettings
    Description: Imports settings from a table, with validation.
    Parameters:
        - data (table): The table containing settings data to import.
]]
function SettingsManager:importSettings(data)
    assert(type(data) == "table", "Import data must be a table.")
    for key, value in pairs(data) do
        if self.registeredSettings[key] then
            local validator = self.settingsValidators[key]
            if validator(value) then
                self.settingsValues[key] = value
                log("Imported setting: " .. key)
            else
                log("Invalid value for setting during import: " .. key)
            end
        else
            log("Ignoring unregistered setting during import: " .. key)
        end
    end

    -- Trigger callbacks for updated settings
    for key, _ in pairs(data) do
        SettingsCallbacks:handleSettingChange(key, self.settingsValues[key])
    end

    -- Save settings
    self:saveSettings()
end

--[[
    Function: getSettingMetadata
    Description: Retrieves metadata for a registered setting.
    Parameters:
        - modName (string): The name of the mod.
        - settingKey (string): The unique key for the setting.
    Returns: A table containing the setting's metadata.
]]
function SettingsManager:getSettingMetadata(modName, settingKey)
    local fullKey = modName .. "." .. settingKey
    if not self.registeredSettings[fullKey] then
        handleError("Setting not registered: " .. fullKey)
    end

    return {
        defaultValue = self.settingsDefaults[fullKey],
        description = self.settingsDescriptions[fullKey],
        options = self.settingsOptions[fullKey],
        category = self.settingsCategories[fullKey],
        settingType = self.settingsTypes[fullKey],
        dependencies = self.settingsDependencies[fullKey],
    }
end

--[[
    Function: getSettingsByCategory
    Description: Retrieves all settings under a specific category.
    Parameters:
        - category (string): The category name.
    Returns: A table of settings keys under the specified category.
]]
function SettingsManager:getSettingsByCategory(category)
    local settingsInCategory = {}
    for key, cat in pairs(self.settingsCategories) do
        if cat == category then
            table.insert(settingsInCategory, key)
        end
    end
    return settingsInCategory
end

--[[
    Function: getAllCategories
    Description: Retrieves a list of all categories.
    Returns: A table containing all unique categories.
]]
function SettingsManager:getAllCategories()
    local categories = {}
    local categorySet = {}
    for _, cat in pairs(self.settingsCategories) do
        if not categorySet[cat] then
            categorySet[cat] = true
            table.insert(categories, cat)
        end
    end
    return categories
end

--[[
    Function: searchSettings
    Description: Searches settings based on a query string.
    Parameters:
        - query (string): The search query.
    Returns: A table of settings keys that match the query.
]]
function SettingsManager:searchSettings(query)
    local results = {}
    for key, desc in pairs(self.settingsDescriptions) do
        if string.find(key:lower(), query:lower()) or string.find(desc:lower(), query:lower()) then
            table.insert(results, key)
        end
    end
    return results
end

--[[
    Function: initialize
    Description: Initializes the SettingsManager, loading settings and setting up profiles.
]]
function SettingsManager:initialize()
    -- Set default profile if none is active
    if not self.activeProfile then
        self.activeProfile = ProfilesManager:getDefaultProfileName()
    end

    -- Load settings
    self:loadSettings()

    -- Validate settings
    if not self:validateAllSettings() then
        log("One or more settings have invalid values. Resetting invalid settings.")
        -- Reset invalid settings
        for key, validator in pairs(self.settingsValidators) do
            local value = self.settingsValues[key]
            if not validator(value) then
                self.settingsValues[key] = self.settingsDefaults[key]
                SettingsCallbacks:handleSettingChange(key, self.settingsValues[key])
            end
        end
        -- Save settings after reset
        self:saveSettings()
    end

    log("SettingsManager initialized.")
end

--[[
    Function: unregisterSetting
    Description: Unregisters a setting and removes its value.
    Parameters:
        - modName (string): The name of the mod.
        - settingKey (string): The unique key for the setting.
]]
function SettingsManager:unregisterSetting(modName, settingKey)
    local fullKey = modName .. "." .. settingKey
    if not self.registeredSettings[fullKey] then
        handleError("Setting not registered: " .. fullKey)
    end

    self.registeredSettings[fullKey] = nil
    self.settingsValues[fullKey] = nil
    self.settingsDefaults[fullKey] = nil
    self.settingsValidators[fullKey] = nil
    self.settingsDescriptions[fullKey] = nil
    self.settingsOptions[fullKey] = nil
    self.settingsCategories[fullKey] = nil
    self.settingsTypes[fullKey] = nil
    self.settingsDependencies[fullKey] = nil

    SettingsCallbacks:removeAllCallbacks(fullKey)
    log("Setting unregistered: " .. fullKey)

    -- Save settings after removal
    self:saveSettings()
end

--[[
    Function: listSettings
    Description: Prints all registered settings and their current values.
]]
function SettingsManager:listSettings()
    print("Registered Settings:")
    for key, _ in pairs(self.registeredSettings) do
        local value = self.settingsValues[key]
        local defaultValue = self.settingsDefaults[key]
        print(string.format("- %s: %s (Default: %s)", key, tostring(value), tostring(defaultValue)))
    end
end

--[[
    Function: getAllSettings
    Description: Retrieves all settings values.
    Returns: A table containing all settings and their values.
]]
function SettingsManager:getAllSettings()
    return self.settingsValues
end

--[[
    Function: mergeSettings
    Description: Merges another settings table into the current settings, with validation.
    Parameters:
        - newSettings (table): The settings table to merge.
]]
function SettingsManager:mergeSettings(newSettings)
    assert(type(newSettings) == "table", "newSettings must be a table.")
    for key, value in pairs(newSettings) do
        if self.registeredSettings[key] then
            local validator = self.settingsValidators[key]
            if validator(value) then
                self.settingsValues[key] = value
                log("Merged setting: " .. key)
                SettingsCallbacks:handleSettingChange(key, value)
            else
                log("Invalid value for setting during merge: " .. key)
            end
        else
            log("Ignoring unregistered setting during merge: " .. key)
        end
    end

    -- Save settings after merge
    self:saveSettings()
end

--[[
    Function: cloneProfile
    Description: Clones the current settings to a new profile.
    Parameters:
        - newProfileName (string): The name of the new profile.
]]
function SettingsManager:cloneProfile(newProfileName)
    assert(type(newProfileName) == "string", "newProfileName must be a string.")
    if ProfilesManager:profileExists(newProfileName) then
        handleError("Profile already exists: " .. newProfileName)
    end

    ProfilesManager:cloneProfile(self.activeProfile, newProfileName)
    log("Profile cloned to: " .. newProfileName)
end

--[[
    Function: deleteProfile
    Description: Deletes a profile.
    Parameters:
        - profileName (string): The name of the profile to delete.
]]
function SettingsManager:deleteProfile(profileName)
    ProfilesManager:deleteProfile(profileName)
    log("Profile deleted via SettingsManager: " .. profileName)
end

--[[
    Function: exportSettingsToFile
    Description: Exports settings to a specified file path.
    Parameters:
        - filePath (string): The file path to save the settings to.
]]
function SettingsManager:exportSettingsToFile(filePath)
    assert(type(filePath) == "string", "filePath must be a string.")
    local settingsData = self:exportSettings()
    local success, err = pcall(function()
        SettingsStorage:saveToFile(settingsData, filePath)
    end)
    if success then
        log("Settings exported to file: " .. filePath)
    else
        handleError("Failed to export settings to file: " .. err)
    end
end

--[[
    Function: loadSettingsFromFile
    Description: Loads settings from a specified file path.
    Parameters:
        - filePath (string): The file path to load the settings from.
]]
function SettingsManager:loadSettingsFromFile(filePath)
    assert(type(filePath) == "string", "filePath must be a string.")
    local success, settingsData = pcall(function()
        return SettingsStorage:loadFromFile(filePath)
    end)
    if success and settingsData then
        self:mergeSettings(settingsData)
        self:saveSettings()
        log("Settings loaded from file: " .. filePath)
    else
        handleError("Failed to load settings from file.")
    end
end

--[[
    Function: generateSettingsReport
    Description: Generates a detailed report of all settings for debugging.
    Returns: A formatted string containing the settings report.
]]
function SettingsManager:generateSettingsReport()
    local report = "Settings Report:\n"
    for key, _ in pairs(self.registeredSettings) do
        local value = self.settingsValues[key]
        local defaultValue = self.settingsDefaults[key]
        local description = self.settingsDescriptions[key]
        local category = self.settingsCategories[key]
        local settingType = self.settingsTypes[key]
        report = report .. string.format(
            "Key: %s\n  Value: %s\n  Default: %s\n  Type: %s\n  Category: %s\n  Description: %s\n\n",
            key, tostring(value), tostring(defaultValue), settingType, category, description)
    end
    return report
end

--[[
    Function: unregisterAllCallbacks
    Description: Unregisters all callbacks for all settings.
]]
function SettingsManager:unregisterAllCallbacks()
    SettingsCallbacks:unregisterAllCallbacks()
    log("All callbacks unregistered.")
end

--[[
    Function: listAllSettings
    Description: Prints all registered settings and their current values.
]]
function SettingsManager:listAllSettings()
    self:listSettings()
end

--[[
    Function: reloadSettings
    Description: Reloads settings by re-initializing the SettingsManager.
]]
function SettingsManager:reloadSettings()
    self:initialize()
    log("Settings reloaded.")
end

--[[
    Function: handleSettingChange
    Description: Handles external changes to settings by reloading them.
    Parameters:
        - settingKey (string): The key of the setting that changed.
        - newValue (any): The new value of the setting.
]]
function SettingsManager:handleSettingChange(settingKey, newValue)
    -- This function can be expanded to handle specific actions when settings change
    log("Handle change for setting: " .. settingKey .. " = " .. tostring(newValue))
end

--[[
    Function: unregisterAllSettings
    Description: Unregisters all settings managed by SettingsManager.
]]
function SettingsManager:unregisterAllSettings()
    for key, _ in pairs(self.registeredSettings) do
        self:unregisterSetting(string.match(key, "^(.-)%.") or "Unknown", string.match(key, "%.([^%.]+)$") or "Unknown")
    end
    log("All settings have been unregistered.")
end

--[[
    Function: mergeSettingsFromProfile
    Description: Merges settings from one profile into another with optional conflict resolution.
    Parameters:
        - sourceProfile (string): The name of the source profile.
        - targetProfile (string): The name of the target profile.
        - conflictResolution (function): (Optional) A function to resolve conflicts.
]]
function SettingsManager:mergeSettingsFromProfile(sourceProfile, targetProfile, conflictResolution)
    assert(type(sourceProfile) == "string", "sourceProfile must be a string.")
    assert(type(targetProfile) == "string", "targetProfile must be a string.")
    if not ProfilesManager:profileExists(sourceProfile) then
        handleError("Source profile does not exist: " .. sourceProfile)
    end
    if not ProfilesManager:profileExists(targetProfile) then
        handleError("Target profile does not exist: " .. targetProfile)
    end

    local success, sourceSettings = pcall(function()
        return SettingsStorage:load(sourceProfile)
    end)
    if not success or not sourceSettings then
        handleError("Failed to load settings from source profile: " .. sourceProfile)
    end

    local success, targetSettings = pcall(function()
        return SettingsStorage:load(targetProfile)
    end)
    if not success or not targetSettings then
        handleError("Failed to load settings from target profile: " .. targetProfile)
    end

    -- Merge settings
    for key, sourceValue in pairs(sourceSettings) do
        local targetValue = targetSettings[key]
        if targetValue ~= nil then
            if conflictResolution and type(conflictResolution) == "function" then
                targetSettings[key] = conflictResolution(sourceValue, targetValue)
                log("Conflict resolved for setting '" .. key .. "': " .. tostring(targetSettings[key]))
            else
                -- Default conflict resolution: overwrite target with source
                targetSettings[key] = sourceValue
                log("Conflict resolved by overwriting setting '" .. key .. "' with source value.")
            end
        else
            targetSettings[key] = sourceValue
            log("Merged new setting '" .. key .. "' into target profile.")
        end
    end

    -- Save merged settings to targetProfile
    SettingsStorage:save(targetSettings, targetProfile)
    log("Settings merged from '" .. sourceProfile .. "' into '" .. targetProfile .. "'")

    -- Trigger callbacks for all merged settings
    for key, _ in pairs(sourceSettings) do
        SettingsCallbacks:handleSettingChange(key, targetSettings[key])
    end
end

--[[
    Function: getRegisteredSettings
    Description: Retrieves a list of all settings that have been registered.
    Returns: A table containing setting keys.
]]
function SettingsManager:getRegisteredSettings()
    local registered = {}
    for key, _ in pairs(self.registeredSettings) do
        table.insert(registered, key)
    end
    return registered
end

--[[
    Function: exportSettingsReport
    Description: Exports a settings report to a file.
    Parameters:
        - filePath (string): The file path to save the report to.
]]
function SettingsManager:exportSettingsReport(filePath)
    local report = self:generateSettingsReport()
    local success, err = pcall(function()
        local file, err = io.open(filePath, "w")
        if not file then
            handleError("Failed to open report file for writing: " .. filePath .. " Error: " .. tostring(err))
        end
        file:write(report)
        file:close()
    end)
    if success then
        log("Settings report exported to " .. filePath)
    else
        handleError("Failed to export settings report: " .. tostring(err))
    end
end

--[[
    Function: importSettingsFromFile
    Description: Imports settings from an external report file.
    Parameters:
        - filePath (string): The file path to load the report from.
]]
function SettingsManager:importSettingsFromFile(filePath)
    self:loadSettingsFromFile(filePath)
    log("Settings imported from report file: " .. filePath)
end

--[[
    Function: setCallbackPriority
    Description: Sets the priority of an existing callback.
    Parameters:
        - settingKey (string): The unique key for the setting (including mod name).
        - callback (function): The callback function whose priority to set.
        - newPriority (number): The new priority level.
]]
function SettingsManager:setCallbackPriority(settingKey, callback, newPriority)
    SettingsCallbacks:setCallbackPriority(settingKey, callback, newPriority)
end

--[[
    Function: wrapCallbackWithErrorHandling
    Description: Wraps a callback function with error handling to prevent it from affecting other callbacks.
    Parameters:
        - callback (function): The callback function to wrap.
    Returns: The wrapped callback function.
]]
function SettingsManager:wrapCallbackWithErrorHandling(callback)
    return SettingsCallbacks:wrapCallbackWithErrorHandling(callback)
end

--[[
    Function: generateSettingsReport
    Description: Generates a detailed report of all settings for debugging.
    Returns: A formatted string containing the settings report.
]]
function SettingsManager:generateSettingsReport()
    local report = "Settings Report:\n"
    for key, _ in pairs(self.registeredSettings) do
        local value = self.settingsValues[key]
        local defaultValue = self.settingsDefaults[key]
        local description = self.settingsDescriptions[key]
        local category = self.settingsCategories[key]
        local settingType = self.settingsTypes[key]
        report = report .. string.format(
            "Key: %s\n  Value: %s\n  Default: %s\n  Type: %s\n  Category: %s\n  Description: %s\n\n",
            key, tostring(value), tostring(defaultValue), settingType, category, description)
    end
    return report
end

--[[
    Function: unregisterAllCallbacks
    Description: Unregisters all callbacks for all settings.
]]
function SettingsManager:unregisterAllCallbacks()
    SettingsCallbacks:unregisterAllCallbacks()
    log("All callbacks unregistered.")
end

--[[
    Function: listAllSettings
    Description: Prints all registered settings and their current values.
]]
function SettingsManager:listAllSettings()
    self:listSettings()
end

--[[
    Function: reloadSettings
    Description: Reloads settings by re-initializing the SettingsManager.
]]
function SettingsManager:reloadSettings()
    self:initialize()
    log("Settings reloaded.")
end

--[[
    Function: handleSettingChange
    Description: Handles external changes to settings by reloading them.
    Parameters:
        - settingKey (string): The key of the setting that changed.
        - newValue (any): The new value of the setting.
]]
function SettingsManager:handleSettingChange(settingKey, newValue)
    -- This function can be expanded to handle specific actions when settings change
    log("Handle change for setting: " .. settingKey .. " = " .. tostring(newValue))
end

--[[
    Function: unregisterAllSettings
    Description: Unregisters all settings managed by SettingsManager.
]]
function SettingsManager:unregisterAllSettings()
    for key, _ in pairs(self.registeredSettings) do
        self:unregisterSetting(string.match(key, "^(.-)%.") or "Unknown", string.match(key, "%.([^%.]+)$") or "Unknown")
    end
    log("All settings have been unregistered.")
end

--[[
    Function: mergeSettingsFromProfile
    Description: Merges settings from one profile into another with optional conflict resolution.
    Parameters:
        - sourceProfile (string): The name of the source profile.
        - targetProfile (string): The name of the target profile.
        - conflictResolution (function): (Optional) A function to resolve conflicts.
]]
function SettingsManager:mergeSettingsFromProfile(sourceProfile, targetProfile, conflictResolution)
    self:mergeSettingsFromProfile(sourceProfile, targetProfile, conflictResolution)
end

--[[
    Function: getRegisteredSettings
    Description: Retrieves a list of all settings that have been registered.
    Returns: A table containing setting keys.
]]
function SettingsManager:getRegisteredSettings()
    local registered = {}
    for key, _ in pairs(self.registeredSettings) do
        table.insert(registered, key)
    end
    return registered
end

--[[
    Function: exportSettingsReport
    Description: Exports a settings report to a file.
    Parameters:
        - filePath (string): The file path to save the report to.
]]
function SettingsManager:exportSettingsReport(filePath)
    local report = self:generateSettingsReport()
    local success, err = pcall(function()
        local file, err = io.open(filePath, "w")
        if not file then
            handleError("Failed to open report file for writing: " .. filePath .. " Error: " .. tostring(err))
        end
        file:write(report)
        file:close()
    end)
    if success then
        log("Settings report exported to " .. filePath)
    else
        handleError("Failed to export settings report: " .. tostring(err))
    end
end

-- Initialize the SettingsManager
function SettingsManager:initialize()
    -- Set default profile if none is active
    if not self.activeProfile then
        self.activeProfile = ProfilesManager:getDefaultProfileName()
    end

    -- Load settings
    self:loadSettings()

    -- Validate settings
    if not self:validateAllSettings() then
        log("One or more settings have invalid values. Resetting invalid settings.")
        -- Reset invalid settings
        for key, validator in pairs(self.settingsValidators) do
            local value = self.settingsValues[key]
            if not validator(value) then
                self.settingsValues[key] = self.settingsDefaults[key]
                SettingsCallbacks:handleSettingChange(key, self.settingsValues[key])
            end
        end
        -- Save settings after reset
        self:saveSettings()
    end

    log("SettingsManager initialized.")
end

--[[
    Function: registerSettings
    Description: Registers all settings required by the addon.
    Note: This function should be customized based on the specific settings your addon requires.
]]
function SettingsManager:registerSettings()
    -- Example settings registration
    self:registerSetting(
        "MyAddon",
        "EnableFeature",
        true,
        "boolean",
        "Enable or disable the main feature of the addon.",
        {},
        "General",
        "boolean",
        {}
    )

    self:registerSetting(
        "MyAddon",
        "FeatureIntensity",
        50,
        function(value)
            return type(value) == "number" and value >= 0 and value <= 100
        end,
        "Adjust the intensity of the main feature.",
        { min = 0, max = 100, steps = 10 },
        "General",
        "number",
        { "MyAddon.EnableFeature" }
    )

    self:registerSetting(
        "MyAddon",
        "FeatureMode",
        "Automatic",
        "string",
        "Select the operating mode of the main feature.",
        { options = { "Automatic", "Manual", "Semi-Automatic" } },
        "Advanced",
        "dropdown",
        {}
    )
    
    -- Add more settings as needed
end

--[[
    Function: initialize
    Description: Initializes the SettingsManager, loading settings and setting up profiles.
]]
function SettingsManager:initialize()
    -- Set default profile if none is active
    if not self.activeProfile then
        self.activeProfile = ProfilesManager:getDefaultProfileName()
    end

    -- Register all settings
    self:registerSettings()

    -- Load settings
    self:loadSettings()

    -- Validate settings
    if not self:validateAllSettings() then
        log("One or more settings have invalid values. Resetting invalid settings.")
        -- Reset invalid settings
        for key, validator in pairs(self.settingsValidators) do
            local value = self.settingsValues[key]
            if not validator(value) then
                self.settingsValues[key] = self.settingsDefaults[key]
                SettingsCallbacks:handleSettingChange(key, self.settingsValues[key])
            end
        end
        -- Save settings after reset
        self:saveSettings()
    end

    log("SettingsManager initialized.")
end

-- Initialize the SettingsManager
SettingsManager:initialize()

return SettingsManager
