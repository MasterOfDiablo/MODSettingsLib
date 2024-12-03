-- File: debugging/error_logger.lua
-- Author: MasterOfDiablo
-- Description: Handles logging of informational messages, warnings, and errors.
-- Version: 1.0.0

local ErrorLogger = {}
ErrorLogger.__index = ErrorLogger

-- Dependencies
local lfs = require("lfs")

-- Constants
ErrorLogger.LOG_FILE = "MODSettingsLib_Log.txt"
ErrorLogger.LOG_DIR = "MODSettingsLib_Logs"

-- Ensure log directory exists
local function ensureLogDirectory()
    local attributes = lfs.attributes(ErrorLogger.LOG_DIR)
    if not attributes then
        local success, err = lfs.mkdir(ErrorLogger.LOG_DIR)
        if not success then
            print("[ErrorLogger] Failed to create log directory: " .. tostring(err))
            return false
        end
    end
    return true
end

-- Initialize log directory
local function initializeLogger()
    if not ensureLogDirectory() then
        print("[ErrorLogger] Logger initialization failed.")
    else
        print("[ErrorLogger] Logger initialized.")
    end
end

-- Logging Levels
local LOG_LEVELS = {
    INFO = "[INFO]",
    WARNING = "[WARNING]",
    ERROR = "[ERROR]",
}

--[[
    Function: log
    Description: Writes a log message to the log file with the specified level.
    Parameters:
        - level (string): The log level (INFO, WARNING, ERROR).
        - message (string): The log message.
]]
function ErrorLogger:log(level, message)
    if not ensureLogDirectory() then
        return
    end

    local logPath = self.LOG_DIR .. "/" .. self.LOG_FILE
    local file, err = io.open(logPath, "a")
    if not file then
        print("[ErrorLogger] Failed to open log file: " .. tostring(err))
        return
    end

    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    file:write(string.format("%s %s %s\n", timestamp, LOG_LEVELS[level] or "[INFO]", message))
    file:close()
end

--[[
    Function: logInfo
    Description: Logs an informational message.
    Parameters:
        - message (string): The message to log.
]]
function ErrorLogger:logInfo(message)
    self:log("INFO", message)
end

--[[
    Function: logWarning
    Description: Logs a warning message.
    Parameters:
        - message (string): The warning message to log.
]]
function ErrorLogger:logWarning(message)
    self:log("WARNING", message)
end

--[[
    Function: logError
    Description: Logs an error message.
    Parameters:
        - message (string): The error message to log.
]]
function ErrorLogger:logError(message)
    self:log("ERROR", message)
end

--[[
    Function: getLogContents
    Description: Retrieves the contents of the log file.
    Returns: A string containing the log file contents.
]]
function ErrorLogger:getLogContents()
    local logPath = self.LOG_DIR .. "/" .. self.LOG_FILE
    local file, err = io.open(logPath, "r")
    if not file then
        print("[ErrorLogger] Failed to open log file: " .. tostring(err))
        return ""
    end
    local contents = file:read("*all")
    file:close()
    return contents
end

-- Initialize the ErrorLogger
function ErrorLogger:initialize()
    initializeLogger()
end

-- Initialize upon loading
ErrorLogger:initialize()

return ErrorLogger
