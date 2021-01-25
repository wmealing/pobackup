local wave = {}

local instances = setmetatable({}, {__mode = 'v'})


local sData = love.sound.newSoundData( 1, 1, 16, 1 ) -- samples, rate, BITS per sample, channels

sData:setSample(0, 0.7)
local strData = sData:getString()
local b1, b2 = strData:sub(1,1):byte(), strData:sub(2,2):byte()

local endian = (b1 == 152 and b2 == 89) and "little" or (b1 == 89 and b2 == 152) and "big"
assert(endian, "IS IT LITTLE OR BIG")

-- M is bytes per sample
-- Nc is number of channels
-- Ns is numbers of samples
-- F is sampling rate
local header = "RIFF%sWAVEfmt %s%s%s%s%s%s%sdata%s"
header = function() return {"RIFF", [3] = "WAVEfmt ", [11] = "data"} end
-- chunk size (4 + 24 + (8 + M*Nc*Ns) + (0 or 1))
-- subchunk size (LE(16,4))
-- type (LE(1, 2))
-- Nc
-- F
-- F * M * Nc
-- M * Nc
-- 8*M
-- M*Nc*Ns

wave.save = function(arg1, sound, callback, overwrite, exceptionMode)

    --name/argtable, soundData/soundTable, callback, overwrite, exceptionMode (error, clip, normalize)

    local filename

    if type(arg1) == "table" then
        filename = arg1.filename
        sound = arg1.sound
        callback = arg1.callback
        overwrite = arg1.overwrite
        exceptionMode = arg1.exceptionMode
    else
        filename = arg1
    end

    assert(type(filename) == "string", "Wrong filename - expected string, got " .. type(filename) .. ".")

    exceptionMode = exceptionMode or "error"

    
    local i = {}
    i.percent = {channel = love.thread.newChannel()}
    i.status = {channel = love.thread.newChannel()}
    i.error = {channel = love.thread.newChannel()}
    i.thread = love.thread.newThread [==[

    require "love.filesystem"
    require "love.sound"

    local sound, filename, overwrite, exceptionMode, percent, status, err, header, endian = ...
    local t = type(sound)

    status:push "analyzing"

    local LE = function(n, len)
        local t = {}
        while n > 0 do
            table.insert(t, n%256)
            n = math.floor(n/256)
        end

        while #t < len do table.insert(t, 0) end

        local s = ""

        for i, v in ipairs(t) do
            s = s .. string.char(v)
        end
        return s
    end

    local pushError = function(error)
        status:push "error"
        err:push(error)
    end

    local analyze = function(t)

        local max = 1
        
        for i, v in ipairs(t) do
            if not (type(v) == "number") then 
                max = nil
                break
            end
            if exceptionMode == "clip" then
                if v > 1 then
                    t[i] = 1
                elseif v < -1 then
                    t[i] = -1
                end
            else
                if v > 0 and v > max then
                    max = v
                elseif v < 0 and -v > max then
                    max = -v
                end
            end
        end

        assert( sound.bitDepth == 8 or sound.bitDepth == 16, "The bit depth doesn't exist or is invalid (it must be 8 or 16).")
        assert( type(sound.channels) == "number", "The channels number doesn't exist or is invalid (it must be a positive number, it's " .. type(sound.channels) .. ".")
        assert( sound.channels > 0, "The channels number doesn't exist or is invalid (it must be a positive number, it's " .. sound.channels .. ".")
    	assert( type(sound.sampleRate) == "number", "The sample rate doesn't exist or is invalid (it must be a  positive number, it's " .. type(sound.sampleRate) .. ".")
        assert( sound.sampleRate > 0, "The sample rate doesn't exist or is invalid (it must be a positive number, it's " .. sound.sampleRate .. ".")
        assert( #sound >= 1, "The table is not an array.")
        assert( max, "The array contains a non-number value.")
        assert( (exceptionMode ~= "error") or (max <= 1), "The table contains numbers bigger than 1 or smaller than -1.")
        print(max)
        return max
    end


    local t = type(sound)
    local max
    if t == "table" then
        local success, error = pcall(analyze, sound)
        if not success then
            pushError(error)
            return
        end
        max = error
        print(max)
    elseif t == "userdata" then
    	local _, t2 = pcall(sound.typeOf, sound, "SoundData")
        if not (_ and t2) then
            pushError "Expected SoundData or table, got other userdata instead"
            return
        end
    else
        pushError("Expected SoundData or table, got " .. t .. " instead.")
        return
    end

    local M = (sound.bitDepth or sound:getBitDepth()) / 8
    local Nc = sound.channels or sound:getChannelCount()
    local Ns = (t == "table" and #sound or sound:getSampleCount()) -- Here lied the issue I talk about below
    local F = sound.sampleRate or sound:getSampleRate()
    --local round = 0 --Ns%2 --is this even needed

    local h = header
    	h[2] = LE(4 + 28 + 8 + M * Nc * Ns, 4) -- chunk size, maybe an issue lies here? No, it didn't
        h[4] = LE(16, 4) -- subchunk size, just 16
        h[5] = LE(1, 2)  -- format, just 1
    	h[6] = LE(Nc, 2) -- number of channels
    	h[7] = LE(F, 4)  -- number of samples per second in each channel
    	h[8] = LE(F * M * Nc, 4) -- number of bytes per second
    	h[9] = LE(M * Nc, 2) -- block size (bytes per channel)
    	h[10] = LE(M * 8, 2) -- bits sample size
    	h[12] = LE(M * Nc * Ns, 4) -- data size, maybe an issue lies here?

    local header = table.concat(h, "")

    local f = love.filesystem.newFile(filename, "r")

    if f and not overwrite then
        pushError("The file \"" .. filename .. "\" already exists.")
        return
    elseif f then f:close() end

    --local str = t == "userdata" and sound:getString()

    f = love.filesystem.newFile(filename, "w")

    if not f then
        pushError("Could not open file \"" .. filename .. "\".")
        return
    end

    status:push("saving")
    ---[[auto
    if t == "userdata" then
        if ((M == 2 and endian == "little") or (M == 1)) then
        	f:write(header)
            f:write(sound)
        else
            --print("REVERSING")
        	f:write(header .. sound.getString():gsub("(.)(.)", "%2%1"))
        end
    end--]]

    ---[[manual; can easily be used to save from tables I guess?
    --EDIT: yes, apparently it can. It is slow though.
    if t == "table" then
        f:write(header)
        local samples = #sound - 1
        local oldPerc
        for i = 0, samples do
            local perc = math.floor(i/samples * 100)
            if perc ~= oldPerc then
                percent:push(perc)
                oldPerc = perc
            end
            local v = sound[i+1]
            local s = math.floor( (v + 1) * (2 ^ (M*8 - 2) - 1) / max )
            --print(s)
            f:write(LE(s, M))
            --f:write()
        end
    end--]]
    status:push("done")

    f:close()
    return
    --]==]

    instances[i.thread] = i

    i.getStatus = function(self)
        if self.status.Value then return self.status.Value end
        local status
        local c = self.status.channel
        while c:getCount() >= 1 do
            status = c:pop()
        end
        self.status.value = status or self.status.value
        return self.status.value
    end

    i.getError = function(self)
        local error
        local c = self.error.channel
        while c:getCount() >= 1 do
            error = c:pop()
        end
        self.error.value = error or self.error.value
        return self.error.value
    end

    i.getPercent = function(self)
        local percent
        local c = self.percent.channel
        while c:getCount() >= 1 do
            percent = c:pop()
        end
        self.percent.value = percent or self.percent.value
        return self.percent.value
    end

    i.thread:start(sound, filename, overwrite, exceptionMode, i.percent.channel, i.status.channel, i.error.channel, header(), endian)

    if callback == false then
        i.thread:wait()
        if i:getStatus() == "error" then
            return false, i:getError()
        end
        return true
    end
    i.callback = callback

    return i
end

wave.update = function(dt)
    
    for i, v in pairs(instances) do
        if (v:getStatus() == "done" or v:getStatus() == "error") and not v.done then
            v.done = true
            if type(v.callback) == "function" then
                v.callback(v:getStatus() == "done")
            end
        end
    end

end

return wave
