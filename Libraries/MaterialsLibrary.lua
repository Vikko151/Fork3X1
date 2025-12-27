local Tool = script.Parent.Parent
local IsPlugin = Tool.Parent:IsA("Plugin") and true or false

local UsesNewMaterials = game.MaterialService:GetAttribute("UsesNewMaterials") or true					-- We'll proceed that way because letting us access Use2022Materials is a pain for Roadblocks.

local MaterialsDecal = {
	["SmoothPlastic"] = 0;
	["Brick"] = UsesNewMaterials and 9920482813 or 7546648254;
	["Cobblestone"] = UsesNewMaterials and 9919718991 or 7546651802;
	["Concrete"] = UsesNewMaterials and 9920484153 or 7546653328;
	["Corroded Metal"] = UsesNewMaterials and 9920589327 or 7547183598;
	["Diamond Plate"] = UsesNewMaterials and 10237720195 or 7546654401;
	["Fabric"] = UsesNewMaterials and 9920517696 or 7547100606;
	["Foil"] = UsesNewMaterials and 9466552117 or 7546644642;
	["Granite"] = UsesNewMaterials and 9920550238 or 7547164400;
	["Grass"] = UsesNewMaterials and 9920551868 or 7547167347;
	["Ice"] = UsesNewMaterials and 9920555943 or 7546644642;
	["Marble"] = UsesNewMaterials and 9439430596 or 7547174345;
	["Metal"] = UsesNewMaterials and 9920574687 or 7547178395;
	["Pebble"] = UsesNewMaterials and 9920581082 or 7547291174;
	["Sand"] = UsesNewMaterials and 9920591683 or 7547294684;
	["Slate"] = UsesNewMaterials and 9920599782 or 7547297050;
	["Wood"] = UsesNewMaterials and 9920625290 or 7547190453;
	["Wood Planks"] = UsesNewMaterials and 9920626778 or 7547301709;
	["Glass"] = 9438868521;
	["Asphalt"] = UsesNewMaterials and 9930003046 or 7547349715;
	["Basalt"] = UsesNewMaterials and 9920482056 or 7551975939;
	["Cracked Lava"] = UsesNewMaterials and 9920484943 or 7551980711;
	["Glacier"] = UsesNewMaterials and 	9920518732 or 7547646888;
	["Ground"] = UsesNewMaterials and 9920554482 or 7547348623;
	["Leafy Grass"] = UsesNewMaterials and 9920557906 or 7546663659;
	["Limestone"] = UsesNewMaterials and 9920561437 or 7547206319;
	["Mud"] = UsesNewMaterials and 9920578473 or 7551972606;
	["Pavement"] = UsesNewMaterials and 9920579943 or 7547678151;
	["Rock"] = UsesNewMaterials and 9920587470 or 7546659890;
	["Salt"] = UsesNewMaterials and 9920590225 or 7546666647;
	["Sandstone"] = UsesNewMaterials and 9920596120 or 7547202858;
	["Snow"] = UsesNewMaterials and 9920620284 or 7547315875;
	["Cardboard"] = 14108651729;
	["Carpet"] = 14108662587;
	["Ceramic Tiles"] = 17429425079;
	["Clay Roof Tiles"] = 18147681935;
	["Leather"] = 14108670073;
	["Roof Shingles"] = 119722544879522;
	["Plaster"] = 14108671255;
	["Rubber"] = 14108673018;
}

for _, MaterialVariant in game:GetService("MaterialService"):GetDescendants() do
	if MaterialVariant:IsA("MaterialVariant") then
		if MaterialVariant:GetAttribute("ColorMap") then
			MaterialsDecal[MaterialVariant.Name] = MaterialVariant:GetAttribute("ColorMap")
		elseif IsPlugin then
			MaterialsDecal[MaterialVariant.Name] = MaterialVariant.ColorMap
		end
	end
end

return MaterialsDecal