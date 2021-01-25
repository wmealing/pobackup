local urutora = require('urutora')
local inspect = require('inspect')
local Timer = require('timer')

local u
local wave

local bgColor = urutora.utils.toRGB('#343a40')
local canvas

local backup_dir = ""
local backup_list = {}

-- audio stuff
local recDev = nil
local foundRecordingSettings = nil

local audioSource = nil
local devicesString
local recordingFreq, recordingChan, recordingBitDepth
local soundDataTable = {}
local soundDataLen = 0
local startedRecording = faflse
local saveRecording = false

-- Possible combination testing
local sampleFmts = {48000, 44100, 32000, 22050, 16000, 8000}
local chanStereo = {2, 1}
local bitDepths = {16, 8}

-- sintructions
local overlay_image = nil


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

   math.randomseed( os.time() )

   width, height, flags = love.window.getMode( )
   wave = require "wave"

   u = urutora:new()

   make_save_dir()

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

   -- find recording settings
   setup_recording_device()

   -- yeah ?
   find_best_recording_settings ()

   local w, h = love.window.getMode()

   -- FIXME: i dont know how to caculate this but without it
   -- the notification bar covers the buttons.
   local tab_button_height = h / 8.0
   local widget_padding = 5

   canvas = love.graphics.newCanvas(w, h)
   canvas:setFilter('nearest', 'nearest')

   local pixelscale = love.window.getDPIScale()
   print ("PX SCALE:"..  pixelscale)

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
            set_overlay()
            Timer.after(3, function() start_recording () end)
            elseif (RecordingButton.state == ButtonState.Recording) then
            stop_recording ()
            RecordingButton.text = "Record"
            RecordingButton.state = ButtonState.Stopped
            save_recording ()
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

   BackupListTabContents = u.panel( { rows = 12,
                                      cols = 1,
                                      csy = 150,
                                      x = widget_padding,
                                      y = tab_button_height + (widget_padding * 4) ,
                                      w = w - (widget_padding * 2),
                                      h = h - tab_button_height,
                                      tag = 'BackupListTabContents'})

   BackupListTabContents.outline = true

   update_backup_panel(BackupListTabContents)


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
              update_backup_panel(BackupListTabContents)
              u:deactivateByTag('RecordTabContents')
              u:activateByTag('BackupListTabContents')
        end)
end

function love.update(dt)
   u:update(dt)
   Timer.update(dt)
   
   if recDev:isRecording () then

      local data = recDev:getData()

      if data then
         soundDataLen = soundDataLen + data:getSampleCount()
         soundDataTable[#soundDataTable + 1] = data
         print("Current sound data len: ",  #soundDataTable)
      end

   end

end

function love.draw()
	love.graphics.setCanvas(canvas)
	love.graphics.clear(bgColor)
	u:draw()
	love.graphics.setCanvas()

        x, y, w, h = love.window.getSafeArea()

        love.graphics.draw(canvas, x, y, 0,
                           love.graphics.getWidth() / canvas:getWidth(),
		           love.graphics.getHeight() / canvas:getHeight()
                           )

        if overlay_image then

           image_height = overlay_image:getHeight()
           image_width = overlay_image:getWidth()

           love.graphics.draw(overlay_image,
                              (w  / 2.0)  - (image_width / 2.0),                                               (h  / 2.0)  - (image_height / 2.0))
        end
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

function update_backup_panel (Panel)

   backup_list = update_backup_list()
   -- first disable everything in the panel.
   Panel:forEach (function (e)
         e:deactivate()
   end)

   for k,wavfile in ipairs(backup_list) do

      local SongButton = u.button({ text = "Track " .. wavfile ,
                                     h = 20,
                                     song = wavfile
                                     })

      SongButton:action (function (e)
            backup_path = "backups/" .. wavfile
            print ("loading from backup path" .. backup_path)
            music = love.audio.newSource(backup_path, "stream")
            music:play()
      end)

      Panel:addAt(k,1,SongButton)

   end

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
   print (inspect(filtered_list))
   print("Update completed")
   return filtered_list
end

function find_best_recording_settings ()
   print ("Finding best recording settings...")

   backup_list = update_backup_list()

   local success = false

   for _, sampleFmt in ipairs(sampleFmts) do
      for _, bitDepth in ipairs(bitDepths) do
         for _, stereo in ipairs(chanStereo) do
            success = recDev:start(16384, sampleFmt, bitDepth, stereo)
            recDev:stop() -- not sure if this s a good idea to do on failure.

            if success then
               recordingFreq = sampleFmt
               recordingBitDepth = bitDepth
               recordingChan = stereo
               foundRecordingSettings = true
               print("Found good recording settings", sampleFmt, bitDepth, stereo)
               return
            end
            print("Coudlnt find a recording format, this app wont work otherwise")
         end
      end
   end
end

function set_overlay ()
   print ("Setting overlay")
   overlay_image = love.graphics.newImage('img/po-record-plug.png')
   print (overlay_image)
end


function start_recording ()

   print ("started recording" , recordingFreq, recordingBitDepth, recordingChan)
   recDev:start(16384, recordingFreq, recordingBitDepth, recordingChan)
end

function stop_recording ()
   print ("Stopped recording")
   recDev:stop()
end


function save_recording ()
   print ("Saving file")
   
   local soundDataIdx = 0
   
   -- this is where we were recording but not now.
   local soundData = love.sound.newSoundData(soundDataLen,
                                             recordingFreq,
                                             recordingBitDepth,
                                             recordingChan)

   for _, v in ipairs(soundDataTable) do
      for i = 0, v:getSampleCount() - 1 do
            for j = 1, recordingChan do
               local m = v:getSample (i,j)
               soundData:setSample(soundDataIdx, j, m)
            end
            soundDataIdx = soundDataIdx + 1
      end
      v:release()
   end

   soundDataTable = {}

   randomName = "backups/".. CreateRandomString(8) .. ".wav"

   print ("Saving as " .. randomName)

   ret = wave.save { filename = randomName,
                             sound = soundData,
                             overwrite = true,
                             callback = false}

   print ("Done saving file")
end

function setup_recording_device ()

   -- get a list of devices ( https://love2d.org/forums/viewtopic.php?t=88151&p=231722 )
   local devices = love.audio.getRecordingDevices()
   assert(#devices > 0, "no recording devices found")

   --this may not be right, maybe set this as a preference
   recDev = devices[1]
end

