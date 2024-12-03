-- File: profiles/profiles_manager.lua
-- Author: MasterOfDiablo
-- Description: Manages user profiles for MODSettingsLib, including creation, deletion, switching, cloning, renaming, and merging.
-- Version: 1.0.0

--[[
    The ProfilesManager module provides comprehensive management of user profiles within MODSettingsLib.
    It allows users to create, delete, switch, clone, rename, and merge profiles, ensuring that each profile
    maintains its own set of settings. Integration with SettingsStorage ensures that profiles are persistently stored.
]]

local ProfilesManager = {}
ProfilesManager.__index = ProfilesManager

-- Dependencies
local SettingsStorage = require("core/settings_storage")
local SettingsManager = require("core/settings_manager")
local ErrorLogger = require("debugging/error_logger")

-- Constants
ProfilesManager.DEFAULT_PROFILE_NAME = "Default"
ProfilesManager.PROFILES_LIST_KEY = "profiles_list"  -- Key to store the list of profiles in storage

-- Internal tables
ProfilesManager.profilesList = {}     -- List of all profile names
ProfilesManager.activeProfile = nil   -- Currently active profile

-- Logging
local function log(message)
    print("[ProfilesManager] " .. message)
    ErrorLogger:logInfo("[ProfilesManager] " .. message)
end

-- Error handling
local function handleError(message)
    print("[ProfilesManager] ERROR: " .. message)
    ErrorLogger:logError("[ProfilesManager] " .. message)
    error("[ProfilesManager] " .. message)
end

--[[
    Function: initialize
    Description: Initializes the ProfilesManager, loading existing profiles or creating the default profile.
]]
function ProfilesManager:initialize()
    -- Load profiles list from storage
    local success, profilesData = pcall(function()
        return SettingsStorage:load("profiles")
    end)
    
    if success and profilesData and profilesData[ProfilesManager.PROFILES_LIST_KEY] then
        self.profilesList = profilesData[ProfilesManager.PROFILES_LIST_KEY]
        log("Profiles list loaded successfully.")
    else
        -- Initialize with default profile if profiles data doesn't exist
        log("Profiles data not found. Creating default profile.")
        self.profilesList = { ProfilesManager.DEFAULT_PROFILE_NAME }
        SettingsStorage:save({ [ProfilesManager.PROFILES_LIST_KEY] = self.profilesList }, "profiles")
    end
    
    -- Ensure the default profile exists
    if not self:profileExists(ProfilesManager.DEFAULT_PROFILE_NAME) then
        log("Default profile missing. Creating default profile.")
        self:createProfile(ProfilesManager.DEFAULT_PROFILE_NAME)
    end
    
    -- Set active profile to default if not set
    if not self.activeProfile then
        self.activeProfile = ProfilesManager.DEFAULT_PROFILE_NAME
        SettingsManager:setActiveProfile(self.activeProfile)
        log("Active profile set to default: " .. self.activeProfile)
    end
    
    log("ProfilesManager initialized.")
end

--[[
    Function: getAllProfiles
    Description: Retrieves a list of all available profiles.
    Returns: A table containing profile names.
]]
function ProfilesManager:getAllProfiles()
    return self.profilesList
end

--[[
    Function: profileExists
    Description: Checks if a profile with the given name exists.
    Parameters:
        - profileName (string): The name of the profile to check.
    Returns: True if the profile exists, false otherwise.
]]
function ProfilesManager:profileExists(profileName)
    for _, name in ipairs(self.profilesList) do
        if name == profileName then
            return true
        end
    end
    return false
end

--[[
    Function: createProfile
    Description: Creates a new profile.
    Parameters:
        - profileName (string): The name of the new profile.
        - baseProfile (string): (Optional) The name of the profile to clone from. If nil, creates an empty profile.
]]
function ProfilesManager:createProfile(profileName, baseProfile)
    assert(type(profileName) == "string", "profileName must be a string.")
    if self:profileExists(profileName) then
        handleError("Profile already exists: " .. profileName)
    end

    -- If baseProfile is provided, clone settings from it
    local settingsData = {}
    if baseProfile then
        assert(type(baseProfile) == "string", "baseProfile must be a string.")
        if not self:profileExists(baseProfile) then
            handleError("Base profile does not exist: " .. baseProfile)
        end
        local success, clonedSettings = pcall(function()
            return SettingsStorage:load(baseProfile)
        end)
        if success and clonedSettings then
            for key, value in pairs(clonedSettings) do
                settingsData[key] = value
            end
            log("Cloned settings from base profile: " .. baseProfile)
        else
            handleError("Failed to clone settings from base profile: " .. baseProfile)
        end
    end

    -- Add the new profile to profilesList
    table.insert(self.profilesList, profileName)
    log("Profile created: " .. profileName)

    -- Save the profiles list
    SettingsStorage:save({ [ProfilesManager.PROFILES_LIST_KEY] = self.profilesList }, "profiles")

    -- Save the settings data for the new profile
    SettingsStorage:save(settingsData, profileName)
    log("Settings saved for new profile: " .. profileName)
