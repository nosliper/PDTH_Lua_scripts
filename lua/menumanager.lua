-- ADD MENU ITEMS

core:import("CoreMenuNode")
core:import("CoreMenuData")
core:import("CoreMenuLogic")
local orig_init = MenuManager.init
function MenuManager:init(...)
	orig_init(self, ...)
	-- register custom mods menu
	for _, v in pairs({"menu_main", "menu_pause", "menu_gameover", "lobby_menu", "kit_menu", "menu_dialog_options"}) do
		local menu = self._registered_menus[v]
		if menu then
			local nodes = menu.logic._data._nodes
			self:modify_menu_nodes(v, menu, nodes)
		end
	end
end

function MenuManager:insert_menu_item(nodes, node_names, insert_location, item_data, item_params)
	local inserted_item = false
	
	-- allow for multiple insertions at the same time
	local n = #item_data
	local items_to_insert = {}
	if n > 1 and n == table.size(item_data) then
		for _, idata in ipairs(item_data) do
			if idata.data and not idata.name then
				table.insert(items_to_insert, idata)
			else
				table.insert(items_to_insert, { data = idata })
			end
		end
	else
		table.insert(items_to_insert, { data = item_data })
	end
	
	local nodes_to_modify = {}
	if not node_names then
		nodes_to_modify = { nodes }
	else
		node_names = type(node_names) == 'table' and node_names or { node_names }
		for _, node_name in ipairs(node_names) do
			local node = nodes[node_name]
			if node then
				table.insert(nodes_to_modify, node)
			end
		end
	end
	
	for _, node in pairs(nodes_to_modify) do
		local insert_t, insert_at = type(insert_location)
		if not insert_location then
			insert_at = #node:items()
		elseif insert_t == "number" then
			insert_at = insert_location
		else
			local index_addition, item_name = 0
			if insert_t == "table" then
				if insert_location.after then
					item_name, index_addition = insert_location.after, 1
				elseif insert_location.before then
					item_name, index_addition = insert_location.before, 0
				end
			elseif insert_t == "string" then
				item_name, index_addition = insert_location, 1
			end
			
			if item_name then
				for i, item in ipairs(node:items()) do
					if item:name() == item_name then
						insert_at = i + index_addition
						break
					end
				end
			end
		end
		
		if insert_at then
			for i, citem in ipairs(items_to_insert) do
				local citem_data = citem.data
				local citem_params = citem.params or item_params
				
				citem_data._meta = citem_data._meta or "item"
				if citem_data._params then
					citem_params = table.merge(citem_params, citem_data._params)
					citem_data._params = nil
				end
				if citem_data.type and (not citem_params or not citem_params.type) then
					citem_params = citem_params or item_params or {}
					citem_params.type = citem_data.type
				end
				local new_item = node:create_item(citem_params, citem_data)
				
				-- copy some actions from the insert method in the node class
				new_item.dirty_callback = callback(node, node, "item_dirty")
				if node.callback_handler then
					new_item:set_callback_handler(node.callback_handler)
				end
				
				table.insert(node:items(), insert_at + (i - 1), new_item)
			end
			inserted_item = true
			break
		end
	end
	
	return inserted_item
end

function MenuManager:update_menu_item(nodes, node_names, item_name, params)
	local updated_items
	node_names = type(node_names) == 'table' and node_names or { node_names }
	for _, node_name in ipairs(node_names) do
		local node = nodes[node_name]
		if node then
			local items
			if item_name ~= true then
				if type(item_name) == "string" then
					items = { node:item(item_name) }
				elseif type(item_name) == "table" then
					if item_name.name then
						items = { item_name }
					else
						for _,item in pairs(node:items()) do
							for k,v in pairs(item_name) do
								if item:name() == v then
									table.insert(items, item)
								end
							end
						end
					end
				else
					items = {}
				end
			else
				items = node:items()
			end
			
			for _, item in pairs(items) do
				if item then
					-- there is no update method, so repeat everything that's done in the init method
					if params.visible_callback ~= nil then
						if params.visible_callback then
							item._visible_callback_name_list = string.split(params.visible_callback, " ")
						else
							item._visible_callback_name_list = nil
						end
						
						if item._visible_callback_name_list and item._callback_handler then
							item._visible_callback_list = {}
							for _, visible_callback_name in pairs(item._visible_callback_name_list) do
								table.insert(item._visible_callback_list, callback(item._callback_handler, item._callback_handler, visible_callback_name))
							end
						end
					end

					if params.enabled_callback ~= nil then
						if params.enabled_callback then
							item._enabled_callback_name_list = string.split(params.enabled_callback, " ")
						else
							item._enabled_callback_name_list = nil
						end
						
						item:set_enabled(true)
						if item._enabled_callback_name_list and item._callback_handler then
							for _, enabled_callback_name in pairs(item._enabled_callback_name_list) do
								if not item._callback_handler[enabled_callback_name](item) then
									item:set_enabled(false)
								end
							end
						end
					end

					if params.callback ~= nil then
						if params.callback then
							params.callback_name = string.split(params.callback, " ")
							params.callback = {}
							
							if item._callback_handler then
								for _, callback_name in pairs(item._parameters.callback_name) do
									table.insert(item._parameters.callback, callback(item._callback_handler, item._callback_handler, callback_name))
								end
							end
						else
							params.callback_name = {}
							params.callback = {}
						end
					end
				
					for name, value in pairs(params) do
						item:set_parameter(name, value)
					end
					
					item:dirty()
					
					updated_items = updated_items or {}
					updated_items[node_name] = updated_items[node_name] or {}
					table.insert(updated_items[node_name], item)
				end
			end
		end
	end
	return updated_items
