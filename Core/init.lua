--!optimize 2
--!native

local Core = {}
Core.Tool = script.Parent;
Core.Plugin = (Core.Tool.Parent:IsA 'Plugin') and Core.Tool.Parent or nil

-- Detect mode
Core.Mode = Core.Plugin and 'Plugin' or 'Tool';

-- Load tool completely
local Indicator = Core.Tool:WaitForChild 'Loaded';
while not Indicator.Value do
	Indicator.Changed:Wait();
end;

-- Modules
Core.Security = require(script.Security)
Core.History = require(script.History)
Core.Selection = require(script.Selection)
Core.Targeting = require(script.Targeting)

Core.Profiles = Core.Tool:WaitForChild("Profiles", 0.1)
Core.Tools = Core.Tool:WaitForChild("Tools")
Core.Libraries = Core.Tool:WaitForChild("Libraries")
Core.UIFolder = Core.Tool:WaitForChild("UI")
Core.Interfaces = Core.Tool:WaitForChild("Interfaces")
Core.Sounds = Core.Tool:WaitForChild("Sounds")

-- Libraries
Core.Signal = require(Core.Libraries.Signal)
Core.Support = require(Core.Libraries.SupportLibrary)
Core.Try = require(Core.Libraries.Try)
Core.Make = require(Core.Libraries.Make)
local Roact = require(Core.Tool.Vendor:WaitForChild 'Roact')
local Maid = require(Core.Libraries:WaitForChild 'Maid')
local Cryo = require(Core.Libraries:WaitForChild('Cryo'))

-- References
Core.Services = Core.Support.ImportServices();
Core.SyncAPI = Core.Tool.SyncAPI;
Core.Player = Core.Services.Players.LocalPlayer;
Core.Options = Core.Tool:WaitForChild("Options", 1) and require(Core.Tool.Options)

Core.CurrentProfile = "CementDark"
--Core.CurrentTheme, Core.CurrentToken, Core.CurrentComponents = Core.Options.CheckTheme(Core.Player)

--[[
if not Core.CurrentTheme then
	local SelectedTheme = Core.Tool.Themes:GetChildren()[1]
	
	Core.CurrentTheme, Core.CurrentToken = SelectedTheme:FindFirstChildOfClass("StyleSheet"), SelectedTheme:FindFirstChild("Tokens"):FindFirstChildOfClass("StyleSheet")
end]]

Core.GlobalStyleToken = Instance.new("StyleSheet")
Core.GlobalStyleToken.Parent = script
Core.GlobalStyleToken:SetAttribute("StyleCategory", "Themes")

Core.StyleTokenDerive = Instance.new("StyleDerive")
Core.StyleTokenDerive.Priority = 999
Core.StyleTokenDerive.Parent = Core.GlobalStyleToken

--Core.StyleMaid = Maid.new()
Core.RoactComponents = {}
Core.ComponentsToRevert = {}

Roact.setComponentsTable(Core.RoactComponents)

Core.UseGigsDarkWithPlugin = false

if not Core.Options then
	error("F3X Core failed to load: Options are missing!")
end

local DataStoresEnabled

local RunService = game:GetService('RunService')
local CanClone = true
local WasExplorerOpen = nil

-- Preload assets
Core.Assets = require(Core.Tool:WaitForChild("Assets"))

-- Core events
Core.ToolChanged = Core.Signal.new()
Core.ProfileUpdate = Core.Signal.new()

function Core.EquipTool(Tool)
	-- Equips and switches to the given tool

	if table.find(Core.Options.ToolsBlacklist, Tool.Name) then
		return
	end

	-- Unequip current tool
	if Core.CurrentTool and Core.CurrentTool.Equipped then
		Core.CurrentTool:Unequip();
		Core.CurrentTool.Equipped = false;
	end;

	-- Set `tool` as current
	Core.CurrentTool = Tool;
	Core.CurrentTool.Equipped = true;

	-- Fire relevant events
	Core.ToolChanged:Fire(Tool);

	-- Equip the tool
	Tool:Equip();

end;

function Core.RecolorHandle(Color)
	Core.SyncAPI:Invoke('RecolorHandle', Color);
end;

-- Theme UI to current tool
Core.ToolChanged:Connect(function (Tool)
	Core.GlobalStyleToken:SetAttribute("CurrentToolColor", Tool.Color.Color)
	coroutine.wrap(Core.RecolorHandle)(Tool.Color);
	coroutine.wrap(Core.Selection.RecolorOutlines)(Tool.Color);
end);

-- Core hotkeys
Hotkeys = {};

function Core.AssignHotkey(Hotkey, Callback)
	-- Assigns the given hotkey to `Callback`

	-- Standardize enum-described hotkeys
	if type(Hotkey) == 'userdata' then
		Hotkey = { Hotkey };

		-- Standardize string-described hotkeys
	elseif type(Hotkey) == 'string' then
		Hotkey = { Enum.KeyCode[Hotkey] };

		-- Standardize string table-described hotkeys
	elseif type(Hotkey) == 'table' then
		for Index, Key in ipairs(Hotkey) do
			if type(Key) == 'string' then
				Hotkey[Index] = Enum.KeyCode[Key];
			end;
		end;
	end;

	-- Register the hotkey
	table.insert(Hotkeys, { Keys = Hotkey, Callback = Callback });
end;

function Core.EnableHotkeys()
	-- Begins to listen for hotkey triggering

	-- Listen for pressed keys
	Core.Connections.Hotkeys = Core.Support.AddUserInputListener('Began', 'Keyboard', false, function (Input)
		
		local _PressedKeys = Core.Support.GetListMembers(Core.Services.UserInputService:GetKeysPressed(), 'KeyCode');

		-- Filter out problematic keys
		local PressedKeys = {};
		local FilteredKeys = Core.Support.FlipTable { 'LeftAlt', 'W', 'S', 'A', 'D', 'Space' };
		for _, Key in ipairs(_PressedKeys) do
			if not FilteredKeys[Key.Name] then
				table.insert(PressedKeys, Key);
			end;
		end;

		-- Count pressed keys
		local KeyCount = #PressedKeys;

		-- Prioritize hotkeys based on # of required keys
		table.sort(Hotkeys, function (A, B)
			if #A.Keys > #B.Keys then
				return true;
			end;
		end);

		-- Identify matching hotkeys
		for _, Hotkey in ipairs(Hotkeys) do
			if KeyCount == #Hotkey.Keys then

				-- Get the hotkey's key index
				local Keys = Core.Support.FlipTable(Hotkey.Keys)
				local MatchingKeys = 0;

				-- Check matching pressed keys
				for _, PressedKey in pairs(PressedKeys) do
					if Keys[PressedKey] then
						MatchingKeys = MatchingKeys + 1;
					end;
				end;

				-- Trigger the first matching hotkey's callback
				if MatchingKeys == KeyCount then
					Hotkey.Callback();
					break;
				end;

			end;
		end;
	end);

end;

Core.Enabling = Core.Signal.new()
Core.Disabling = Core.Signal.new()
Core.Enabled = Core.Signal.new()
Core.Disabled = Core.Signal.new()