end

--[[
    Function: deleteProfile
    Description: Deletes a profile.
    Parameters:
        - profileName (string): The name of the profile to delete.
]]
function ProfilesManager:deleteProfile(profileName)
    assert(type(profileName) == "string", "profileName must be a string.")
    if profileName == ProfilesManager.DEFAULT_PROFILE_NAME then
        handleError("Cannot delete the default profile.")
    end
    if not self:profileExists(profileName) then
        handleError("Profile does not exist: " .. profileName)
    end

    -- Remove profile from profilesList
    for i, name in ipairs(self.profilesList) do
        if name == profileName then
            table.remove(self.profilesList, i)
            break
        end
    end
    log("Profile deleted: " .. profileName)

    -- Save the updated profiles list
    SettingsStorage:save({ [ProfilesManager.PROFILES_LIST_KEY] = self.profilesList }, "profiles")

    -- Delete settings and backups associated with the profile
    SettingsStorage:deleteSettings(profileName)
    log("Settings and backups deleted for profile: " .. profileName)

    -- Switch to default profile if the deleted profile was active
    if self.activeProfile == profileName then
        self.activeProfile = ProfilesManager.DEFAULT_PROFILE_NAME
        SettingsManager:setActiveProfile(self.activeProfile)
        log("Active profile switched to default: " .. self.activeProfile)
    end
end

--[[
    Function: switchProfile
    Description: Switches the active profile to the specified profile.
    Parameters:
        - profileName (string): The name of the profile to switch to.
]]
function ProfilesManager:switchProfile(profileName)
    assert(type(profileName) == "string", "profileName must be a string.")
    if not self:profileExists(profileName) then
        handleError("Profile does not exist: " .. profileName)
    end

    self.activeProfile = profileName
    SettingsManager:setActiveProfile(profileName)
    log("Switched active profile to: " .. profileName)
end

--[[
    Function: cloneProfile
    Description: Clones an existing profile to a new profile.
    Parameters:
        - sourceProfile (string): The name of the profile to clone from.
        - newProfileName (string): The name of the new profile.
]]
function ProfilesManager:cloneProfile(sourceProfile, newProfileName)
    assert(type(sourceProfile) == "string", "sourceProfile must be a string.")
    assert(type(newProfileName) == "string", "newProfileName must be a string.")
    if not self:profileExists(sourceProfile) then
        handleError("Source profile does not exist: " .. sourceProfile)
    end
    if self:profileExists(newProfileName) then
        handleError("New profile name already exists: " .. newProfileName)
    end

    -- Clone settings from sourceProfile
    local success, clonedSettings = pcall(function()
        return SettingsStorage:load(sourceProfile)
    end)
    if not success or not clonedSettings then
        handleError("Failed to clone settings from profile: " .. sourceProfile)
    end

    -- Create the new profile with cloned settings
    self:createProfile(newProfileName)
    SettingsStorage:save(clonedSettings, newProfileName)
    log("Profile cloned from '" .. sourceProfile .. "' to '" .. newProfileName .. "'")
end

--[[
    Function: renameProfile
    Description: Renames an existing profile.
    Parameters:
        - oldName (string): The current name of the profile.
        - newName (string): The new name for the profile.
]]
function ProfilesManager:renameProfile(oldName, newName)
    assert(type(oldName) == "string", "oldName must be a string.")
    assert(type(newName) == "string", "newName must be a string.")
    if not self:profileExists(oldName) then
        handleError("Profile does not exist: " .. oldName)
    end
    if self:profileExists(newName) then
        handleError("New profile name already exists: " .. newName)
    end

    -- Update profilesList
    for i, name in ipairs(self.profilesList) do
        if name == oldName then
            self.profilesList[i] = newName
            break
        end
    end

    -- Save the updated profiles list
    SettingsStorage:save({ [ProfilesManager.PROFILES_LIST_KEY] = self.profilesList }, "profiles")

    -- Rename settings file and backups
    SettingsStorage:renameProfileFiles(oldName, newName)
    log("Profile renamed from '" .. oldName .. "' to '" .. newName .. "'")

    -- Update activeProfile if necessary
    if self.activeProfile == oldName then
        self.activeProfile = newName
        SettingsManager:setActiveProfile(newName)
        log("Active profile updated to: " .. newName)
    end
end

