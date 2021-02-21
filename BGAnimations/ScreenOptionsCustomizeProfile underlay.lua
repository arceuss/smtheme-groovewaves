-- Pester Kyzentun for an explanation if you need to customize this screen.
-- Also, this might be rewritten to us a proper customizable lua menu system
-- in the future.

-- Copy this file into your theme, then modify as needed to suit your theme.
-- Each of the things on this list has a comment marking it, so you can
-- quickly find it by searching.
-- Things you will want to change:
-- 1.  The Numpad
-- 2.  The Cursor
-- 3.  The Menu Items
-- 4.  The Menu Values
-- 4.1  The L/R indicators
-- 5.  The Menu Fader

local profile= GAMESTATE:GetEditLocalProfile()
local master = GAMESTATE:GetMasterPlayerNumber()
local profile_id= GAMESTATE:GetEditLocalProfileID()

-- 1.  The Numpad
-- This is what sets up how the numpad looks.  See Scripts/04 NumPadEntry.lua
-- for a full description of how to customize a NumPad.
-- Note that if you provide a custom prompt actor for the NumPad, it must
-- have a SetCommand because the NumPad is used any time the player needs to
-- enter a number, and the prompt is updated by running its SetCommand.
local number_entry= new_numpad_entry{
	Name= "number_entry",
	InitCommand= function(s) s:diffusealpha(0):xy(_screen.cx, _screen.cy) end,
	value_color= PlayerColor(master),
	cursor_draw= "first",
	cursor_color= PlayerDarkColor(master),
}

local function calc_list_pos(value, list)
	for i, entry in ipairs(list) do
		if entry.setting == value then
			return i
		end
	end
	return 1
end

local function item_value_to_text(item, value)
	if item.item_type == "bool" then
		if value then
			value= THEME:GetString("ScreenOptionsCustomizeProfile", item.true_text)
		else
			value= THEME:GetString("ScreenOptionsCustomizeProfile", item.false_text)
		end
	elseif item.item_type == "list" then
		local pos= calc_list_pos(value, item.list)
		return item.list[pos].display_name
	end
	return value
end

local char_list= {}
do
	local all_chars= CHARMAN:GetAllCharacters()
	for i, char in ipairs(char_list) do
		char_list[#char_list+1]= {
			setting= char:GetCharacterID(), display_name= char:GetDisplayName()}
	end
end

local menu_items= {
	{name= "weight", get= "GetWeightPounds", set= "SetWeightPounds",
	 item_type= "number", auto_done= 100},
	{name= "voomax", get= "GetVoomax", set= "SetVoomax", item_type= "number",
	 auto_done= 10},
	{name= "birth_year", get= "GetBirthYear", set= "SetBirthYear",
	 item_type= "number", auto_done= 1000},
	{name= "calorie_calc", get= "GetIgnoreStepCountCalories",
	 set= "SetIgnoreStepCountCalories", item_type= "bool",
	 true_text= "use_heart", false_text= "use_steps"},
	{name= "gender", get= "GetIsMale", set= "SetIsMale", item_type= "bool",
	 true_text= "male", false_text= "female"},
}
if #char_list > 0 then
	menu_items[#menu_items+1]= {
		name= "character", get= "GetCharacter", set= "SetCharacter",
		item_type= "list", list= char_list}