function Core.Enable(Mouse)

	-- Ensure tool is disabled or disabling, and not already enabling
	if (Core.IsEnabled and not Core.IsDisabling) or Core.IsEnabling then
		return;

		-- If tool is disabling, enable it once fully disabled
	elseif Core.IsDisabling then
		Core.Disabled:Wait();
		return Core.Enable(Mouse);
	end;

	local UILoaded = false

	-- Wait for UI to initialize asynchronously
	UILoaded = Core.InitializeUI()

	-- Indicate that tool is enabling
	Core.IsEnabling = true;
	Core.Enabling:Fire();

	-- Update the core mouse
	Core.Mouse = Mouse;

	-- Use default mouse behavior
	Core.Services.UserInputService.MouseBehavior = Enum.MouseBehavior.Default;

	-- Disable mouse lock in tool mode
	if Core.Mode == 'Tool' then
		coroutine.resume(coroutine.create(function ()
			Core.SyncAPI:Invoke('SetMouseLockEnabled', false)
		end))
	end

	-- Show UI
	Core.UI.Parent = Core.UIContainer;

	-- Display startup notifications
	if not Core.StartupNotificationsDisplayed then
		-- Create a table to add notifications
		Core.Notifications = {}
		Core.NewNotification = Core.Signal.new()

		local NotificationsComponent = require(Core.UIFolder:WaitForChild('Notifications'))
		local NotificationsElement = Roact.createElement(NotificationsComponent, {
			Core = Core;
			Notifications = Core.Notifications
		})
		local NotificationsHandle = Roact.mount(NotificationsElement, Core.UI, 'Notifications')

		Core.NewNotification:Connect(function()
			Roact.update(NotificationsHandle, Roact.createElement(NotificationsComponent, {
				Core = Core;
				Notifications = Cryo.List.join(Core.Notifications);
			}))
		end)

		Core.StartupNotificationsDisplayed = true
	end;

	-- Start systems
	Core.EnableHotkeys();
	Core.Targeting:EnableTargeting()
	Core.Selection.EnableOutlines();
	Core.Selection.EnableBeams();
	Core.Selection.ShowHiddenAttachments();
	Core.Selection.EnableMultiselectionHotkeys();

	-- Open the explorer again if desired
	if WasExplorerOpen == true then
		WasExplorerOpen = false
		-- Defer the task to avoid duplicates
		task.delay(0.2, function()
			Core.OpenExplorer(true)
		end)
	end

	-- Sync studio selection in
	if Core.Mode == 'Plugin' then
		local LastSelectionChangeHandle
		Core.Connections.StudioSelectionListener = Core.Services.SelectionService.SelectionChanged:Connect(function ()
			local SelectionChangeHandle = {}
			LastSelectionChangeHandle = SelectionChangeHandle

			-- Replace selection if it hasn't changed in a heartbeat
			RunService.Heartbeat:Wait()
			if LastSelectionChangeHandle == SelectionChangeHandle then
				Core.Selection.Replace(Core.Services.SelectionService:Get(), false)
			end
		end)
	end

	-- Equip current tool
	Core.EquipTool(Core.CurrentTool or require(Core.Tools.Move));

	-- Indicate that tool is now enabled
	Core.IsEnabled = true;
	Core.IsEnabling = false;
	Core.Enabled:Fire();

end;

function Core.Disable()

	-- Ensure tool is enabled or enabling, and not already disabling
	if (not Core.IsEnabled and not Core.IsEnabling) or Core.IsDisabling then
		return;

		-- If tool is enabling, disable it once fully enabled
	elseif Core.IsEnabling then
		Core.Enabled:Wait();
		return Core.Disable();
	end;

	-- Indicate that tool is now disabling
	Core.IsDisabling = true;
	Core.Disabling:Fire();

	-- Reenable mouse lock option in tool Core.Mode
	if Core.Mode == 'Tool' then
		coroutine.resume(coroutine.create(function ()
			Core.SyncAPI:Invoke('SetMouseLockEnabled', true)
		end))
	end

	-- Hide UI
	if Core.UI and Core.UI.Parent ~= nil then
		Core.UI.Parent = script;
	end;

	-- Hide attachments while the tool is being inactive
	Core.Selection.HideHiddenAttachments()

	-- Close the explorer if desired by the options
	if Core.Options.CloseExplorerWhenUnequipping == true and Core.ExplorerVisible == true then
		WasExplorerOpen = true
		Core.CloseExplorer()
	end

	-- Unequip current tool
	if Core.CurrentTool then
		Core.CurrentTool:Unequip();
		Core.CurrentTool.Equipped = false;
	end;

	-- Clear temporary connections
	Core.ClearConnections();

	-- Indicate that tool is now disabled
	Core.IsEnabled = false;
	Core.IsDisabling = false;
	Core.Disabled:Fire();

end;


-- Core connections
Core.Connections = {};

function Core.ClearConnections()
	-- Clears and disconnects temporary connections
	for Index, Connection in pairs(Core.Connections) do
		Connection:Disconnect();
		Core.Connections[Index] = nil;
	end;
end;

local UIElements = Core.UIFolder
local ExplorerTemplate = require(Core.UIFolder:WaitForChild 'Explorer')
Core.ExplorerVisibilityChanged = Core.Signal.new()
Core.ExplorerVisible = false

function Core.ToggleExplorer()
	if type(Core.Options.CanUseExplorer) == "boolean" and Core.Options.CanUseExplorer == false or type(Core.Options.CanUseExplorer) == "function" and Core.Options.CanUseExplorer(Core.Player) == false then
		if not Core.UIFolder:FindFirstChild("Version") or Core.UIFolder.Version.Value == 1 then
			local DialogHandle
			local DialogComponent = require(Core.UIFolder:WaitForChild('Error'))

			local DialogElement = Roact.createElement(DialogComponent, {
				Text = "You're not allowed to use the explorer.";
				Hide = function()
					Roact.unmount(DialogHandle)
				end,
			})
			DialogHandle = Roact.mount(DialogElement, Core.UI, 'Error')
		else
			table.insert(Core.Notifications, {
				ThemeColor = Color3.new(1, 0, 0);
				NoticeText = "You're not allowed to use the explorer.";
				DetailText = "Own this game? Make sure to not <b>disable</b> Explorer to hide the icon when trying to open it with another tool.";
			})

			if Core.NewNotification then
				Core.NewNotification:Fire()
			end
		end
		return
	end
	if not Core.ExplorerVisible then
		Core.OpenExplorer()
	else
		Core.CloseExplorer()
	end
end

function Core.OpenExplorer(RevertToOldPosition)

	-- Ensure explorer not already open
	if ExplorerHandle then
		return
	end

	ExplorerTemplate = require(Core.UIFolder:WaitForChild 'Explorer')
	-- Initialize explorer
	Core.Explorer = Roact.createElement(ExplorerTemplate, {
		BTCore = Core,
		Close = Core.CloseExplorer,
		Scope = Core.Targeting.Scope,
		RevertToOldPosition = RevertToOldPosition
	})

	-- Mount explorer
	ExplorerHandle = Roact.mount(Core.Explorer, Core.UI, 'Explorer')
	Core.ExplorerVisible = true

	-- Unmount explorer on tool cleanup
	Core.UIMaid.Explorer = Core.Support.Call(Roact.unmount, ExplorerHandle)
	Core.UIMaid.ExplorerScope = Core.Targeting.ScopeChanged:Connect(function (Scope)
		local UpdatedProps = Core.Support.Merge({}, Core.Explorer.props, { Scope = Scope })
		local UpdatedExplorer = Roact.createElement(ExplorerTemplate, UpdatedProps)
		ExplorerHandle = Roact.update(ExplorerHandle, UpdatedExplorer)
	end)

	-- Fire signal
	Core.ExplorerVisibilityChanged:Fire()
end

function Core.CloseExplorer()

	-- Clean up explorer
	Core.UIMaid.Explorer = nil
	Core.UIMaid.ExplorerScope = nil
	ExplorerHandle = nil
	Core.ExplorerVisible = false

	-- Fire signal
	Core.ExplorerVisibilityChanged:Fire()
end

-- Create scope HUD when tool opens
local CreateScope = function()
	coroutine.wrap(function ()
		if not Core.IsEnabled then
			Core.Enabled:Wait()
		end

		-- Create scope HUD
		local ScopeHUDTemplate = require(UIElements:WaitForChild 'ScopeHUD')
		local ScopeHUD = Roact.createElement(ScopeHUDTemplate, {
			Core = Core;
		})

		-- Mount scope HUD
		Roact.mount(ScopeHUD, Core.UI, 'ScopeHUD')
	end)()
end

CreateScope()

-- Register explorer pane toggling hotkeys
Core.AssignHotkey({ 'LeftShift', 'H' }, Core.ToggleExplorer)
Core.AssignHotkey({ 'RightShift', 'H' }, Core.ToggleExplorer)

