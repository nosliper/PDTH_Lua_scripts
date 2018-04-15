-- CORPSE DESPAWN
-- PR to lib/managers/enemymanager

local EnemyManager = EnemyManager
EnemyManager._MAX_NR_CORPSES = 5

local mvec3_dis = mvector3.distance
local mvec3_dot = mvector3.dot

function EnemyManager:_upd_corpse_disposal()
	local enemy_data = self._enemy_data
	local nr_corpses = enemy_data.nr_corpses
	
	self._has_corpse_disposal_task = false
	
	if nr_corpses > self._MAX_NR_CORPSES then
		local disposals_needed = nr_corpses - self._MAX_NR_CORPSES
		local corpses = enemy_data.corpses
		local nav_mngr = managers.navigation
		local player = managers.player:player_unit()
		local pl_tracker, cam_pos, cam_fwd
		if player then
			pl_tracker = player:movement():nav_tracker()
			cam_pos = player:movement():m_head_pos()
			cam_fwd = player:camera():forward()
		elseif managers.viewport:get_current_camera() then
			cam_pos = managers.viewport:get_current_camera_position()
			cam_fwd = managers.viewport:get_current_camera_rotation():y()
		end

		local to_dispose = {}
		local nr_found = 0
		if pl_tracker then
			for u_key, u_data in pairs(corpses) do
				local u_tracker = u_data.tracker
				if not pl_tracker:check_visibility(u_tracker) then
					to_dispose[u_key] = true
					nr_found = nr_found + 1
				end
			end
		end

		if disposals_needed > nr_found then
			-- the first sweep didn't produce enough, search harder
			if cam_pos then
				for u_key, u_data in pairs(corpses) do
					local u_pos = u_data.m_pos
					if not to_dispose[u_key] and mvec3_dis(cam_pos, u_pos) > 300 and 0 > mvec3_dot(cam_fwd, u_pos - cam_pos) then
						to_dispose[u_key] = true
						nr_found = nr_found + 1
						if nr_found == disposals_needed then
							break -- not in the original code (commented?), but it's useless to stop searching here
						end
					end
				end
			end

			if disposals_needed > nr_found then
				-- still not done? then also include the oldest corpse around
				local oldest_u_key, oldest_t
				for u_key, u_data in pairs(corpses) do
					if (not oldest_t or oldest_t > u_data.death_t) and not to_dispose[u_key] then
						oldest_u_key = u_key
						oldest_t = u_data.death_t
					end
				end

				if oldest_u_key then
					to_dispose[oldest_u_key] = true
					nr_found = nr_found + 1
				end
			end
		end

		for u_key, u_data in pairs(to_dispose) do
			local u_data = corpses[u_key]
			u_data.unit:base():set_slot(u_data.unit, 0)
			corpses[u_key] = nil
		end

		enemy_data.nr_corpses = nr_corpses - nr_found
		if nr_corpses > math.max(0, self._MAX_NR_CORPSES * .75) then
			self._has_corpse_disposal_task = true
			self:queue_task("EnemyManager._upd_corpse_disposal", self._upd_corpse_disposal, self, self._t + 0.1)
		end
	end
end

function EnemyManager:on_enemy_died(dead_unit, damage_info)
	local u_key = dead_unit:key()
	local enemy_data = self._enemy_data
	local u_data = enemy_data.unit_data[u_key]
	self:on_enemy_unregistered(dead_unit)
	enemy_data.unit_data[u_key] = nil
	if not self._has_corpse_disposal_task and enemy_data.nr_corpses + 1 > math.max(0, self._MAX_NR_CORPSES * .75) then
		self._has_corpse_disposal_task = true
		self:queue_task("EnemyManager._upd_corpse_disposal", self._upd_corpse_disposal, self, self._t + self._corpse_disposal_upd_interval)
	end

	enemy_data.nr_corpses = enemy_data.nr_corpses + 1
	enemy_data.corpses[u_key] = u_data
	u_data.death_t = self._t
	self:_destroy_unit_gfx_lod_data(u_key)
	u_data.u_id = dead_unit:id()
	Network:detach_unit(dead_unit)
end

function EnemyManager:on_enemy_destroyed(enemy)
	local u_key = enemy:key()
	local enemy_data = self._enemy_data
	if enemy_data.unit_data[u_key] then
		self:on_enemy_unregistered(enemy)
		enemy_data.unit_data[u_key] = nil
		self:_destroy_unit_gfx_lod_data(u_key)
	elseif enemy_data.corpses[u_key] then
		enemy_data.nr_corpses = enemy_data.nr_corpses - 1
		enemy_data.corpses[u_key] = nil
		if self._has_corpse_disposal_task and enemy_data.nr_corpses <= 0 then
			self:unqueue_task("EnemyManager._upd_corpse_disposal")
			self._has_corpse_disposal_task = false
		end
	end
end

function EnemyManager:on_civilian_died(dead_unit, damage_info)
	local u_key = dead_unit:key()
	if Network:is_server() and damage_info.attacker_unit and not dead_unit:base().enemy then
		managers.groupai:state():hostage_killed(damage_info.attacker_unit)
	end

	local u_data = self._civilian_data.unit_data[u_key]
	local enemy_data = self._enemy_data
	if not self._has_corpse_disposal_task and enemy_data.nr_corpses + 1 > math.max(0, self._MAX_NR_CORPSES * .75) then
		self._has_corpse_disposal_task = true
		self:queue_task("EnemyManager._upd_corpse_disposal", self._upd_corpse_disposal, self, self._t + self._corpse_disposal_upd_interval)
	end

	enemy_data.nr_corpses = enemy_data.nr_corpses + 1
	enemy_data.corpses[u_key] = u_data
	u_data.death_t = TimerManager:game():time()
	self._civilian_data.unit_data[u_key] = nil
	self:_destroy_unit_gfx_lod_data(u_key)
	u_data.u_id = dead_unit:id()
	Network:detach_unit(dead_unit)
end

function EnemyManager:on_civilian_destroyed(enemy)
	local u_key = enemy:key()
	local enemy_data = self._enemy_data
	if enemy_data.corpses[u_key] then
		enemy_data.nr_corpses = enemy_data.nr_corpses - 1
		enemy_data.corpses[u_key] = nil
		if self._has_corpse_disposal_task and enemy_data.nr_corpses <= 0 then
			self:unqueue_task("EnemyManager._upd_corpse_disposal")
			self._has_corpse_disposal_task = false
		end
	else
		self._civilian_data.unit_data[u_key] = nil
		self:_destroy_unit_gfx_lod_data(u_key)
	end
end