-- File: ui/MODSettingsLib_SettingsUI.lua
-- Author: MasterOfDiablo
-- Description: Handles the User Interface for MODSettingsLib, including rendering settings, categories, and profiles.
-- Version: 1.1.0

--[[
    The MODSettingsLib_SettingsUI module manages the rendering and interaction of the settings UI.
    It populates categories, settings, and profiles, and handles user input to modify settings and manage profiles.
]]
local SettingsUI = {}
SettingsUI.__index = SettingsUI

-- Dependencies
local SettingsManager = require("core/settings_manager")
local ProfilesManager = require("profiles/profiles_manager")
local ErrorLogger = require("debugging/error_logger")

-- Constants
local SETTINGS_WINDOW_NAME = "MODSettingsLib_SettingsWindow"

-- Control References
local settingsWindow
local categoriesList
local settingsList
local profilesList
local createProfileButton
local deleteProfileButton
local searchBox

-- Initialization flag
local isInitialized = false

-- Current selected category
local currentCategory = nil

-- Logging
local function log(message)
    print("[SettingsUI] " .. message)
    ErrorLogger:logInfo("[SettingsUI] " .. message)
end

-- Error handling
local function handleError(message)
    print("[SettingsUI] ERROR: " .. message)
    ErrorLogger:logError("[SettingsUI] " .. message)
    -- Optionally, display an in-game error message to the user
end

--[[
    Function: initialize
    Description: Initializes the settings UI, setting up controls and event handlers.
]]
function SettingsUI:initialize()
    if isInitialized then
        return
    end

    -- Reference to the main settings window
    settingsWindow = WINDOW_MANAGER:GetWindowByName(SETTINGS_WINDOW_NAME)
    if not settingsWindow then
        handleError("Settings window not found: " .. SETTINGS_WINDOW_NAME)
        return
    end

    -- Reference to Categories Panel
    categoriesList = settingsWindow.CategoriesPanel.CategoryList

    -- Reference to Settings Panel
    settingsList = settingsWindow.SettingsPanel.SettingsList

    -- Reference to Profiles Panel
    profilesList = settingsWindow.ProfilesPanel.ProfilesList
    createProfileButton = settingsWindow.ProfilesPanel.ProfileButtons.CreateProfileButton
    deleteProfileButton = settingsWindow.ProfilesPanel.ProfileButtons.DeleteProfileButton

    -- Reference to Search Box
    searchBox = WINDOW_MANAGER:CreateControlFromVirtual("$(parent)SearchBox", settingsWindow.SettingsPanel, "ZO_EditBox")
    searchBox:SetAnchor(TOPRIGHT, settingsWindow.SettingsPanel, TOPRIGHT, -10, 10)
    searchBox:SetDimensions(200, 30)
    searchBox:SetFont("ZoFontWinH4")
    searchBox:SetMaxInputChars(0)
    searchBox:SetText("")
    searchBox:SetHintText("Search Settings...")
    searchBox:SetHandler("OnTextChanged", function(control, isUserInput)
        if isUserInput then
            local query = control:GetText()
            self:filterSettingsList(query)
        end
    end)

    -- Populate Categories and Profiles
    self:populateCategories()
    self:populateProfiles()

    -- Set up event handlers for Profile Buttons
    createProfileButton:SetHandler("OnClicked", function()
        self:showCreateProfileDialog()
    end)

    deleteProfileButton:SetHandler("OnClicked", function()
        self:showDeleteProfileDialog()
    end)

    -- Initially select the first category
    if #SettingsManager:getAllCategories() > 0 then
        local firstCategory = SettingsManager:getAllCategories()[1]
        self:selectCategory(firstCategory)
    end

    -- Register for profile changes to update the UI
    EVENT_MANAGER:RegisterForEvent("MODSettingsLib_SettingsUI", EVENT_PROFILE_CHANGED, function(eventCode, profileName)
        self:refreshProfilesList()
        self:refreshSettingsList()
    end)

    isInitialized = true
    log("Settings UI initialized.")
end

--[[
    Function: showSettingsWindow
    Description: Displays the settings window.
]]
function SettingsUI:showSettingsWindow()
    if not isInitialized then
        self:initialize()
    end
    settingsWindow:SetHidden(false)
    log("Settings window displayed.")
end

--[[
    Function: hideSettingsWindow
    Description: Hides the settings window.
]]
function SettingsUI:hideSettingsWindow()
    if settingsWindow then
        settingsWindow:SetHidden(true)
        log("Settings window hidden.")
    end
