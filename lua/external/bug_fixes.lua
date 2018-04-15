-- BUG FIXES
--[[
 - [lib/units/weapons/trip_mine/tripminebase, lua/bug_fixes.lua]
 - [lib/network/extensions/player_team/huskteamaidamage, lua/bug_fixes.lua]
 - [lib/units/beings/player/playercamera, lua/bug_fixes.lua]
 - [lib/managers/menu/menuinput, lua/bug_fixes.lua]
 - [lib/managers/trademanager, lua/bug_fixes.lua]
 - [lib/network/networkgame, lua/bug_fixes.lua]
 - [lib/managers/menu/menulobbyrenderer, lua/bug_fixes.lua]
 - [lib/managers/killzonemanager, lua/bug_fixes.lua]
 - [lib/managers/hudmanager, lua/bug_fixes.lua]
 - [lib/units/enemies/cop/actions/upper_body/copactiontase, lua/bug_fixes.lua]
 - [lib/utils/game_state_machine/gamestatemachine, lua/bug_fixes.lua]
 - [lib/network/matchmaking/networkmatchmakingsteam, lua/bug_fixes.lua]
 - [lib/states/ingamelobbymenu, lua/bug_fixes.lua]
]]

if RequiredScript == "lib/units/weapons/trip_mine/tripminebase" then
	local orig_trip = TripMineBase.sync_trip_mine_set_armed
	function TripMineBase:sync_trip_mine_set_armed(armed, length, ...)
		if length then
			orig_trip(self, armed, length, ...)
		end
		if not armed and self._activate_timer then
			self._activate_timer = nil
		end
	end
end
if RequiredScript == "lib/network/extensions/player_team/huskteamaidamage" then
	local orig_hsk_taidmg = HuskTeamAIDamage.sync_damage_incapacitated
	function HuskTeamAIDamage:sync_damage_incapacitated()
		self._unit:interaction():set_tweak_data("revive")
		orig_hsk_taidmg(self)
	end
end
if RequiredScript == "lib/units/beings/player/playercamera" then
	local orig_cam_pos = PlayerCamera.set_position
	function PlayerCamera:set_position(pos)
		if self._camera_controller then
			return orig_cam_pos(self, pos)
		end
	end
	local orig_cam_rot = PlayerCamera.set_rotation
	function PlayerCamera:set_rotation(rot)
		if self._camera_controller then
			return orig_cam_rot(self, rot)
		end
	end
	function PlayerCamera:setup_viewport(data)
		if self._vp then self._vp:destroy() end
		local dimensions = data.dimensions
		local name = "player" .. tostring(self._id)
		local vp = managers.viewport:new_vp(dimensions.x, dimensions.y, dimensions.w, dimensions.h, name)
		self._director = vp:director()
		self._shaker = self._director:shaker()
		self._camera_controller = self._director:make_camera(self._camera_object, Idstring("fps"))
		self._director:position_as(self._camera_object)
		if self._camera_controller then
			self._director:set_camera(self._camera_controller)
			self._camera_controller:set_both(self._camera_unit)
		end
		self._shakers = {}
		local s = { bobdaeh = 0, gnihtaerb = 0.3 }
		for k,v in pairs(s) do
			self._shakers[k:reverse()] = self._shaker:play(k:reverse(), v)
		end
		vp:set_camera(self._camera_object)
		vp:set_environment(managers.environment_area:default_environment())
		self._vp = vp
	end
end
if RequiredScript == "lib/managers/menu/menuinput" then
	local orig_input_ks = MenuInput.input_kitslot
	function MenuInput:input_kitslot(item, controller, mouse_click)
		if item then
			orig_input_ks(self, item, controller, mouse_click)
		end
	end
	local orig_input_mc = MenuInput.input_multi_choice
	function MenuInput:input_multi_choice(item, controller, mouse_click)
		if item then
			orig_input_mc(self, item, controller, mouse_click)
		end
	end
