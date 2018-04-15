-- notesingame.lua
-- @author jetbriant
require "lua/global.lua"
require "lua/config.lua"
require "lua/JSON.lua"
function show_note_player_dropin(peer)
	if peer and isPlaying() then
		local name = peer:name()
		local note_msg = "Player " .. name .. " is about to drop in."
		showNote(note_msg, Config.data.ingame_notes_public)
	end
end
function show_note_name_spoof(peer)
	if managers and managers.menu then
		local ingame_name = tostring(peer:name())
		local real_name = tostring(Steam:username(peer:user_id()))
		if ingame_name ~= real_name then
			local note_msg = "Player " .. peer:name() .. " has ingame name different from Steam: " .. real_name
			showNote(note_msg, Config.data.ingame_notes_public)
		end
	end
end
function show_note_peer_removed(peer, reason)
	local reason_msg = managers.localization:text("menu_lobby_message_has_" .. (reason or "left"))
	if reason == "removed_dead" then
		reason_msg = "has been lost (removed dead)"
	end				
	local note_msg = "Player " .. peer:name() .. " " .. reason_msg
	if isPlaying() then
		showNote(note_msg, Config.data.ingame_notes_public)
	end
end
if NetworkGame then
	local call_orig_on_peer_removed = NetworkGame.on_peer_removed
	function NetworkGame:on_peer_removed(peer, peer_id, reason, ...)
		if self._members[peer_id] then
			call_orig_on_peer_removed(self, peer, peer_id, reason, ...)
			if peer and managers.menu then
				show_note_peer_removed(peer, reason)
			end
		end
	end
	
	local call_orig_on_peer_added = NetworkGame.on_peer_added
	function NetworkGame:on_peer_added(peer, peer_id)
		show_note_player_dropin(peer)
		show_note_name_spoof(peer)
		call_orig_on_peer_added(self, peer, peer_id)
	end
	function NetworkGame:on_steam_playtime_request(real_name, success, data)
		real_name = real_name or "Unknown"
		note_msg = "Player " .. real_name .. " has"
		if success then
			data = JSON:decode(data)
			local data_response = data and data.response
			if data_response and data_response.games then
				for _, game in ipairs(data_response.games) do
					if game.playtime_forever then
						note_msg = note_msg .. tostring(math.floor(game.playtime_forever / 60)) .. " hours."
						showNote(note_msg, Config.data.ingame_notes_public)
						return
					end
				end
			end
			showNote(note_msg .. " a private profile.", Config.data.ingame_notes_public)
		else
			showNote("Failed on resquesting playtime for player " .. real_name, Config.data.ingame_notes_public)
		end
	end
end