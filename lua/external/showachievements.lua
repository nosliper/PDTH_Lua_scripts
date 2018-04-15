if Config.data.show_challenges_completed then
	local orig_set_flag = ChallengesManager.set_flag
	local orig_check_compl = ChallengesManager._check_completed
	local orig_compl_chal = ChallengesManager._completed_challenge

	function ChallengesManager:set_flag(flag_id, ...)
		if self._flag_map[flag_id] then
			local ignore_completed_state = true
			if ignore_completed_state then
				for _, name in ipairs(self._flag_map[flag_id]) do
					if not (self._global.active[name] and (not self._global.completed[name] or self._global.active[name].already_awarded)) then
						self:_check_completed(name)
					end
				end
			end
		end
		
		orig_set_flag(self, flag_id, ...)
	end

	function ChallengesManager:_check_completed(name, ...)
		if self._global.active[name] then
			orig_check_compl(self, name, ...)
		elseif self._global.completed[name] then
			self:_completed_challenge(name)
		end
	end

	function ChallengesManager:_completed_challenge(name)
		if self._global.completed[name] or not self._global.active[name] then
			if managers.hud then
				if self._completed_challenges_shown and self._completed_challenges_shown[name] then
					return
				end
				
				local achievement = self:get_awarded_achievment(name)
				local challenge_found = false
				local challenge_includes = {"blood_in_blood_out","drop_armored_car","windowlicker","take_money","the_darkness","chavez_can_run","ninja","take_sapphires","quick_gold","stand_together","kill_thugs","kill_cameras","hot_lava","bomb_man","ready_yet","cant_touch","dozen_angry","noob_herder","crowd_control","quick_hands","pacifist","blow_out","saviour","det_gadget","wrong_door","afraid_of_the_dark"}
				for _, v in pairs(challenge_includes) do
					if name == v then
						challenge_found = true
						break
					end
				end
				if challenge_found == false then
					return
				end
				
				self._completed_challenges_shown = self._completed_challenges_shown or {}
				self._completed_challenges_shown[name] = true
				
				managers.hud:present_mid_text({
					title = managers.localization:text("present_challenge_completed_title"),
					text = self:get_title_text(name),
					time = 4,
					icon = nil,
					event = "stinger_objectivecomplete",
					type = "challenge"
				})
			end
			
			return -- it's already awarded
		end

		if self._global.active[name] and not self._global.active[name].already_awarded then
			self._completed_challenges_shown = self._completed_challenges_shown or {}
			self._completed_challenges_shown[name] = true
		end
		
		return orig_compl_chal(self, name)
	end
end