end
if RequiredScript == "lib/managers/trademanager" then
	function TradeManager:begin_hostage_trade_dialog(i)
		print("begin_hostage_trade_dialog", i)
		if self._cancel_trade then
			self._hostage_trade_clbk = nil
			self._cancel_trade = nil
			return
		end
		if i == 1 then
			self._megaphone_sound_source = self:_get_megaphone_sound_source()
			print("Snd: megaphone", self._megaphone_sound_source)
			if not self._megaphone_sound_source:post_event("mga_t01a_con_plu", callback(self, self, "begin_hostage_trade_dialog", 2), nil, "end_of_event") then
				self:begin_hostage_trade_dialog(2)
				print("Megaphone fail")
			end

		elseif i == 2 then
			-- added some checks here so that the game won't crash on unexpected values
			local criminal_to_trade = self:get_criminal_to_trade()
			local csdata = criminal_to_trade and managers.criminals:character_static_data_by_name(criminal_to_trade.id)
			if csdata then
				local ssuffix = csdata.ssuffix
				if ssuffix == "a" then
					i = 2
				elseif ssuffix == "b" then
					i = 3
				elseif ssuffix == "c" then
					i = 4
				elseif ssuffix == "d" then
					i = 5
				end
			end

			self:sync_hostage_trade_dialog(i)
			local respawn_t = self._t + 5
			managers.enemy:add_delayed_clbk(self._hostage_trade_clbk, callback(self, self, "begin_hostage_trade"), respawn_t)
		end

		managers.network:session():send_to_peers("hostage_trade_dialog", i)
	end
	local orig_trade_bht = TradeManager.begin_hostage_trade
	function TradeManager:begin_hostage_trade()
		self._hostage_trade_clbk = nil
		if not table.empty(self._criminals_to_respawn) then
			orig_trade_bht(self)
		end
	end
	function TradeManager:on_hostage_traded(trading_unit)
		print("RC: Traded hostage!!")
		if self._criminal_respawn_clbk then return end
		self._hostage_to_trade = nil
		local respawn_criminal = self:get_criminal_to_trade()
		if not respawn_criminal then return end
		local respawn_delay = respawn_criminal.respawn_penalty
		self:_send_finish_trade(respawn_criminal, respawn_delay, respawn_criminal.hostages_killed)
		local respawn_t = self._t + 2
		local clbk_id = "Respawn_criminal_on_trade"
		self._criminal_respawn_clbk = clbk_id
		managers.enemy:add_delayed_clbk(clbk_id, callback(self, self, "clbk_respawn_criminal", trading_unit), respawn_t)
	end
	function TradeManager:play_custody_voice(criminal_name)
		if managers.criminals:local_character_name() == criminal_name then return end
		if #self._criminals_to_respawn == 3 then
			local criminal_left
			for _, crim_data in pairs(managers.groupai:state():all_char_criminals()) do
				if not crim_data.unit:movement():downed() then
					criminal_left = managers.criminals:character_name_by_unit(crim_data.unit)
				end
			end

			if managers.criminals:local_character_name() == criminal_left then
				managers.achievment:set_script_data("last_man_standing", true)
				if managers.groupai:state():bain_state() then
					local static_data = managers.criminals:character_static_data_by_name(criminal_left)
					if static_data then
						managers.dialog:queue_dialog("Play_ban_i20" .. static_data.ssuffix, {})
					end
				end
				return
			end
		end

		if managers.groupai:state():bain_state() then
			local character_code = managers.criminals:character_static_data_by_name(criminal_name).ssuffix
			managers.dialog:queue_dialog("Play_ban_h11" .. character_code, {})
		end
	end
end
if RequiredScript == "lib/network/networkgame" then
	local orig_odiprr = NetworkGame.on_drop_in_pause_request_received
	function NetworkGame:on_drop_in_pause_request_received(peer_id, nickname, state)
		if managers.hud and state then
			if not managers.network:session():closing() and game_state_machine:current_state_name() == "ingame_waiting_for_players" then
				local component = managers.hud._component_map[Idstring( "guis/level_intro" ):key()]
				if component and alive(component.panel) and component.panel:visible() then
					managers.menu:show_person_joining(peer_id, nickname)
				end
			end
		end
		orig_odiprr(self, peer_id, nickname, state)
	end
	function NetworkGame:on_dropin_progress_received(dropin_peer_id, progress_percentage)
		local peer = managers.network:session():peer(dropin_peer_id)
		if peer:synched() then return end
		local dropin_member = self._members[dropin_peer_id]
		local old_drop_in_prog = dropin_member:drop_in_progress()
		if not old_drop_in_prog or progress_percentage > old_drop_in_prog then
			dropin_member:set_drop_in_progress(progress_percentage)
			local is_in_kitmenu = false
			if game_state_machine:last_queued_state_name() == "ingame_waiting_for_players" then
				local component = managers.hud._component_map[Idstring( "guis/level_intro" ):key()]
				if not component or not alive(component.panel) or not component.panel:visible() then
					is_in_kitmenu = true
				end
			end
			if is_in_kitmenu then
				managers.menu:get_menu("kit_menu").renderer:set_dropin_progress(dropin_peer_id, progress_percentage)
			else
				managers.menu:update_person_joining(dropin_peer_id, progress_percentage)
			end
		end
	end
