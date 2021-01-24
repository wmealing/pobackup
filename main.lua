local urutora = require('urutora')
local inspect = require('inspect')
local u

local bgColor = urutora.utils.toRGB('#343a40')
local canvas

local backup_dir = ""
local backup_list = {}


local heightFunc = love.graphics.getHeight();

function love.load()

   width, height, flags = love.window.getMode( )

   u = urutora:new()

   make_save_dir()
   update_backup_list()

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
   local top_offset = 50
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

        RecordingButton = u.button({ text = 'Record' })
        RecordingButton:setStyle({padding = 15})

        RecordingImage = u.image({ image = love.graphics.newImage('img/microphone-icon.png'),
                                   keep_aspect_ratio = true })

        RecordingLabel =  u.label({ text = 'Press Record button' }):setStyle({ font = FontSmall })
        RecordingLabel2 = u.label({ text = 'below to start recording' }):setStyle({ font = FontSmall  })


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

        for k,v in ipairs(backup_list) do
           SongButton = u.button({ text = "Track " .. v ,
                                   h = 20}) -- :setStyle({ font = FontSmall })
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

        local debug = 0

        if debug then
           love.graphics.print(x,100,100,0,1,1,0,0,0,0)
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


function update_backup_list()
   print("Updating backup list")

   local filtered_list = {}

   local files = love.filesystem.getDirectoryItems ("backups")

   for i, v in ipairs(files) do
      if string.find(v, "wav") then
         table.insert (filtered_list,v)
      end

   end

   print (inspect (filtered_list))
   backup_list = filtered_list

end