end
menu_items[#menu_items+1]= {name= "scatter_edit", item_type= "menu", screen_name= "ScreenDetailStatEdit"}
menu_items[#menu_items+1]= {name= "avatimg_edit", item_type= "menu", get=function()
	local ProfileImage = LoadModule("Config.Load.lua")( "AvatarImage", "/Save/LocalProfiles/"..profile_id.."/OutFoxPrefs.ini" )
	return ProfileImage and string.gsub(ProfileImage, "/Appearance/Avatars/","") or "default"
end,
screen_name= "ScreenAvatarImageSelection"}
menu_items[#menu_items+1]= {name= "exit", item_type= "exit"}

local menu_pos= 1
local menu_start= SCREEN_CENTER_Y-120
local menu_x= 100
local value_x= SCREEN_RIGHT-500
local fader
local cursor_on_menu= "main"
local menu_item_actors= {}
local menu_values= {}
local list_pos= 0
local active_list= {}
local left_showing= false
local right_showing= false
local sfx

local function fade_actor_to(actor, alf)
	actor:stoptweening()
	actor:linear(.2)
	actor:diffusealpha(alf)
end

local function update_menu_cursor()
	MESSAGEMAN:Broadcast("UpdateCursor",{ind=menu_pos})
end

local function update_list_cursor()
	local valactor= menu_values[menu_pos]
	valactor:playcommand("Set", {active_list[list_pos].display_name})
	if list_pos > 1 then
		if not left_showing then
			valactor:playcommand("ShowLeft")
			left_showing= true
		end
	else
		if left_showing then
			valactor:playcommand("HideLeft")
			left_showing= false
		end
	end
	if list_pos < #active_list then
		if not right_showing then
			valactor:playcommand("ShowRight")
			right_showing= true
		end
	else
		if right_showing then
			valactor:playcommand("HideRight")
			right_showing= false
		end
	end
end

local function exit_screen(newscreen)
	local profile_id= GAMESTATE:GetEditLocalProfileID()
	PROFILEMAN:SaveLocalProfile(profile_id)
	if newscreen then
		SCREENMAN:GetTopScreen():SetNextScreenName( newscreen )
	end
	SCREENMAN:GetTopScreen():StartTransitioningScreen("SM_GoToNextScreen")
	SOUND:PlayOnce(THEME:GetPathS("Common", "Start"))
end

local function input(event)
	local pn= event.PlayerNumber
	if not pn then return false end
	if event.type == "InputEventType_Release" then return false end
	local button= event.GameButton
	if cursor_on_menu == "main" then
		if button == "Start" then
			local item= menu_items[menu_pos]
			if item.item_type == "bool" then
				local value= not profile[item.get](profile)
				menu_values[menu_pos]:playcommand(
					"Set", {item_value_to_text(item, value)})
				profile[item.set](profile, value)
			elseif item.item_type == "number" then
				fade_actor_to(fader, .8)
				fade_actor_to(number_entry.container, 1)
				number_entry.value= profile[item.get](profile)
				number_entry.value_actor:playcommand("Set", {number_entry.value})
				number_entry.auto_done_value= item.auto_done
				number_entry.max_value= item.max
				number_entry:update_cursor(number_entry.cursor_start)
				number_entry.prompt_actor:playcommand(
					"Set", {THEME:GetString("ScreenOptionsCustomizeProfile", item.name)})
				cursor_on_menu= "numpad"
			elseif item.item_type == "list" then
				cursor_on_menu= "list"
				active_list= menu_items[menu_pos].list
				list_pos= calc_list_pos(
					profile[menu_items[menu_pos].get](profile), active_list)
				update_list_cursor()
			elseif item.item_type == "menu" then
				exit_screen( item.screen_name )
			elseif item.item_type == "exit" then
				exit_screen()
			end
		elseif button == "Back" then
			exit_screen()
		else
			if button == "MenuLeft" or button == "MenuUp" then
				if menu_pos > 1 then menu_pos= menu_pos - 1 end
				update_menu_cursor()
				MESSAGEMAN:Broadcast("UpdateSound")
			elseif button == "MenuRight" or button == "MenuDown" then
				if menu_pos < #menu_items then menu_pos= menu_pos + 1 end
				update_menu_cursor()
				MESSAGEMAN:Broadcast("UpdateSound")
			end
		end
	elseif cursor_on_menu == "numpad" then
		local done= number_entry:handle_input(button)
		if done or button == "Back" then
			local item= menu_items[menu_pos]
			if button ~= "Back" then
				profile[item.set](profile, number_entry.value)
				menu_values[menu_pos]:playcommand(
					"Set", {item_value_to_text(item, number_entry.value)})
			end
			fade_actor_to(fader, 0)
			fade_actor_to(number_entry.container, 0)
			cursor_on_menu= "main"
		end
	elseif cursor_on_menu == "list" then
		if button == "MenuLeft" or button == "MenuUp" then
			if list_pos > 1 then list_pos= list_pos - 1 end
			update_list_cursor()
			menu_values[menu_pos]:playcommand("PressLeft")
		elseif button == "MenuRight" or button == "MenuDown" then
			if list_pos < #active_list then list_pos= list_pos + 1 end
			update_list_cursor()
			menu_values[menu_pos]:playcommand("PressRight")
		elseif button == "Start" or button == "Back" then
			if button ~= "Back" then
				profile[menu_items[menu_pos].set](
					profile, active_list[list_pos].setting)
			end
			local valactor= menu_values[menu_pos]
			left_showing= false
			right_showing= false
			valactor:playcommand("HideLeft")
			valactor:playcommand("HideRight")
			cursor_on_menu= "main"
		end
	end
end

local args= {
	Def.Actor{
		OnCommand= function(self)
			MESSAGEMAN:Broadcast("UpdateCursor",{ind=1})
			SCREENMAN:GetTopScreen():AddInputCallback(input)
		end
	},
}

-- Note that the "character" item in the menu only shows up if there are
-- characters to choose from.  You might want to adjust positioning for that.
local itemspacing = 56
for i, item in ipairs(menu_items) do
	local item_y= menu_start + ((i-1) * itemspacing)
	-- 3.  The Menu Items
	-- This creates the actor that will be used to show each item on the menu.
	local menuitemnew
	if item.get then
		local value_text= type(item.get) == "string" and item_value_to_text(item, profile[item.get](profile)) or item.get()
		-- 4.  The Menu Values
		-- Each of the values needs to have a SetCommand so it can be updated
		-- when the player changes it.
		-- And ActorFrame is used because values for list items need to have
		-- left/right indicators for when the player is making a choice.
		local value_args= {
			Name= "value_" .. item.name, 
			InitCommand= function(self)
				-- Note that the ActorFrame is being added to the list menu_values
				-- so it can be easily fetched and updated when the value changes.
				menu_values[i]= self
				self:x(value_x)
				self:diffusealpha(0):linear(0.2):diffusealpha(1)
			end,
			OffCommand=function(s) s:linear(0.2):diffusealpha(0) end,
			Def.BitmapText{
				Name= "val", Font= "Common Normal", Text= value_text,
				InitCommand= function(self)
					self:diffuse(Color.White)
					self:horizalign(left)
				end,
				SetCommand= function(self, param)
					self:settext(param[1])
				end,
			}
		}
		if item.item_type == "list" then
			-- 4.1  The L/R indicators
			-- The L/R indicators are there to tell the player when there is a
			-- choice to the left or right of the choice they are on.
			-- Note that they are placed inside the ActorFrame for the value, so
			-- when commands are played on the ActorFrame, they are played for the
			-- indicators too.
			-- The commands are ShowLeft, HideLeft, PressLeft, and the same for
			-- Right.
			-- Note that the right indicator has a SetCommand so it sees when the
			-- value changes and checks the new width to position itself.
			-- Show/Hide is only played when the indicator changes state.
			-- Command execution order: Set, Show/Hide (if change occurred), Press
			value_args[#value_args+1]= Def.ActorMultiVertex{
				InitCommand= function(self)
					self:SetVertices{
						{{-5, 0, 0}, Color.White}, {{0, -10, 0}, Color.White},
						{{0, 10, 0}, Color.White}}
					self:SetDrawState{Mode= "DrawMode_Triangles"}
					self:x(-8)
					self:visible(false)
					self:playcommand("Set", {value_text})
				end,
				ShowLeftCommand= function(s) s:visible(true) end,
				HideLeftCommand= function(s) s:visible(false) end,
				PressLeftCommand= cmd(stoptweening; linear, .2; zoom, 2; linear, .2;
															zoom, 1),
			}
			value_args[#value_args+1]= Def.ActorMultiVertex{
				InitCommand= function(self)
					self:SetVertices{
						{{5, 0, 0}, Color.White}, {{0, -10, 0}, Color.White},
						{{0, 10, 0}, Color.White}}
					self:SetDrawState{Mode= "DrawMode_Triangles"}
					self:visible(false)
				end,
				SetCommand= function(self)
					local valw= self:GetParent():GetChild("val"):GetWidth()
					self:x(valw+8)
				end,
				ShowRightCommand= function(s) s:visible(true) end,
				HideRightCommand= function(s) s:visible(false) end,
				PressRightCommand= cmd(stoptweening; linear, .2; zoom, 2; linear, .2;
															zoom, 1),
			}
		end
		menuitemnew = Def.ActorFrame(value_args)
	end

	args[#args+1]= Def.ActorFrame{
		InitCommand=function(s) s:y(item_y) end,
		UpdateCursorMessageCommand=function(s)
			s:stoptweening():smooth(0.2):y( menu_pos > 8 and item_y-(itemspacing*(menu_pos-8)) or item_y )
		end,
		Def.Quad{
			OnCommand=function(s)
				s:x( 0 ):halign(0):zoomto( SCREEN_WIDTH, 50 ):diffuse( color("#00000076") )
				s:diffusealpha(0):linear(0.2):diffuse( color("#00000076") )
			end,
			OffCommand=function(s) s:linear(0.2):diffusealpha(0) end,
		},

		Def.Sprite{
			Texture=THEME:GetPathG("_StepsDisplayListRow","Cursor"),
			InitCommand=function(s)
				s:x( 40 ):diffuse( PlayerColor( master ) ):diffusealpha(0)
			end,
			OffCommand=function(s) s:linear(0.2):diffusealpha(0) end,
			UpdateCursorMessageCommand=function(self,param)
				self:stoptweening():easeoutsine(0.16)
				self:diffusealpha(param.ind == i and 1 or 0)
				self:x( param.ind == i and 50 or 10 )
			end,
		},

		Def.ActorFrame{
			InitCommand=function(s) s:diffusealpha(0) end,
			OffCommand=function(s) s:linear(0.2):diffusealpha(0) end,
			UpdateCursorMessageCommand=function(self,param)
				self:stoptweening():linear(0.16):diffusealpha(param.ind == i and 1 or 0)
			end,
			Def.Quad {InitCommand=function(self) self:x(0)
				:faderight( 0.5 )
				:zoomto(SCREEN_WIDTH, 4 ):halign(0):vertalign(top):y(-52/2):diffuse(PlayerColor(master)):diffuseleftedge(ColorLightTone(PlayerColor(master)))
			 end
			},
			Def.Quad {InitCommand=function(self) self:x(0)
				:faderight( 0.5 )
				:zoomto(SCREEN_WIDTH, 4 ):halign(0):vertalign(bottom):y(52/2):diffuse(ColorLightTone(PlayerColor(master))):diffuseleftedge(PlayerColor(master))
			 end
			},
		},

		Def.BitmapText{
			Name= "menu_" .. item.name, Font= "Common Normal",
			Text= THEME:GetString("ScreenOptionsCustomizeProfile", item.name),
			InitCommand= function(self)
				-- Note that the item adds itself to the list menu_item_actors.  This
				-- is so that when the cursor is moved, the appropriate item can be
				-- easily fetched for positioning and sizing the cursor.
				-- Note the ActorFrames have a width of 1 unless you set it, so when
				-- you change this from an BitmapText to a ActorFrame, you will have
				-- to make the FitCommand of your cursor look at the children.
				menu_item_actors[i] = self
				self:x(menu_x)
				self:diffuse(Color.White)
				self:horizalign(left)
				self:diffusealpha(0):linear(0.2):diffusealpha(1)
			end,
			UpdateCursorMessageCommand=function(self,param)
				self:stoptweening():linear(0.16)
				self:diffusealpha(param.ind == i and 1 or 0.6)
			end,
			OffCommand=function(s) s:linear(0.2):diffusealpha(0) end,
		},
		menuitemnew
	}
end

-- 5.  The Menu Fader
-- This is just something to tell the player that the menu is no longer
-- active because they are interacting with the numpad.
-- Default is to just fade this in over the top of the menu.  If you want
-- something different, change the places in the input function that call
-- fade_actor_to to do what you want with the fader.
args[#args+1]= Def.Quad{
	Name= "fader", InitCommand= function(self)
		fader= self
		self:setsize( SCREEN_WIDTH ,SCREEN_HEIGHT)
		self:Center(menu_x-10, menu_start-12)
		self:diffuse(Color.Black)
		self:diffusealpha(0)
	end
}

args[#args+1] = Def.Sound{
	File=THEME:GetPathS("Common","value"),
	UpdateSoundMessageCommand=function(s)
		s:play()
	end,
}

local profile_id= GAMESTATE:GetEditLocalProfileID()
local AvI = LoadModule("Config.Load.lua")( "AvatarImage", "/Save/LocalProfiles/"..profile_id.."/OutFoxPrefs.ini" )
local ProfileImage = AvI and AvI or THEME:GetPathG("UserProfile","generic icon")
args[#args+1] = Def.ActorFrame{
    Name="InfoFrame",
    OnCommand=function(s)
        s:diffusealpha(0):addy(-20):easeoutsine(0.2):addy(20):diffusealpha(1)
    end,
    OffCommand=function(s)
        s:accelerate(0.2):addy(-20):diffusealpha(0)
    end,

    Def.Quad{
        OnCommand=function(s)
            s:xy( SCREEN_CENTER_X, SCREEN_CENTER_Y-224 ):zoomto( SCREEN_WIDTH-40, 120 )
            :diffuse( ColorDarkTone(Color.Blue) )
        end,
    },
    
    Def.Sprite{
        InitCommand=function(s) s:Load( ProfileImage )end,
        OnCommand=function(s)
            s:xy( 38, 136 ):halign(0):setsize(96,96)
        end,
    },

	Def.BitmapText{ Font="Common Normal", Text=profile:GetDisplayName(), OnCommand=function(s) s:xy( 50+96, 100 ):zoom(1.2):halign(0) end, },
	Def.BitmapText{ Font="Common Normal", Text="GUID: "..profile:GetGUID(), OnCommand=function(s) s:xy( 50+96, 100+4+(28*1) ):halign(0) end, },
	Def.BitmapText{ Font="Common Normal", Text=Screen.String("TotalTime").. ": "..SecondsToHHMMSS(profile:GetTotalGameplaySeconds()), OnCommand=function(s) s:xy( 50+96, 100+4+(28*2) ):halign(0) end, },
}

args[#args+1]= number_entry:create_actors()

return Def.ActorFrame(args)
