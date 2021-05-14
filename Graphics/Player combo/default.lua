local c
local player = Var "Player";
local ShowComboAt = THEME:GetMetric("Combo", "ShowComboAt");
local Pulse = function(self)
	local combo=self:GetZoom()
	local newZoom=scale(combo,0,500,0.9,1.4)
	self:zoom(1.2*newZoom):linear(0.05):zoom(newZoom)
end
local PulseLabel = THEME:GetMetric("Combo", "PulseLabelCommand");

local NumberMinZoom = THEME:GetMetric("Combo", "NumberMinZoom");
local NumberMaxZoom = THEME:GetMetric("Combo", "NumberMaxZoom");
local NumberMaxZoomAt = THEME:GetMetric("Combo", "NumberMaxZoomAt");

local LabelMinZoom = THEME:GetMetric("Combo", "LabelMinZoom");
local LabelMaxZoom = THEME:GetMetric("Combo", "LabelMaxZoom");

local t = Def.ActorFrame {
 	LoadActor(THEME:GetPathG("Combo","100Milestone")) .. {
		Name="OneHundredMilestone",
		FiftyMilestoneCommand=function(self) self:playcommand("Milestone") end
	},
	LoadActor(THEME:GetPathG("Combo","1000Milestone")) .. {
		Name="OneThousandMilestone",
		ToastyAchievedMessageCommand=function(self) self:playcommand("Milestone") end
	},
	Def.BitmapText {
		Font="_xenotron metal",
		Name="Number",
		OnCommand = THEME:GetMetric("Combo", "NumberOnCommand"),
	},
	Def.Sprite {
		Texture=THEME:GetPathG("Combo","Label"),
		Name="Label",
		OnCommand = THEME:GetMetric("Combo", "LabelOnCommand"),
	},

	InitCommand = function(self)
		-- We'll have to deal with this later
		--self:draworder(notefield_draw_order.over_field)
		c = self:GetChildren()
		c.Number:visible(false)
		c.Label:visible(false)
	end,
	-- Milestones:
	-- 25,50,100,250,600 Multiples;
--[[ 		if (iCombo % 100) == 0 then
			c.OneHundredMilestone:playcommand("Milestone");
		elseif (iCombo % 250) == 0 then
			-- It should really be 1000 but thats slightly unattainable, since
			-- combo doesnt save over now.
			c.OneThousandMilestone:playcommand("Milestone");
		else
			return
		end; --]]
	ComboCommand=function(self, param)
		local iCombo = param.Misses or param.Combo
		if not iCombo or iCombo < ShowComboAt then
			c.Number:visible(false)
			c.Label:visible(false)
			return
		end

		local labeltext = param.Combo and "COMBO" or "MISSES"
		-- c.Label:settext( labeltext )
		c.Label:visible(false)

		param.Zoom = scale( iCombo, 0, NumberMaxZoomAt, NumberMinZoom, NumberMaxZoom )
		param.Zoom = clamp( param.Zoom, NumberMinZoom, NumberMaxZoom )

		param.LabelZoom = scale( iCombo, 0, NumberMaxZoomAt, LabelMinZoom, LabelMaxZoom )
		param.LabelZoom = clamp( param.LabelZoom, LabelMinZoom, LabelMaxZoom )

		c.Number:visible(true)
		c.Label:visible(true)
		c.Number:settext( string.format("%i", iCombo) )
		
		c.Number:finishtweening()
		c.Label:finishtweening()
		
		-- FullCombo Rewards
		if param.FullComboW1 then
			c.Number:diffuse(color("#8CCBFF")):diffusetopedge(color("#ACFFFD"))
			c.Label:diffuse(color("#8CCBFF")):diffusetopedge(color("#ACFFFD"))
		elseif param.FullComboW2 then
			c.Number:diffuse(color("#FAFAFA")):diffusetopedge(color("#FFFBA3"))
			c.Label:diffuse(color("#FAFAFA")):diffusetopedge(color("#FFFBA3"))
		elseif param.FullComboW3 then
			c.Number:diffuse(color("#8CFFB8")):diffusetopedge(color("#C5FFA3"))
			c.Label:diffuse(color("#8CFFB8")):diffusetopedge(color("#C5FFA3"))
		elseif param.Combo then
			c.Number:diffuse(color("#FFFFFF")):diffusetopedge(color("#DCE7FB"))
			c.Label:diffuse(color("#FFFFFF")):diffusetopedge(color("#DCE7FB"))
		else
			c.Number:diffuse(color("#f7d8d8")):diffusetopedge(color("#db7d7d"))
			c.Label:diffuse(color("#f7d8d8")):diffusetopedge(color("#db7d7d"))
		end
		-- Pulse
		Pulse( c.Number, param )
		PulseLabel( c.Label, param )
	end
}

return t