-- File: settings_callbacks.lua
-- Manages callbacks triggered by setting changes, including prioritization, conditions, and debugging.

local SettingsCallbacks = {}

-- Storage for registered callbacks, grouped by setting key
SettingsCallbacks.callbacks = {}

--[[
    Function: registerCallback
    Description: Registers a callback for a specific setting.
    Parameters:
        - settingKey (string): The unique key for the setting.
        - callback (function): The function to execute when the setting changes.
        - priority (number): (Optional) The priority of the callback (higher = earlier execution).
        - condition (function): (Optional) A condition function that determines whether the callback should execute.
    Example Usage:
        SettingsCallbacks:registerCallback("example_setting", function(value) print(value) end, 10)
]]
function SettingsCallbacks:registerCallback(settingKey, callback, priority, condition)
    assert(type(settingKey) == "string", "Setting key must be a string.")
    assert(type(callback) == "function", "Callback must be a function.")

    if not self.callbacks[settingKey] then
        self.callbacks[settingKey] = {}
    end

    table.insert(self.callbacks[settingKey], {
        callback = callback,
        priority = priority or 0,
        condition = condition or nil,
    })

    -- Sort callbacks by priority (descending)
    table.sort(self.callbacks[settingKey], function(a, b)
        return a.priority > b.priority
    end)
end

--[[
    Function: unregisterCallback
    Description: Unregisters a specific callback for a setting by reference.
    Parameters:
        - settingKey (string): The unique key for the setting.
        - callback (function): The callback function to remove.
    Example Usage:
        SettingsCallbacks:unregisterCallback("example_setting", someCallbackFunction)
]]
function SettingsCallbacks:unregisterCallback(settingKey, callback)
    assert(type(settingKey) == "string", "Setting key must be a string.")
    assert(type(callback) == "function", "Callback must be a function.")

    if not self.callbacks[settingKey] then
        return
    end

    for i, cb in ipairs(self.callbacks[settingKey]) do
        if cb.callback == callback then
            table.remove(self.callbacks[settingKey], i)
            return
        end
    end
end

--[[
    Function: handleSettingChange
    Description: Executes all callbacks registered for a specific setting.
    Parameters:
        - settingKey (string): The unique key for the setting.
        - newValue (any): The new value of the setting.
    Example Usage:
        SettingsCallbacks:handleSettingChange("example_setting", 42)
]]
function SettingsCallbacks:handleSettingChange(settingKey, newValue)
    if not self.callbacks[settingKey] then
        return
    end

    for _, cb in ipairs(self.callbacks[settingKey]) do
        local shouldExecute = true

        -- Evaluate condition if present
        if cb.condition and type(cb.condition) == "function" then
            local status, result = pcall(cb.condition, newValue)
            if status then
                shouldExecute = result
            else
                print("Error in condition function for " .. settingKey .. ": " .. tostring(result))
                shouldExecute = false
            end
        end

        -- Execute the callback if allowed
        if shouldExecute then
            local status, err = pcall(cb.callback, newValue)
            if not status then
                print("Error executing callback for " .. settingKey .. ": " .. tostring(err))
            end
        end
    end
end

--[[
    Function: clearCallbacks
    Description: Clears callbacks for a specific setting or all settings if no key is provided.
    Parameters:
        - settingKey (string): (Optional) The unique key for the setting.
    Example Usage:
        SettingsCallbacks:clearCallbacks() -- Clears all
        SettingsCallbacks:clearCallbacks("example_setting") -- Clears specific setting
]]
function SettingsCallbacks:clearCallbacks(settingKey)
    if settingKey then
        self.callbacks[settingKey] = nil
    else
        self.callbacks = {}
    end
end

--[[
    Function: listCallbacks
    Description: Lists all registered callbacks for debugging purposes.
    Parameters:
        - settingKey (string): (Optional) The unique key for the setting.
    Returns: (table) List of callbacks for the specified setting or all settings.
]]
function SettingsCallbacks:listCallbacks(settingKey)
    if settingKey then
        return self.callbacks[settingKey] or {}
    else
        return self.callbacks
    end
end

--[[
    Function: debugPrintCallbacks
    Description: Prints all registered callbacks to the debug console for review.
]]
function SettingsCallbacks:debugPrintCallbacks()
    for settingKey, callbacks in pairs(self.callbacks) do
        print("Setting: " .. settingKey)
        for i, cb in ipairs(callbacks) do
            print(string.format("  [%d] Priority: %d, Condition: %s", i, cb.priority, type(cb.condition)))
        end
    end
end

--[[
    Function: prioritizeCallback
    Description: Updates the priority of a registered callback.
    Parameters:
        - settingKey (string): The unique key for the setting.
        - callback (function): The callback function to prioritize.
        - newPriority (number): The new priority value.
]]
function SettingsCallbacks:prioritizeCallback(settingKey, callback, newPriority)
    assert(type(settingKey) == "string", "Setting key must be a string.")
    assert(type(callback) == "function", "Callback must be a function.")
    assert(type(newPriority) == "number", "Priority must be a number.")

    if not self.callbacks[settingKey] then
        return
    end

    for _, cb in ipairs(self.callbacks[settingKey]) do
        if cb.callback == callback then
            cb.priority = newPriority
        end
    end

    -- Re-sort callbacks by updated priorities
    table.sort(self.callbacks[settingKey], function(a, b)
        return a.priority > b.priority
    end)
end

--[[
    Function: executeDebugCommand
    Description: Executes a debug command for manipulating callbacks (for developers).
    Parameters:
        - command (string): The command to execute.
]]
function SettingsCallbacks:executeDebugCommand(command)
    assert(type(command) == "string", "Command must be a string.")
    if command == "list" then
        self:debugPrintCallbacks()
    elseif command:sub(1, 6) == "clear " then
        local key = command:sub(7)
        self:clearCallbacks(key)
        print("Cleared callbacks for setting: " .. key)
    else
        print("Unknown debug command: " .. command)
    end
end

return SettingsCallbacks
