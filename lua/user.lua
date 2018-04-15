-- user stuff

---[[
function countdownToChat(times, delay)
	delay = delay or 0.7
	sendChatMsg(tostring(times), "LOBBY", true)
	times = times - 1
	local times_loop = times
	DelayedCallbacks:add_new(function()
		sendChatMsg(tostring(times), "LOBBY", true)
		times = times - 1
	end, delay, times_loop)
	DelayedCallbacks:add_new(function()
		sendChatMsg("GO!", "LOBBY", true)
	end,(times_loop + 1) * delay)
end

Keybinds:add_new_cmd("5", function()
	if not isPlaying() then return end
	countdownToChat(5, 0.7)
end)

Keybinds:add_new("h", function() -- tased
	if not isPlaying() then return end
	sayVoiceline("s07x_sin")
end)

Keybinds:add_new("6", function() -- tased peers
	if not isPlaying() then return end
	sayVoiceline("s07x_sin", "peers")
end)

Keybinds:add_new("f1", function()
	sayVoiceline("f11a_sin") -- dallas help
end)

Keybinds:add_new("f2", function() -- chains help
	sayVoiceline("f11b_sin")
end)

Keybinds:add_new("f3", function() -- wolf help
	sayVoiceline("f11c_sin")
end)

Keybinds:add_new("f4", function() -- hoxton help
	sayVoiceline("f11d_sin")
end)

Keybinds:add_new_cmd("f1", function()
	sayVoiceline("f11a_sin", "peers") -- peers dallas help
end)

Keybinds:add_new_cmd("f2", function() -- peers chains help
	sayVoiceline("f11b_sin", "peers")
end)

Keybinds:add_new_cmd("f3", function() -- peers wolf help
	sayVoiceline("f11c_sin", "peers")
end)

Keybinds:add_new_cmd("f4", function() -- peers hoxton help
	sayVoiceline("f11d_sin", "peers")
end)

Keybinds:add_new("7", function() -- fake surrender
	if not isPlaying() then return end
	sayVoiceline("l01x_sin")
	DelayedCallbacks:add_new(function()
		sayVoiceline("l02x_sin", "local")
	end, 1.8)
	DelayedCallbacks:add_new(function()
		sayVoiceline("l03x_sin", "local")
	end, 3.4)
end)
-----------------------------------------------------------------------------------------------------------------
-- Keybinds:add_new_cmd("b", function() -- spawn unit at crosshair
	-- spawnOnCrosshair('tank')
	-- beep()
-- end)

-- Keybinds:add_new("k", function() -- stop tase on self
	-- local player_unit = managers.player:player_unit()
	-- if alive(player_unit) and player_unit:movement():current_state_name() == "tased" then
		-- managers.player:set_player_state("standard")
	-- end
-- end)

Keybinds:add_new("l", function() -- stop tase on peers
	for _, peer in pairs(managers.network:session():peers()) do
		local name = managers.criminals:character_name_by_peer_id(peer:id())
		local player_unit = managers.criminals:character_unit_by_name(name)
		if alive(player_unit) and player_unit:movement():current_state_name() == "tased" then
			managers.network:session():send_to_peers_synched("sync_player_movement_state", player_unit, "standard", player_unit:character_damage():down_time(), player_unit:id())
			player_unit:movement():sync_movement_state("standard", player_unit:character_damage():down_time())
			player_unit:network():send_to_unit( { "sync_player_movement_state", player_unit, "standard", 0, player_unit:id() } )
		end
	end
end)

Keybinds:add_new_cmd("f10", function() -- respawn
	respawn()
	beep()
end)

--[[
Keybinds:add_new("9", function() -- tase peer on crosshair
	local player_unit = teammateOnCrosshair()
	if player_unit and alive(player_unit) then
		managers.network:session():send_to_peers_synched("sync_player_movement_state", player_unit, "tased", player_unit:character_damage():down_time(), player_unit:id())
		player_unit:movement():sync_movement_state("tased", player_unit:character_damage():down_time())
		player_unit:network():send_to_unit( { "sync_player_movement_state", player_unit, "tased", 0, player_unit:id() } )
	end
end)

--]]

Keybinds:add_new_cmd("f11", function() -- get down
	if managers.player then
		local player_unit = managers.player:player_unit()
		if player_unit and player_unit:movement():current_state_name() == "standard" then
			player_unit:character_damage():damage_fall({ height = 9000 })
		end
	end
end)

Keybinds:add_new_cmd("o", function()
	if not isPlaying() then return end
	for _, peer in pairs(managers.network:session():peers()) do
		if peer then
			local msg = peer:name() .. ": " .. getPeerPing(peer)
			sendChatMsg(msg, "LOBBY ", false)
		end
	end
end)
--]]