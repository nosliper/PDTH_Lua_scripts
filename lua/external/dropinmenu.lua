-- DROP IN MENU
-- PR to lib/managers/systemmenumanager

function is_dropin_dialog(dialog)
	if not dialog or not dialog:id() then
		return false
	end
	return string.find(dialog:id(), "^user_dropin")
end

local orig_init = MenuManager.init
function MenuManager:init(is_start_menu)
	orig_init(self, is_start_menu)
	
	local instance = managers.system_menu

	-- system menu is always available at this point, so just hook functions here
	function instance:is_active(ignore_dropin)
		if self._active_dialog ~= nil then
			if is_dropin_dialog(self._active_dialog) then
				return false -- do not let the dropin dialog stop other dialogs from showing
			end
			return true
		end
		return false
	end
	
	function instance:get_dialog(id, include_queued)
		if not id then return end
		if self._active_dialog and self._active_dialog:id() == id then
			return self._active_dialog
		end
		if include_queued then
			if self._dialog_queue then
				for _, dialog in pairs(self._dialog_queue) do
					if dialog:id() == id then
						return dialog
					end
				end
			end
			if self._active_dropin_dialog and self._active_dropin_dialog:id() == id then
				return self._active_dropin_dialog
			end
		end
	end
	
	function instance:update_queue()
		if self._active_dialog == nil and self._dialog_queue then
			local dialog, index
			for next_index, next_dialog in ipairs(self._dialog_queue) do
				if not dialog or next_dialog:priority() > dialog:priority() then
					if not self._active_dropin_dialog or not is_dropin_dialog(next_dialog) then
						index = next_index
						dialog = next_dialog
					end
				end
			end
			table.remove(self._dialog_queue, index)
			if not next(self._dialog_queue) then
				self._dialog_queue = nil
			end
			if dialog then self:_show_instance(dialog, true) end
		end
	end
	
	function instance:_show_instance(dialog, force)
		local is_active = self:is_active() --self._active_dialog ~= nil
		if is_active and force then
			self:hide_active_dialog()
		end
		local queue = true
		if not is_active then
			if not self._active_dialog or not is_dropin_dialog(dialog) then
				-- queue dropin dialogs, but not others
				queue = not dialog:show()
			end
		end
		if queue then
			self:queue_dialog(dialog, force and 1 or nil)
		end
	end
	
	function instance:event_dialog_shown(dialog)
		if Global.category_print.dialog_manager then
			cat_print("dialog_manager", "[SystemMenuManager] [Show dialog] " .. tostring(dialog:to_string()))
		end

		local fade_in = true
		do
			local is_dropin = is_dropin_dialog(dialog)
			if is_dropin then
				dialog._panel_script:set_fade(1)
				dialog:set_input_enabled(false)
				dialog._fade_in_time = nil
				managers.menu:update_dropin_dialog_visibility(dialog)
				fade_in = false
			elseif self._active_dialog ~= nil and self._active_dialog ~= dialog and is_dropin_dialog(self._active_dialog) then
				if self._active_dialog and not self._active_dialog:is_closing() and self._active_dialog.hide then
					self._active_dropin_dialog = self._active_dialog
					self._active_dialog:hide()
				end
			end
		end
		if fade_in then dialog:fade_in() end
		self:set_active_dialog(dialog)
		self._dialog_shown_callback_handler:dispatch(dialog)
	end
	
	function instance:_promote_active_dropin_dialog(dialog)
		if self._active_dropin_dialog and dialog ~= self._active_dropin_dialog then
			local has_next_dialog = false
			if self._dialog_queue then
				for next_index, next_dialog in ipairs(self._dialog_queue) do
					if not is_dropin_dialog(next_dialog) then
						has_next_dialog = true
					end
				end
			end
			
			if not has_next_dialog then
				if not self._active_dropin_dialog:is_closing() then
					self._active_dropin_dialog:show()
					self._active_dialog = self._active_dropin_dialog
				end
				self._active_dropin_dialog = nil
			end
		end
	end
	
	local orig_hidden = instance.event_dialog_hidden
	function instance:event_dialog_hidden(dialog)
		orig_hidden(self, dialog)
		self:_promote_active_dropin_dialog(dialog)
	end
	
	local orig_closed = instance.event_dialog_closed
	function instance:event_dialog_closed(dialog)
		orig_closed(self, dialog)
		self:_promote_active_dropin_dialog(dialog)
	end
	
	function instance:close(id)
		if not id then return end
		print("close active dialog", self._active_dialog and self._active_dialog:id(), id)
		if self._active_dialog and self._active_dialog:id() == id then
			self._active_dialog:fade_out_close()
		end
		if self._active_dropin_dialog and self._active_dropin_dialog:id() == id then
			self._active_dropin_dialog = nil
			
			if self._dialog_queue then
				local dialog, index, has_next_dialog
				for next_index, next_dialog in ipairs(self._dialog_queue) do
					if is_dropin_dialog(next_dialog) then
						if not dialog or next_dialog:priority() > dialog:priority() then
							index = next_index
							dialog = next_dialog
						end
					else
						has_next_dialog = true
					end
				end
				
				if dialog then
					table.remove(self._dialog_queue, index)
					if not next(self._dialog_queue) then
						self._dialog_queue = nil
					end
					
					if has_next_dialog then
						self._active_dropin_dialog = dialog
					else
						self:_show_instance(dialog, true)
					end
				end
			end
		end

		if self._dialog_queue then
			local N = #self._dialog_queue
			for i, dialog in ipairs(self._dialog_queue) do
				if dialog:id() == id then
					print("remove from queue", id)
					self._dialog_queue[i] = nil
				end
			end
			
			-- fix table indices
			local i = 1
			for j = 2, N do
				if self._dialog_queue[i] then
					i = i + 1
				else
					if self._dialog_queue[j] then
						self._dialog_queue[i] = self._dialog_queue[j]
						self._dialog_queue[j] = nil
						i = i + 1
					end
				end
			end
		end
	end
	
	return instance