end

--[[
    Function: toggleSettingsWindow
    Description: Toggles the visibility of the settings window.
]]
function SettingsUI:toggleSettingsWindow()
    if settingsWindow:IsHidden() then
        self:showSettingsWindow()
    else
        self:hideSettingsWindow()
    end
end

--[[
    Function: populateCategories
    Description: Populates the categories list in the UI.
]]
function SettingsUI:populateCategories()
    ZO_ScrollList_Clear(categoriesList)
    
    local categories = SettingsManager:getAllCategories()
    for _, category in ipairs(categories) do
        local data = ZO_ScrollList_CreateDataEntry(1, category)
        ZO_ScrollList_Insert(categoriesList, data)
    end

    -- Set up the category list's callback for selection
    categoriesList:SetHandler("OnRowSelected", function(control, data, selected)
        self:selectCategory(data.data)
    end)

    log("Categories populated.")
end

--[[
    Function: selectCategory
    Description: Handles the selection of a category, populating the settings list.
    Parameters:
        - categoryName (string): The name of the selected category.
]]
function SettingsUI:selectCategory(categoryName)
    currentCategory = categoryName
    ZO_ScrollList_Clear(settingsList)
    self:populateSettingsList(categoryName)
    log("Category selected: " .. categoryName)
end

--[[
    Function: populateSettingsList
    Description: Populates the settings list based on the selected category.
    Parameters:
        - categoryName (string): The name of the selected category.
]]
function SettingsUI:populateSettingsList(categoryName)
    ZO_ScrollList_Clear(settingsList)
    
    local settingsKeys = SettingsManager:getSettingsByCategory(categoryName)
    for _, fullKey in ipairs(settingsKeys) do
        local modName, settingKey = string.match(fullKey, "^(.-)%.([^%.]+)$")
        local settingMetadata = SettingsManager:getSettingMetadata(modName, settingKey)
        local settingValue = SettingsManager:getSetting(modName, settingKey)
        
        local rowData = ZO_ScrollList_CreateDataEntry(1, fullKey)
        rowData.data = {
            fullKey = fullKey,
            settingKey = settingKey,
            settingName = string.gsub(settingKey, "_", " "),
            settingType = settingMetadata.settingType,
            settingValue = settingValue,
            settingOptions = settingMetadata.options,
            settingDescription = settingMetadata.description,
        }
        ZO_ScrollList_Insert(settingsList, rowData)
    end

    -- Iterate through each row and create the corresponding control
    for _, row in ipairs(settingsList.dataList) do
        local control = self:createSettingControl(row.data)
        row.control = control
    end

    log("Settings list populated for category: " .. categoryName)
end

--[[
    Function: populateProfiles
    Description: Populates the profiles list in the UI.
]]
function SettingsUI:populateProfiles()
    ZO_ScrollList_Clear(profilesList)
    
    local profiles = ProfilesManager:getAllProfiles()
    for _, profileName in ipairs(profiles) do
        local data = ZO_ScrollList_CreateDataEntry(1, profileName)
        ZO_ScrollList_Insert(profilesList, data)
    end

    -- Set up the profiles list's callback for selection
    profilesList:SetHandler("OnRowSelected", function(control, data, selected)
        ProfilesManager:switchProfile(data.data)
        self:refreshProfilesList()
        self:refreshSettingsList()
    end)

    log("Profiles populated.")
end

--[[
    Function: refreshProfilesList
    Description: Refreshes the profiles list to reflect any changes.
]]
function SettingsUI:refreshProfilesList()
    ZO_ScrollList_Clear(profilesList)
    
    local profiles = ProfilesManager:getAllProfiles()
    for _, profileName in ipairs(profiles) do
        local data = ZO_ScrollList_CreateDataEntry(1, profileName)
        ZO_ScrollList_Insert(profilesList, data)
    end

    log("Profiles list refreshed.")
end

--[[
    Function: refreshSettingsList
    Description: Refreshes the settings list based on the selected category and active profile.
]]
function SettingsUI:refreshSettingsList()
    if currentCategory then
        self:populateSettingsList(currentCategory)
    end
    log("Settings list refreshed.")
end

