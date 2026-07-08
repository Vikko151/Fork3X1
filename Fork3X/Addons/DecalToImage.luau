--[[
==============================
NOTE ABOUT FORK3X ADD-ONS
==============================

At the time being, a Fork3X addon is just a module that modifies the options module in order to enhance people's experience

They're meant for NOTHING ELSE. Any setting in Advanced Setup must only return a new value.

MAKE SURE the add-on you're currently using has the Sandboxed property set to "true" and solely has the "Basic" capability on. If this is not the case, it may be a virus!
]]

local Addon = {
	-- Put the name of the settings
	-- You mustn't put them in their categories, else the addon won't work!

	-- This erases the given settings
	Erase = {},

	-- You can use this to assemble settings together
	-- The function gives the current  
	AdvancedSetup = {
		CustomSyncModuleFunctions = function(OriginalValue, IsConflictPossible)
			-- Create the new actions we want to add
			local ExtraActions = {
				['ExtractImageFromDecal'] = function (SyncModule, DecalAssetId)
					-- Returns the first image found in the given decal asset
					
					-- Get RunService to determine if the action must be done on the server side
					local RunService = game:GetService("RunService")
					
					-- Offload action to server-side if API is running locally
					if RunService:IsClient() and not RunService:IsStudio() then
						return SyncModule.SyncAPI.ServerEndpoint:InvokeServer('ExtractImageFromDecal', DecalAssetId);
					end;
					
					local AssetService = game:GetService("AssetService")
					
					local FinalID = tonumber(DecalAssetId)

					if not FinalID then
						return DecalAssetId
					end

					local InsertedDecal = AssetService:LoadAssetAsync(FinalID)

					if #InsertedDecal:GetChildren() == 1 and InsertedDecal:FindFirstChildOfClass("Decal") then

						FinalID = tonumber(InsertedDecal:FindFirstChildOfClass("Decal").Texture:lower():match("%d+"))

					end

					InsertedDecal:Destroy()

					return FinalID
				end;
			}
			
			-- Merge both options together
			for Name, Value in ExtraActions do
				if OriginalValue[Name] and IsConflictPossible then
					warn("[FORK3X - DECALTOIMAGE]: The action `" .. Name .. "` has already been set by the default Options module or another addon. To avoid conflicts, the addon won't load.\n\nIn order to fix this, you must remove this action in the default Options, or set the Priority attribute to a higher value.")
					return OriginalValue
				end
				
				OriginalValue[Name] = Value
			end

			-- Return the new value
			return OriginalValue
		end,
	},
	
	VariableSettings = {}
}

return Addon