--[[
    Function: mergeProfiles
    Description: Merges settings from sourceProfile into targetProfile.
    Parameters:
        - sourceProfile (string): The name of the profile to merge from.
        - targetProfile (string): The name of the profile to merge into.
        - conflictResolution (function): (Optional) A function that defines how to resolve conflicts. It should accept two values and return the desired value.
    ]]
function ProfilesManager:mergeProfiles(sourceProfile, targetProfile, conflictResolution)
    assert(type(sourceProfile) == "string", "sourceProfile must be a string.")
    assert(type(targetProfile) == "string", "targetProfile must be a string.")
    if not self:profileExists(sourceProfile) then
        handleError("Source profile does not exist: " .. sourceProfile)
    end
    if not self:profileExists(targetProfile) then
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

    -- Save the merged settings to targetProfile
    SettingsStorage:save(targetSettings, targetProfile)
    log("Profiles merged from '" .. sourceProfile .. "' into '" .. targetProfile .. "'")
end

--[[
    Function: getDefaultProfileName
    Description: Retrieves the name of the default profile.
    Returns: The name of the default profile.
]]
function ProfilesManager:getDefaultProfileName()
    return ProfilesManager.DEFAULT_PROFILE_NAME
end

--[[
    Function: listProfiles
    Description: Prints all available profiles.
]]
function ProfilesManager:listProfiles()
    print("Available Profiles:")
    for _, name in ipairs(self.profilesList) do
        if name == self.activeProfile then
            print(string.format("- %s (Active)", name))
        else
            print("- " .. name)
        end
    end
end

--[[
    Function: getActiveProfile
    Description: Retrieves the name of the currently active profile.
    Returns: The name of the active profile.
]]
function ProfilesManager:getActiveProfile()
    return self.activeProfile
end

--[[
    Function: exportProfile
    Description: Exports a profile's settings to a table.
    Parameters:
        - profileName (string): The name of the profile to export.
    Returns: A table containing the profile's settings.
]]
function ProfilesManager:exportProfile(profileName)
    assert(type(profileName) == "string", "profileName must be a string.")
    if not self:profileExists(profileName) then
        handleError("Profile does not exist: " .. profileName)
    end

    local success, settingsData = pcall(function()
        return SettingsStorage:load(profileName)
    end)
    if not success or not settingsData then
        handleError("Failed to export settings from profile: " .. profileName)
    end

    log("Profile exported: " .. profileName)
    return settingsData
end

--[[
    Function: importProfile
    Description: Imports settings into a profile from a table.
    Parameters:
        - profileName (string): The name of the profile to import into.
        - settingsData (table): The settings data to import.
]]
function ProfilesManager:importProfile(profileName, settingsData)
    assert(type(profileName) == "string", "profileName must be a string.")
    assert(type(settingsData) == "table", "settingsData must be a table.")
    if not self:profileExists(profileName) then
        handleError("Profile does not exist: " .. profileName)
    end

    -- Merge settings into the profile
    SettingsManager:mergeSettings(settingsData)
    SettingsStorage:save(settingsData, profileName)
    log("Profile imported: " .. profileName)
end

--[[
    Function: saveProfilesList
    Description: Saves the profiles list to storage.
]]
function ProfilesManager:saveProfilesList()
    SettingsStorage:save({ [ProfilesManager.PROFILES_LIST_KEY] = self.profilesList }, "profiles")
    log("Profiles list saved.")
end

--[[
    Function: renameProfileFiles
    Description: Renames the settings file and backups when a profile is renamed.
    Parameters:
        - oldName (string): The current name of the profile.
        - newName (string): The new name for the profile.
]]
function SettingsManager:renameProfileFiles(oldName, newName)
    -- Rename settings file
    local oldFilePath = SettingsStorage:getSettingsFilePath(oldName)
    local newFilePath = SettingsStorage:getSettingsFilePath(newName)
    os.rename(oldFilePath, newFilePath)
    log("Settings file renamed from '" .. oldFilePath .. "' to '" .. newFilePath .. "'")

    -- Rename backup files
    local backups = SettingsStorage:listBackups(oldName)
    for _, backup in ipairs(backups) do
        local oldBackupPath = backup.path
        local timestamp = string.match(oldBackupPath, oldName .. "_(%d+)" .. SettingsStorage.BACKUP_EXTENSION)
        if timestamp then
            local newBackupPath = SettingsStorage:getBackupFilePath(newName, tonumber(timestamp))
            os.rename(oldBackupPath, newBackupPath)
            log("Backup file renamed from '" .. oldBackupPath .. "' to '" .. newBackupPath .. "'")
        end
    end
end