-- Enable tool or plugin
if Core.Mode == 'Plugin' then

	-- Set the UI root
	Core.UIContainer = Core.Services.CoreGui;

	-- Create the toolbar button
	PluginToolbar = Core.Plugin:CreateToolbar('Fork3X Building Tools by Vikko151')

	PluginButton = PluginToolbar:CreateButton(
		'Building Tools by F3X',
		'Building Tools by F3X',
		Core.Assets.PluginIcon
	);

	ThemeButton = PluginToolbar:CreateButton(
		'Change Theme',
		'Change Theme',
		Core.Assets.ThemeIcon
	);


	-- Connect the button to the system
	PluginButton.Click:Connect(function ()
		PluginEnabled = not PluginEnabled;
		PluginButton:SetActive(PluginEnabled);

		-- Toggle the tool
		if PluginEnabled then
			Core.Plugin:Activate(true);
			Core.Enable(Core.Plugin:GetMouse());
		else
			Core.Disable();
		end;
	end);

	ThemeButton.Click:Connect(function ()
		Core.UseGigsDarkWithPlugin = not Core.UseGigsDarkWithPlugin
		if Core.IsEnabled then
			Core.Disable()
			if Core.IsDisabling then
				Core.Disabled:Wait()
			end
			Core.Enable(Core.Plugin:GetMouse())
		else
			Core.InitializeUI()
		end
	end);

	-- Disable the tool upon plugin deactivation
	Core.Plugin.Deactivation:Connect(Core.Disable);

	-- Sync Studio selection to internal selection
	Core.Selection.Changed:Connect(function ()
		Core.Services.SelectionService:Set(Core.Selection.Items);
	end);

	-- Sync internal selection to Studio selection on enabling
	Core.Enabling:Connect(function ()
		Core.Selection.Replace(Core.Services.SelectionService:Get());
	end);

	-- Roughly sync Studio history to internal history (API lacking necessary functionality)
	Core.History.Changed:Connect(function ()
		Core.Services.ChangeHistoryService:SetWaypoint 'Building Tools by F3X';
	end);

	-- Add plugin action for toggling tool
	local ToggleAction = Core.Plugin:CreatePluginAction(
		'Fork3X/ToggleBuildingTools',
		'Toggle Building Tools',
		'Toggles the Building Tools by F3X plugin.',
		Core.Assets.PluginIcon,
		true
	)

	ToggleAction.Triggered:Connect(function ()
		PluginEnabled = not PluginEnabled
		PluginButton:SetActive(PluginEnabled)

		-- Toggle the tool
		if PluginEnabled then
			Core.Plugin:Activate(true)
			Core.Enable(Core.Plugin:GetMouse())
		else
			Core.Disable()
		end
	end)

elseif Core.Mode == 'Tool' then

	-- Set the UI root
	Core.UIContainer = Core.Player:WaitForChild 'PlayerGui';

	-- Connect the tool to the system
	Core.Tool.Equipped:Connect(Core.Enable);
	Core.Tool.Unequipped:Connect(Core.Disable);

	-- Disable the tool if not parented
	if not Core.Tool.Parent then
		Core.Disable();
	end;

	-- Disable the tool automatically if not equipped or in backpack

	Core.Tool.AncestryChanged:Connect(function (Item, Parent)
		if not Parent or not (Parent:IsA 'Backpack' or (Parent:IsA 'Model' and Core.Services.Players:GetPlayerFromCharacter(Parent))) then
			Core.Disable();
		end;
	end);

end;

-- Assign hotkeys for undoing (left or right shift + Z)
Core.AssignHotkey({ 'LeftShift', 'Z' }, Core.History.Undo);
Core.AssignHotkey({ 'RightShift', 'Z' }, Core.History.Undo);

-- Assign hotkeys for redoing (left or right shift + Y)
Core.AssignHotkey({ 'LeftShift', 'Y' }, Core.History.Redo);
Core.AssignHotkey({ 'RightShift', 'Y' }, Core.History.Redo);

-- If in-game, enable ctrl hotkeys for undoing and redoing
if Core.Mode == 'Tool' then
	Core.AssignHotkey({ 'LeftControl', 'Z' }, Core.History.Undo);
	Core.AssignHotkey({ 'RightControl', 'Z' }, Core.History.Undo);
	Core.AssignHotkey({ 'LeftControl', 'Y' }, Core.History.Redo);
	Core.AssignHotkey({ 'RightControl', 'Y' }, Core.History.Redo);
end;

local function GetDepthFromAncestor(Item, Ancestor)
	-- Returns the depth of `Item` from `Ancestor`

	local Depth = 0

	-- Go through ancestry until reaching `Ancestor`
	while Item ~= Ancestor do
		Depth = Depth + 1
		Item = Item.Parent
	end

	-- Return depth
	return Depth
end

local function GetHighestParent(Items)
	local HighestItem, HighestItemDepth

	-- Calculate depth of each item & keep highest
	for _, Item in ipairs(Items) do
		local Depth = GetDepthFromAncestor(Item, game)
		if (not HighestItemDepth) or (Depth < HighestItemDepth) then
			HighestItem = Item
			HighestItemDepth = Depth
		end
	end

	-- Return parent of highest item
	return HighestItem and HighestItem.Parent or nil
end

