require "lua/keybindsetup.lua"
Config = Config or class()
local self = Config
local colors = {
	"FFFFFF", -- 1: white
	"000000", -- 2: black
	"DB2C5A", -- 3: pink
	"6A0375", -- 4: purple
	"FF0000"  -- 5: red
}
self.data = {
	chat_height 			  = 2.5,
	chat_width 				  = 2.5,
	melee_shake_effect 	  	  = false,
	blank_forum_link 		  = true,
	auto_skip_to_main_menu 	  = true,
	auto_skip_intro 		  = true,
	show_challenges_completed = true,
	ingame_notes_public		  = false,
	hide_name_labels_ADS	  = true
}
self.data.stats_line = {
	visible 				  = true,
	alignment 				  = "center",
	font 					  = "font_univers_530_medium",
	font_size 				  = 14,
	color 					  = Color.white,
	assault_timer_color 	  = Color.red,
	accuracy_show_shots   	  = true,
	show_enemies_nr			  = true,
	show_kills_per_minute	  = true,
	accuracy_double_precision = true,
	show_after_ingame 		  = true,
	refresh_rate 			  = 0.1
}