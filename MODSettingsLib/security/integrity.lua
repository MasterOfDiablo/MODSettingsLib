-- File: security/encryption.lua
-- Author: MasterOfDiablo
-- Description: Handles encryption and decryption of settings data.
-- Version: 1.0.0

local Encryption = {}
Encryption.__index = Encryption

-- Dependencies
local crypto = require("crypto")
local ErrorLogger = require("debugging/error_logger")

-- Constants
Encryption.KEY = "YourSecureEncryptionKey"  -- Replace with a securely generated key
Encryption.IV = "YourSecureIV12345"         -- Replace with a securely generated IV (16 bytes for AES)

-- Logging
local function log(message)
    print("[Encryption] " .. message)
    ErrorLogger:logInfo("[Encryption] " .. message)
end

-- Error handling
local function handleError(message)
    print("[Encryption] ERROR: " .. message)
    ErrorLogger:logError("[Encryption] " .. message)
    error("[Encryption] " .. message)
end

--[[
    Function: encrypt
    Description: Encrypts plaintext using AES-256-CBC.
    Parameters:
        - plaintext (string): The data to encrypt.
    Returns: Base64-encoded ciphertext.
]]
function Encryption:encrypt(plaintext)
    assert(type(plaintext) == "string", "Plaintext must be a string.")
    local cipher = crypto.encrypt("aes-256-cbc", self.KEY, self.IV)
    local ciphertext = cipher:final(plaintext)
    local encoded = crypto.base64_encode(ciphertext)
    log("Data encrypted successfully.")
    return encoded
end

--[[
    Function: decrypt
    Description: Decrypts ciphertext using AES-256-CBC.
    Parameters:
        - ciphertext (string): The Base64-encoded data to decrypt.
    Returns: Decrypted plaintext string.
]]
function Encryption:decrypt(ciphertext)
    assert(type(ciphertext) == "string", "Ciphertext must be a string.")
    local decoded = crypto.base64_decode(ciphertext)
    local decipher = crypto.decrypt("aes-256-cbc", self.KEY, self.IV)
    local success, plaintext = pcall(function()
        return decipher:final(decoded)
    end)
    if success then
        log("Data decrypted successfully.")
        return plaintext
    else
        handleError("Failed to decrypt data.")
    end
end

-- Initialize the Encryption module
function Encryption:initialize()
    if not self.KEY or not self.IV then
        handleError("Encryption key and IV must be set.")
    end
    log("Encryption module initialized.")
end

-- Initialize upon loading
Encryption:initialize()

return Encryption
