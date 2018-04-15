-- SKIP TO MAIN MENU
--[[
 - [lib/states/bootupstate, lua/skip_main.lua]
 - [lib/states/menutitlescreenstate, lua/skip_main.lua]
 - [lib/managers/menumanager, lua/skip_main.lua]
]]
require "lua/config.lua"

if BootupState then
	local orig_call = BootupState.setup
	function BootupState:setup()
		orig_call(self)
		self._play_data_list = {}
	end
end
-- AUTO PRESS on TITLE SCREEN
if MenuTitlescreenState and Config.data.auto_skip_to_main_menu then
	local get_start_pressed_controller_index_actual = MenuTitlescreenState.get_start_pressed_controller_index
	function MenuTitlescreenState:get_start_pressed_controller_index(...)
		local num_connected = 0
		local keyboard_index = nil
		for index, controller in ipairs(self._controller_list) do
			if controller._was_connected then
				num_connected = num_connected + 1
			end
			if controller._default_controller_id == "keyboard" then
				keyboard_index = index
			end
		end
		if num_connected == 1 and keyboard_index ~= nil then
			return keyboard_index
		else
			return get_start_pressed_controller_index_actual(self, ...)
		end
	end
end
-- BLANK FORUM
if Config.data.blank_forum_link then
	function MenuCallbackHandler:on_visit_forum() return false end
end