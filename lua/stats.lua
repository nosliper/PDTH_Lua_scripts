-- stats.lua, jetbriant

Stats = Stats or class()
local self = Stats
local start_time
local assault_start_time
local space = "        "
local conf = Config.data.stats_line
function Stats:_generate_kills_str()
	local show_shots = conf.accuracy_show_shots
	local show_kpm = conf.show_kills_per_minute
	local show_acc_dp = conf.accuracy_double_precision
	local playtime = start_time and math.floor(Application:time() - start_time)
	
	local stats 	= managers.statistics
	local total		= stats._global.session.killed.total.count
	local headshots	= stats._global.session.killed.total.head_shots
	local specials  = stats:session_total_specials_kills()
	local enemies	= managers.enemy._enemy_data.nr_units
	local shots 	= stats._global.session.shots_fired.total or 0
    local hits  	= stats._global.session.shots_fired.hits  or 0
	local accuracy	= shots > 0 and string.format(show_acc_dp and "%.2f" or "%i", (hits/shots) * 100) .. "%" or "0%"
	local kills_min = (show_kpm and playtime) and string.format("(%.1f k/m)", total/(playtime/60)) or ""
	local kills_str = string.format("Kills: %d/%d/%d %s", total, headshots, specials, kills_min)
	local accuracy_str = show_shots and ("Acc: " .. accuracy .. " (" .. hits .. "/" .. shots .. ")") or "Acc: " .. accuracy
	local enemies_str = conf.show_enemies_nr and string.format("%sEnemies: %d", space, enemies) or ""
	
	local kills_statsline = kills_str .. space .. accuracy_str .. enemies_str
	return kills_statsline
end

function Stats:_generate_time_str()
	local time_str = ""
	local stats = managers.statistics
	if isPlaying() and stats then
		if stats._start_session_time and stats._session_started then
			if not start_time then
				start_time = stats._start_session_time
			end
			time_str = formatTime(Application:time() - start_time)
		end
	else
		start_time = nil
	end
	return time_str
end

function Stats:_generate_assault_str()
	local assault_str = ""
	local state = managers.groupai:state()
	if isPlaying() and state and state._assault_mode then 
		if not assault_start_time then
			assault_start_time = Application:time()
		end
		assault_str = formatTime(Application:time() - assault_start_time)
	else
		assault_start_time = nil
	end
	return assault_str
end

self.res = RenderSettings.resolution
self.workspace = Overlay:newgui():create_screen_workspace()
self.panel = self.workspace:panel({w = self.res.x, h = self.res.y, x = 0, y = 0})

local text_settings = {
	font = "fonts/" .. conf.font or "font_univers_530_medium",
	font_size = conf.font_size or 14,
	color = conf.color or Color.white,
	layer = conf.show_after_ingame and 2 or 1,
	w = self.res.x,
	h = 40,
	align = conf.alignment or "center",
	halign = "center",
	vertical = "center",
	text = "",
	visible = conf.visible or true
}

self.panel:set_w(self.res.x)
self.panel:set_h(self.res.y)

self.stats_text = self.panel:text(text_settings)
self.stats_text:set_center_y(self.res.y - 10)

function Stats:_update_text_pos()
	local sl_x = self.stats_text:center_x()
	local al = conf.alignment or self.stats_text:align()
	local adjust = al == "left" and 30 or (al == "right" and -30 or 0)
	self.stats_text:set_align(al)
	self.stats_text:set_center_x(sl_x + adjust)
end
self:_update_text_pos()

function Stats:_update_text_color(time_str, assault_str)
	local left = time_str:len() + space:len() - 1
	local right = left + assault_str:len() + 1
	local color = conf.color or Color.white
	local alpha = not isPlaying() and 0.5 or 1
	self.stats_text:set_color(color:with_alpha(alpha))
	if assault_start_time then
		self.stats_text:clear_range_color(left, right)
		self.stats_text:set_range_color(left, right, conf.assault_timer_color or Color.red)
	else
		self.stats_text:clear_range_color(left, right)
	end
end

function Stats:update()
	local time_str = self:_generate_time_str()
	local kills_str	= self:_generate_kills_str()
	local assault_str = self:_generate_assault_str()
	local stats_line = time_str .. (time_str ~= "" and space or "") ..
		assault_str .. (assault_str ~= "" and space or "") .. kills_str
	self.stats_text:set_text(stats_line)
	self:_update_text_color(time_str, assault_str)
end