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
				['Export'] = function (SyncModule, Parts)
					-- Serializes, exports, and returns ID for importing given parts
					
					-- Get RunService to determine if the action must be done on the server side
					local RunService = game:GetService("RunService")
					
					-- Offload action to server-side if API is running locally
					if RunService:IsClient() and not RunService:IsStudio() then
						return SyncModule.SyncAPI.ServerEndpoint:InvokeServer('Export', Parts);
					end;
					
					local HttpService = game:GetService("HttpService")
					
					-- Ensure valid selection
					assert(type(Parts) == 'table', 'Invalid item table');

					-- Ensure there are items to export
					if #Parts == 0 then
						return;
					end;

					-- Ensure parts are selectable
					if not SyncModule.CanModifyItems(Parts) then
						return;
					end;

					-- Cache up permissions for all private areas
					local AreaPermissions = SyncModule.Security.GetPermissions(SyncModule.Security.GetSelectionAreas(Parts), SyncModule.Player);

					-- Make sure the player is allowed to access these parts
					if SyncModule.Security.ArePartsViolatingAreas(Parts, SyncModule.Player, true, AreaPermissions) then
						return;
					end;

					-- Get all descendants of the parts
					local Items = SyncModule.Support.CloneTable(Parts);
					for _, Part in pairs(Parts) do
						SyncModule.Support.ConcatTable(Items, Part:GetDescendants());
					end;

					if SyncModule.Options.PreSerialization then
						if SyncModule.Options.PreSerialization(Items, SyncModule.Player) ~= true then
							error("Failed PreSerialization")
						end
					end

					-- After confirming permissions, serialize parts
					local SerializedBuildData = SyncModule.SerializationV3.SerializeModel(Items);

					-- Push serialized data to server
					local Response = HttpService:JSONDecode(
						HttpService:PostAsync(
							'http://f3xteam.com/bt/export',
							HttpService:JSONEncode { data = SerializedBuildData, version = 3, userId = (SyncModule.Player and SyncModule.Player.UserId) },
							Enum.HttpContentType.ApplicationJson,
							true
						)
					);

					-- Return creation ID on success
					if Response.success then
						return Response.id;
					else
						error('Export failed due to server-side error', 2);
					end;

				end;
			}
			
			-- Merge both options together
			for Name, Value in ExtraActions do
				if OriginalValue[Name] and IsConflictPossible then
					warn("[FORK3X - EXPORTING]: The action `" .. Name .. "` in CustomSyncModuleFunctions has already been set by the default Options module or another addon. To avoid conflicts, the addon won't load.\n\nIn order to fix this, you must remove this action in the default Options, or set the Priority attribute to a higher value.")
					return OriginalValue
				end
				
				OriginalValue[Name] = Value
			end

			-- Return the new value
			return OriginalValue
		end,
		
		CustomCoreFunctions = function(OriginalValue, IsConflictPossible)
			-- Create the new functions we want to add
			local NewFunctions = {
				ExportSelection = {
					function(Core)
						-- Exports the selected parts

						-- Get the Roact module
						local Roact = Core.Roact

						-- Make sure that there are items in the selection
						if #Core.Selection.Items == 0 or not Core.Options.CanUseExport then
							return;
						end;

						-- Start an export dialog
						local DialogHandle
						local DialogComponent = require(Core.UIFolder:WaitForChild('ExportDialog'))
						local DialogDismissCallback = function ()
							DialogHandle = Roact.unmount(DialogHandle)
						end
						local DialogElement = Roact.createElement(DialogComponent, {
							Text = 'Uploading selection...';
							OnDismiss = DialogDismissCallback;
						})
						DialogHandle = Roact.mount(DialogElement, Core.UI, 'ExportDialog')

						-- Send the exporting request to the server
						Core.Try(Core.SyncAPI.Invoke, Core.SyncAPI, 'Export', Core.Selection.Items)

							-- Display creation ID on success
							:Then(function (CreationId)
								Roact.update(DialogHandle, Roact.createElement(DialogComponent, {
									Text = 'Your creation\'s ID:<font size="5"><br /></font>\n' ..
									'<font weight="900" size="18">' .. CreationId .. '</font><font size="6"><br /></font>\n' .. 
									'<font weight="400" size="10">Use the code above to import your creation using the plugin in Studio.</font>';
									OnDismiss = DialogDismissCallback;
								}))
								print('[Building Tools by F3X] Uploaded Export:', CreationId);
							end)

							-- Display error messages on failure
							:Catch('Http requests are not enabled', function ()
								Roact.update(DialogHandle, Roact.createElement(DialogComponent, {
									Text = 'Please enable HTTP requests.';
									OnDismiss = DialogDismissCallback;
								}))
							end)
							:Catch('Export failed due to server-side error', function ()
								Roact.update(DialogHandle, Roact.createElement(DialogComponent, {
									Text = 'An error occurred — please try again.';
									OnDismiss = DialogDismissCallback;
								}))
							end)
							:Catch('Post data too large', function ()
								Roact.update(DialogHandle, Roact.createElement(DialogComponent, {
									Text = 'Try splitting up your build.';
									OnDismiss = DialogDismissCallback;
								}))
							end)
							:Catch('Blacklisted content', function ()
								Roact.update(DialogHandle, Roact.createElement(DialogComponent, {
									Text = 'Unable to export.';
									OnDismiss = DialogDismissCallback;
								}))
							end)
							:Catch('Failed PreSerialization', function ()
								Roact.update(DialogHandle, Roact.createElement(DialogComponent, {
									Text = "Your selection has been denied by Fork3X's configuration.";
									OnDismiss = DialogDismissCallback;
								}))
							end)
							:Catch(function (Error, Stack, Attempt)
								Roact.update(DialogHandle, Roact.createElement(DialogComponent, {
									Text = 'An unknown error occurred — please try again.';
									OnDismiss = DialogDismissCallback;
								}))
								warn('❌ [Building Tools by F3X] Failed to export selection', '\n\nError:\n', Error, '\n\nStack:\n', Stack)
							end)
					end,

					{ 'Shift', 'P' },
					game:GetService("RunService"):IsRunning() and { 'Ctrl', 'P' } or nil
				}
			}
			
			-- Merge both options together
			for Name, Value in NewFunctions do
				if OriginalValue[Name] and IsConflictPossible then
					warn("[FORK3X - EXPORTING]: The action `" .. Name .. "` in CustomCoreFunctions has already been set by the default Options module or another addon. To avoid conflicts, the addon won't load.\n\nIn order to fix this, you must remove this action in the default Options, or set the Priority attribute to a higher value.")
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