--[[
    Function: renameProfileFiles
    Description: Renames the settings file and backups when a profile is renamed.
    Parameters:
        - oldName (string): The current name of the profile.
        - newName (string): The new name for the profile.
]]
function SettingsManager:renameProfileFiles(oldName, newName)
    -- Rename settings file
    local oldFilePath = SettingsStorage:getSettingsFilePath(oldName)
    local newFilePath = SettingsStorage:getSettingsFilePath(newName)
    local success, err = pcall(function()
        os.rename(oldFilePath, newFilePath)
    end)
    if not success then
        handleError("Failed to rename settings file from '" .. oldFilePath .. "' to '" .. newFilePath .. "': " .. err)
    end
    log("Settings file renamed from '" .. oldFilePath .. "' to '" .. newFilePath .. "'")

    -- Rename backup files
    local backups = SettingsStorage:listBackups(oldName)
    for _, backup in ipairs(backups) do
        local oldBackupPath = backup.path
        local timestamp = string.match(oldBackupPath, oldName .. "_(%d+)" .. SettingsStorage.BACKUP_EXTENSION)
        if timestamp then
            local newBackupPath = SettingsStorage:getBackupFilePath(newName, tonumber(timestamp))
            local success, err = pcall(function()
                os.rename(oldBackupPath, newBackupPath)
            end)
            if not success then
                handleError("Failed to rename backup file from '" .. oldBackupPath .. "' to '" .. newBackupPath .. "': " .. err)
            end
            log("Backup file renamed from '" .. oldBackupPath .. "' to '" .. newBackupPath .. "'")
        end
    end
end

--[[
    Function: mergeSettingsIntoProfile
    Description: Merges settings from a source profile into a target profile.
    Parameters:
        - sourceProfile (string): The name of the source profile.
        - targetProfile (string): The name of the target profile.
        - conflictResolution (function): (Optional) A function to resolve conflicts.
]]
function ProfilesManager:mergeSettingsIntoProfile(sourceProfile, targetProfile, conflictResolution)
    assert(type(sourceProfile) == "string", "sourceProfile must be a string.")
    assert(type(targetProfile) == "string", "targetProfile must be a string.")
    if not self:profileExists(sourceProfile) then
        handleError("Source profile does not exist: " .. sourceProfile)
    end
    if not self:profileExists(targetProfile) then
        handleError("Target profile does not exist: " .. targetProfile)
    end

    -- Retrieve settings from both profiles
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

    -- Save merged settings to target profile
    SettingsStorage:save(targetSettings, targetProfile)
    log("Settings merged from '" .. sourceProfile .. "' into '" .. targetProfile .. "'")
end

--[[
    Function: setActiveProfile
    Description: Sets the active profile to the specified profile.
    Parameters:
        - profileName (string): The name of the profile to set as active.
]]
function ProfilesManager:setActiveProfile(profileName)
    assert(type(profileName) == "string", "profileName must be a string.")
    if not self:profileExists(profileName) then
        handleError("Profile does not exist: " .. profileName)
    end

    self.activeProfile = profileName
    SettingsManager:setActiveProfile(profileName)
    log("Active profile set to: " .. profileName)
end

--[[
    Function: getActiveProfile
    Description: Retrieves the name of the currently active profile.
    Returns: The name of the active profile.
]]
function ProfilesManager:getActiveProfile()
    return self.activeProfile
end

--[[
    Function: listProfiles
    Description: Prints all available profiles, indicating the active profile.
]]
function ProfilesManager:listProfiles()
    print("Available Profiles:")
    for _, name in ipairs(self.profilesList) do
        if name == self.activeProfile then
            print(string.format("- %s (Active)", name))
        else
            print("- " .. name)
        end
    end
end

--[[
    Function: exportProfile
    Description: Exports a profile's settings to a table.
    Parameters:
        - profileName (string): The name of the profile to export.
    Returns: A table containing the profile's settings.
]]
function ProfilesManager:exportProfile(profileName)
    assert(type(profileName) == "string", "profileName must be a string.")
    if not self:profileExists(profileName) then
        handleError("Profile does not exist: " .. profileName)
    end

    local success, settingsData = pcall(function()
        return SettingsStorage:load(profileName)
    end)
    if not success or not settingsData then
        handleError("Failed to export settings from profile: " .. profileName)
    end

    log("Profile exported: " .. profileName)
    return settingsData
end

--[[
    Function: importProfile
    Description: Imports settings into a profile from a table.
    Parameters:
        - profileName (string): The name of the profile to import into.
        - settingsData (table): The settings data to import.
]]
function ProfilesManager:importProfile(profileName, settingsData)
    assert(type(profileName) == "string", "profileName must be a string.")
    assert(type(settingsData) == "table", "settingsData must be a table.")
    if not self:profileExists(profileName) then
        handleError("Profile does not exist: " .. profileName)
    end

    -- Merge settings into the profile
    SettingsManager:mergeSettings(settingsData)
    SettingsStorage:save(settingsData, profileName)
    log("Profile imported: " .. profileName)
end