--[[
    Function: filterSettingsList
    Description: Filters the settings list based on a search query.
    Parameters:
        - query (string): The search query entered by the user.
]]
function SettingsUI:filterSettingsList(query)
    ZO_ScrollList_Clear(settingsList)
    
    if query == "" then
        -- If query is empty, show all settings in the current category
        self:populateSettingsList(currentCategory)
        return
    end

    local allSettings = SettingsManager:getAllSettings()
    for fullKey, value in pairs(allSettings) do
        if string.find(fullKey:lower(), query:lower()) or string.find(tostring(value):lower(), query:lower()) then
            local modName, settingKey = string.match(fullKey, "^(.-)%.([^%.]+)$")
            local settingMetadata = SettingsManager:getSettingMetadata(modName, settingKey)
            local settingValue = SettingsManager:getSetting(modName, settingKey)
            
            local rowData = ZO_ScrollList_CreateDataEntry(1, fullKey)
            rowData.data = {
                fullKey = fullKey,
                settingKey = settingKey,
                settingName = string.gsub(settingKey, "_", " "),
                settingType = settingMetadata.settingType,
                settingValue = settingValue,
                settingOptions = settingMetadata.options,
                settingDescription = settingMetadata.description,
            }
            ZO_ScrollList_Insert(settingsList, rowData)
        end
    end

    -- Iterate through each row and create the corresponding control
    for _, row in ipairs(settingsList.dataList) do
        local control = self:createSettingControl(row.data)
        row.control = control
    end

    log("Settings list filtered with query: " .. query)
end

--[[
    Function: createCreateProfileDialog
    Description: Creates a dialog for creating a new profile.
]]
function SettingsUI:createCreateProfileDialog()
    ZO_Dialogs_RegisterCustomDialog("MODSettingsLib_CreateProfileDialog",
    {
        title =
        {
            text = "Create New Profile",
        },
        mainText =
        {
            text = "Enter a name for the new profile:",
        },
        buttons =
        {
            {
                text = "Create",
                callback = function(dialog)
                    local profileName = dialog.data.profileName
                    if profileName and profileName ~= "" then
                        ProfilesManager:createProfile(profileName)
                        self:refreshProfilesList()
                        self:selectProfile(profileName)
                        log("New profile created: " .. profileName)
                        self:printTooltip("Profile '" .. profileName .. "' created successfully.")
                    else
                        handleError("Profile name cannot be empty.")
                        self:printTooltip("Profile name cannot be empty.")
                    end
                end,
            },
            {
                text = "Cancel",
                callback = function()
                    -- Do nothing on cancel
                end,
            },
        },
        editing = true,
        setup = function(dialog)
            dialog.data = { profileName = "" }
            dialog:GetNamedChild("MainText"):SetText("Enter a name for the new profile:")
            local editBox = ZO_Dialogs_GetControl(dialog, "EditBox")
            editBox:SetMaxInputChars(50)
            editBox:SetText("")
            editBox:SetHandler("OnTextChanged", function(control, isUserInput)
                dialog.data.profileName = control:GetText()
            end)
        end,
    })

    ZO_Dialogs_ShowDialog("MODSettingsLib_CreateProfileDialog")
end

--[[
    Function: createDeleteProfileDialog
    Description: Creates a dialog for deleting the selected profile.
]]
function SettingsUI:createDeleteProfileDialog()
    local selectedRow = ZO_ScrollList_GetSelectedData(profilesList)
    if not selectedRow then
        handleError("No profile selected to delete.")
        self:printTooltip("No profile selected to delete.")
        return
    end

    local profileName = selectedRow.data

    if profileName == ProfilesManager:getDefaultProfileName() then
        handleError("Cannot delete the default profile.")
        self:printTooltip("Cannot delete the default profile.")
        return
    end

    ZO_Dialogs_RegisterCustomDialog("MODSettingsLib_DeleteProfileDialog",
    {
        title =
        {
            text = "Delete Profile",
        },
        mainText =
        {
            text = string.format("Are you sure you want to delete the profile '%s'? This action cannot be undone.", profileName),
        },
        buttons =
        {
            {
                text = "Delete",
                callback = function(dialog)
                    ProfilesManager:deleteProfile(profileName)
                    self:refreshProfilesList()
                    self:refreshSettingsList()
                    log("Profile deleted: " .. profileName)
                    self:printTooltip("Profile '" .. profileName .. "' deleted successfully.")
                end,
            },
            {
                text = "Cancel",
                callback = function()
                    -- Do nothing on cancel
                end,
            },
        },
    })

    ZO_Dialogs_ShowDialog("MODSettingsLib_DeleteProfileDialog")
end