end

function MenuManager:toggle_menu_state()
	if managers.hud and managers.hud._chat_focus then return end
	local menu_is_active = managers.system_menu:is_active() and not is_dropin_dialog(managers.system_menu._active_dialog)
	if not self._is_start_menu and (not Application:editor() or Global.running_simulation) and not menu_is_active then
		if self:is_open("menu_pause") then
			if not self:is_pc_controller() or self:is_in_root("menu_pause") then
				self:close_menu("menu_pause")
			end
		elseif not self:active_menu() or #self:active_menu().logic._node_stack == 1 then
			self:open_menu("menu_pause")
			if Global.game_settings.single_player then
				Application:set_pause(true)
				SoundDevice:set_rtpc("ingame_sound", 0)
			end
		end
	end
end

function MenuManager:update_dropin_dialog_visibility(dialog)
	dialog = dialog or managers.system_menu._active_dialog
	if is_dropin_dialog(dialog) then
		local menu_showing = self:is_open("menu_pause")
		dialog._panel_script.bg:set_visible(not menu_showing)
		dialog._panel_script.bg_frame:set_color(Color.black:with_alpha(menu_showing and 0.25 or 0.75))
	end
end

local orig_open_menu = MenuManager.open_menu
function MenuManager:open_menu(menu_name)
	orig_open_menu(self, menu_name)
	if menu_name == "menu_pause" then
		self:update_dropin_dialog_visibility()
	end
end

local orig_close_menu = MenuManager.close_menu
function MenuManager:close_menu(menu_name)
	orig_close_menu(self, menu_name)
	if menu_name == "menu_pause" then
		self:update_dropin_dialog_visibility()
	end
end

local orig_show_person_joining = MenuManager.show_person_joining
function MenuManager:show_person_joining(id, nick)
	local dlg = managers.system_menu:get_dialog("user_dropin" .. id, true)
	if dlg then
		dlg:set_title(managers.localization:text("dialog_dropin_title", {
			USER = string.upper(nick)
		}))
	else
		orig_show_person_joining(self, id, nick)
	end
end