--[[
    Function: mergeProfiles
    Description: Merges settings from sourceProfile into targetProfile.
    Parameters:
        - sourceProfile (string): The name of the profile to merge from.
        - targetProfile (string): The name of the profile to merge into.
        - conflictResolution (function): (Optional) A function that defines how to resolve conflicts. It should accept two values and return the desired value.
]]
function ProfilesManager:mergeProfiles(sourceProfile, targetProfile, conflictResolution)
    assert(type(sourceProfile) == "string", "sourceProfile must be a string.")
    assert(type(targetProfile) == "string", "targetProfile must be a string.")
    if not self:profileExists(sourceProfile) then
        handleError("Source profile does not exist: " .. sourceProfile)
    end
    if not self:profileExists(targetProfile) then
        handleError("Target profile does not exist: " .. targetProfile)
    end

    -- Retrieve settings from both profiles
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
    log("Profiles merged from '" .. sourceProfile .. "' into '" .. targetProfile .. "'")
end

--[[
    Function: generateProfilesReport
    Description: Generates a detailed report of all profiles and their settings for debugging.
    Returns: A formatted string containing the profiles report.
]]
function ProfilesManager:generateProfilesReport()
    local report = "Profiles Report:\n"
    for _, profileName in ipairs(self.profilesList) do
        report = report .. string.format("Profile: %s\n", profileName)
        local success, settingsData = pcall(function()
            return SettingsStorage:load(profileName)
        end)
        if success and settingsData then
            for key, value in pairs(settingsData) do
                report = report .. string.format("  - %s: %s\n", key, tostring(value))
            end
        else
            report = report .. "  - Failed to load settings.\n"
        end
        report = report .. "\n"
    end
    return report
end

--[[
    Function: exportAllProfiles
    Description: Exports all profiles and their settings to a table.
    Returns: A table containing all profiles and their settings.
]]
function ProfilesManager:exportAllProfiles()
    local exportData = {}
    for _, profileName in ipairs(self.profilesList) do
        local success, settingsData = pcall(function()
            return SettingsStorage:load(profileName)
        end)
        if success and settingsData then
            exportData[profileName] = settingsData
        else
            log("Failed to export settings for profile: " .. profileName)
        end
    end
    log("All profiles exported.")
    return exportData
end

--[[
    Function: importAllProfiles
    Description: Imports multiple profiles from a table.
    Parameters:
        - importData (table): A table containing profiles and their settings.
]]
function ProfilesManager:importAllProfiles(importData)
    assert(type(importData) == "table", "importData must be a table.")
    for profileName, settingsData in pairs(importData) do
        if not self:profileExists(profileName) then
            self:createProfile(profileName)
        end
        self:importProfile(profileName, settingsData)
        log("Imported profile: " .. profileName)
    end
    log("All profiles imported.")
end

--[[
    Function: setActiveProfile
    Description: Sets the active profile to the specified profile.
    Parameters:
        - profileName (string): The name of the profile to set as active.
]]
function ProfilesManager:setActiveProfile(profileName)
    assert(type(profileName) == "string", "profileName must be a string.")
    if not self:profileExists(profileName) then
        handleError("Profile does not exist: " .. profileName)
    end

    self.activeProfile = profileName
    SettingsManager:setActiveProfile(profileName)
    log("Active profile set to: " .. profileName)
end

--[[
    Function: getActiveProfile
    Description: Retrieves the name of the currently active profile.
    Returns: The name of the active profile.
]]
function ProfilesManager:getActiveProfile()
    return self.activeProfile
end

--[[
    Function: listProfiles
    Description: Prints all available profiles, indicating the active profile.
]]
function ProfilesManager:listProfiles()
    print("Available Profiles:")
    for _, name in ipairs(self.profilesList) do
        if name == self.activeProfile then
            print(string.format("- %s (Active)", name))
        else
            print("- " .. name)
        end
    end
end

--[[
    Function: getDefaultProfileName
    Description: Retrieves the name of the default profile.
    Returns: The name of the default profile.
]]
function ProfilesManager:getDefaultProfileName()
    return ProfilesManager.DEFAULT_PROFILE_NAME
end

--[[
    Function: exportProfile
    Description: Exports a profile's settings to a table.
    Parameters:
        - profileName (string): The name of the profile to export.
    Returns: A table containing the profile's settings.
]]
function ProfilesManager:exportProfile(profileName)
    assert(type(profileName) == "string", "profileName must be a string.")
    if not self:profileExists(profileName) then
        handleError("Profile does not exist: " .. profileName)
    end

    local success, settingsData = pcall(function()
        return SettingsStorage:load(profileName)
    end)
    if not success or not settingsData then
        handleError("Failed to export settings from profile: " .. profileName)
    end

    log("Profile exported: " .. profileName)
    return settingsData
