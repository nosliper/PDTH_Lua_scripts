-- global.lua
function getCrosshairPos(player_unit)
	if not player_unit then
		player_unit = managers.player:player_unit()
	end
	local camera = player_unit:movement()._current_state._ext_camera
	local from_pos = camera:position()
	local mvec_to = Vector3()
	mvector3.set(mvec_to, camera:forward())
	mvector3.multiply(mvec_to, 20000)
	mvector3.add(mvec_to, from_pos)
	local ray = World:raycast("ray", from_pos, mvec_to, "slot_mask", managers.slot:get_mask("bullet_impact_targets"))
	if not ray then
		return player_unit:position()
	end
	return ray.hit_position
end

function isPlaying()
	if not BaseNetworkHandler then return false end
	return BaseNetworkHandler._gamestate_filter.any_ingame_playing[ game_state_machine:last_queued_state_name() ]
end

function ShowHint(message, duration)
	if managers and managers.hud then
		managers.hud:show_hint({text = message, time = duration})
	end
end

function isOnChat()
	return managers.hud._chat_focus
end

function showNote(text, sync)
	local local_id = managers.network:session():local_peer():id()
	if not text then return end
	if not local_id then return end
	local msg_note = "LOBBY " .. ":" .. text
	managers.menu:relay_chat_message(msg_note, local_id)
	if Network:is_server() and sync == true then
		managers.network:session():send_to_peers("sync_chat_message", msg_note)
	end
end

function beep()
	local beepSound = SoundDevice:create_source("beepsound")
	beepSound:post_event("menu_enter")
end

function spawnOnCrosshair(unit_name)
	unit_name = unit_name or 'tank'
	if alive(managers.player:player_unit()) and (Network:is_server() or Global.game_settings.single_player) then
		local position = getCrosshairPos()
		local rotation = Rotation(managers.player:player_unit():movement():m_head_rot():yaw(),0,0)
		local unit = 'units/characters/enemies/'.. unit_name ..'/'.. unit_name
		World:spawn_unit( Idstring(unit), position, rotation )
	end
end

function sayVoiceline(soundID, mode)
	-- modes: "local", "peers", "any"
	mode = mode or "local"
	if Global.game_settings.single_player then
		mode = "local"
	end
	local player_unit = managers.player:player_unit()
	if alive(player_unit) and soundID and mode == "local" then
		player_unit:sound():say(soundID, true)
	elseif soundID  and (mode == "peers" or mode == "any") then
		for _, peer in pairs(managers.network:session():peers()) do
			local name = managers.criminals:character_name_by_peer_id(peer:id())
			local peer_unit = managers.criminals:character_unit_by_name(name)
			if alive(peer_unit) then
				peer_unit:sound():say(soundID, true)
				if mode == "any" then return end
			end
		end
	end
end

function respawn()
	local player_unit = managers.player:player_unit()
	if isPlaying() and not isOnChat() and alive(player_unit) then
		local nearest_teammate = nil
		for peer_id,member in pairs(managers.network:game():all_members()) do
			if alive(member:unit()) and member:unit():key() ~= player_unit:key() then
				local distance = mvector3.distance_sq(player_unit:position(), member:unit():position())
				nearest_teammate = {member = member, distance = distance}
			end
		end
		if nearest_teammate then
			local member = nearest_teammate.member
			managers.player:warp_to(member:unit():position(), member:unit():rotation())
		else
			for u_key, u_data in pairs(GroupAIStateBase:all_AI_criminals()) do
				managers.player:warp_to(u_data.unit:position(), u_data.unit:rotation())
				break
			end
		end
	end
end

function formatTime(time)
	local hours	= nil
	local minutes = 0
	local seconds = 0
	if time >= 3600 then
		hours = math.floor(time / 3600)
		time = time - hours * 3600
	end
	minutes = math.floor(time / 60)
	time = time - minutes * 60
	seconds = math.floor(time)
	return (not hours and "" or hours .. ":") .. minutes .. ":" .. (seconds < 10 and "0" .. seconds or seconds)
end

function sendChatMsg(msg, title, sync)
	if msg and managers and managers.menu and managers.network:session() then
		local peer = managers.network:session():local_peer()
		local sender_id = peer:id()
		if Network:is_server() and title then
			msg = title .. ": " .. msg
		else
			msg = string.upper(peer:name()) .. ": " .. msg
		end
		managers.menu:relay_chat_message(msg, sender_id)
		if sync ~= false then
			managers.network:session():send_to_peers("sync_chat_message", msg)
		end
	end
end

function teammateOnCrosshair()
	if managers.player and managers.groupai then
		local player_unit = managers.player:player_unit()
		if player_unit and player_unit:movement():current_state() then
			local player_state = player_unit:movement():current_state()
		
			local char_table = {}
			local cam_fwd = player_unit:camera():forward()
			local my_head_pos = player_unit:movement():m_head_pos()
		
			local criminals = managers.groupai:state():all_criminals()
			for u_key, u_data in pairs(criminals) do
				if not u_data.is_deployable and not u_data.unit:movement():downed() and not u_data.unit:base().is_local_player then
					player_state:_add_unit_to_char_table(char_table, u_data.unit, 2, 100000, true, true, 0.01, my_head_pos, cam_fwd)
				end
			end

			local prime_target = player_state:_get_interaction_target(char_table, my_head_pos, cam_fwd)
			if prime_target and prime_target.unit then
				for u_key, u_data in pairs(criminals) do
					if u_data.status ~= "dead" then
						local unit = criminals[u_key].unit
						if unit == prime_target.unit then
							return unit
						end
					end	
				end
			end
		end
	end
end

function getPeerPing(peer)
	local current_qos = Network and Network.qos and peer:steam_rpc() and Network:qos(peer:steam_rpc())
	local current_ping = current_qos and current_qos.ping

	return math.floor(current_ping) or 0
end

function printTable(item, file, sep, level)
	if sep:len() > level then return end
	if type(item) ~= "table" then
		if type(item) == "number" or type(item) == "string" then
			file:write(sep .. item .. " Type: " .. type(item) .. "\n")
			return
		else
			return
		end
	end
	for index, value in pairs(item) do
		file:write(sep .. tostring(index) .. " Type: " .. type(value) .. "\n")
		printTable(value, file, sep .. sep, level)
	end
end