end
if RequiredScript == "lib/managers/menu/menulobbyrenderer" then
	local mugshot_stencil = {
		random    = { "bg_lobby_fullteam", 65 },
		undecided = { "bg_lobby_fullteam", 65 },
		american  = { "bg_hoxton", 80 },
		german    = { "bg_wolf", 55 },
		russian   = { "bg_dallas", 65 },
		spanish   = { "bg_chains", 60 }
	}

	function MenuLobbyRenderer:highlight_item(item, ...)
		MenuLobbyRenderer.super.highlight_item(self, item, ...)
		local session = managers.network and managers.network:session()
		if session and session:local_peer() then
			local character = session:local_peer():character()
			managers.menu:active_menu().renderer:set_stencil_image(mugshot_stencil[character][1])
			managers.menu:active_menu().renderer:set_stencil_align("manual", mugshot_stencil[character][2])
			self:post_event("highlight")
		end
	end
end
if RequiredScript == "lib/managers/killzonemanager" then
	function KillzoneManager:update(t, dt)
		for unit_key, data in pairs(self._units) do
			if alive(data.unit) then
				if data.type == "gas" then
					data.timer = data.timer + dt
					if data.timer > data.next_gas then
						data.next_gas = data.timer + 0.25
						self:_deal_gas_damage(data.unit)
					end

				elseif data.type == "fire" then
					data.timer = data.timer + dt
					if data.timer > data.next_fire then
						data.next_fire = data.timer + 0.5
						self:_deal_fire_damage(data.unit)
					end
				
				elseif data.type == "sniper" then
					-- this is not used, but whatever
					data.timer = data.timer + dt
					if data.timer > data.next_shot then
						local warning_time = 4
						data.next_shot = data.timer + math.rand(warning_time < data.timer and 0.5 or 1)
						local warning_shot = math.max(warning_time - data.timer, 1)
						warning_shot = math.rand(warning_shot) > 0.75
						if warning_shot then
							self:_warning_shot(data.unit)
						else
							self:_deal_damage(data.unit)
						end
					end
				end
			else
				-- shouldn't still be here
				if data.timer and data.timer + 5 < t then
					self:_remove_unit(data.unit)
				end
			end
		end
	end
end
if RequiredScript == "lib/managers/hudmanager" then
	function HUDManager:add_mugshot_without_unit(char_name, ai, peer_id, name)
		local character_name = name
		local character_name_id = char_name
		local crew_bonus --, peer_id <- is the cause, this local variable has no value
		if not ai then
			crew_bonus = managers.player:get_crew_bonus_by_peer(peer_id)
		end

		local mask_name = managers.criminals:character_data_by_name(character_name_id).mask_icon
		local mask_icon, mask_texture_rect = tweak_data.hud_icons:get_icon_data(mask_name)
		local use_lifebar = not ai
		local mugshot_id = managers.hud:add_mugshot({
			name = string.upper(character_name),
			use_lifebar = use_lifebar,
			mask_icon = mask_icon,
			mask_texture_rect = mask_texture_rect,
			crew_bonus = crew_bonus,
			peer_id = peer_id,
			character_name_id = character_name_id,
			location_text = ""
		})
		return mugshot_id
	end