end

--[[
    Function: importProfile
    Description: Imports settings into a profile from a table.
    Parameters:
        - profileName (string): The name of the profile to import into.
        - settingsData (table): The settings data to import.
]]
function ProfilesManager:importProfile(profileName, settingsData)
    assert(type(profileName) == "string", "profileName must be a string.")
    assert(type(settingsData) == "table", "settingsData must be a table.")
    if not self:profileExists(profileName) then
        handleError("Profile does not exist: " .. profileName)
    end

    -- Merge settings into the profile
    SettingsManager:mergeSettings(settingsData)
    SettingsStorage:save(settingsData, profileName)
    log("Profile imported: " .. profileName)
end

--[[
    Function: exportAllProfiles
    Description: Exports all profiles and their settings to a table.
    Returns: A table containing all profiles and their settings.
]]
function ProfilesManager:exportAllProfiles()
    local exportData = {}
    for _, profileName in ipairs(self.profilesList) do
        local success, settingsData = pcall(function()
            return SettingsStorage:load(profileName)
        end)
        if success and settingsData then
            exportData[profileName] = settingsData
        else
            log("Failed to export settings for profile: " .. profileName)
        end
    end
    log("All profiles exported.")
    return exportData
end

--[[
    Function: importAllProfiles
    Description: Imports multiple profiles from a table.
    Parameters:
        - importData (table): A table containing profiles and their settings.
]]
function ProfilesManager:importAllProfiles(importData)
    assert(type(importData) == "table", "importData must be a table.")
    for profileName, settingsData in pairs(importData) do
        if not self:profileExists(profileName) then
            self:createProfile(profileName)
        end
        self:importProfile(profileName, settingsData)
        log("Imported profile: " .. profileName)
    end
    log("All profiles imported.")
end

--[[
    Function: mergeSettingsIntoProfile
    Description: Merges settings from sourceProfile into targetProfile.
    Parameters:
        - sourceProfile (string): The name of the profile to merge from.
        - targetProfile (string): The name of the profile to merge into.
        - conflictResolution (function): (Optional) A function to resolve conflicts.
]]
function ProfilesManager:mergeSettingsIntoProfile(sourceProfile, targetProfile, conflictResolution)
    assert(type(sourceProfile) == "string", "sourceProfile must be a string.")
    assert(type(targetProfile) == "string", "targetProfile must be a string.")
    if not self:profileExists(sourceProfile) then
        handleError("Source profile does not exist: " .. sourceProfile)
    end
    if not self:profileExists(targetProfile) then
        handleError("Target profile does not exist: " .. targetProfile)
    end

    -- Retrieve settings from both profiles
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
    log("Profiles merged from '" .. sourceProfile .. "' into '" .. targetProfile .. "'")
end

--[[
    Function: renameProfile
    Description: Renames an existing profile.
    Parameters:
        - oldName (string): The current name of the profile.
        - newName (string): The new name for the profile.
]]
function ProfilesManager:renameProfile(oldName, newName)
    assert(type(oldName) == "string", "oldName must be a string.")
    assert(type(newName) == "string", "newName must be a string.")
    if not self:profileExists(oldName) then
        handleError("Profile does not exist: " .. oldName)
    end
    if self:profileExists(newName) then
        handleError("New profile name already exists: " .. newName)
    end

    -- Update profilesList
    for i, name in ipairs(self.profilesList) do
        if name == oldName then
            self.profilesList[i] = newName
            break
        end
    end

    -- Save the updated profiles list
    SettingsStorage:save({ [ProfilesManager.PROFILES_LIST_KEY] = self.profilesList }, "profiles")

    -- Rename settings file and backups
    SettingsManager:renameProfileFiles(oldName, newName)
    log("Profile renamed from '" .. oldName .. "' to '" .. newName .. "'")

    -- Update activeProfile if necessary
    if self.activeProfile == oldName then
        self.activeProfile = newName
        SettingsManager:setActiveProfile(newName)
        log("Active profile updated to: " .. newName)
    end
end

--[[
    Function: generateProfilesReport
    Description: Generates a detailed report of all profiles and their settings for debugging.
    Returns: A formatted string containing the profiles report.
]]
function ProfilesManager:generateProfilesReport()
    local report = "Profiles Report:\n"
    for _, profileName in ipairs(self.profilesList) do
        report = report .. string.format("Profile: %s\n", profileName)
        local success, settingsData = pcall(function()
            return SettingsStorage:load(profileName)
        end)
        if success and settingsData then
            for key, value in pairs(settingsData) do
                report = report .. string.format("  - %s: %s\n", key, tostring(value))
            end
        else
            report = report .. "  - Failed to load settings.\n"
        end
        report = report .. "\n"
    end
    return report
end

