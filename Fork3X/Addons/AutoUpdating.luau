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
	-- The function 
	AdvancedSetup = {
		CustomSyncModuleConnections = function(OriginalValue, IsConflictPossible)
			-- Returns a new function that runs the current setting after execution
			return function(SyncModule)
				local Tool = SyncModule.Tool

				local LoadedValue = Tool.Loaded
				local DescendantCount = LoadedValue.DescendantCount
				local DescendantCounter = DescendantCount.DescendantCounter
				
				DescendantCount.Value = 0
				DescendantCounter.Enabled = false
				
				local AssetService = game:GetService("AssetService")
				
				local function IsVersionOutdated(Version)
					-- Returns whether the given version of Building Tools is out of date

					-- Check most recent version number
					local AssetInfo = game:GetService('MarketplaceService'):GetProductInfoAsync(74515839665793, Enum.InfoType.Asset);
					local LatestMajorVersion, LatestMinorVersion, LatestPatchVersion, LatestHotfix = AssetInfo.Description:match '%[Version: ([0-9]+)%.([0-9]+)%.([0-9]+)%.([0-9]+)%]';
					local CurrentMajorVersion, CurrentMinorVersion, CurrentPatchVersion, CurrentHotfix = Version:match '([0-9]+)%.([0-9]+)%.([0-9]+)%.([0-9]+)';

					if not CurrentMajorVersion then
						CurrentMajorVersion, CurrentMinorVersion, CurrentPatchVersion = Version:match '([0-9]+)%.([0-9]+)%.([0-9]+)';
					end

					-- Convert version data into numbers
					local LatestMajorVersion, LatestMinorVersion, LatestPatchVersion, LatestHotfix =
						tonumber(LatestMajorVersion), tonumber(LatestMinorVersion), tonumber(LatestPatchVersion), tonumber(LatestHotfix);
					local CurrentMajorVersion, CurrentMinorVersion, CurrentPatchVersion, CurrentHotfix =
						tonumber(CurrentMajorVersion), tonumber(CurrentMinorVersion), tonumber(CurrentPatchVersion), tonumber(CurrentHotfix) or 0;

					-- Determine whether current version is outdated
					if LatestMajorVersion > CurrentMajorVersion then
						return true;
					elseif LatestMajorVersion == CurrentMajorVersion then
						if LatestMinorVersion > CurrentMinorVersion then
							return true;
						elseif LatestMinorVersion == CurrentMinorVersion then
							if LatestPatchVersion > CurrentPatchVersion then
								return true
							elseif LatestPatchVersion == CurrentPatchVersion then
								return LatestHotfix > CurrentHotfix;
							end
						end;
					end;

					-- Return an up-to-date status if not oudated
					return false;

				end;
				
				-- Ensure tool mode is enabled, auto-updating is enabled, and version is outdated
				if not (Tool:IsA 'Tool' and IsVersionOutdated(Tool.Version.Value)) then
					
					DescendantCount.Value = 0
					DescendantCounter.Enabled = true
					
					OriginalValue(SyncModule)
					
					return;
				end;

				-- Use module to insert latest tool
				local Success, NewTool = pcall(AssetService.LoadAssetAsync, AssetService, 74515839665793)

				if not Success then
					if NewTool == "User is not authorized to access Asset." then
						warn([[Fork3X tried to update to the latest version, but the owner doesn't own the asset nor have enabled Allow Loading Third Party Assets in the game!
		
						If you don't want Fork3X to trigger this warning, set the value of AutoUpdate to false.]])
					end
					
					DescendantCount.Value = 0
					DescendantCounter.Enabled = true
					
					OriginalValue(SyncModule)

					return;
				end;

				-- Get latest copy of tool
				--local NewTool = GetLatestTool();
				if NewTool then
					NewTool = NewTool:FindFirstChildOfClass("Tool")
					-- Prevent update attempt loops since fetched version is now cached
					--NewTool.AutoUpdate.Value = false;
					
					-- Cancel replacing current tool if fetched version is the same
					if NewTool.Version.Value == Tool.Version.Value then
						
						DescendantCount.Value = 0
						DescendantCounter.Enabled = true
					
						OriginalValue(SyncModule)
											
						return;
					end;

					-- Detach update script from tool and save old tool parent
					script.Parent = nil;
					Tool.Sandboxed = true

					NewTool.Options:Destroy()
					
					-- If there is the Auto-Updating add-on, destroy it
					local Addons = Tool:FindFirstChild("Addons")
					
					if Addons then
						if Addons:FindFirstChild("AutoUpdating") then
							Addons.AutoUpdating:Destroy()
						end
						
						if #Addons:GetChildren() ~= 0 then
							if NewTool:FindFirstChild("Addons") then
								NewTool.Addons:Destroy()
							end
							
							Addons.Parent = NewTool
						end
					end
					
					Tool.Options.Parent = NewTool

					local Profiles = Tool:FindFirstChild("Profiles")

					if Profiles then
						local ProfilesFolderChildren = Profiles:GetChildren()
						local ProfilesCount = #ProfilesFolderChildren

						for _, Profile in ProfilesFolderChildren do
							if NewTool.Themes:FindFirstChild(Profile.Name) then
								ProfilesCount -= 1
								Profile:Destroy()
							end
						end

						if ProfilesCount ~= 0 then
							Profiles.Parent = NewTool
						end
					end

					local Themes = Tool:FindFirstChild("Themes")

					if Themes then
						for _, Theme in Themes:GetChildren() do
							if not NewTool.Themes:FindFirstChild(Theme.Name) then
								Theme.Parent = NewTool.Themes
							end
						end
					end

					local WhatToKeep = Tool:QueryDescendants(">.FORK3X_Keep")

					for _, Object in WhatToKeep do
						Object.Parent = nil
					end

					-- Remove current tool (delayed to prevent parenting conflicts)
					--task.wait(0.05);
					local Handle = Tool.Handle
					Handle.Parent = nil

					Tool:ClearAllChildren();

					Handle.Parent = Tool
					task.wait(0.05);

					--	NewTool.Sandboxed = false

					for _, Child in NewTool:GetChildren() do
						if Child ~= NewTool.Handle then
							Child.Parent = Tool
						end
					end

					for _, Object in WhatToKeep do
						Object.Parent = Tool
					end

					NewTool:Destroy()

					Tool.Sandboxed = false
				else
					DescendantCount.Value = 0
					DescendantCounter.Enabled = true
					
					OriginalValue(SyncModule)
				end;
			end
		end,
	},
	
	VariableSettings = {}
}

return Addon