function Core.CloneSelection()
	-- Clones selected parts

	-- Make sure that there are items in the selection
	if (#Core.Selection.Items == 0) or CanClone == false then
		return;
	end;

	CanClone = false

	-- Clones selected parts

	-- Make sure that there are items in the selection

	-- Send the cloning request to the server
	local Clones, StreamingCloneId, StreamingCloneCount = Core.SyncAPI:Invoke('Clone', Core.Selection.Items, GetHighestParent(Core.Selection.Items))

	-- If the server is streaming clones, wait for them to replicate
	if Clones == nil then
		Clones = {}

		-- Gather initial available clones
		for _, Clone in game:GetService("CollectionService"):GetTagged("BTStreamingClone") do
			if Clone:GetAttribute("BTStreamingCloneID") == StreamingCloneId then
				table.insert(Clones, Clone)
			end
		end

		-- Listen for clones yet to arrive
		if #Clones < StreamingCloneCount then
			local thread = coroutine.running()

			-- If streaming takes too long, ignore remaining clones and resume thread early
			local CLONE_STREAMING_TIMEOUT = 3
			local timeoutThread = task.delay(CLONE_STREAMING_TIMEOUT, function ()
				warn(`[Building Tools by F3X] Cloning operation only received {#Clones}/{StreamingCloneCount} items after {CLONE_STREAMING_TIMEOUT} seconds, ignoring rest`)
				coroutine.resume(thread)
			end)

			-- Track incoming clones from this cloning operation
			local replicationListener = game:GetService("CollectionService"):GetInstanceAddedSignal("BTStreamingClone"):Connect(function (clone)
				if clone:GetAttribute("BTStreamingCloneID") == StreamingCloneId then
					table.insert(Clones, clone)

					-- Once all clones have arrived, resume thread
					if #Clones == StreamingCloneCount then
						task.cancel(timeoutThread)
						coroutine.resume(thread)
					end
				end
			end)

			-- Yield until resumed by replication completion, or timeout thread
			coroutine.yield()
			replicationListener:Disconnect()
		end
	end

	-- Put together the history record
	local HistoryRecord = {
		Clones = Clones;

		Unapply = function (HistoryRecord)
			-- Reverts this change

			-- Deselect the clones
			Core.Selection.Remove(HistoryRecord.Clones, false);

			-- Remove the clones
			Core.SyncAPI:Invoke('Remove', HistoryRecord.Clones);

		end;

		Apply = function (HistoryRecord)
			-- Reapplies this change

			-- Restore the clones
			Core.SyncAPI:Invoke('UndoRemove', HistoryRecord.Clones);

			-- Reselect the restored clones
			Core.Selection.Replace(HistoryRecord.Clones)

		end;

	};

	-- Register the history record
	Core.History.Add(HistoryRecord);

	-- Select the clones
	Core.Selection.Replace(Clones);

	-- Flash the outlines of the new parts
	coroutine.wrap(Core.Selection.FlashOutlines)();
	task.delay(Core.Options.CloningDelay, function() CanClone = true; end)

end;

function Core.DeleteSelection()
	-- Deletes selected items

	-- Put together the history record
	local HistoryRecord = {
		IsDeleting = true;
		Parts = Core.Support.CloneTable(Core.Selection.Items);

		Unapply = function (HistoryRecord)
			-- Reverts this change

			-- Restore the parts
			Core.SyncAPI:Invoke('UndoRemove', HistoryRecord.Parts);

			-- Select the restored parts
			Core.Selection.Replace(HistoryRecord.Parts);

		end;

		Apply = function (HistoryRecord)
			-- Applies this change

			-- Deselect the parts
			Core.Selection.Remove(HistoryRecord.Parts, false);

			-- Remove the parts
			Core.SyncAPI:Invoke('Remove', HistoryRecord.Parts);

		end;

	};

	-- Deselect parts before deleting
	Core.Selection.Remove(HistoryRecord.Parts, false);

	-- Perform the removal
	Core.SyncAPI:Invoke('Remove', HistoryRecord.Parts);

	-- Register the history record
	Core.History.Add(HistoryRecord);

end;

-- Assign hotkeys for cloning (left or right shift + c)
Core.AssignHotkey({ 'LeftShift', 'C' }, Core.CloneSelection);
Core.AssignHotkey({ 'RightShift', 'C' }, Core.CloneSelection);

-- Assign hotkeys for deletion (left or right shift + X)
Core.AssignHotkey({ 'LeftShift', 'X' }, Core.DeleteSelection);
Core.AssignHotkey({ 'RightShift', 'X' }, Core.DeleteSelection);

-- If in-game, enable ctrl hotkeys for cloning and deleting
if Core.Mode == 'Tool' then
	Core.AssignHotkey({ 'LeftControl', 'C' }, Core.CloneSelection);
	Core.AssignHotkey({ 'RightControl', 'C' }, Core.CloneSelection);
	Core.AssignHotkey({ 'LeftControl', 'X' }, Core.DeleteSelection);
	Core.AssignHotkey({ 'RightControl', 'X' }, Core.DeleteSelection);
end;

-- Assign hotkeys for prism selection
Core.AssignHotkey({ 'LeftShift', 'K' }, Core.Targeting.PrismSelect);
Core.AssignHotkey({ 'RightShift', 'K' }, Core.Targeting.PrismSelect);

-- If in-game, enable ctrl hotkeys for prism selection
if Core.Mode == 'Tool' then
	Core.AssignHotkey({ 'LeftControl', 'K' }, Core.Targeting.PrismSelect);
	Core.AssignHotkey({ 'RightControl', 'K' }, Core.Targeting.PrismSelect);
end;

-- Assign hotkeys for sibling selection
Core.AssignHotkey({ 'LeftBracket' }, Core.Support.Call(Core.Targeting.SelectSiblings, false, true));
Core.AssignHotkey({ 'LeftShift', 'LeftBracket' }, Core.Support.Call(Core.Targeting.SelectSiblings, false, false));
Core.AssignHotkey({ 'RightShift', 'LeftBracket' }, Core.Support.Call(Core.Targeting.SelectSiblings, false, false));

-- Assign hotkeys for selection clearing
Core.AssignHotkey({ 'LeftShift', 'R' }, Core.Support.Call(Core.Selection.Clear, true));
Core.AssignHotkey({ 'RightShift', 'R' }, Core.Support.Call(Core.Selection.Clear, true));

-- If in-game, enable ctrl hotkeys for sibling selection & selection clearing
if Core.Mode == 'Tool' then
	Core.AssignHotkey({ 'LeftControl', 'LeftBracket' }, Core.Support.Call(Core.Targeting.SelectSiblings, false, false));
	Core.AssignHotkey({ 'RightControl', 'LeftBracket' }, Core.Support.Call(Core.Targeting.SelectSiblings, false, false));
	Core.AssignHotkey({ 'LeftControl', 'R' }, Core.Support.Call(Core.Selection.Clear, true));
	Core.AssignHotkey({ 'RightControl', 'R' }, Core.Support.Call(Core.Selection.Clear, true));
end;

function Core.GroupSelection(GroupType)
	-- Groups the selected items

	-- Create history record
	local HistoryRecord = {
		Items = Core.Support.CloneTable(Core.Selection.Items),
		CurrentParents = Core.Support.GetListMembers(Core.Selection.Items, 'Parent')
	}

	function HistoryRecord:Unapply()
		Core.SyncAPI:Invoke('SetParent', self.Items, self.CurrentParents)
		Core.SyncAPI:Invoke('Remove', { self.NewParent })
		Core.Selection.Replace(self.Items)
	end

	function HistoryRecord:Apply()
		Core.SyncAPI:Invoke('UndoRemove', { self.NewParent })
		Core.SyncAPI:Invoke('SetParent', self.Items, self.NewParent)
		Core.Selection.Replace({ self.NewParent })
	end

	-- Perform group creation
	HistoryRecord.NewParent = Core.SyncAPI:Invoke('CreateGroup', GroupType,
		GetHighestParent(HistoryRecord.Items),
		HistoryRecord.Items
	)

	-- Register history record
	Core.History.Add(HistoryRecord)

	-- Select new group
	Core.Selection.Replace({ HistoryRecord.NewParent })

end

function Core.UngroupSelection()
	-- Ungroups the selected groups

	-- Create history record
	local HistoryRecord = {
		Selection = Core.Selection.Items
	}

	function HistoryRecord:Unapply()
		Core.SyncAPI:Invoke('UndoRemove', self.Groups)

		-- Reparent children
		for GroupId, Items in ipairs(self.GroupChildren) do
			coroutine.resume(coroutine.create(function ()
				Core.SyncAPI:Invoke('SetParent', Items, self.Groups[GroupId])
			end))
		end

		-- Reselect groups
		Core.Selection.Replace(self.Selection)
	end

	function HistoryRecord:Apply()

		-- Get groups from selection
		self.Groups = {}
		for _, Item in ipairs(self.Selection) do
			if Item:IsA 'Model' or Item:IsA 'Folder' then
				self.Groups[#self.Groups + 1] = Item
			end
		end

		-- Perform ungrouping
		self.GroupParents = Core.Support.GetListMembers(self.Groups, 'Parent')
		self.GroupChildren = Core.SyncAPI:Invoke('Ungroup', self.Groups) or {}

		-- Get unpacked children
		local UnpackedChildren = Core.Support.CloneTable(self.Selection)
		for GroupId, Children in pairs(self.GroupChildren) do
			for _, Child in ipairs(Children) do
				UnpackedChildren[#UnpackedChildren + 1] = Child
			end
		end

		-- Select unpacked items
		Core.Selection.Replace(UnpackedChildren)

	end

	-- Perform action
	HistoryRecord:Apply()

	-- Register history record
	Core.History.Add(HistoryRecord)

end

-- Assign grouping hotkeys
Core.AssignHotkey({ 'LeftShift', 'G' }, Core.Support.Call(Core.GroupSelection, 'Model'))
Core.AssignHotkey({ 'RightShift', 'G' }, Core.Support.Call(Core.GroupSelection, 'Model'))
Core.AssignHotkey({ 'LeftShift', 'F' }, Core.Support.Call(Core.GroupSelection, 'Folder'))
Core.AssignHotkey({ 'RightShift', 'F' }, Core.Support.Call(Core.GroupSelection, 'Folder'))
Core.AssignHotkey({ 'LeftShift', 'U' }, Core.UngroupSelection)
Core.AssignHotkey({ 'RightShift', 'U' }, Core.UngroupSelection)

function Core.ArrangePartHotkey()
	-- Exports the selected parts

	-- Make sure that there are items in the selection
	if #Core.Selection.Items == 0 then
		return;
	end;

	-- Start an export dialog
	local DialogHandle
	local DialogComponent = require(Core.UIFolder:WaitForChild('GroupDialog'))
	local FolderCallback = function ()
		Core.GroupSelection("Folder")
		DialogHandle = Roact.unmount(DialogHandle)
	end
	local ModelCallback = function ()
		Core.GroupSelection("Model")
		DialogHandle = Roact.unmount(DialogHandle)
	end
	local UngroupCallback = function ()
		Core.UngroupSelection()
		DialogHandle = Roact.unmount(DialogHandle)
	end
	local GroupCallback = function ()
		Roact.update(DialogHandle, Roact.createElement(DialogComponent, {
			Text = 'What kind of grouping do you want to do?<font size="5"><br /></font>\n' ..
				'<font weight="400" size="10"> Tip: If you still need to select your group piece per piece, a folder might be better. </font>';
			Function1 = ModelCallback;
			Function2 = FolderCallback;
			CallForGroup = nil;
			CallForUnGroup = nil;
			Option1 = "Model";
			Option2 = "Folder";
		}))
	end
	local DialogElement = Roact.createElement(DialogComponent, {
		Text = 'What kind of arrangement do you want to do?<font size="5"><br /></font>\n' ..
			'<font weight="400" size="10"> WARNING: Ungrouping a NPC or player might result into consequences! </font>';
		CallForGroup = nil;
		CallForUnGroup = nil;
		Function1 = GroupCallback;
		Function2 = UngroupCallback;
		Option1 = "Group";
		Option2 = "Ungroup";
	})
	DialogHandle = Roact.mount(DialogElement, Core.UI, 'ExportDialog')
end

Core.SaveLoadVisibilityChanged = Core.Signal.new()
Core.SaveLoadVisible = false
local CanLoad = true

function Core.ToggleSaveLoad()
	if not Core.UIFolder:FindFirstChild("Version") or Core.UIFolder.Version.Value == 1 then
		if type(Core.Options.CanUseSaveLoad) == "boolean" and Core.Options.CanUseSaveLoad == false or type(Core.Options.CanUseSaveLoad) == "function" and Core.Options.CanUseSaveLoad(Core.Player) == false then

			local DialogHandle
			local DialogComponent = require(Core.UIFolder:WaitForChild('UI'):WaitForChild('Error'))

			local DialogElement = Roact.createElement(DialogComponent, {
				Text = "You're not allowed to use the save/load interface.";
				Hide = function()
					Roact.unmount(DialogHandle)
				end,
			})
			DialogHandle = Roact.mount(DialogElement, Core.UI, 'Error')
			return 

		elseif DataStoresEnabled == false then

			local DialogHandle
			local DialogComponent = require(Core.UIFolder:WaitForChild('Error'))

			local DialogElement = Roact.createElement(DialogComponent, {
				Text = "You cannot use Save/Load because DataStores are disabled in this game.";
				Hide = function()
					Roact.unmount(DialogHandle)
				end,
			})
			DialogHandle = Roact.mount(DialogElement, Core.UI, 'Error')
			return 

		elseif Core.Mode == 'Plugin' then

			local DialogHandle
			local DialogComponent = require(Core.UIFolder:WaitForChild('UI'):WaitForChild('Error'))

			local DialogElement = Roact.createElement(DialogComponent, {
				Text = "You cannot use Save/Load in Studio.";
				Hide = function()
					Roact.unmount(DialogHandle)
				end,
			})
			DialogHandle = Roact.mount(DialogElement, Core.UI, 'Error')
			return 

		end
	else
		if type(Core.Options.CanUseSaveLoad) == "boolean" and Core.Options.CanUseSaveLoad == false or type(Core.Options.CanUseSaveLoad) == "function" and Core.Options.CanUseSaveLoad(Core.Player) == false then

			table.insert(Core.Notifications, {
				ThemeColor = Color3.new(1, 0, 0);
				NoticeText = "You're not allowed to use Save/Load.";
				DetailText = "Own this game? Make sure to not <b>disable</b> Save/Load to hide the icon when trying to open it with another tool.";
			})

			if Core.NewNotification then
				Core.NewNotification:Fire()
			end
			return 

		elseif DataStoresEnabled == false then

			table.insert(Core.Notifications, {
				ThemeColor = Color3.new(1, 0, 0);
				NoticeText = "You cannot use Save/Load because DataStores are disabled in this game.";
				DetailText = "Own this game? Edit it in Studio, and toggle on\nHOME > <b>Game Settings</b> > Security > <b>Enable Studio Access to API services</b>";
			})
			if Core.NewNotification then
				Core.NewNotification:Fire()
			end
			return 

		elseif Core.Mode == 'Plugin' then

			table.insert(Core.Notifications, {
				ThemeColor = Color3.new(1, 0, 0);
				NoticeText = "You cannot use Save/Load with the plugin.";
				DetailText = "Looking to save something you built in Studio? You can use Fork3X in-game to do so.";
			})
			if Core.NewNotification then
				Core.NewNotification:Fire()
			end
			return 

		end
	end
	if not Core.UI:FindFirstChild("SaveInterface") then
		Core.SaveLoadVisible = true
		Core.CreateSaveAndLoad()
		Core.SaveLoadVisibilityChanged:Fire()
	elseif not Core.SaveLoadVisible then
		Core.SaveLoadVisible = true
		Core.SaveLoadVisibilityChanged:Fire()
	else
		Core.SaveLoadVisible = false
		Core.SaveLoadVisibilityChanged:Fire()
	end
end

function Core.CreateSaveAndLoad()
	-- Exports the selected parts
	-- Start an export dialog
	local DialogHandle
	local DialogComponent = require(Core.UIFolder:WaitForChild('SaveInterface'))

	local SaveSlots = {}

	local Sizes = Core.Options.SizeLimit ~= 0 and {} or nil

	local TotalSize = Core.Options.SizeLimit < 0 and 0 or nil

	if Core.UIFolder:FindFirstChild("Version") and Core.UIFolder.Version.Value == 2 then	
		local Save = function(Slot)
			if #Core.Selection.Items == 0 then
				return;
			end;
			game:GetService("SoundService"):PlayLocalSound(Core.Sounds:WaitForChild("Press"))
			local Success, Details = Core.SyncAPI:Invoke('SaveBuild', Core.Selection.Items, Slot)
			if Success == true then
				game:GetService("SoundService"):PlayLocalSound(Core.Sounds:WaitForChild("Add"))
			else
				game:GetService("SoundService"):PlayLocalSound(Core.Sounds:WaitForChild("Remove"))

				table.insert(Core.Notifications, {
					ThemeColor = Color3.new(1, 0, 0);
					NoticeText = Success;
					DetailText = Details;
				})

				if Core.NewNotification then
					Core.NewNotification:Fire()
				end
			end
		end

		local Load = function(Slot)	
			if not CanLoad then
				return;
			end;
			--Core.SyncAPI:Invoke('LoadBuild', "1")
			game:GetService("SoundService"):PlayLocalSound(Core.Sounds:WaitForChild("Press"))
			local Success = Core.SyncAPI:Invoke('LoadBuild', Slot)
			if Success then
				game:GetService("SoundService"):PlayLocalSound(Core.Sounds:WaitForChild("Add"))
			else
				game:GetService("SoundService"):PlayLocalSound(Core.Sounds:WaitForChild("Remove"))
			end
			CanLoad = false
			task.delay(Core.Options.LoadDelay, function() CanLoad = true end)
		end

		for i = 1, Core.Options.NumberOfSaveSlots do
			SaveSlots[i] = "Slot " .. i

			if Sizes then
				Sizes[i] = true
			end
		end

		if Sizes then
			Sizes = Core.SyncAPI:Invoke('GetSlotsSize', Sizes)

			if TotalSize then
				for _, Size in Sizes do
					TotalSize += Size
				end
			end
		end

		local DialogElement = Roact.createElement(DialogComponent, {
			Core = Core;
			Save = Save;
			Load = Load;
			TotalSize = TotalSize;
			Sizes = Sizes;
			MaxSize = Core.Options.SizeLimit;
			Slots = SaveSlots
		})
		DialogHandle = Roact.mount(DialogElement, Core.UI, 'SaveInterface')
	else
		local FirstSaveCallback = function ()	
			if #Core.Selection.Items == 0 then
				return;
			end;
			game:GetService("SoundService"):PlayLocalSound(Core.Sounds:WaitForChild("Press"))
			local Success = Core.SyncAPI:Invoke('SaveBuild', Core.Selection.Items, "1")
			if Success then
				game:GetService("SoundService"):PlayLocalSound(Core.Sounds:WaitForChild("Add"))
			else
				game:GetService("SoundService"):PlayLocalSound(Core.Sounds:WaitForChild("Remove"))
			end
		end

		local SecondSaveCallback = function ()	
			if #Core.Selection.Items == 0 then
				return;
			end;
			game:GetService("SoundService"):PlayLocalSound(Core.Sounds:WaitForChild("Press"))
			local Success = Core.SyncAPI:Invoke('SaveBuild', Core.Selection.Items, "2")
			if Success then
				game:GetService("SoundService"):PlayLocalSound(Core.Sounds:WaitForChild("Add"))
			else
				game:GetService("SoundService"):PlayLocalSound(Core.Sounds:WaitForChild("Remove"))
			end
		end

		local ThirdSaveCallback = function ()	
			if #Core.Selection.Items == 0 then
				return;
			end;
			game:GetService("SoundService"):PlayLocalSound(Core.Sounds:WaitForChild("Press"))
			local Success = Core.SyncAPI:Invoke('SaveBuild', Core.Selection.Items, "3")
			if Success then
				game:GetService("SoundService"):PlayLocalSound(Core.Sounds:WaitForChild("Add"))
			else
				game:GetService("SoundService"):PlayLocalSound(Core.Sounds:WaitForChild("Remove"))
			end
		end

		local FirstLoadCallback = function ()	
			if not CanLoad then
				return;
			end;
			--Core.SyncAPI:Invoke('LoadBuild', "1")
			game:GetService("SoundService"):PlayLocalSound(Core.Sounds:WaitForChild("Press"))
			local Success = Core.SyncAPI:Invoke('LoadBuild', "1")
			if Success then
				game:GetService("SoundService"):PlayLocalSound(Core.Sounds:WaitForChild("Add"))
			else
				game:GetService("SoundService"):PlayLocalSound(Core.Sounds:WaitForChild("Remove"))
			end
			CanLoad = false
			task.delay(Core.Options.LoadDelay, function() CanLoad = true end)
		end

		local SecondLoadCallback = function ()	
			if not CanLoad then
				return;
			end;
			game:GetService("SoundService"):PlayLocalSound(Core.Sounds:WaitForChild("Press"))
			local Success = Core.SyncAPI:Invoke('LoadBuild', "2")
			if Success then
				game:GetService("SoundService"):PlayLocalSound(Core.Sounds:WaitForChild("Add"))
			else
				game:GetService("SoundService"):PlayLocalSound(Core.Sounds:WaitForChild("Remove"))
			end
			CanLoad = false
			task.delay(Core.Options.LoadDelay, function() CanLoad = true end)
		end

		local ThirdLoadCallback = function ()	
			if not CanLoad then
				return;
			end;
			game:GetService("SoundService"):PlayLocalSound(Core.Sounds:WaitForChild("Press"))
			local Success = Core.SyncAPI:Invoke('LoadBuild', "3")
			if Success then
				game:GetService("SoundService"):PlayLocalSound(Core.Sounds:WaitForChild("Add"))
			else
				game:GetService("SoundService"):PlayLocalSound(Core.Sounds:WaitForChild("Remove"))
			end
			CanLoad = false
			task.delay(Core.Options.LoadDelay, function() CanLoad = true end)
		end

		local DialogElement = Roact.createElement(DialogComponent, {
			Core = Core;
			FirstSaveLoad = FirstLoadCallback;
			FirstSave = FirstSaveCallback;
			SecondSaveLoad = SecondLoadCallback;
			SecondSave = SecondSaveCallback;
			ThirdSaveLoad = ThirdLoadCallback;
			ThirdSave = ThirdSaveCallback;
		})
		DialogHandle = Roact.mount(DialogElement, Core.UI, 'SaveInterface')
	end
end 

function Core.GetPartsFromSelection(Selection)
	local Parts = {}

	-- Get parts from selection
	for _, Item in pairs(Selection) do
		if Item:IsA 'BasePart' then
			Parts[#Parts + 1] = Item

			-- Get parts within other items
		else
			for _, Descendant in pairs(Item:GetDescendants()) do
				if Descendant:IsA 'BasePart' then
					Parts[#Parts + 1] = Descendant
				end
			end
		end
	end

	-- Return parts
	return Parts
end

function Core.IsSelectable(Items, Filter)
	-- Returns whether `Items` can be selected

	-- Check each item
	for _, Item in pairs(Items) do

		-- Ensure item exists and is not locked
		if (not Item) or (not Item.Parent) then
			return false
		elseif Item:IsA 'BasePart' and Item.Locked then
			return false
		end

		-- Ensure item can be modified
		if not Core.Security.IsItemAllowed(Item, Core.Player) then
			return false
		end

		if not Core.Options.ConsiderPart(Item, Core.Player) then
			return false
		end
	end

	-- Check if parts intruding into private areas
	local Parts = Core.GetPartsFromSelection(Items)
	if Core.Security.ArePartsViolatingAreas(Parts, Core.Player, true) then
		return false
	end

	-- If no checks fail, items are selectable
	return true

end

local Factor = 0

function Core.FilterParts(Items)
	for Item in Items do
		Factor += 1
		--if Factor % 400 == 0 then
		--	task.wait()
		--end
		if not Core.IsSelectable({Item}) then
			Items[Item] = nil
		end
	end

	return Items
end

function Core.ExportSelection()
	-- Exports the selected parts

	-- Make sure that there are items in the selection
	if #Core.Selection.Items == 0 then
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


end;

-- Assign hotkey for exporting selection
Core.AssignHotkey({ 'LeftShift', 'P' }, Core.ExportSelection);
Core.AssignHotkey({ 'RightShift', 'P' }, Core.ExportSelection);

-- If in-game, enable ctrl hotkeys for exporting
if Core.Mode == 'Tool' then
	Core.AssignHotkey({ 'LeftControl', 'P' }, Core.ExportSelection);
	Core.AssignHotkey({ 'RightControl', 'P' }, Core.ExportSelection);
end;

function Core.IsVersionOutdated()
	-- Returns whether this version of Building Tools is out of date
--[[
	-- Check most recent version number
	local AssetInfo = game.MarketplaceService:GetProductInfo(142785488, Enum.InfoType.Asset);
	local LatestMajorVersion, LatestMinorVersion, LatestPatchVersion = AssetInfo.Description:match '%[Version: ([0-9]+)%.([0-9]+)%.([0-9]+)%]';
	local CurrentMajorVersion, CurrentMinorVersion, CurrentPatchVersion = Core.Tool.Version.Value:match '([0-9]+)%.([0-9]+)%.([0-9]+)';

	-- Convert version data into numbers
	local LatestMajorVersion, LatestMinorVersion, LatestPatchVersion =
		tonumber(LatestMajorVersion), tonumber(LatestMinorVersion), tonumber(LatestPatchVersion);
	local CurrentMajorVersion, CurrentMinorVersion, CurrentPatchVersion =
		tonumber(CurrentMajorVersion), tonumber(CurrentMinorVersion), tonumber(CurrentPatchVersion);

	-- Determine whether current version is outdated
	if LatestMajorVersion > CurrentMajorVersion then
		return true;
	elseif LatestMajorVersion == CurrentMajorVersion then
		if LatestMinorVersion > CurrentMinorVersion then
			return true;
		elseif LatestMinorVersion == CurrentMinorVersion then
			return LatestPatchVersion > CurrentPatchVersion;
		end;
	end;]]

	-- Return an up-to-date status if not oudated
	return false;

end;

function Core.ToggleMultiSelect()
	if Core.Selection.Multiselecting == false then
		Core.Selection.Multiselecting = true
	elseif Core.Selection.Multiselecting == true then
		Core.Selection.Multiselecting = false
	end
	Core.Selection.MultiselectToggle:Fire()
end

function Core.NewExport()
	-- Imports an object according to it's ID.

	-- Start an export dialog
	local DialogHandle
	local DialogComponent = require(Core.UIFolder:WaitForChild('ImportDialog'))
	local DialogDismissCallback = function ()
		DialogHandle = Roact.unmount(DialogHandle)
	end
	local DialogSendCallback = function (CreationID)
		if CreationID == nil then return end
		Core.Try(Core.SyncAPI.Invoke, Core.SyncAPI, 'Import', CreationID)
			:Then(function ()
				Roact.update(DialogHandle, Roact.createElement(DialogComponent, {
					Text = 'Your creation has been succesfully imported!<font size="5"><br /></font>\n';
					OnDismiss = DialogDismissCallback;
				}))
			end)
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
			:Catch(function (Error, Stack, Attempt)
				Roact.update(DialogHandle, Roact.createElement(DialogComponent, {
					Text = 'An unknown error occurred — please try again.';
					OnDismiss = DialogDismissCallback;
				}))
				warn('❌ [Building Tools by F3X] Failed to import', '\n\nError:\n', Error, '\n\nStack:\n', Stack)
			end)
		DialogHandle = Roact.unmount(DialogHandle)
	end
	local DialogElement = Roact.createElement(DialogComponent, {
		Text = 'Loading...';
		OnDismiss = DialogDismissCallback;
	})
	DialogHandle = Roact.mount(DialogElement, Core.UI, 'ImportDialog')
	Roact.update(DialogHandle, Roact.createElement(DialogComponent, {
		Text = 'How would you like to export your creation?<font size="5"><br /></font>\n';
		OnDismiss = DialogDismissCallback;
		OnSend = DialogSendCallback;			}))

end;

-- Assign hotkey for exporting selection
--Core.AssignHotkey({ 'LeftShift', 'M' }, Import);
--Core.AssignHotkey({ 'RightShift', 'M' }, Import);

-- If in-game, enable ctrl hotkeys for exporting
--if Core.Mode == 'Tool' then
--	Core.AssignHotkey({ 'LeftControl', 'M' }, Import);
--	Core.AssignHotkey({ 'RightControl', 'M' }, Import);
--end;

function Core.ToggleSwitch(CurrentButtonName, SwitchContainer)
	-- Toggles between the buttons in a switch

	-- Reset all buttons
	for _, Button in SwitchContainer:GetChildren() do

		-- Make sure to not mistake the option label for a button
		if Button.Name ~= 'Label' and Button:IsA("Frame") then

			-- Set appearance to disabled
			Button:RemoveTag("STATE_CurrentOption")
			
--			Button.SelectedIndicator.BackgroundTransparency = 1;
--			Button.Background.Image = Core.Assets.LightSlantedRectangle;

		end;

	end;

	-- Make sure there's a new current button
	if CurrentButtonName then

		-- Get the current button
		local CurrentButton = SwitchContainer[CurrentButtonName];

		-- Set the current button's appearance to enabled
		CurrentButton:AddTag("STATE_CurrentOption")

	end;
end;

-- Picks one tag depending on the submitted value
function Core.AlternateTags(Value, Object, TrueTagName, MultipleTagName)

	-- Go through the inputs and data
	if Value == true then
		-- Clear every UI tags
		Object:AddTag(TrueTagName)
		Object:RemoveTag(MultipleTagName)

		--			ShadowsCheckbox.Image = Core.Assets.CheckedCheckbox;
	elseif Value == false then
		-- Clear every UI tags
		Object:RemoveTag(TrueTagName)
		Object:RemoveTag(MultipleTagName)

		--			ShadowsCheckbox.Image = Core.Assets.UncheckedCheckbox;
	elseif Value == nil then
		-- Clear every UI tags
		Object:RemoveTag(TrueTagName)
		Object:AddTag(MultipleTagName)

		--			ShadowsCheckbox.Image = Core.Assets.SemicheckedCheckbox;
	end;

end;

-- References to reduce indexing time
local GetConnectedParts = Instance.new('Part').GetConnectedParts;
local GetChildren = script.GetChildren;

function Core.GetPartJoints(Part, Whitelist)
	-- Returns any manual joints involving `Part`

	local Joints = {};

	-- Get joints stored inside `Part`
	for Joint, JointParent in pairs(Core.SearchJoints(Part, Part, Whitelist)) do
		Joints[Joint] = JointParent;
	end;

	-- Get joints stored inside connected parts
	for _, ConnectedPart in pairs(GetConnectedParts(Part)) do
		for Joint, JointParent in pairs(Core.SearchJoints(ConnectedPart, Part, Whitelist)) do
			Joints[Joint] = JointParent;
		end;
	end;

	-- Return all found joints
	return Joints;

end;

-- Types of joints to assume should be preserved
local ManualJointTypes = Core.Support.FlipTable { 'Weld', 'ManualWeld', 'ManualGlue', 'Motor', 'Motor6D' };

function Core.SearchJoints(Haystack, Part, Whitelist)
	-- Searches for and returns manual joints in `Haystack` involving `Part` and other parts in `Whitelist`

	local Joints = {};

	-- Search the haystack for joints involving `Part`
	for _, Item in GetChildren(Haystack) do

		-- Check if this item is a manual, intentional joint
		if ManualJointTypes[Item.ClassName] and
			(Whitelist[Item.Part0] and Whitelist[Item.Part1]) then

			-- Save joint and state if intentional
			Joints[Item] = Item.Parent;

		end;

	end;

	-- Return the found joints
	return Joints;

end;

function Core.RestoreJoints(Joints)
	-- Restores the joints from the given `Joints` data

	-- Restore each joint
	for Joint, JointParent in pairs(Joints) do
		Joint.Parent = JointParent;
	end;

end;

function Core.PreserveJoints(Part, Whitelist)
	-- Preserves and returns intentional joints of `Part` connecting parts in `Whitelist`

	-- Get the part's joints
	local Joints = Core.GetPartJoints(Part, Whitelist);

	-- Save the joints from being broken
	for Joint in pairs(Joints) do
		Joint.Parent = nil;
	end;

	-- Return the joints
	return Joints;

end;

local ToolList = {}

function Core.PurgeUI()
	-- Delete everything that's not a selection box or handles

	if not Core.UI then
		return {}
	end

	local ChildrenToKeep = {}

	for _, Child in Core.UI:GetChildren() do
		if Child:IsA("SelectionBox") or Child:IsA("Highlight") or Child.Name == "BTHandles" then
			Child.Parent = nil
			table.insert(ChildrenToKeep, Child)
		end
	end

	Core.UI:Destroy()
	Core.UI = nil
	
	return ChildrenToKeep

end

function Core.CheckTheme()
	local Theme, Token, Components = Core.Options.CheckTheme(Core, Core.Player)

	if Theme and Token and Components and Theme ~= Core.CurrentTheme then

		Core.CurrentTheme = Theme
		Core.CurrentToken = Token
		Core.StyleTokenDerive.StyleSheet = Token
		Core.Components = Components

		local WasCoreEnabled = Core.IsEnabled

		if Core.IsEnabled then
			Core.Disable()
		end

		Core.IsDisabling = true

		-- Delete any component if there are any
		for _, Component in Core.Support.ConcatTable(script.Parent:QueryDescendants(".FORK3X_Component"), Core.UI and Core.UI:QueryDescendants(".FORK3X_Component")) do
			Component:Destroy()
		end

		-- Clear every components' tables
		for _, Function in Core.ComponentsToRevert do
			Function(Core)
		end

		table.clear(Core.ComponentsToRevert)
		table.clear(Core.RoactComponents)

		local ChildrenToKeep = Core.PurgeUI()

		--Core.StyleConnections:DoCleaning()

					--[[
			local RoactString = string.sub(Tag.Name, 1, 8)

			-- The component needs to be bound to a Roact component
			if RoactString == "ROACTUI_" then
				RoactString = string.gsub(Tag.Name, "ROACTUI_", "", 1)

				if not Core.RoactComponents[RoactString] then
					Core.RoactComponents[RoactString] = {}
				end

				for _, Component in Tag:GetChildren() do
					if Component:IsA("ModuleScript") then
						-- The component is a Roact component
						Core.RoactComponents[RoactString][Component.Name] = require(Component)
					else
						-- The component is an UI item
						-- Wrap the item into a Roact portal function
						local RoactFunction = function(props, state)


							return Roact.createElement("Frame", {
								[Roact.Ref] = function(rbx)
									if rbx then
										local Item = Component:Clone()
										Item:AddTag("FORK3X_Component")

										Item.Parent = rbx.Parent	

										rbx:Destroy()
									end
								end,
							})
						end

						Core.RoactComponents[RoactString][Component.Name] = RoactFunction
					end
				end
			end]]

		for _, Tag in Components:GetChildren() do
			local RoactString = string.sub(Tag.Name, 1, 8)

			-- The component needs to be bound to a Roact component
			if RoactString == "ROACTUI_" then
				RoactString = string.gsub(Tag.Name, "ROACTUI_", "", 1)
				
				if not Core.RoactComponents[RoactString] then
					Core.RoactComponents[RoactString] = {}
				end

				for _, Component in Tag:GetChildren() do
					if Component:IsA("ModuleScript") then
						-- The component is a Roact component
						Core.RoactComponents[RoactString][Component.Name] = require(Component)
					else
						-- The component is an UI item
						-- Wrap the item into a Roact portal function
						local RoactFunction = function(props, state)


							return Roact.createElement("Frame", {
								[Roact.Ref] = function(rbx)
									if rbx then
										local Item = Component:Clone()
										Item:AddTag("FORK3X_Component")

										Item.Parent = rbx.Parent	

										rbx:Destroy()
									end
								end,
							})
						end

						Core.RoactComponents[RoactString][Component.Name] = RoactFunction
					end
				end
			else
				local Objects = Core.Support.ConcatTable(script.Parent:QueryDescendants(Tag:GetAttribute("Selector")), Core.UI and Core.UI:QueryDescendants(Tag:GetAttribute("Selector")))

				for _, Object in Objects do
					for _, Component in Tag:GetChildren() do
						if Component:IsA("ModuleScript") then
							-- The component is a Roact component
							-- Run it directly

							local Returned = require(Component)

							if type(Returned) == "function" then
								local RoactItem = Returned(Object, Core)

								if RoactItem then
									Roact.mount(RoactItem, Object, Component.Name)
								end
							elseif type(Returned) == "table" and Returned.Apply then
								Returned.Apply(Object, Core)
								if Returned.Revert and not Core.ComponentsToRevert[Component] then
									Core.ComponentsToRevert[Component] = Returned.Revert
								end
							end
						else
							-- The component is an UI item
							-- Just clone and drop the item inside the object

							local Clone = Component:Clone()
							Clone:AddTag("FORK3X_Component")
							Clone.Parent = Object
						end
					end
				end
			end
		end
		
		if Core.StyleLink then
			Core.StyleLink.StyleSheet = Core.CurrentTheme
		end
		
		Core.InitializeUI()
		CreateScope()

		for _, Child in ChildrenToKeep do
			Child.Parent = Core.UI
		end
		
		Core.IsDisabling = false

		if WasCoreEnabled then
			Core.Enable(Core.Services.Players.LocalPlayer:GetMouse())
		end
	end
end

function Core.InitializeUI()
	-- Sets up the UI

	-- Ensure UI has not yet been initialized

	local ProfilesFolder = Core.Mode == "Plugin" and not Core.UseGigsDarkWithPlugin and game.ReplicatedStorage:FindFirstChild("Fork3XProfile") or Core.Profiles

	if ProfilesFolder then

		local Profile = Core.UseGigsDarkWithPlugin and "GigsDark" or Core.Mode == "Plugin" and ProfilesFolder.Name == "Fork3XProfile" and ProfilesFolder:GetChildren()[1].Name or Core.Options.CheckProfile(Core.Player)

		if Profile ~= Core.CurrentProfile and Profile ~= nil then
			Core.CurrentProfile = Profile
			local NewProfile = ProfilesFolder:WaitForChild(Core.CurrentProfile, 0.2)

			if NewProfile then
				-- Wait a bit for the UI to fully load (Release 695 added extreme delays to indexing)
				if Core.Options.WaitForProfile and Core.Options.WaitForProfile > 0 then
					task.wait(Core.Options.WaitForProfile)
				end

				local NewProfile = NewProfile:Clone()

				if Core.UI then
					Core.UI:Destroy()
					Core.UI = nil
				end

				local OldItemsHierarchy = {}

				for _, Item in Core.Interfaces:GetDescendants() do		
					if Item:GetAttribute("IsNegligible") == true then continue end
					OldItemsHierarchy[Item] = {}
					local CurrentParent = Item.Parent

					if Item.Parent == Core.Interfaces then
						table.insert(OldItemsHierarchy[Item], CurrentParent)
						continue
					end

					repeat
						table.insert(OldItemsHierarchy[Item], CurrentParent)
						CurrentParent = CurrentParent.Parent
					until CurrentParent == Core.Interfaces
					table.insert(OldItemsHierarchy[Item], Core.Interfaces)
				end

				for _, Item in Core.UIFolder:GetDescendants() do			
					OldItemsHierarchy[Item] = {}
					local CurrentParent = Item.Parent

					if Item.Parent == Core.UIFolder then
						table.insert(OldItemsHierarchy[Item], CurrentParent)
						continue
					end

					repeat
						table.insert(OldItemsHierarchy[Item], CurrentParent)
						CurrentParent = CurrentParent.Parent
					until CurrentParent == Core.UIFolder
					table.insert(OldItemsHierarchy[Item], Core.UIFolder)
				end

				for MainItem, Item in OldItemsHierarchy do
					local Count = #Item
					local KnownParent = NewProfile

					local Ended = false

					repeat
						local ItemToFind

						if Count == 0 then
							ItemToFind = MainItem
						else
							ItemToFind = Item[Count]
						end

						if KnownParent:FindFirstChild(ItemToFind.Name) and ItemToFind:GetAttribute("ChangeAnyway") ~= true then
							KnownParent = KnownParent[ItemToFind.Name]
						elseif KnownParent:FindFirstChild(ItemToFind.Name) and ItemToFind:GetAttribute("ChangeAnyway") == true then
							break
						else
							ItemToFind:Clone().Parent = KnownParent
							Ended = true
							break
						end

						if Count == 0 then
							Ended = true
							break
						end

						Count -= 1
					until Ended == true
				end

				Core.Interfaces:Destroy()
				Core.UIFolder:Destroy()

				Core.UIFolder = NewProfile.UI
				Core.Interfaces = NewProfile.Interfaces

				NewProfile.Interfaces.Parent = script.Parent

				NewProfile.UI.Parent = script.Parent

				UIElements = Core.UIFolder

				NewProfile:Destroy()
			end
		end

	end

	Core.CheckTheme()

	if Core.UI then
		return true;
	end;

	-- Create the root UI
	Core.UI = Instance.new('ScreenGui')
	Core.UI.Name = 'Building Tools by F3X (UI)'

	Core.StyleLink = Instance.new("StyleLink")
	Core.StyleLink.StyleSheet = Core.CurrentTheme
	Core.StyleLink.Parent = Core.UI

	Core.StyleTokenDerive.Parent = Core.CurrentTheme
	Core.StyleTokenDerive.StyleSheet = Core.GlobalStyleToken

	local ThemeStyleDerive = Instance.new("StyleDerive")
	ThemeStyleDerive.Parent = Core.GlobalStyleToken
	ThemeStyleDerive.StyleSheet = Core.CurrentToken

	-- Set up connections for every components


	--	script.StyleLink.Parent = Core.UI
	-- Create dock
	local DockComponent = require(Core.UIFolder:WaitForChild('Dock'))
	local DockElement = Roact.createElement(DockComponent, {
		Core = Core;
		Tools = ToolList;
		Camera = game.Workspace.CurrentCamera;
	})
	local DockHandle = Roact.mount(DockElement, Core.UI, 'Dock')

	-- Provide API for adding Core.Tool buttons to dock
	local function AddToolButton(IconAssetId, HotkeyLabel, Tool, Position, Size, AnchorPoint)
		if table.find(Core.Options.ToolsBlacklist, Tool.Name) then
			return
		end

		table.insert(ToolList, {
			IconAssetId = IconAssetId;
			HotkeyLabel = HotkeyLabel;
			Tool = Tool;
			Position = Position;
			Size = Size;
			AnchorPoint = AnchorPoint;
		})

		Core.ProfileUpdate:Fire(DockHandle, DockComponent)
		-- Update dock
		--[[
		Roact.update(DockHandle, Roact.createElement(DockComponent, {
			Core = Core;
			Tools = Cryo.List.join(ToolList);
		}))]]
	end

	Core.AddToolButton = AddToolButton

	-- Clean up UI on tool teardown
	Core.UIMaid = Maid.new()
	Core.Tool.AncestryChanged:Connect(function (Item, Parent)
		if Parent == nil then
			Core.UIMaid:Destroy()
		end
	end)

	Core.ProfileUpdate:Fire(DockHandle, DockComponent)

	return true
end

function Core.SetToolTipPortal(Portal)
	Core.ToolTipPortal = Portal
end

-- Initialize the UI
Core.IsDisabling = true
Core.InitializeUI();
Core.IsDisabling = false
Core.Disabled:Fire();

DataStoresEnabled = Core.SyncAPI:Invoke('CheckDataStores')

Core.ProfileUpdate:Connect(function(DockHandle, DockComponent)
	Roact.update(DockHandle, Roact.createElement(DockComponent, {
		Core = Core;
		Tools = Cryo.List.join(ToolList);
	}))
end)

--[[
-- Setup Parallel Luau for better performance
local CoreFolder = Core.Make("Folder")({
	Name = "Actors",
	Parent = script
})

Core.ParallelCores = {}

for i = 1, 1 do
	Core.ParallelCores[i] = Instance.new("Actor")
	Core.ParallelCores[i].Name = "Actor"
	Core.ParallelCores[i].Parent = CoreFolder
	Core.ParallelCores[i]:SetAttribute("Number", i)

	local ThreadScript = script.Thread:Clone()
	ThreadScript.Parent = Core.ParallelCores[i]

	-- Enable the script in its respective environment
	require(ThreadScript)(Core.FilterParts, Core.Targeting, Core.Selection, i, Core.Support)
end]]

-- Set up external connections
Core.Options.CustomCoreConnections(Core)

for FunctionName, Arguments in Core.Options.CustomCoreFunctions do
	Core[FunctionName] = function(...)
		return Arguments[1](Core, ...)
	end

	if Arguments[2] then
		Core.AssignHotkey(Arguments[2], Core[FunctionName])
	end
end

-- Return core
return Core;
