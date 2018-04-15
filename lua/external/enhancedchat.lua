-- enhanced chat
--[[
# - [lib/managers/hudmanager, lua/enhancedchat.lua]
# - [lib/managers/menu/menunodegui, lua/enhancedchat.lua]
# - [lib/managers/menumanager, lua/enhancedchat.lua]
--]]

require "lua/config.lua"

local _chat_height_multiplier = Config.data.chat_height or 2.5
local _chat_width_multiplier = Config.data.chat_width or 2.5

if RequiredScript == "lib/managers/hudmanager" then
	if not orig_call_PI then
		orig_call_PI = HUDManager._player_info_hud_layout
	end
	
	function HUDManager:_player_info_hud_layout()
		orig_call_PI(self)
		local requires_update = false
		local full_hud = managers.hud:script(PlayerBase.PLAYER_INFO_HUD_FULLSCREEN)
		local mult = _chat_height_multiplier
		if type(mult) == 'number' and mult > 0 then
			full_hud.panel:child("textscroll"):set_size(
				400 * tweak_data.scale.chat_multiplier * _chat_width_multiplier,
				118 * tweak_data.scale.chat_multiplier * mult
			)
			requires_update = true
		end
		mult = _chat_width_multiplier
		if type(mult) == 'number' and mult > 0 then
			full_hud.panel:child("chat_input"):set_size(
				500 * tweak_data.scale.chat_multiplier * mult,
				25 * tweak_data.scale.chat_multiplier
			)
			requires_update = true
		end
		if requires_update then
			self:_layout_chat_output()
		end
	end
end

if RequiredScript == "lib/managers/menu/menunodegui" then
	local orig_align_ch = MenuNodeGui._align_chat
	function MenuNodeGui:_align_chat(row_item)		
		local mult = _chat_height_multiplier
		if type(mult) == 'number' and mult > 0 then
			tweak_data.scale.chat_menu_h_multiplier = mult
		end
		orig_align_ch(self, row_item)
	end
end

if RequiredScript == "lib/managers/menumanager" then
	function MenuManager:toggle_chatinput()
		--if Global.game_settings.single_player then return end
		if Application:editor() then return end
		if self:active_menu() then return end
		if not managers.network:session() then return end
		if managers.hud then managers.hud:toggle_chatinput() end
	end
end