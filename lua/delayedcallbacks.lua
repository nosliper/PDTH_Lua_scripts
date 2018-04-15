-- delayedcallbacks.lua, jetbriant
DelayedCallbacks = DelayedCallbacks or class()
local self = DelayedCallbacks
self.delayed_clbks = {}

function DelayedCallbacks:_add_new(clbk_func, delay)
	if not clbk_func then return end
	delay = delay or 0
	local exec_t = Application:time() + delay
	local clbk_data = {}
	if clbk_func and type(clbk_func) == "function" then
		clbk_data = {
			["clbk_func"] = clbk_func,
			["exec_t"] = exec_t
		}
		local i = #self.delayed_clbks
		while i > 0 and clbk_data.exec_t < self.delayed_clbks[i].exec_t do
			i = i - 1
		end
		table.insert(self.delayed_clbks, (i + 1), clbk_data)
	end
end

function DelayedCallbacks:add_new(clbk_func, delay, times)
	times = times or 1
	times = math.floor(times)
	if type(times) == "number" then
		for i = 1, times do
			self:_add_new(clbk_func, delay * i)
		end
	end
end

function DelayedCallbacks:_process_delayed_clbks()
	for index, clbk in pairs(self.delayed_clbks) do
		if clbk.clbk_func and clbk.exec_t <= Application:time() then
			local callback_function = clbk.clbk_func
			callback_function()
			table.remove(self.delayed_clbks, index)
		end
	end
end
