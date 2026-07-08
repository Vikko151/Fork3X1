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
			OriginalValue.IsHttpServiceEnabled = function (SyncModule)
				-- Returns whether HttpService is enabled

				-- Get RunService to determine if the action must be done on the server side
				local RunService = game:GetService("RunService")

				-- Offload action to server-side if API is running locally
				if RunService:IsClient() then
					return SyncModule.SyncAPI.ServerEndpoint:InvokeServer('IsHttpServiceEnabled')
				end

				-- Get HttpService to see if we can send requests
				local HttpService = game:GetService("HttpService")
				
				-- Just return HttpService.HttpEnabled
				return HttpService.HttpEnabled
			end;

			-- Return the new value
			return OriginalValue
		end,
		
		CustomCoreConnections = function(OriginalValue)
			return function(Core)
				local IsHttpServiceDisabled = (Core.Mode == 'Tool') and
					not Core.SyncAPI:Invoke('IsHttpServiceEnabled')
				if Core.Options.ShowHttpRequestsWarning == true and Core.Options.EnableAPIs ~= true and Core.AddNotification then
					Core.AddNotification:Fire({
						ThemeColor = Color3.fromRGB(255, 0, 4);
						NoticeText = 'HTTP requests must be <b>enabled</b> for some features of Building Tools to work, including exporting.';
						DetailText = 'Own this place? Edit it in Studio, and toggle on\nHOME > <b>Experience Settings</b> > Security > <b>Allow HTTP Requests</b> :-)';
					})
				end
				
				OriginalValue(Core)
			end
		end,
	},
	
	VariableSettings = {}
}

return Addon