--[[
    Function: showCreateProfileDialog
    Description: Displays the create profile dialog.
]]
function SettingsUI:showCreateProfileDialog()
    self:createCreateProfileDialog()
end

--[[
    Function: showDeleteProfileDialog
    Description: Displays the delete profile dialog.
]]
function SettingsUI:showDeleteProfileDialog()
    self:createDeleteProfileDialog()
end

--[[
    Function: createSettingControl
    Description: Creates an appropriate control for a setting based on its type, with tooltips.
    Parameters:
        - rowData (table): The data entry for the setting.
]]
function SettingsUI:createSettingControl(rowData)
    local settingType = rowData.settingType
    local controlName = rowData.fullKey .. "_Control"
    local control

    if settingType == "boolean" then
        control = CreateControlFromVirtual(controlName, settingsList, "ZO_CheckButton")
        control:SetAnchor(TOPLEFT, rowData.control, TOPLEFT, 220, 10)
        control:SetDimensions(20, 20)
        control:SetToggleFunction(function(isChecked)
            SettingsManager:setSetting(string.match(rowData.fullKey, "^(.-)%.") or "Unknown", rowData.settingKey, isChecked)
        end)
        control:SetChecked(rowData.settingValue)
        -- Set tooltip
        control:SetHandler("OnMouseEnter", function()
            InitializeTooltip(ItemTooltip, control, TOPLEFT, 0, 0)
            SetTooltipText(ItemTooltip, rowData.settingDescription or "No description available.")
        end)
        control:SetHandler("OnMouseExit", function()
            ClearTooltip(ItemTooltip)
        end)
    elseif settingType == "number" then
        control = CreateControlFromVirtual(controlName, settingsList, "ZO_Slider")
        control:SetAnchor(TOPLEFT, rowData.control, TOPLEFT, 220, 10)
        control:SetDimensions(300, 20)
        control:SetMinMax(rowData.settingOptions.min or 0, rowData.settingOptions.max or 100)
        control:SetValue(rowData.settingValue)
        control:SetSteps(rowData.settingOptions.steps or 10)
        control:SetHandler("OnValueChanged", function(control, value)
            SettingsManager:setSetting(string.match(rowData.fullKey, "^(.-)%.") or "Unknown", rowData.settingKey, value)
        end)
        -- Set tooltip
        control:SetHandler("OnMouseEnter", function()
            InitializeTooltip(ItemTooltip, control, TOPLEFT, 0, 0)
            SetTooltipText(ItemTooltip, rowData.settingDescription or "No description available.")
        end)
        control:SetHandler("OnMouseExit", function()
            ClearTooltip(ItemTooltip)
        end)
    elseif settingType == "string" then
        control = CreateControlFromVirtual(controlName, settingsList, "ZO_EditBox")
        control:SetAnchor(TOPLEFT, rowData.control, TOPLEFT, 220, 10)
        control:SetDimensions(300, 30)
        control:SetText(rowData.settingValue)
        control:SetHandler("OnTextChanged", function(editBox)
            local newValue = editBox:GetText()
            SettingsManager:setSetting(string.match(rowData.fullKey, "^(.-)%.") or "Unknown", rowData.settingKey, newValue)
        end)
        -- Set tooltip
        control:SetHandler("OnMouseEnter", function()
            InitializeTooltip(ItemTooltip, control, TOPLEFT, 0, 0)
            SetTooltipText(ItemTooltip, rowData.settingDescription or "No description available.")
        end)
        control:SetHandler("OnMouseExit", function()
            ClearTooltip(ItemTooltip)
        end)
    elseif settingType == "dropdown" then
        control = CreateControlFromVirtual(controlName, settingsList, "ZO_ComboBox")
        control:SetAnchor(TOPLEFT, rowData.control, TOPLEFT, 220, 10)
        control:SetDimensions(200, 30)
        
        local comboBox = ZO_ComboBox_ObjectFromContainer(control)
        comboBox:SetSortsItems(false)
        comboBox:SetSpacing(5)
        
        -- Populate dropdown options
        for _, option in ipairs(rowData.settingOptions.options or {}) do
            comboBox:AddItem(CreateMenuItemEntry(option, function()
                SettingsManager:setSetting(string.match(rowData.fullKey, "^(.-)%.") or "Unknown", rowData.settingKey, option)
            end))
        end
        
        -- Set current selection
        local currentIndex = 1
        for i, option in ipairs(rowData.settingOptions.options or {}) do
            if option == rowData.settingValue then
                currentIndex = i
                break
            end
        end
        comboBox:SelectItemByIndex(currentIndex)

        -- Set tooltip
        control:SetHandler("OnMouseEnter", function()
            InitializeTooltip(ItemTooltip, control, TOPLEFT, 0, 0)
            SetTooltipText(ItemTooltip, rowData.settingDescription or "No description available.")
        end)
        control:SetHandler("OnMouseExit", function()
            ClearTooltip(ItemTooltip)
        end)
    else
        -- Default to a simple label if type is unrecognized
        control = CreateControlFromVirtual(controlName, settingsList, "ZO_OptionsLabel")
        control:SetAnchor(TOPLEFT, rowData.control, TOPLEFT, 220, 10)
        control:SetDimensions(300, 20)
        control:SetText(tostring(rowData.settingValue))
        -- Set tooltip
        control:SetHandler("OnMouseEnter", function()
            InitializeTooltip(ItemTooltip, control, TOPLEFT, 0, 0)
            SetTooltipText(ItemTooltip, rowData.settingDescription or "No description available.")
        end)
        control:SetHandler("OnMouseExit", function()
            ClearTooltip(ItemTooltip)
        end)
    end

    return control
