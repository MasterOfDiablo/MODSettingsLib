-- File: core/settings_storage.lua
-- Author: MasterOfDiablo
-- Description: Handles persistent storage of settings, profiles, and backups with encryption and integrity checks.
-- Version: 1.0.0

local SettingsStorage = {}
SettingsStorage.__index = SettingsStorage

-- Dependencies
local lfs = require("lfs")              -- LuaFileSystem for directory operations
local json = require("dkjson")          -- JSON encoding/decoding
local crypto = require("crypto")        -- LuaCrypto for encryption and hashing
local zlib = require("zlib")            -- For compression
local Encryption = require("security.encryption")
local Integrity = require("security.integrity")
local ErrorLogger = require("debugging/error_logger")

-- Constants
SettingsStorage.STORAGE_DIR = "MODSettingsLib_Data"       -- Directory to store settings
SettingsStorage.BACKUP_DIR = "MODSettingsLib_Backups"     -- Directory to store backups
SettingsStorage.BACKUP_EXTENSION = ".bak"                -- Backup file extension

-- Ensure storage directories exist
local function ensureDirectories()
    local attributes = lfs.attributes(SettingsStorage.STORAGE_DIR)
    if not attributes then
        local success, err = lfs.mkdir(SettingsStorage.STORAGE_DIR)
        if not success then
            ErrorLogger:logError("Failed to create storage directory: " .. tostring(err))
            return false
        end
    end

    attributes = lfs.attributes(SettingsStorage.BACKUP_DIR)
    if not attributes then
        local success, err = lfs.mkdir(SettingsStorage.BACKUP_DIR)
        if not success then
            ErrorLogger:logError("Failed to create backup directory: " .. tostring(err))
            return false
        end
    end
    return true
end

-- Initialize storage directories
local function initializeStorage()
    if not ensureDirectories() then
        ErrorLogger:logError("Failed to initialize storage directories.")
    else
        ErrorLogger:logInfo("Storage directories initialized.")
    end
end

-- Encryption and Integrity Handlers
local function encryptData(data)
    local encrypted = Encryption:encrypt(data)
    return encrypted
end

local function decryptData(encryptedData)
    local decrypted = Encryption:decrypt(encryptedData)
    return decrypted
end

local function attachIntegrity(data)
    local combined = Integrity:attachHash(data)
    return combined
end

local function verifyAndExtractIntegrity(combinedData)
    local data, hash = Integrity:extractDataAndHash(combinedData)
    local isValid = Integrity:verifyIntegrity(data, hash)
    if isValid then
        return data
    else
        return nil
    end
end

-- Logging
local function log(message)
    print("[SettingsStorage] " .. message)
    ErrorLogger:logInfo("[SettingsStorage] " .. message)
end

-- Error handling
local function handleError(message)
    print("[SettingsStorage] ERROR: " .. message)
    ErrorLogger:logError("[SettingsStorage] " .. message)
    error("[SettingsStorage] " .. message)
end

--[[
    Function: save
    Description: Saves settings to a JSON file with encryption and integrity checks.
    Parameters:
        - data (table): The settings data to save.
        - profileName (string): The profile name to save under.
    ]]
function SettingsStorage:save(data, profileName)
    assert(type(data) == "table", "Data must be a table.")
    assert(type(profileName) == "string", "Profile name must be a string.")

    -- Serialize to JSON
    local jsonData = json.encode(data, { indent = true })
    if not jsonData then
        handleError("Failed to encode data to JSON.")
    end

    -- Attach integrity hash
    local dataWithHash = attachIntegrity(jsonData)

    -- Compress data
    local compressedData = zlib.deflate()(dataWithHash, "finish")

    -- Encrypt data
    local encryptedData = encryptData(compressedData)

    -- Define file path
    local filePath = self:getSettingsFilePath(profileName)

    -- Write to file
    local file, err = io.open(filePath, "w")
    if not file then
        handleError("Failed to open file for writing: " .. filePath .. " Error: " .. tostring(err))
    end
    file:write(encryptedData)
    file:close()

    log("Settings saved successfully to " .. filePath)
end

--[[
    Function: load
    Description: Loads settings from a JSON file with decryption and integrity checks.
    Parameters:
        - profileName (string): The profile name to load.
    Returns: A table containing the settings data.
    ]]
