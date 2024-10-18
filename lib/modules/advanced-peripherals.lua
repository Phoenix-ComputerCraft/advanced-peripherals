if not PHOENIX_VERSION then error("This must be loaded as a kernel module.") end

local function noArgMethod(method)
    return function(self)
        return self.internalState.peripheral.call(self.id, method)
    end
end

local function noArgRootMethod(method)
    return function(self, process)
        if process.user ~= "root" then error("Permission denied", 0) end
        return self.internalState.peripheral.call(self.id, method)
    end
end

local function oneArgMethod(method)
    return function(...)
        local types = {...}
        return function(self, process, value)
            expect(1, value, table.unpack(types))
            return self.internalState.peripheral.call(self.id, method, value)
        end
    end
end

local function oneArgRootMethod(method)
    return function(...)
        local types = {...}
        return function(self, process, value)
            expect(1, value, table.unpack(types))
            if process.user ~= "root" then error("Permission denied", 0) end
            return self.internalState.peripheral.call(self.id, method, value)
        end
    end
end

--#region Chat Box

local peripheral_chatBox = {
    name = "peripheral_chatBox",
    type = "chatBox",
    properties = {},
    methods = {}
}

function peripheral_chatBox.methods:send(process, message, options)
    expect(1, message, "string")
    if expect(2, options, "table", "nil") then
        expect.field(options, "username", "string", "nil")
        expect.field(options, "formatted", "boolean", "nil")
        expect.field(options, "toast", "boolean", "nil")
        expect.field(options, "prefix", "string", "nil")
        expect.field(options, "brackets", "string", "nil")
        expect.field(options, "bracketColor", "string", "nil")
        expect.field(options, "range", "number", "nil")
        if options.brackets then
            if #options.brackets ~= 2 then error("Brackets not matched", 2) end
        end
        if options.bracketColor then
            if not options.bracketColor:match "^&%x$" then error("Invalid bracket color", 2) end
        end
    else options = {} end
    if options.toast then
        expect.field(options, "username", "string")
        expect.field(options, "title", "string")
        if options.formatted then
            return self.internalState.peripheral.call(self.id, "sendFormattedToastToPlayer", message, options.username, options.prefix, options.brackets, options.bracketColor, options.range)
        else
            return self.internalState.peripheral.call(self.id, "sendToastToPlayer", message, options.title, options.username, options.prefix, options.brackets, options.bracketColor, options.range)
        end
    elseif options.formatted then
        if options.username then
            return self.internalState.peripheral.call(self.id, "sendFormattedMessageToPlayer", message, options.username, options.prefix, options.brackets, options.bracketColor, options.range)
        else
            return self.internalState.peripheral.call(self.id, "sendFormattedMessage", message, options.prefix, options.brackets, options.bracketColor, options.range)
        end
    elseif options.username then
        return self.internalState.peripheral.call(self.id, "sendMessageToPlayer", message, options.username, options.prefix, options.brackets, options.bracketColor, options.range)
    else
        return self.internalState.peripheral.call(self.id, "sendMessage", message, options.prefix, options.brackets, options.bracketColor, options.range)
    end
end

function peripheral_chatBox:init()
    self.displayName = "Chat Box on " .. self.id
end

registerDriver(peripheral_chatBox)

eventHooks.chat = eventHooks.chat or {}
eventHooks.chat[#eventHooks.chat+1] = function(ev)
    for _, node in ipairs{hardware.find("chatBox")} do
        hardware.broadcast(node, "chat", {username = ev[2], message = ev[3], uuid = ev[4], isHidden = ev[5]})
    end
end

--#endregion
--#region Energy Detector

local peripheral_energyDetector = {
    name = "peripheral_energyDetector",
    type = "energyDetector",
    properties = {
        "transferRate",
        "transferRateLimit"
    },
    methods = {}
}

peripheral_energyDetector.methods.getTransferRate = noArgMethod "getTransferRate"
peripheral_energyDetector.methods.getTransferRateLimit = noArgMethod "getTransferRateLimit"
peripheral_energyDetector.methods.setTransferRateLimit = oneArgMethod "setTransferRateLimit" "number"

registerDriver(peripheral_energyDetector)

--#endregion

--#region Environment Detector

local peripheral_environmentDetector = {
    name = "peripheral_environmentDetector",
    type = "environmentDetector",
    properties = {
        "lightLevel",
        "moonPhase",
        "time",
        "radiation",
        "weather",
        "biome",
        "dimension",
        "dimensions",
        "isSlimeChunk"
    },
    methods = {}
}

function peripheral_environmentDetector.methods:getLightLevel()
    return {
        block = self.internalState.peripheral.call(self.id, "getBlockLightLevel"),
        day = self.internalState.peripheral.call(self.id, "getDayLightLevel"),
        sky = self.internalState.peripheral.call(self.id, "getSkyLightLevel")
    }
end

function peripheral_environmentDetector.methods:getMoonPhase()
    return {
        name = self.internalState.peripheral.call(self.id, "getMoonName"),
        id = self.internalState.peripheral.call(self.id, "getMoonId")
    }
end

peripheral_environmentDetector.methods.getTime = noArgMethod "getTime"

function peripheral_environmentDetector.methods:getRadiation()
    local retval = self.internalState.peripheral.call(self.id, "getRadiation")
    if not retval then return nil end
    retval.raw = self.internalState.peripheral.call(self.id, "getRadiationRaw")
    return retval
end

function peripheral_environmentDetector.methods:getWeather()
    return {
        raining = self.internalState.peripheral.call(self.id, "isRaining"),
        sunny = self.internalState.peripheral.call(self.id, "isSunny"),
        thunder = self.internalState.peripheral.call(self.id, "isThunder"),
    }
end

peripheral_environmentDetector.methods.isDimension = oneArgMethod "isDimension" "string"
peripheral_environmentDetector.methods.isMoon = oneArgMethod "isMoon" "number"
peripheral_environmentDetector.methods.scan = oneArgMethod "scanEntities" "number"

peripheral_environmentDetector.methods.getDimensions = noArgMethod "listDimensions"
peripheral_environmentDetector.methods.getIsSlimeChunk = noArgMethod "isSlimeChunk"
peripheral_environmentDetector.methods.getBiome = noArgMethod "getBiome"

function peripheral_environmentDetector.methods:getDimension()
    return {
        name = self.internalState.peripheral.call(self.id, "getDimensionName"),
        provider = self.internalState.peripheral.call(self.id, "getDimensionProvider"),
        id = self.internalState.peripheral.call(self.id, "getDimensionPaN")
    }
end

registerDriver(peripheral_environmentDetector)

--#endregion

syslog.log({module = "advanced-peripherals"}, "Loaded drivers for Advanced Peripherals")

return {
    unload = function()
        deregisterDriver(peripheral_chatBox)
        deregisterDriver(peripheral_energyDetector)
        deregisterDriver(peripheral_environmentDetector)
    end
}
