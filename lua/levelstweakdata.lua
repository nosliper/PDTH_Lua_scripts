if LevelsTweakData then
	local call_orig_init = LevelsTweakData.init
	function LevelsTweakData:init()
		call_orig_init(self)
		self.bridge.environment_effects = {
			-- "rain",
			-- "raindrop_screen",
			"lightning"
		}
	end
end

-- currently inative