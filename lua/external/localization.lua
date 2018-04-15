--- LOCALIZATION
-- PR to lib/managers/localizationmanager
-- Call them by: managers.localization:text("example_id")

local new_strings = { 
	["menu_force_disconnect"] = "FORCE DISCONNECT",
	["menu_players_list"] = "PLAYERS",
	["dialog_mp_players_actions"] = "You really want to mess with this guy?",
	["dialog_mp_players_actions_msg"] = "Actions for $PLAYER;:",
	["dialog_mp_players_cloak"] = "Spawn Cloaker",
	["dialog_mp_players_overdoze"] = "Spawn Dozer",
	["dialog_mp_players_tase"] = "Tase",
	["dialog_mp_players_tase_100"] = "Tase 100",
	["dialog_mp_players_jail"] = "Send to Jail",
	["dialog_mp_players_cancel"] = "Cancel",
}

local orig_call = LocalizationManager.text
function LocalizationManager:text(string_id, ...)
	if string_id == nil then
		return tostring(string_id)
	end
	return new_strings[string_id] or orig_call(self, string_id, ...)
end