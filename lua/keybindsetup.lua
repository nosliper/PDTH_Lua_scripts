--- keybindsetup.lua, jetbriant
Keybinds = Keybinds or class()
local self = Keybinds
self.keyboard = Input:keyboard()
self.cmd_key = 42 -- left shift
self.keybinds_list = {}
self.cmd_list = {}
function Keybinds:get_keycode(key)
	return Idstring(key)
end

function Keybinds:add_new(key, clbk_function)
	if not key or not clbk_function then return end
	key = string.lower(key)
	if type(clbk_function) == "function" and not self.keybinds_list[key] then
		self.keybinds_list[key] = clbk_function
	end
end

function Keybinds:add_new_cmd(key, clbk_function)
	if not key or not clbk_function then return end
	key = string.lower(key)
	if type(clbk_function) == "function" and not self.cmd_list[key] then
		self.cmd_list[key] = clbk_function
	end
end

function Keybinds:_setup_simple_keybinds()
	for key, clbk_function in pairs(self.keybinds_list) do
		if self.keyboard then
			self.keyboard:add_trigger(Idstring(key), function()
			if managers.hud and managers.hud._chat_focus then
				return
			end
			clbk_function()
			end)
		end		
	end
end

function Keybinds:_setup_cmd_keybinds()
	for key, clbk_function in pairs(self.cmd_list) do
		if self.keyboard and Idstring(key) ~= self.cmd_key then
			self.keyboard:add_trigger(Idstring(key), function()
			if managers.hud and managers.hud._chat_focus then
				return
			end
			if self.keyboard:down(self.cmd_key) then
				clbk_function()
			end
			end)
		end
	end
end

function Keybinds:_setup()
	self.keyboard:clear_triggers(true)
	self:_setup_cmd_keybinds()
	self:_setup_simple_keybinds()
end

