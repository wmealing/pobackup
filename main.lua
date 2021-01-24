local urutora = require('urutora')
local inspect = require('inspect')

local u
local wave

local bgColor = urutora.utils.toRGB('#343a40')
local canvas

local backup_dir = ""
local backup_list = {}

-- audio stuff
local recDev = nil
local isRecording = -1
local soundDataTable = {}
local soundDataLen = 0
local audioSource = nil
local devicesString
local recordingFreq, recordingChan, recordingBitDepth
local soundData

-- Possible combination testing
local sampleFmts = {48000, 44100, 32000, 22050, 16000, 8000}
local chanStereo = {2, 1}
local bitDepths = {16, 8}

function CreateRandomString(length)
    local uuid = ""
    local chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
    for i = 1, length do
        local l = math.random(1, #chars)
        uuid = uuid .. string.sub(chars, l, l)
    end
    return uuid
end

function love.load()

   width, height, flags = love.window.getMode( )
   wave = require "wave"

   u = urutora:new()

   make_save_dir()
   update_backup_list()

   -- get a list of devices ( https://love2d.org/forums/viewtopic.php?t=88151&p=231722 )
   local devices = love.audio.getRecordingDevices()
   assert(#devices > 0, "no recording devices found")

   --this may not be right, maybe set this as a preference
   recDev = devices[1]

   local devStr = {}

   for i, v in ipairs(devices) do
      devStr[#devStr + 1] = string.format("%d. %s", i, v:getName())
   end

   devicesString = table.concat(devStr, "\n")


   function love.mousepressed(x, y, button) u:pressed(x, y) end
   function love.mousemoved(x, y, dx, dy) u:moved(x, y, dx, dy) end
   function love.mousereleased(x, y, button) u:released(x, y) end
   function love.textinput(text) u:textinput(text) end
   function love.wheelmoved(x, y) u:wheelmoved(x, y) end

   function love.keypressed(k, scancode, isrepeat)
      u:keypressed(k, scancode, isrepeat)

      if k == 'escape' then
         love.event.quit()
      end
   end


   local w, h = love.window.getMode()

   -- FIXME: i dont know how to caculate this but without it
   -- the notification bar covers the buttons.
   
   local tab_button_height = h / 8.0
   local widget_padding = 5

   canvas = love.graphics.newCanvas(w, h)
   canvas:setFilter('nearest', 'nearest')

   local DefaultFont = love.graphics.newFont('fonts/block.ttf',20)
   local FontSmall = love.graphics.newFont('fonts/block.ttf',12)

   u.setDefaultFont(DefaultFont)

   u.setResolution(canvas:getWidth(), canvas:getHeight())

   local RecordTabButton = urutora.button({
         text = '[ Recording ]',
         x = widget_padding,
         y = 2,
         w = (width / 2.0 ) - widget_padding,
         h = tab_button_height,
         tag = 'RecordTabButton'
        })

        local BackupListTabButton = urutora.button({
              text = 'Backups',
              x = (width / 2.0 ) + widget_padding,
              y = 2,
              w = (width / 2.0 ) - widget_padding,
              h = tab_button_height,
              tag = 'BackupListTabButton'
        })

        RecordTabContents= u.panel({ rows = 6,
                           cols = 2,
                           x = widget_padding,
                           y = tab_button_height + ( widget_padding * 4),
                           w = w - (widget_padding * 2),
                           h = h - tab_button_height,
                           tag = 'RecordTabContents' })

        RecordingLabel =  u.label({ text = 'Press Record button' }):setStyle({ font = FontSmall })
        RecordingLabel2 = u.label({ text = 'below to start recording' }):setStyle({ font = FontSmall  })

        RecordingImage = u.image({ image = love.graphics.newImage('img/microphone-icon.png'),
                                   keep_aspect_ratio = true })

        ButtonState = {
           Recording = 1,
           Stopped = 2,
           Processing = 3
        }

        RecordingButton = u.button({ text = "Record" , state = ButtonState.Stopped  })
        RecordingButton:setStyle({padding = 15})

        RecordingButton:action(function(e)

              -- dumb way of managing button state, this is still broken
              if (RecordingButton.state == ButtonState.Stopped) then
                 RecordingButton.text = "Stop"
                 RecordingButton.state = ButtonState.Recording
                 
                 elseif (RecordingButton.state == ButtonState.Recording) then
                 recDev:stop()
                 RecordingButton.text = "Recording"
                 RecordingButton.state = ButtonState.Recording
              end


              if isRecording == -1 then

                 local success = false

                 for _, sampleFmt in ipairs(sampleFmts) do
                    for _, bitDepth in ipairs(bitDepths) do
                       for _, stereo in ipairs(chanStereo) do
                          success = recDev:start(16384, sampleFmt, bitDepth, stereo)

                          if success then
                             recordingFreq = sampleFmt
                             recordingBitDepth = bitDepth
                             recordingChan = stereo
                             isRecording = 5
                             print("Recording", sampleFmt, bitDepth, stereo)
                             return
                          end

                          print("Record parameter failed", sampleFmt, bitDepth, stereo)
                       end
                    end
                 end

                 assert(success, "cannot start capture")

              elseif isRecording == -math.huge and audioSource then

                 if audioSource:isPlaying() then
                    audioSource:pause()
                 else
                    print ("Saving file")
                    print ( love.filesystem.getSaveDirectory())
                    wave.save{ filename = "backups/" .. CreateRandomString(8) .. ".wav",
                                          sound = soundData,
                                          overwrite = true,
                                          callback = function() love.graphics.setColor(255, 0, 0) end}
                    end
              end
        end) 

        RecordTabContents
           :colspanAt(1, 1, 2)
           :colspanAt(2, 1, 2)
           :colspanAt(3, 1, 2)
           :colspanAt(5, 1, 2)
           :addAt(1, 1, RecordingLabel)
           :addAt(2, 1, RecordingLabel2)
           :addAt(3, 1, RecordingImage)
           :addAt(5, 1, RecordingButton)

        RecordTabContents.outline = true

        BackupListTabContents = u.panel( { rows = 4,
                                           cols = 1,
                                           csy = 150,
                                           x = widget_padding,
                                           y = tab_button_height + (widget_padding * 4) ,
                                           w = w - (widget_padding * 2),
                                           h = h - tab_button_height,
                                           tag = 'BackupListTabContents'})

        BackupListTabContents.outline = true

        BackupListTabContents.outline = true

        for k,wavfile in ipairs(backup_list) do
           local SongButton = u.button({ text = "Track " .. wavfile ,
                                         h = 20,
                                         song = wavfile
           }) 

           SongButton:action (function (e)
                                       backup_path = "backups/" .. e.wavfile
                                       print ("loading from backup path" .. e.backup_path)
                                       music = love.audio.newSource(backup_path, "stream")
                                       music:play()
           end)

           BackupListTabContents:addAt(k,1,SongButton)
        end

        u:add(RecordTabButton)
        u:add(BackupListTabButton)
	u:add(RecordTabContents)
        u:add(BackupListTabContents)

        -- start off with the recording tab infront.
        u:deactivateByTag('BackupListTabContents')

        RecordTabButton:action(function(e)
              print("Showing Recording interface")
              RecordTabButton.text = "[ Recording ]"
              BackupListTabButton.text = "Backups"
              u:deactivateByTag('BackupListTabContents')
              u:activateByTag('RecordTabContents')
        end)

        BackupListTabButton:action(function(e) 
              print("Listing Backups")
              RecordTabButton.text = "Recording"
              BackupListTabButton.text = "[ Backups ]"
              update_backup_list()
              u:deactivateByTag('RecordTabContents')
              u:activateByTag('BackupListTabContents')
        end)
end

function love.update(dt)
   u:update(dt)
   wave.update (dt)

   if isRecording > 0 then
      isRecording = isRecording - dt

      -- I think that this is soundata ?
      local data = recDev:getData()

      if data then
         soundDataLen = soundDataLen + data:getSampleCount()
         soundDataTable[#soundDataTable + 1] = data
      end

      if isRecording <= 0 then
         -- Stop recording
         isRecording = -math.huge


         -- assemble soundData
         soundData = love.sound.newSoundData(soundDataLen, recordingFreq, recordingBitDepth, recordingChan)
         local soundDataIdx = 0

         for _, v in ipairs(soundDataTable) do
            for i = 0, v:getSampleCount() - 1 do
               for j = 1, recordingChan do
                  soundData:setSample(soundDataIdx, j, v:getSample(i, j))
               end
               soundDataIdx = soundDataIdx + 1
            end
            v:release()
         end

         audioSource = love.audio.newSource(soundData)
      end
   end


end

function love.draw()
	love.graphics.setCanvas(canvas)
	love.graphics.clear(bgColor)
	u:draw()
	love.graphics.setCanvas()

        --
        x, y, w, h = love.window.getSafeArea()

        love.graphics.draw(canvas, x, y, 0,
                           love.graphics.getWidth() / canvas:getWidth(),
		           love.graphics.getHeight() / canvas:getHeight()
        )

end


function make_save_dir()

   -- maybe ?
   love.filesystem.setIdentity("po-backup")
   -- on android this will be the path on 
   base_dir = love.filesystem.getSaveDirectory()

   backup_dir = base_dir .. "/backups"

   -- this needs to be tested better.
   success = love.filesystem.createDirectory( "backups" )

end


function update_backup_list()
   print("Updating backup list")

   local filtered_list = {}

   local files = love.filesystem.getDirectoryItems ("backups")

   for i, v in ipairs(files) do
      if string.find(v, "wav") then
         table.insert (filtered_list,v)
      end

   end

   backup_list = filtered_list

end