end

function MenuManager:insert_menu_node(menu, item_data, set_default)
	if item_data.name then
		local nodes = menu and menu.logic._data._nodes
		if nodes and not nodes[item_data.name] then -- do not override
			local node_class = CoreMenuNode.MenuNode
			local node_type = item_data.type
			if node_type then
				node_class = CoreSerialize.string_to_classtable(node_type)
			end

			item_data._meta = item_data._meta or "node"
			local new_node = node_class:new(item_data)
			nodes[item_data.name] = new_node
			
			-- weird things happen if there's no callback handler; afaik it's always the same as the menus
			if new_node and not new_node._callback_handler then
				new_node:set_callback_handler(menu.callback_handler)
			end
			
			if set_default then
				menu.logic._data._default_node_name = item_data.name
			end
			
			if node_type == "MenuNodeTable" and item_data.columns then
				for _, column in ipairs(item_data.columns) do
					new_node:_add_column(column)
				end
			
				new_node:parameters().total_proportions = 0
				for _, data in pairs(new_node:columns()) do
					new_node:parameters().total_proportions = new_node:parameters().total_proportions + data.proportions
				end
			end
			
			return new_node
		end
	else
		Application:error("Menu node without name in '" .. module:id() .. "'")
	end
end

function MenuManager:sort_items(node)
	if node and node:items() then
		table.sort(node:items(), function(a, b)
			local a_params, b_params = a:parameters(), b:parameters()
			local a_priority, b_priority = (a_params.priority or 0), (b_params.priority or 0)
			if a_priority > b_priority then
				return true
			elseif a_priority < b_priority then
				return false
			else
				return a_params.text_id < b_params.text_id
			end
		end)
	end
	
	return node
end

------------------------MAKE CHANGES HERE--------------------------------

function MenuManager:modify_menu_nodes(menu_name, menu, nodes)
	if menu_name == "menu_pause" then

		-- FORCE DISCONNECT
		self:insert_menu_node(menu, {
			_meta = "node",
			name = "menu_force_disconnect",
			topic_id = "menu_force_disconnect",
			modifier = "ForceDisconnect",
			stencil_image = "bg_lobby_fullteam",
			stencil_align = "manual",
			stencil_align_percent = "65",
			use_info_rect = "false",
			align_line = "0.75",
		})
		self:insert_menu_item(nodes, { "main", "pause" }, { after = "kick_player" }, { 
			_meta = "item",
			name = "menu_force_disconnect",
			next_node = "menu_force_disconnect",
			visible_callback = "is_multiplayer",
			text_id = "menu_force_disconnect",
			help_id = nil,
		})

		-- PLAYERS LIST
		self:insert_menu_node(menu, {
			_meta = "node",
			name = "menu_players_list",
			topic_id = "menu_players_list",
			modifier = "PlayersList",
			stencil_image = "bg_lobby_fullteam",
			stencil_align = "manual",
			stencil_align_percent = "65",
			use_info_rect = "false",
			align_line = "0.75",
		})
		self:insert_menu_item(nodes, { "main", "pause" }, { after = "kick_player" }, { 
			_meta = "item",
			name = "menu_players_list",
			next_node = "menu_players_list",
			visible_callback = "is_multiplayer",
			text_id = "menu_players_list",
			help_id = nil,
		})
	end
end

ForceDisconnect = ForceDisconnect or class()

function ForceDisconnect:modify_node(node)
	local new_node = deep_clone(node)
	if managers.network:session() then
		for _, peer in pairs(managers.network:session():peers()) do
			local new_item = node:create_item(nil, {
				name = peer:name(),
				text_id = peer:name(),
				callback = "_force_disconnect",
				localize = "false",
				rpc = peer:rpc(),
				peer = peer
			})
			new_node:add_item(new_item)
		end
	end
	managers.menu:add_back_button(new_node)
	return new_node
end

function MenuCallbackHandler:_force_disconnect(item)
	local peer = item:parameters().peer
	managers.network:session():on_peer_lost(peer, peer:id())
	managers.menu:back()
end

PlayersList = PlayersList or class()

function PlayersList:modify_node(node)
	local new_node = deep_clone(node)
	if managers.network:session() then
		for _, peer in pairs(managers.network:session():peers()) do
			if peer:synched() then
				local new_item = node:create_item(nil, {
					name = peer:name(),
					text_id = peer:name(),
					callback = "menu_players_list_callback",
					localize = "false",
					rpc = peer:rpc(),
					peer = peer
				})
				new_node:add_item(new_item)
			end
		end
	end
	
	managers.menu:add_back_button(new_node)
	return new_node