--[[
    Function: deleteAllProfiles
    Description: Deletes all profiles except the default profile.
]]
function ProfilesManager:deleteAllProfiles()
    for _, profileName in ipairs({ table.unpack(self.profilesList) }) do
        if profileName ~= ProfilesManager.DEFAULT_PROFILE_NAME then
            self:deleteProfile(profileName)
        end
    end
    log("All non-default profiles have been deleted.")
end

--[[
    Function: resetAllProfiles
    Description: Resets all profiles to their default settings.
]]
function ProfilesManager:resetAllProfiles()
    for _, profileName in ipairs(self.profilesList) do
        SettingsManager:resetAllSettings()
        SettingsStorage:save(SettingsManager:getAllSettings(), profileName)
        log("Profile reset to default settings: " .. profileName)
    end
    log("All profiles have been reset to default settings.")
end

--[[
    Function: cleanupOrphanedProfiles
    Description: Removes profiles that no longer have associated settings files.
]]
function ProfilesManager:cleanupOrphanedProfiles()
    local existingProfiles = {}
    for _, profileName in ipairs(self.profilesList) do
        local success, settingsData = pcall(function()
            return SettingsStorage:load(profileName)
        end)
        if not success or not settingsData then
            -- Profile settings file does not exist; remove profile
            self:deleteProfile(profileName)
            log("Orphaned profile removed: " .. profileName)
        else
            table.insert(existingProfiles, profileName)
        end
    end
    self.profilesList = existingProfiles
    SettingsStorage:save({ [ProfilesManager.PROFILES_LIST_KEY] = self.profilesList }, "profiles")
    log("Orphaned profiles cleanup completed.")
end

--[[
    Function: autoBackupProfiles
    Description: Automatically backs up profiles at specified intervals.
    Note: This function should be called periodically, e.g., via a timer or scheduled task.
]]
function ProfilesManager:autoBackupProfiles()
    for _, profileName in ipairs(self.profilesList) do
        SettingsStorage:backupSettingsManually(profileName)
    end
    log("Auto backup of all profiles completed.")
end

--[[
    Function: importProfilesFromFile
    Description: Imports profiles from an external file.
    Parameters:
        - filePath (string): The path to the external file containing profiles data.
]]
function ProfilesManager:importProfilesFromFile(filePath)
    assert(type(filePath) == "string", "filePath must be a string.")
    local success, importData = pcall(function()
        return SettingsStorage:loadFromFile(filePath)
    end)
    if not success or not importData then
        handleError("Failed to import profiles from file: " .. filePath)
    end

    self:importAllProfiles(importData)
    log("Profiles imported from file: " .. filePath)
end

--[[
    Function: exportProfilesToFile
    Description: Exports all profiles to an external file.
    Parameters:
        - filePath (string): The path to the external file to save profiles data.
]]
function ProfilesManager:exportProfilesToFile(filePath)
    assert(type(filePath) == "string", "filePath must be a string.")
    local exportData = self:exportAllProfiles()
    local success, err = pcall(function()
        SettingsStorage:saveToFile(exportData, filePath)
    end)
    if not success then
        handleError("Failed to export profiles to file: " .. err)
    end
    log("Profiles exported to file: " .. filePath)
end

--[[
    Function: resetProfile
    Description: Resets a specific profile to its default settings.
    Parameters:
        - profileName (string): The name of the profile to reset.
]]
function ProfilesManager:resetProfile(profileName)
    assert(type(profileName) == "string", "profileName must be a string.")
    if not self:profileExists(profileName) then
        handleError("Profile does not exist: " .. profileName)
    end

    SettingsManager:resetAllSettings()
    SettingsStorage:save(SettingsManager:getAllSettings(), profileName)
    log("Profile reset to default settings: " .. profileName)
end

--[[
    Function: resetAllProfiles
    Description: Resets all profiles to their default settings.
]]
function ProfilesManager:resetAllProfiles()
    for _, profileName in ipairs(self.profilesList) do
        self:resetProfile(profileName)
    end
    log("All profiles have been reset to default settings.")
end

--[[
    Function: mergeSettingsFromProfile
    Description: Merges settings from one profile into another with optional conflict resolution.
    Parameters:
        - sourceProfile (string): The name of the source profile.
        - targetProfile (string): The name of the target profile.
        - conflictResolution (function): (Optional) A function to resolve conflicts.
]]
function ProfilesManager:mergeSettingsFromProfile(sourceProfile, targetProfile, conflictResolution)
    self:mergeProfiles(sourceProfile, targetProfile, conflictResolution)
end

