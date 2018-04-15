-- override, no melee shake effect

function PlayerStandard:_check_action_melee(t, input)
	local new_action
	local action_wanted = input.btn_melee_press
	if action_wanted then
		local action_forbidden = self._melee_expire_t or self._use_item_expire_t or self:_changing_weapon() or self:_interacting()
		if not action_forbidden then
			self._equipped_unit:base():tweak_data_anim_stop("fire")
			self:_interupt_action_reload(t)
			self:_interupt_action_steelsight(t)
			self:_interupt_action_running(t)
			managers.network:session():send_to_peers("play_distance_interact_redirect", self._unit, "melee")
			if Config.data.melee_shake_effect then
				self._unit:camera():play_shaker("player_melee")
			end
			self._unit:camera():play_redirect(self.IDS_MELEE)
			self._melee_expire_t = t + 0.6
			local range = 200 * managers.player:synced_crew_bonus_upgrade_value("gang_of_ninjas", 1)
			local from = self._unit:movement():m_head_pos()
			local to = from + self._unit:movement():m_head_rot():y() * range
			local sphere_cast_radius = 20
			local col_ray = self._unit:raycast("ray", from, to, "slot_mask", self._slotmask_bullet_impact_targets, "sphere_cast_radius", sphere_cast_radius, "ray_type", "body melee")
			if col_ray then
				do
					local damage, damage_effect = self._equipped_unit:base():melee_damage_info()
					col_ray.sphere_cast_radius = sphere_cast_radius
					local hit_unit = col_ray.unit
					if not hit_unit:character_damage() or not hit_unit:character_damage()._no_blood then
						managers.game_play_central:play_impact_flesh({col_ray = col_ray})
						managers.game_play_central:play_impact_sound_and_effects({col_ray = col_ray, no_decal = true})
					end

					if hit_unit:damage() and col_ray.body:extension() and col_ray.body:extension().damage then
						col_ray.body:extension().damage:damage_melee(self._unit, col_ray.normal, col_ray.position, col_ray.direction, damage)
						if hit_unit:id() ~= -1 then
							managers.network:session():send_to_peers_synched("sync_body_damage_melee", col_ray.body, self._unit, col_ray.normal, col_ray.position, col_ray.direction, damage)
						end
					end

					managers.rumble:play("melee_hit")
					managers.game_play_central:physics_push(col_ray)
					if hit_unit:character_damage() and hit_unit:character_damage().damage_melee then
						local action_data = {}
						action_data.variant = "melee"
						action_data.damage = damage
						action_data.damage_effect = damage_effect
						action_data.attacker_unit = self._unit
						action_data.col_ray = col_ray
						local defense_data = col_ray.unit:character_damage():damage_melee(action_data)
						return defense_data
					end
				end
			else
			end
			new_action = true
		end
	end
	return new_action
end
-- override, don't stop reload after start running:
--[[
function PlayerStandard:_start_action_running(t)
	if not self._move_dir then
		self._running_wanted = true
		return
	end
	
	if (self._shooting or self:_changing_weapon() or self._melee_expire_t) then
		self._running_wanted = true
		return
	end

	if self._in_air or self._use_item_expire_t then
		self._running_wanted = true
		return
	end

	if self._ducking and not self:_can_stand() then
		self._running_wanted = true
		return
	end

	if managers.player:get_player_rule("no_run") then
		return
	end

	self._running_wanted = false
	self._running = true
	self._end_running_expire_t = nil
	self._start_running_t = t

	self._df_sprintcamera = true
	self._unit:camera():play_redirect(self.IDS_START_RUNNING)
	--self:_interupt_action_reload(t)
	self:_interupt_action_steelsight(t)

	self:_interupt_action_ducking(t)
end
--]]