end

function MenuCallbackHandler:menu_players_list_callback(item)
	managers.menu:back(true)
	
	local peer = item:parameters().peer
	local peer_id = item:parameters().peer:id()
	local name = managers.criminals:character_name_by_peer_id(peer_id)
	local player_unit = managers.criminals:character_unit_by_name(name)
	
	-- DIALOG STYLE MENU:
	local dialog_data = {}
	dialog_data.title = managers.localization:text("dialog_mp_players_actions")
	dialog_data.text = managers.localization:text("dialog_mp_players_actions_msg", {
		PLAYER = item:parameters().peer:name()
	})
	-- BUTTONS:
	
	local button_cancel = {}
	button_cancel.text = managers.localization:text("dialog_mp_players_cancel")
	button_cancel.cancel_button = true
	
	local button_cloak = {}
	button_cloak.text = managers.localization:text("dialog_mp_players_cloak")
	function button_cloak.callback_func()
		if Network:is_server() and player_unit and alive(player_unit) then
			local position = player_unit:position()
			local rotation = Rotation(player_unit:movement():m_head_rot():yaw(),0,0)
			local unit = 'units/characters/enemies/spooc/spooc'
			World:spawn_unit( Idstring(unit), position, rotation )
		end
		managers.menu:back(true)
	end
	
	local button_overdoze = {}
	button_overdoze.text = managers.localization:text("dialog_mp_players_overdoze")
	function button_overdoze.callback_func()
		if Network:is_server() and player_unit and alive(player_unit) then
			local position = player_unit:position()
			local rotation = Rotation(player_unit:movement():m_head_rot():yaw(),0,0)
			local unit = 'units/characters/enemies/tank/tank'
			World:spawn_unit( Idstring(unit), position, rotation )
		end
		managers.menu:back(true)
	end
	
	local button_tase = {}
	button_tase.text = managers.localization:text("dialog_mp_players_tase")
	function button_tase.callback_func()
		if player_unit and alive(player_unit) then
			managers.network:session():send_to_peers_synched("sync_player_movement_state", player_unit, "tased", player_unit:character_damage():down_time(), player_unit:id())
			player_unit:movement():sync_movement_state("tased", player_unit:character_damage():down_time())
			player_unit:network():send_to_unit( { "sync_player_movement_state", player_unit, "tased", 0, player_unit:id() } )
			
			DelayedCallbacks:add_new(function()
				if player_unit and alive(player_unit) then
					managers.network:session():send_to_peers_synched("sync_player_movement_state", player_unit, "standard", player_unit:character_damage():down_time(), player_unit:id())
					player_unit:movement():sync_movement_state("standard", player_unit:character_damage():down_time())
				end
			end, 9, 1)
		end
		managers.menu:back(true)
	end
	
	local button_tase_100 = {}
	button_tase_100.text = managers.localization:text("dialog_mp_players_tase_100")
	function button_tase_100.callback_func()
		if player_unit and alive(player_unit) then
			managers.network:session():send_to_peers_synched("sync_player_movement_state", player_unit, "tased", player_unit:character_damage():down_time(), player_unit:id())
			player_unit:movement():sync_movement_state("tased", player_unit:character_damage():down_time())
			player_unit:network():send_to_unit( { "sync_player_movement_state", player_unit, "tased", 0, player_unit:id() } )
		
			DelayedCallbacks:add_new(function()
				if player_unit and alive(player_unit) then
					managers.network:session():send_to_peers_synched("sync_player_movement_state", player_unit, "standard", player_unit:character_damage():down_time(), player_unit:id())
					player_unit:movement():sync_movement_state("standard", player_unit:character_damage():down_time())
					managers.network:session():send_to_peers_synched("sync_player_movement_state", player_unit, "tased", player_unit:character_damage():down_time(), player_unit:id())
					player_unit:movement():sync_movement_state("tased", player_unit:character_damage():down_time())
					player_unit:network():send_to_unit( { "sync_player_movement_state", player_unit, "tased", 0, player_unit:id() } )
				end
			end, 9, 100)
		end
		managers.menu:back(true)
	end
	
	local button_jail = {}
	button_jail.text = managers.localization:text("dialog_mp_players_jail")
	function button_jail.callback_func()
		if Network:is_server() and player_unit and alive(player_unit) then
			player_unit:network():send("sync_player_movement_state", "dead", 0, peer_id)
			player_unit:network():send_to_unit({"spawn_dropin_penalty", true, nil, 0, nil, nil })
			managers.groupai:state():on_player_criminal_death(peer_id)
		end
		managers.menu:back(true)
	end
	
	--ADDING BUTTONS TO BUTTON LIST:
	dialog_data.button_list = {
		button_tase,
		button_tase_100,
		button_cloak,
		button_overdoze,
		button_jail,
	}
	table.insert(dialog_data.button_list, button_cancel)
	
	--SHOWING THE MENU:
	managers.system_menu:show(dialog_data)
	
	managers.menu:back(true)
end