end
if RequiredScript == "lib/units/enemies/cop/actions/upper_body/copactiontase" then
	local temp_vec1 = Vector3()
	local temp_vec2 = Vector3()
	CopActionTase = CopActionTase or class()
	function CopActionTase:update(t)
		if self._expired then
			return
		end

		local shoot_from_pos = self._ext_movement:m_head_pos()
		local target_dis
		local target_vec = temp_vec1
		local target_pos = temp_vec2
		self._attention.unit:character_damage():shoot_pos_mid(target_pos)
		mvector3.set(target_vec, target_pos)
		mvector3.subtract(target_vec, shoot_from_pos)
		target_dis = mvector3.normalize(target_vec)
		local target_vec_flat = target_vec:with_z(0)
		mvector3.normalize(target_vec_flat)
		local fwd_dot = mvector3.dot(self._common_data.fwd, target_vec_flat)
		if fwd_dot > 0.7 then
			if not self._modifier_on then
				self._modifier_on = true
				self._machine:force_modifier(self._modifier_name)
				self._mod_enable_t = t + 0.5
			end

			self._modifier:set_target_y(target_vec)
		else
			if self._modifier_on then
				self._modifier_on = nil
				self._machine:allow_modifier(self._modifier_name)
			end

			if self._turn_allowed and not self._ext_anim.walk and not self._ext_anim.turn and not self._ext_movement:chk_action_forbidden("walk") then
				local spin = target_vec:to_polar_with_reference(self._common_data.fwd, math.UP).spin
				local abs_spin = math.abs(spin)
				if abs_spin > 27 then
					local new_action_data = {}
					new_action_data.type = "turn"
					new_action_data.body_part = 2
					new_action_data.angle = spin
					self._ext_movement:action_request(new_action_data)
				end
			end

			target_vec = nil
		end

		if self._ext_anim.reload or self._ext_anim.equip then
			-- nothing??
		elseif self._discharging then
			if not self._tasing_local_unit:movement():tased() then
				if Network:is_server() then
					self._expired = true
				end

				self._discharging = nil
			end

		elseif self._shoot_t and target_vec and self._common_data.allow_fire and t > self._shoot_t and t > self._mod_enable_t then
			if self._tase_effect then
				World:effect_manager():fade_kill(self._tase_effect)
			end

			self._tase_effect = World:effect_manager():spawn(self._tase_effect_table)
			if self._tasing_local_unit and mvector3.distance(shoot_from_pos, target_pos) < self._w_usage_tweak.tase_distance then
				local record = managers.groupai:state():criminal_record(self._tasing_local_unit:key())
				if (record and record.status) or self._tasing_local_unit:movement():chk_action_forbidden("hurt") then
					if Network:is_server() then
						self._expired = true
					end
				else
					local vis_ray = self._common_data.unit:raycast("ray", shoot_from_pos, target_pos, "slot_mask", self._line_of_fire_slotmask, "ignore_unit", self._tasing_local_unit)
					if not vis_ray then
						self._common_data.ext_network:send("action_tase_fire")
						local attack_data = { attacker_unit = self._common_data.unit }
						self._attention.unit:character_damage():damage_tase(attack_data)
						self._discharging = true
						if not self._tasing_local_unit:base().is_local_player then
							self._tasered_sound = self._common_data.unit:sound():play("tasered_3rd", nil)
						end

						local redir_res = self._ext_movement:play_redirect("recoil")
						if redir_res then
							self._machine:set_parameter(redir_res, "hvy", 0)
						end

						self._shoot_t = nil
					end
				end
			elseif not self._tasing_local_unit then
				self._tasered_sound = self._common_data.unit:sound():play("tasered_3rd", nil)
				local redir_res = self._ext_movement:play_redirect("recoil")
				if redir_res then
					self._machine:set_parameter(redir_res, "hvy", 0)
				end
				self._shoot_t = nil
			end
		end
	end