--[[
    Function: findProfilesByCriteria
    Description: Finds profiles that match certain criteria.
    Parameters:
        - criteriaFunction (function): A function that accepts a profile name and returns true if it matches the criteria.
    Returns: A table of profile names that match the criteria.
]]
function ProfilesManager:findProfilesByCriteria(criteriaFunction)
    assert(type(criteriaFunction) == "function", "criteriaFunction must be a function.")
    local matchingProfiles = {}
    for _, profileName in ipairs(self.profilesList) do
        if criteriaFunction(profileName) then
            table.insert(matchingProfiles, profileName)
        end
    end
    return matchingProfiles
end

--[[
    Function: backupAllProfiles
    Description: Creates backups for all profiles.
]]
function ProfilesManager:backupAllProfiles()
    for _, profileName in ipairs(self.profilesList) do
        SettingsStorage:backupSettingsManually(profileName)
    end
    log("All profiles have been backed up.")
end

--[[
    Function: recoverProfilesFromBackup
    Description: Recovers profiles from their most recent backups.
]]
function ProfilesManager:recoverProfilesFromBackup()
    for _, profileName in ipairs(self.profilesList) do
        local settingsData = SettingsStorage:recoverFromBackup(profileName)
        if settingsData then
            SettingsManager:mergeSettings(settingsData)
            SettingsStorage:save(settingsData, profileName)
            log("Recovered profile from backup: " .. profileName)
        else
            log("Failed to recover profile from backup: " .. profileName)
        end
    end
    log("Profiles recovery from backups completed.")
end

--[[
    Function: cleanupOrphanedProfiles
    Description: Removes profiles that no longer have associated settings files.
]]
function ProfilesManager:cleanupOrphanedProfiles()
    local existingProfiles = {}
    for _, profileName in ipairs(self.profilesList) do
        local success, settingsData = pcall(function()
            return SettingsStorage:load(profileName)
        end)
        if success and settingsData then
            table.insert(existingProfiles, profileName)
        else
            self:deleteProfile(profileName)
            log("Orphaned profile removed: " .. profileName)
        end
    end
    self.profilesList = existingProfiles
    SettingsStorage:save({ [ProfilesManager.PROFILES_LIST_KEY] = self.profilesList }, "profiles")
    log("Orphaned profiles cleanup completed.")
end

--[[
    Function: validateProfiles
    Description: Validates all profiles' settings against the registered settings.
]]
function ProfilesManager:validateProfiles()
    for _, profileName in ipairs(self.profilesList) do
        local success, settingsData = pcall(function()
            return SettingsStorage:load(profileName)
        end)
        if success and settingsData then
            for key, value in pairs(settingsData) do
                if SettingsManager.registeredSettings[key] then
                    local validator = SettingsManager.settingsValidators[key]
                    if not validator(value) then
                        log(string.format("Invalid value for setting '%s' in profile '%s'. Resetting to default.", key, profileName))
                        settingsData[key] = SettingsManager.settingsDefaults[key]
                        SettingsCallbacks:handleSettingChange(key, settingsData[key])
                    end
                else
                    log(string.format("Unregistered setting '%s' found in profile '%s'. Ignoring.", key, profileName))
                end
            end
            -- Save validated settings
            SettingsStorage:save(settingsData, profileName)
        else
            log(string.format("Failed to load settings for profile '%s' during validation.", profileName))
        end
    end
    log("Profiles validation completed.")
end

--[[
    Function: scheduleAutoBackup
    Description: Schedules automatic backups at specified intervals.
    Parameters:
        - interval (number): The time interval between backups in seconds.
    Note: This function requires integration with a scheduler or event loop.
]]
function ProfilesManager:scheduleAutoBackup(interval)
    assert(type(interval) == "number" and interval > 0, "interval must be a positive number.")
    -- Placeholder for scheduling logic. Integration with an external scheduler is required.
    -- Example using a hypothetical scheduler:
    -- Scheduler.scheduleRepeating(function() self:autoBackupProfiles() end, interval)
    log(string.format("Auto backup scheduled every %d seconds.", interval))
end

--[[
    Function: autoBackupProfiles
    Description: Automatically backs up profiles. Intended to be called by a scheduler.
]]
function ProfilesManager:autoBackupProfiles()
    for _, profileName in ipairs(self.profilesList) do
        SettingsStorage:backupSettingsManually(profileName)
    end
    log("Auto backup of all profiles completed.")
end

--[[
    Function: cleanupBackups
    Description: Cleans up old backups based on the maximum number of backups allowed.
]]
function ProfilesManager:cleanupBackups()
    for _, profileName in ipairs(self.profilesList) do
        SettingsStorage:manageBackups(profileName)
    end
    log("Cleanup of old backups completed.")
end

--[[
    Function: initialize
    Description: Initializes the ProfilesManager module.
]]
function ProfilesManager:initialize()
    self:initialize()
end

-- Initialize the ProfilesManager
ProfilesManager:initialize()

return ProfilesManager
