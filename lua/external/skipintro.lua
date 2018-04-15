local IWFPS__audio_done = IngameWaitingForPlayersState._audio_done
local IWFPS_at_exit = IngameWaitingForPlayersState.at_exit
local IWFPS_setup_controller = IngameWaitingForPlayersState.setup_controller
-- callback skip intro:
function IngameWaitingForPlayersState:_skip_intro()
	if managers.hud and managers.hud._chat_focus then
		return
	end
	if not self._starting_game_intro then
		return
	end
	if managers.network.game and Network:is_server() and not self._intro_done then
		if self._intro_source then
			self._intro_source:stop()
		end
		self._intro_done = true
		self._delay_audio_t = nil
		self._delay_start_t = 0
	end
end
-- overrides:
function IngameWaitingForPlayersState:setup_controller(...)
	IWFPS_setup_controller(self, ...)
	local keyboard = Input:keyboard()
	if keyboard then
		keyboard:add_trigger(Idstring("space"), callback(self, self, "_skip_intro"))
	end
end

function IngameWaitingForPlayersState:_audio_done(instance, event_type, self, ...)
	if self._intro_done then
		self._delay_audio_t = nil
		if self._intro_source then
				self._intro_source:stop()
		end
		return
	end
	IWFPS__audio_done(self, instance, event_type, self, ...)
end

-- function IngameWaitingForPlayersState:at_exit(...)
	-- self._intro_done = true
	-- IWFPS_at_exit(self, ...)
-- end