function SettingsStorage:load(profileName)
    assert(type(profileName) == "string", "Profile name must be a string.")

    -- Define file path
    local filePath = self:getSettingsFilePath(profileName)

    -- Read file
    local file, err = io.open(filePath, "r")
    if not file then
        handleError("Failed to open file for reading: " .. filePath .. " Error: " .. tostring(err))
    end
    local encryptedData = file:read("*all")
    file:close()

    -- Decrypt data
    local compressedData = decryptData(encryptedData)
    if not compressedData then
        handleError("Decryption failed for file: " .. filePath)
    end

    -- Decompress data
    local decompressedData, status = zlib.inflate()(compressedData)
    if not decompressedData or status ~= "finish" then
        handleError("Decompression failed for file: " .. filePath)
    end

    -- Verify integrity and extract original data
    local jsonData = verifyAndExtractIntegrity(decompressedData)
    if not jsonData then
        handleError("Data integrity verification failed for file: " .. filePath)
    end

    -- Decode JSON
    local data, pos, err = json.decode(jsonData, 1, nil)
    if err then
        handleError("JSON decoding failed for file: " .. filePath .. " Error: " .. tostring(err))
    end

    log("Settings loaded successfully from " .. filePath)
    return data
end

--[[
    Function: backupSettingsManually
    Description: Creates a manual backup of the settings for a given profile.
    Parameters:
        - profileName (string): The profile name to backup.
    ]]
function SettingsStorage:backupSettingsManually(profileName)
    assert(type(profileName) == "string", "Profile name must be a string.")

    -- Define source and backup file paths
    local sourcePath = self:getSettingsFilePath(profileName)
    local timestamp = os.time()
    local backupPath = self:getBackupFilePath(profileName, timestamp)

    -- Copy file
    local sourceFile, err = io.open(sourcePath, "r")
    if not sourceFile then
        handleError("Failed to open source file for backup: " .. sourcePath .. " Error: " .. tostring(err))
    end
    local data = sourceFile:read("*all")
    sourceFile:close()

    local backupFile, err = io.open(backupPath, "w")
    if not backupFile then
        handleError("Failed to open backup file for writing: " .. backupPath .. " Error: " .. tostring(err))
    end
    backupFile:write(data)
    backupFile:close()

    log("Backup created for profile '" .. profileName .. "' at " .. backupPath)
    return true
end

--[[
    Function: recoverFromBackup
    Description: Recovers settings from the most recent backup for a given profile.
    Parameters:
        - profileName (string): The profile name to recover.
    Returns: A table containing the recovered settings data.
    ]]
