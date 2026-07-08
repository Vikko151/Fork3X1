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
				["SearchAsset"] = function(SyncModule, Type, Input, Page, Settings)

					local Results

					--> Detect if the keyword arg is an ID, and if so, load only that audio instead:

					--> Request songs list from proxy server:
					if Settings.UseHttp == false then
						if Type == "Decal" then
							local InsertService = game:GetService("InsertService")
							
							if not Page then
								Page = 1
							end

							local Success, ErrorMessage = pcall(function()
								Results = SyncModule.Options.CheckDecalResult(InsertService:GetFreeDecalsAsync(Input, Page)[1].Results, Settings)
							end)

							if ErrorMessage then
								warn(ErrorMessage)
							end
							--		Results = game:GetService("InsertService"):GetFreeDecals(Input, Page)[1].Results
						end

						if not Results then
							return {}, true
						else
							return Results, true, Page + 1
						end
					else
						-- Get HttpService to see if we can send requests
						local HttpService = game:GetService("HttpService")
						
						local URL = string.format("https://apis.roblox.com/toolbox-service/v2/assets:search?searchCategoryType=%s&query=%s&pageNumber=%s&maxPageSize=50", Type, Input, Page)

						local Success, Error = pcall(function()
							Results = HttpService:RequestAsync({Url = URL, Method = "GET", Headers = {
								["x-api-key"] = HttpService:GetSecret(SyncModule.Options.SearchingSecret),
								["Content-Type"] = "application/json"}})--> Get songs from search.roblox.com result
						end)

						if not Success then
							warn(Error)
						end

						if not Results then
							return {}, true
						else
							Results = HttpService:JSONDecode(Results.Body)

							return Results.creatorStoreAssets, true, Results.nextPageToken
						end
					end

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
