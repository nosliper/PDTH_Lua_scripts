-- Usage: HTTP:add_request(peer:user_id())

HTTP = HTTP or class()
HTTP.api_key = "YOURKEYHERE"
HTTP.list = {}

function HTTP:callback_playtime(id, success, data)
	local name = Steam:username(id)
	local text = ""
	if success then
		data = JSON:decode(data)
		local collection = data and data.response
		if collection then
			if collection.games then
				for _, game in ipairs(collection.games) do
					if game.playtime_forever then
						text = name .. " has (" .. tostring(math.floor(game.playtime_forever / 60)) .. ") hrs."
					end
				end
			else
				text = name .. " has a private profile." -- or friends-only
			end
		end
	else
		text = "Playtime request failed for player (" .. name .. ")."
	end
	
	DarkUtils:chat_local(nil, text) -- use your equivalent
	
	self:remove_request()
end

function HTTP:request_playtime(id)
	local url = "https://api.steampowered.com/IPlayerService/GetOwnedGames/v1/?key=" .. self.api_key .. "&format=json&steamid=" .. id .. "&appids_filter[0]=24240"
	Steam:http_request(url, callback(self, self, "callback_playtime", id))
end

function HTTP:add_request(id)
	table.insert(self.list, id)
end

function HTTP:remove_request()
	table.remove(self.list, next(self.list))
	self._working = false
end

function HTTP:update() -- call it in GameSetup:update()
	if next(self.list) and not self._working then 
		self._working = true
		self:request_playtime(self.list[1])
	end
end
