-- BOTS COLLISION FIX
-- PR to lib/units/weapons/raycastweaponbase

local init_original = RaycastWeaponBase.init
local setup_original = RaycastWeaponBase.setup

function RaycastWeaponBase:init(...)
	init_original(self, ...)
	self._bullet_slotmask = self._bullet_slotmask - World:make_slot_mask(16)
end

function RaycastWeaponBase:setup(...)
	setup_original(self, ...)
	self._bullet_slotmask = self._bullet_slotmask - World:make_slot_mask(16)
end