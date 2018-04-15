-- update.lua, jetbriant
require "lua/global.lua"
require "lua/keybindsetup.lua"
require "lua/delayedcallbacks.lua"
require "lua/config.lua"
require "lua/stats.lua"
require "lua/user.lua"

local last_update_time
local refresh_rate = Config.data.stats_line_refresh_rate or 0.1

Keybinds:_setup()

if GameSetup then
	local call_orig_update = GameSetup.update
	function GameSetup:update(...)
		call_orig_update(self, ...)
		DelayedCallbacks:_process_delayed_clbks()
	end
end

if HUDManager then
	local call_orig_init = HUDManager.init
	function HUDManager:init(...)
		call_orig_init(self, ...)
		self._in_steelsight = false
	end

	local call_orig_add_mugshot = HUDManager.add_mugshot
	function HUDManager:add_mugshot(data)
		local peer_id = data.peer_id
		local peer = peer_id and managers.network:session():peer(peer_id)
		if peer then	
			data.name = peer:name():upper() .. " [" .. (peer:level() or "-") .. "]"
		end
		return call_orig_add_mugshot(self, data)
	end
	
	local call_orig_update_name_labels = HUDManager._update_name_labels
	function HUDManager:_update_name_labels(...)
		if Config.data.hide_name_labels_ADS and managers.hud._in_steelsight then
			for i, data in ipairs(self._hud.name_labels) do
				local text = data.text
				text:set_visible(false)
			end
		else
			call_orig_update_name_labels(self, ...)
		end
	end
	
	local call_orig_update = HUDManager.update
	function HUDManager:update(...)
		call_orig_update(self, ...)
		if last_update_time and refresh_rate then
			if Application:time() - last_update_time < refresh_rate then
				return
			end
		end
		Stats:update()
		last_update_time = Application:time()
	end
end