end
if RequiredScript == "lib/utils/game_state_machine/gamestatemachine" then
	function GameStateMachine:init()
		if not Global.game_state_machine then
			Global.game_state_machine = {is_boot_intro_done = false, is_boot_from_sign_out = false}
		end
		self._is_boot_intro_done = Global.game_state_machine.is_boot_intro_done
		Global.game_state_machine.is_boot_intro_done = true
		self._is_boot_from_sign_out = Global.game_state_machine.is_boot_from_sign_out
		Global.game_state_machine.is_boot_from_sign_out = false
		local setup_boot = not self._is_boot_intro_done and not Application:editor()
		local setup_title = (setup_boot or self._is_boot_from_sign_out) and not Application:editor()
		local states = {}
		local empty = GameState:new("empty", self)
		local editor = EditorState:new(self)
		local world_camera = WorldCameraState:new(self)
		local bootup = BootupState:new(self, setup_boot)
		local menu_titlescreen = MenuTitlescreenState:new(self, setup_title)
		local menu_main = MenuMainState:new(self)
		local ingame_standard = IngameStandardState:new(self)
		local ingame_mask_off = IngameMaskOffState:new(self)
		local ingame_bleed_out = IngameBleedOutState:new(self)
		local ingame_fatal = IngameFatalState:new(self)
		local ingame_arrested = IngameArrestedState:new(self)
		local ingame_electrified = IngameElectrifiedState:new(self)
		local ingame_incapacitated = IngameIncapacitatedState:new(self)
		local ingame_waiting_for_players = IngameWaitingForPlayersState:new(self)
		local ingame_waiting_for_respawn = IngameWaitingForRespawnState:new(self)
		local ingame_clean = IngameCleanState:new(self)
		local ingame_lobby = IngameLobbyMenuState:new(self)
		local gameoverscreen = GameOverState:new(self)
		local server_left = ServerLeftState:new(self)
		local disconnected = DisconnectedState:new(self)
		local kicked = KickedState:new(self)
		local victoryscreen = VictoryState:new(self)
		local empty_func = callback(nil, empty, "default_transition")
		local editor_func = callback(nil, editor, "default_transition")
		local world_camera_func = callback(nil, world_camera, "default_transition")
		local bootup_func = callback(nil, bootup, "default_transition")
		local menu_titlescreen_func = callback(nil, menu_titlescreen, "default_transition")
		local menu_main_func = callback(nil, menu_main, "default_transition")
		local ingame_standard_func = callback(nil, ingame_standard, "default_transition")
		local ingame_mask_off_func = callback(nil, ingame_mask_off, "default_transition")
		local ingame_bleed_out_func = callback(nil, ingame_bleed_out, "default_transition")
		local ingame_arrested_func = callback(nil, ingame_arrested, "default_transition")
		local ingame_fatal_func = callback(nil, ingame_fatal, "default_transition")
		local ingame_electrified_func = callback(nil, ingame_electrified, "default_transition")
		local ingame_incapacitated_func = callback(nil, ingame_incapacitated, "default_transition")
		local ingame_waiting_for_players_func = callback(nil, ingame_waiting_for_players, "default_transition")
		local ingame_waiting_for_respawn_func = callback(nil, ingame_waiting_for_respawn, "default_transition")
		local ingame_clean_func = callback(nil, ingame_clean, "default_transition")
		local ingame_lobby_func = callback(nil, gameoverscreen, "default_transition")
		local gameoverscreen_func = callback(nil, gameoverscreen, "default_transition")
		local server_left_func = callback(nil, server_left, "default_transition")
		local disconnected_func = callback(nil, disconnected, "default_transition")
		local kicked_func = callback(nil, disconnected, "default_transition")
		local victoryscreen_func = callback(nil, victoryscreen, "default_transition")
		self._controller_enabled_count = 1
		CoreGameStateMachine.GameStateMachine.init(self, empty)
		self:add_transition(editor, empty, editor_func)
		self:add_transition(editor, world_camera, editor_func)
		self:add_transition(editor, editor, editor_func)
		self:add_transition(editor, ingame_standard, editor_func)
		self:add_transition(editor, ingame_mask_off, editor_func)
		self:add_transition(editor, ingame_bleed_out, editor_func)
		self:add_transition(editor, ingame_fatal, editor_func)
		self:add_transition(editor, victoryscreen, editor_func)
		self:add_transition(editor, ingame_clean, editor_func)
		self:add_transition(world_camera, editor, world_camera_func)
		self:add_transition(world_camera, empty, world_camera_func)
		self:add_transition(world_camera, world_camera, world_camera_func)
		self:add_transition(world_camera, ingame_standard, world_camera_func)
		self:add_transition(world_camera, ingame_mask_off, world_camera_func)
		self:add_transition(world_camera, ingame_bleed_out, world_camera_func)
		self:add_transition(world_camera, ingame_fatal, world_camera_func)
		self:add_transition(world_camera, ingame_arrested, world_camera_func)
		self:add_transition(world_camera, ingame_electrified, world_camera_func)
		self:add_transition(world_camera, ingame_incapacitated, world_camera_func)
		self:add_transition(world_camera, ingame_waiting_for_players, world_camera_func)
		self:add_transition(world_camera, ingame_waiting_for_respawn, world_camera_func)
		self:add_transition(world_camera, ingame_clean, world_camera_func)
		self:add_transition(world_camera, server_left, world_camera_func)
		self:add_transition(world_camera, disconnected, world_camera_func)
		self:add_transition(world_camera, kicked, world_camera_func)
		self:add_transition(world_camera, victoryscreen, world_camera)
		self:add_transition(bootup, menu_titlescreen, bootup_func)
		self:add_transition(menu_titlescreen, menu_main, menu_titlescreen_func)
		self:add_transition(ingame_standard, editor, ingame_standard_func)
		self:add_transition(ingame_standard, world_camera, ingame_standard_func)
		self:add_transition(ingame_standard, ingame_mask_off, ingame_standard_func)
		self:add_transition(ingame_standard, ingame_bleed_out, ingame_standard_func)
		self:add_transition(ingame_standard, ingame_fatal, ingame_standard_func)
		self:add_transition(ingame_standard, ingame_arrested, ingame_standard_func)
		self:add_transition(ingame_standard, ingame_electrified, ingame_standard_func)
		self:add_transition(ingame_standard, ingame_incapacitated, ingame_standard_func)
		self:add_transition(ingame_standard, victoryscreen, ingame_standard_func)
		self:add_transition(ingame_standard, ingame_waiting_for_respawn, ingame_standard_func)
		self:add_transition(ingame_standard, ingame_standard, ingame_standard_func)
		self:add_transition(ingame_standard, ingame_waiting_for_players, ingame_standard_func)
		self:add_transition(ingame_standard, ingame_clean, ingame_standard_func)
		self:add_transition(ingame_standard, server_left, ingame_standard_func)
		self:add_transition(ingame_standard, gameoverscreen, ingame_standard_func)
		self:add_transition(ingame_standard, disconnected, ingame_standard_func)
		self:add_transition(ingame_standard, kicked, ingame_standard_func)
		self:add_transition(ingame_mask_off, editor, ingame_mask_off_func)
		self:add_transition(ingame_mask_off, world_camera, ingame_mask_off_func)
		self:add_transition(ingame_mask_off, ingame_standard, ingame_mask_off_func)
		self:add_transition(ingame_mask_off, ingame_bleed_out, ingame_mask_off_func)
		self:add_transition(ingame_mask_off, ingame_fatal, ingame_mask_off_func)
		self:add_transition(ingame_mask_off, ingame_arrested, ingame_mask_off_func)
		self:add_transition(ingame_mask_off, ingame_electrified, ingame_mask_off_func)
		self:add_transition(ingame_mask_off, ingame_incapacitated, ingame_mask_off_func)
		self:add_transition(ingame_mask_off, ingame_waiting_for_respawn, ingame_mask_off_func)
		self:add_transition(ingame_mask_off, ingame_clean, ingame_mask_off_func)
		self:add_transition(ingame_mask_off, server_left, ingame_mask_off_func)
		self:add_transition(ingame_mask_off, gameoverscreen, ingame_mask_off_func)
		self:add_transition(ingame_mask_off, disconnected, ingame_mask_off_func)
		self:add_transition(ingame_mask_off, kicked, ingame_mask_off_func)
		self:add_transition(ingame_clean, editor, ingame_clean_func)
		self:add_transition(ingame_clean, world_camera, ingame_clean_func)
		self:add_transition(ingame_clean, ingame_mask_off, ingame_clean_func)
		self:add_transition(ingame_clean, ingame_standard, ingame_clean_func)
		self:add_transition(ingame_clean, ingame_bleed_out, ingame_clean_func)
		self:add_transition(ingame_clean, ingame_fatal, ingame_clean_func)
		self:add_transition(ingame_clean, ingame_arrested, ingame_clean_func)
		self:add_transition(ingame_clean, ingame_electrified, ingame_clean_func)
		self:add_transition(ingame_clean, ingame_incapacitated, ingame_clean_func)
		self:add_transition(ingame_clean, ingame_waiting_for_respawn, ingame_clean_func)
		self:add_transition(ingame_clean, server_left, ingame_clean_func)
		self:add_transition(ingame_clean, gameoverscreen, ingame_clean_func)
		self:add_transition(ingame_clean, disconnected, ingame_clean_func)
		self:add_transition(ingame_clean, kicked, ingame_clean_func)
		self:add_transition(ingame_bleed_out, editor, ingame_bleed_out_func)
		self:add_transition(ingame_bleed_out, world_camera, ingame_bleed_out_func)
		self:add_transition(ingame_bleed_out, ingame_standard, ingame_bleed_out_func)
		self:add_transition(ingame_bleed_out, ingame_mask_off, ingame_bleed_out_func)
		self:add_transition(ingame_bleed_out, ingame_fatal, ingame_bleed_out_func)
		self:add_transition(ingame_bleed_out, ingame_arrested, ingame_bleed_out_func)
		self:add_transition(ingame_bleed_out, victoryscreen, ingame_bleed_out_func)
		self:add_transition(ingame_bleed_out, ingame_waiting_for_respawn, ingame_bleed_out_func)
		self:add_transition(ingame_bleed_out, gameoverscreen, ingame_bleed_out_func)
		self:add_transition(ingame_bleed_out, server_left, ingame_bleed_out_func)
		self:add_transition(ingame_bleed_out, disconnected, ingame_bleed_out_func)
		self:add_transition(ingame_bleed_out, kicked, ingame_bleed_out_func)
		self:add_transition(ingame_fatal, editor, ingame_fatal_func)
		self:add_transition(ingame_fatal, world_camera, ingame_fatal_func)
		self:add_transition(ingame_fatal, ingame_standard, ingame_fatal_func)
		self:add_transition(ingame_fatal, ingame_mask_off, ingame_fatal_func)
		self:add_transition(ingame_fatal, ingame_bleed_out, ingame_fatal_func)
		self:add_transition(ingame_fatal, victoryscreen, ingame_fatal_func)
		self:add_transition(ingame_fatal, ingame_waiting_for_respawn, ingame_fatal_func)
		self:add_transition(ingame_fatal, gameoverscreen, ingame_fatal_func)
		self:add_transition(ingame_fatal, server_left, ingame_fatal_func)
		self:add_transition(ingame_fatal, disconnected, ingame_fatal_func)
		self:add_transition(ingame_fatal, kicked, ingame_fatal_func)
		self:add_transition(ingame_arrested, editor, ingame_arrested_func)
		self:add_transition(ingame_arrested, world_camera, ingame_arrested_func)
		self:add_transition(ingame_arrested, ingame_standard, ingame_arrested_func)
		self:add_transition(ingame_arrested, victoryscreen, ingame_arrested_func)
		self:add_transition(ingame_arrested, ingame_waiting_for_respawn, ingame_arrested_func)
		self:add_transition(ingame_arrested, gameoverscreen, ingame_arrested_func)
		self:add_transition(ingame_arrested, ingame_bleed_out, ingame_arrested_func)
		self:add_transition(ingame_arrested, server_left, ingame_arrested_func)
		self:add_transition(ingame_arrested, disconnected, ingame_arrested_func)
		self:add_transition(ingame_arrested, kicked, ingame_arrested_func)
		self:add_transition(ingame_electrified, editor, ingame_electrified_func)
		self:add_transition(ingame_electrified, world_camera, ingame_electrified_func)
		self:add_transition(ingame_electrified, ingame_standard, ingame_electrified_func)
		self:add_transition(ingame_electrified, ingame_incapacitated, ingame_electrified_func)
		self:add_transition(ingame_electrified, victoryscreen, ingame_electrified_func)
		self:add_transition(ingame_electrified, ingame_bleed_out, ingame_electrified_func)
		self:add_transition(ingame_electrified, ingame_fatal, ingame_electrified_func)
		self:add_transition(ingame_electrified, server_left, ingame_electrified_func)
		self:add_transition(ingame_electrified, gameoverscreen, ingame_electrified_func)
		self:add_transition(ingame_electrified, disconnected, ingame_electrified_func)
		self:add_transition(ingame_electrified, kicked, ingame_electrified_func)
		self:add_transition(ingame_incapacitated, editor, ingame_incapacitated_func)
		self:add_transition(ingame_incapacitated, world_camera, ingame_incapacitated_func)
		self:add_transition(ingame_incapacitated, ingame_standard, ingame_incapacitated_func)
		self:add_transition(ingame_incapacitated, victoryscreen, ingame_incapacitated_func)
		self:add_transition(ingame_incapacitated, ingame_waiting_for_respawn, ingame_incapacitated_func)
		self:add_transition(ingame_incapacitated, gameoverscreen, ingame_incapacitated_func)
		self:add_transition(ingame_incapacitated, server_left, ingame_incapacitated_func)
		self:add_transition(ingame_incapacitated, gameoverscreen, ingame_incapacitated_func)
		self:add_transition(ingame_incapacitated, disconnected, ingame_incapacitated_func)
		self:add_transition(ingame_incapacitated, kicked, ingame_incapacitated_func)
		self:add_transition(ingame_waiting_for_players, ingame_standard, ingame_waiting_for_players_func)
		self:add_transition(ingame_waiting_for_players, ingame_mask_off, ingame_waiting_for_players_func)
		self:add_transition(ingame_waiting_for_players, ingame_clean, ingame_waiting_for_players_func)
		self:add_transition(ingame_waiting_for_players, gameoverscreen, ingame_waiting_for_players_func)
		self:add_transition(ingame_waiting_for_players, victoryscreen, ingame_waiting_for_players_func)
		self:add_transition(ingame_waiting_for_players, server_left, ingame_waiting_for_players_func)
		self:add_transition(ingame_waiting_for_players, disconnected, ingame_waiting_for_players_func)
		self:add_transition(ingame_waiting_for_players, kicked, ingame_waiting_for_players_func)
		self:add_transition(ingame_waiting_for_players, ingame_lobby, ingame_waiting_for_players_func)
		self:add_transition(ingame_waiting_for_respawn, ingame_standard, ingame_waiting_for_respawn_func)
		self:add_transition(ingame_waiting_for_respawn, ingame_mask_off, ingame_waiting_for_respawn_func)
		self:add_transition(ingame_waiting_for_respawn, editor, ingame_waiting_for_respawn_func)
		self:add_transition(ingame_waiting_for_respawn, ingame_clean, ingame_waiting_for_respawn_func)
		self:add_transition(ingame_waiting_for_respawn, gameoverscreen, ingame_waiting_for_respawn_func)
		self:add_transition(ingame_waiting_for_respawn, victoryscreen, ingame_waiting_for_respawn_func)
		self:add_transition(ingame_waiting_for_respawn, server_left, ingame_waiting_for_respawn_func)
		self:add_transition(ingame_waiting_for_respawn, disconnected, ingame_waiting_for_respawn_func)
		self:add_transition(ingame_waiting_for_respawn, kicked, ingame_waiting_for_respawn_func)
		self:add_transition(gameoverscreen, gameoverscreen, gameoverscreen_func)
		self:add_transition(gameoverscreen, editor, gameoverscreen_func)
		self:add_transition(gameoverscreen, ingame_lobby, gameoverscreen_func)
		self:add_transition(gameoverscreen, server_left, gameoverscreen_func)
		self:add_transition(gameoverscreen, disconnected, gameoverscreen_func)
		self:add_transition(gameoverscreen, kicked, gameoverscreen_func)
		self:add_transition(gameoverscreen, empty, gameoverscreen_func)
		self:add_transition(gameoverscreen, menu_main, gameoverscreen_func)
		self:add_transition(ingame_lobby, empty, ingame_lobby_func)
		self:add_transition(ingame_lobby, server_left, ingame_lobby_func)
		self:add_transition(ingame_lobby, disconnected, ingame_lobby_func)
		self:add_transition(ingame_lobby, kicked, ingame_lobby_func)
		self:add_transition(server_left, empty, gameoverscreen_func)
		self:add_transition(server_left, disconnected, gameoverscreen_func)
		self:add_transition(disconnected, empty, gameoverscreen_func)
		self:add_transition(kicked, empty, gameoverscreen_func)
		-- self:add_transition(victoryscreen, ingame_standard, victoryscreen_func)
		self:add_transition(victoryscreen, editor, victoryscreen_func)
		-- self:add_transition(victoryscreen, ingame_fatal, victoryscreen_func)
		-- self:add_transition(victoryscreen, ingame_bleed_out, victoryscreen_func)
		-- self:add_transition(victoryscreen, ingame_arrested, victoryscreen_func)
		-- self:add_transition(victoryscreen, ingame_electrified, victoryscreen_func)
		self:add_transition(victoryscreen, world_camera, victoryscreen_func)
		self:add_transition(victoryscreen, empty, victoryscreen_func)
		self:add_transition(victoryscreen, ingame_lobby, victoryscreen_func)
		self:add_transition(victoryscreen, server_left, victoryscreen_func)
		self:add_transition(victoryscreen, disconnected, victoryscreen_func)
		self:add_transition(victoryscreen, kicked, victoryscreen_func)
		self:add_transition(victoryscreen, menu_main, victoryscreen_func)
		self:add_transition(empty, editor, empty_func)
		self:add_transition(empty, world_camera, empty_func)
		self:add_transition(empty, bootup, empty_func)
		self:add_transition(empty, menu_titlescreen, empty_func)
		self:add_transition(empty, menu_main, empty_func)
		self:add_transition(empty, ingame_standard, empty_func)
		self:add_transition(empty, ingame_mask_off, empty_func)
		self:add_transition(empty, ingame_bleed_out, empty_func)
		self:add_transition(empty, ingame_clean, empty_func)
		self:add_transition(empty, ingame_waiting_for_players, empty_func)
		self:add_transition(empty, ingame_waiting_for_respawn, empty_func)
		self:add_transition(empty, gameoverscreen, empty_func)
		self:add_transition(empty, victoryscreen, empty_func)
		managers.menu:add_active_changed_callback(callback(self, self, "menu_active_changed_callback"))
		managers.system_menu:add_active_changed_callback(callback(self, self, "dialog_active_changed_callback"))
	end
end
if RequiredScript == "lib/network/matchmaking/networkmatchmakingsteam" then
	local orig_netmmst_lg = NetworkMatchMakingSTEAM._load_globals
	function NetworkMatchMakingSTEAM:_load_globals()
		orig_netmmst_lg(self)
		self._num_players = self._lobby_attributes and self._lobby_attributes.num_players or 1
	end
end
if RequiredScript == "lib/states/ingamelobbymenu" then
	function IngameLobbyMenuState:at_enter()
		managers.platform:set_presence("Mission_end")
		managers.hud:remove_updator("point_of_no_return")
		print("[IngameLobbyMenuState:at_enter()]")
		if Network:is_server() then
			managers.network.matchmake:set_server_state("in_lobby")
			
			-- this check should've been in the base game
			if table.size(managers.network:session():peers()) < 3 then -- player/host isn't included
				managers.network.matchmake:set_server_joinable(true)
			end
			managers.network:session():set_state("in_lobby")
		else
			managers.network:session():send_to_peers_loaded("set_peer_entered_lobby")
		end

		managers.mission:pre_destroy()
		self:setup_controller()
		managers.menu:close_menu()
		managers.menu:open_menu("lobby_menu")
	end
end