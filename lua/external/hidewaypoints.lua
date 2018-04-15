-- HIDE WAYPOINTS IN STEELSIGHT
-- PR to lib/units/beings/player/states/playerstandard

local orig_start = PlayerStandard._start_action_steelsight
local orig_end = PlayerStandard._end_action_steelsight

function PlayerStandard:_start_action_steelsight(t)
	orig_start(self, t)
	local infohud = managers.hud:script(PlayerBase.PLAYER_INFO_HUD)
	if infohud.waypoint_panel:visible() then
		infohud.waypoint_panel:set_visible(false)
	end
	if self._in_steelsight then
		managers.hud._in_steelsight = true
	end
end

function PlayerStandard:_end_action_steelsight(t)
	orig_end(self, t)
	local infohud = managers.hud:script(PlayerBase.PLAYER_INFO_HUD)
	if not infohud.waypoint_panel:visible() then
		infohud.waypoint_panel:set_visible(true)
	end
	managers.hud._in_steelsight = false
end