function SettingsStorage:recoverFromBackup(profileName)
    assert(type(profileName) == "string", "Profile name must be a string.")

    -- Find the latest backup
    local backups = self:listBackups(profileName)
    if #backups == 0 then
        handleError("No backups available for profile: " .. profileName)
    end

    -- Assume backups are sorted by timestamp ascending
    local latestBackup = backups[#backups]
    local backupPath = latestBackup.path

    -- Read backup file
    local file, err = io.open(backupPath, "r")
    if not file then
        handleError("Failed to open backup file for reading: " .. backupPath .. " Error: " .. tostring(err))
    end
    local encryptedData = file:read("*all")
    file:close()

    -- Decrypt data
    local compressedData = decryptData(encryptedData)
    if not compressedData then
        handleError("Decryption failed for backup file: " .. backupPath)
    end

    -- Decompress data
    local decompressedData, status = zlib.inflate()(compressedData)
    if not decompressedData or status ~= "finish" then
        handleError("Decompression failed for backup file: " .. backupPath)
    end

    -- Verify integrity and extract original data
    local jsonData = verifyAndExtractIntegrity(decompressedData)
    if not jsonData then
        handleError("Data integrity verification failed for backup file: " .. backupPath)
    end

    -- Decode JSON
    local data, pos, err = json.decode(jsonData, 1, nil)
    if err then
        handleError("JSON decoding failed for backup file: " .. backupPath .. " Error: " .. tostring(err))
    end

    log("Settings recovered from backup: " .. backupPath)
    return data
end

--[[
    Function: listBackups
    Description: Lists all backups for a given profile, sorted by timestamp ascending.
    Parameters:
        - profileName (string): The profile name to list backups for.
    Returns: A table of backup entries with path and timestamp.
    ]]
function SettingsStorage:listBackups(profileName)
    assert(type(profileName) == "string", "Profile name must be a string.")
    local backups = {}
    for file in lfs.dir(SettingsStorage.BACKUP_DIR) do
        if string.find(file, "^" .. profileName .. "_%d+" .. SettingsStorage.BACKUP_EXTENSION .. "$") then
            local timestampStr = string.match(file, "^" .. profileName .. "_(%d+)" .. SettingsStorage.BACKUP_EXTENSION .. "$")
            if timestampStr then
                local timestamp = tonumber(timestampStr)
                table.insert(backups, { path = SettingsStorage.BACKUP_DIR .. "/" .. file, timestamp = timestamp })
            end
        end
    end

    -- Sort backups by timestamp ascending
    table.sort(backups, function(a, b) return a.timestamp < b.timestamp end)
    return backups
end

--[[
    Function: manageBackups
    Description: Manages backups by limiting the number of backups and removing the oldest if necessary.
    Parameters:
        - profileName (string): The profile name to manage backups for.
    ]]
function SettingsStorage:manageBackups(profileName)
    local maxBackups = 5  -- Maximum number of backups to keep
    local backups = self:listBackups(profileName)
    while #backups > maxBackups do
        local oldestBackup = table.remove(backups, 1)
        local success, err = os.remove(oldestBackup.path)
        if success then
            log("Oldest backup removed: " .. oldestBackup.path)
        else
            handleError("Failed to remove old backup: " .. oldestBackup.path .. " Error: " .. tostring(err))
        end
    end
end

--[[
    Function: getSettingsFilePath
    Description: Constructs the file path for a profile's settings file.
    Parameters:
        - profileName (string): The profile name.
    Returns: The full file path as a string.
    ]]
function SettingsStorage:getSettingsFilePath(profileName)
    return SettingsStorage.STORAGE_DIR .. "/" .. profileName .. ".json"
end

--[[
    Function: getBackupFilePath
    Description: Constructs the file path for a backup file.
    Parameters:
        - profileName (string): The profile name.
        - timestamp (number): The timestamp of the backup.
    Returns: The full backup file path as a string.
    ]]
function SettingsStorage:getBackupFilePath(profileName, timestamp)
    return SettingsStorage.BACKUP_DIR .. "/" .. profileName .. "_" .. tostring(timestamp) .. SettingsStorage.BACKUP_EXTENSION
end

--[[
    Function: renameProfileFiles
    Description: Renames the settings file and all backups when a profile is renamed.
    Parameters:
        - oldName (string): The current name of the profile.
        - newName (string): The new name for the profile.
    ]]
function SettingsStorage:renameProfileFiles(oldName, newName)
    -- Rename settings file
    local oldFilePath = self:getSettingsFilePath(oldName)
    local newFilePath = self:getSettingsFilePath(newName)
    local success, err = pcall(function()
        os.rename(oldFilePath, newFilePath)
    end)
    if not success then
        handleError("Failed to rename settings file from '" .. oldFilePath .. "' to '" .. newFilePath .. "': " .. tostring(err))
    end
    log("Settings file renamed from '" .. oldFilePath .. "' to '" .. newFilePath .. "'")

    -- Rename backup files
    local backups = self:listBackups(oldName)
    for _, backup in ipairs(backups) do
        local oldBackupPath = backup.path
        local timestamp = backup.timestamp
        local newBackupPath = self:getBackupFilePath(newName, timestamp)
        local success, err = pcall(function()
            os.rename(oldBackupPath, newBackupPath)
        end)
        if not success then
            handleError("Failed to rename backup file from '" .. oldBackupPath .. "' to '" .. newBackupPath .. "': " .. tostring(err))
        end
        log("Backup file renamed from '" .. oldBackupPath .. "' to '" .. newBackupPath .. "'")
    end
end

--[[
    Function: saveToFile
    Description: Saves settings data to an external file without encryption (for exporting).
    Parameters:
        - data (table): The settings data to save.
        - filePath (string): The file path to save the data to.
    ]]
function SettingsStorage:saveToFile(data, filePath)
    assert(type(data) == "table", "Data must be a table.")
    assert(type(filePath) == "string", "File path must be a string.")

    -- Serialize to JSON
    local jsonData = json.encode(data, { indent = true })
    if not jsonData then
        handleError("Failed to encode data to JSON for export.")
    end

    -- Write to file
    local file, err = io.open(filePath, "w")
    if not file then
        handleError("Failed to open export file for writing: " .. filePath .. " Error: " .. tostring(err))
    end
    file:write(jsonData)
    file:close()

    log("Settings exported successfully to " .. filePath)
    return true
end

--[[
    Function: loadFromFile
    Description: Loads settings data from an external file without decryption (for importing).
    Parameters:
        - filePath (string): The file path to load the data from.
    Returns: A table containing the settings data.
    ]]
function SettingsStorage:loadFromFile(filePath)
    assert(type(filePath) == "string", "File path must be a string.")

    -- Read file
    local file, err = io.open(filePath, "r")
    if not file then
        handleError("Failed to open import file for reading: " .. filePath .. " Error: " .. tostring(err))
    end
    local jsonData = file:read("*all")
    file:close()

    -- Decode JSON
    local data, pos, err = json.decode(jsonData, 1, nil)
    if err then
        handleError("JSON decoding failed for import file: " .. filePath .. " Error: " .. tostring(err))
    end

    log("Settings imported successfully from " .. filePath)
    return data
end

-- Initialize the SettingsStorage module
function SettingsStorage:initialize()
    initializeStorage()
    log("SettingsStorage initialized.")
end

-- Initialize upon loading
SettingsStorage:initialize()

return SettingsStorage
