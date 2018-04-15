-- playerslistmenu.lua, jetbriant

if not PlayersListMenu then
	if not jino_mainMenu then return end
	PlayersListMenu = PlayersListMenu or class()
	local self = PlayersListMenu
	self.menu_players_list = {}
	--self.peers_str = " "
	-- ACTIONS:
	function PlayersListMenu:_action_tase(peer)
		if not peer:id() then return end
		local name = managers.criminals:character_name_by_peer_id(peer:id())
		local peer_unit = managers.criminals:character_unit_by_name(name)
		if alive(peer_unit) then
			managers.network:session():send_to_peers_synched("sync_player_movement_state", peer_unit, "tased", peer_unit:character_damage():down_time(), peer_unit:id())
			peer_unit:movement():sync_movement_state("tased", peer_unit:character_damage():down_time())
			peer_unit:network():send_to_unit( { "sync_player_movement_state", peer_unit, "tased", 0, peer_unit:id() } )
		end
		local message = "player " .. peer:name() .. " is set to be tased!"
		ShowHint( message:upper(), 3)
	end
	function PlayersListMenu:_action_disconnect(peer)
		if not peer:id() then return end
		if Network then
			managers.network:session():on_peer_lost(peer, peer:id())
		end
		local message = "player " .. peer:name() .. " got disconnected from you!"
		ShowHint(message:upper(), 3)
	end
	-- OPTIONS:
	function PlayersListMenu:_set_option_tase(peer, submenu_peer)
		local tase = function() return end
		if peer then
			tase = function() return self:_action_tase(peer) end
		end
		menu_addToTable(submenu_peer, "Tase", tase)
	end
	
	function PlayersListMenu:_set_option_disconnect(peer, submenu_peer)
		local disconnect = function() return end
		if peer then
			disconnect = function() return self:_action_disconnect(peer) end
		end
		menu_addToTable(submenu_peer, "Force disconnect", disconnect)
	end
	
----------------------------------------------	
	function PlayersListMenu:set_options(peer, submenu_peer)
		self:_set_option_disconnect(peer, submenu_peer)
		self:_set_option_tase(peer, submenu_peer)
	end
	
	function PlayersListMenu:setup_submenus()
		if Network and managers and managers.network then
			for index, peer in pairs(managers.network:session():peers()) do
				local title = peer:name()
				local submenu_peer = {}
				menu_addToTable(self.menu_players_list, title, submenu_peer, nil, index)
				self:set_options(peer, submenu_peer)
			end
		end
	end
	
	function PlayersListMenu:clear_submenus()
		for id, entry in pairs(self.menu_players_list) do
			self.menu_players_list[id] = nil
			table.remove(self.menu_players_list, id)
		end
	end
	
	function PlayersListMenu:update()
		if Network and managers.network and managers.network:session() then
			if not managers.network:session():peers() then return end
			--[[
			local p_str = ""
			for _, peer in pairs(managers.network:session():peers()) do
				p_str = p_str .. peer:name()
			end
			--]]
			if Input:keyboard():pressed(Keybinds:get_keycode("num3")) then --self.peers_str ~= p_str then
				self:clear_submenus()
				self:setup_submenus()
				--self.peers_str = p_str
			end
		end
	end
	menu_addToMenu(jino_mainMenu, "Players", self.menu_players_list)
end