end

--[[
    Function: filterSettingsList
    Description: Filters the settings list based on a search query.
    Parameters:
        - query (string): The search query entered by the user.
]]
function SettingsUI:filterSettingsList(query)
    ZO_ScrollList_Clear(settingsList)
    
    if query == "" then
        -- If query is empty, show all settings in the current category
        self:populateSettingsList(currentCategory)
        return
    end

    local allSettings = SettingsManager:getAllSettings()
    for fullKey, value in pairs(allSettings) do
        if string.find(fullKey:lower(), query:lower()) or string.find(tostring(value):lower(), query:lower()) then
            local modName, settingKey = string.match(fullKey, "^(.-)%.([^%.]+)$")
            local settingMetadata = SettingsManager:getSettingMetadata(modName, settingKey)
            local settingValue = SettingsManager:getSetting(modName, settingKey)
            
            local rowData = ZO_ScrollList_CreateDataEntry(1, fullKey)
            rowData.data = {
                fullKey = fullKey,
                settingKey = settingKey,
                settingName = string.gsub(settingKey, "_", " "),
                settingType = settingMetadata.settingType,
                settingValue = settingValue,
                settingOptions = settingMetadata.options,
                settingDescription = settingMetadata.description,
            }
            ZO_ScrollList_Insert(settingsList, rowData)
        end
    end

    -- Iterate through each row and create the corresponding control
    for _, row in ipairs(settingsList.dataList) do
        local control = self:createSettingControl(row.data)
        row.control = control
    end

    log("Settings list filtered with query: " .. query)
end

--[[
    Function: setupSettingsList
    Description: Sets up the settings list with appropriate controls.
]]
function SettingsUI:setupSettingsList()
    -- Already handled in populateSettingsList and filterSettingsList
end

--[[
    Function: printTooltip
    Description: Displays a temporary tooltip message to the user.
    Parameters:
        - message (string): The message to display.
]]
function SettingsUI:printTooltip(message)
    -- Simple implementation using ZO_Tooltip
    -- Create a temporary tooltip
    InitializeTooltip(ItemTooltip, GuiRoot, TOPLEFT, 0, 0)
    SetTooltipText(ItemTooltip, message)
    zo_callLater(function()
        ClearTooltip(ItemTooltip)
    end, 3000)  -- Display for 3 seconds
end

--[[
    Function: registerEvents
    Description: Registers any necessary event handlers.
]]
function SettingsUI:registerEvents()
    -- Example: Close settings window on pressing Escape
    WINDOW_MANAGER:RegisterForEvent("MODSettingsLib_SettingsUI", EVENT_GLOBAL_KEYBOARD_KEY_UP, function(_, keyCode, ctrl, alt, shift)
        if keyCode == KEY_ESCAPE and settingsWindow and not settingsWindow:IsHidden() then
            SettingsUI:hideSettingsWindow()
        end
    end)

    -- Additional event handlers can be added here
end

--[[
    Function: setup
    Description: Sets up the entire Settings UI.
]]
function SettingsUI:setup()
    self:initialize()
    self:registerEvents()
    log("Settings UI setup completed.")
end

-- Initialize the SettingsUI
SettingsUI:setup()

return SettingsUI
