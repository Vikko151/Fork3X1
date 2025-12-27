Tool = script.Parent.Parent;
Core = require(Tool.Core);
Sounds = Tool:WaitForChild("Sounds");

-- Libraries
local ListenForManualWindowTrigger = require(Tool.Core:WaitForChild('ListenForManualWindowTrigger'))
local BoundingBox = require(Tool.Core.BoundingBox)

-- Import relevant references
Selection = Core.Selection;
Support = Core.Support;
Security = Core.Security;

-- Initialize the tool
local CollisionTool = {
	Name = 'Collision Tool';
	Color = BrickColor.new 'Really black';
}

if table.find(Core.Options.ToolsBlacklist, CollisionTool.Name) then
	return CollisionTool
end

CollisionTool.ManualText = [[<font weight="900" size="24"><u><i>Collision Tool  🛠</i></u></font>
Lets you change whether parts collide with one another.<font size="6"><br /></font>

<b>TIP:</b> Press <b>Enter</b> to toggle collision quickly.]]

-- Container for temporary connections (disconnected automatically)
local Connections = {};

function CollisionTool.Equip()
	-- Enables the tool's equipped functionality

	-- Start up our interface
	ShowUI();
	BindShortcutKeys();
	if Selection.DisableHighlights then
		BoundingBox.StartBoundingBox(function () end)
	end

	Connections.BoundingBox = Selection.Changed:Connect(function()
		if Selection.DisableHighlights and not BoundingBox.GetBoundingBox() then
			BoundingBox.StartBoundingBox(function () end)
		elseif not Selection.DisableHighlights and BoundingBox.GetBoundingBox() then
			BoundingBox.ClearBoundingBox()
		end
	end)

end;

function CollisionTool.Unequip()
	-- Disables the tool's equipped functionality

	-- Clear unnecessary resources
	HideUI();
	ClearConnections();
	BoundingBox.ClearBoundingBox();

end;

function ClearConnections()
	-- Clears out temporary connections

	for ConnectionKey, Connection in pairs(Connections) do
		Connection:Disconnect();
		Connections[ConnectionKey] = nil;
	end;

end;

function ShowUI()
	-- Creates and reveals the UI

	-- Reveal UI if already created
	if UI and UI.Parent ~= nil then

		-- Reveal the UI
		UI.Visible = true;

		-- Update the UI every 0.1 seconds
		UIUpdater = Support.ScheduleRecurringTask(UpdateUI, 0.1);

		-- Skip UI creation
		return;

	end;
	
	if UI then
		UI:Destroy()
	end
	
	-- Create the UI
	UI = Core.Interfaces.BTCollisionToolGUI:Clone();
	UI.Parent = Core.UI;
	UI.Visible = true;

	-- References to UI elements
	local OnButton = UI.Status.On.Button;
	local OffButton = UI.Status.Off.Button;

	-- Enable the collision status switch
	OnButton.MouseButton1Click:Connect(function ()
		SetProperty('CanCollide', true);
	end);
	OnButton.MouseEnter:Connect(function ()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Hover"))
	end);
	OffButton.MouseButton1Click:Connect(function ()
		SetProperty('CanCollide', false);
	end);
	OffButton.MouseEnter:Connect(function ()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Hover"))
	end);

	-- Hook up manual triggering
	local SignatureButton = UI:WaitForChild('Title'):WaitForChild('Signature')
	ListenForManualWindowTrigger(CollisionTool.ManualText, CollisionTool.Color.Color, SignatureButton)

	-- Update the UI every 0.1 seconds
	UIUpdater = Support.ScheduleRecurringTask(UpdateUI, 0.1);

end;

function UpdateUI()
	-- Updates information on the UI

	-- Make sure the UI's on
	if not UI then
		return;
	end;

	-- Check the common collision status of selection
	local Collision = Support.IdentifyCommonProperty(Selection.Parts, 'CanCollide');

	-- Update the collision option switch
	if Collision == true then
		Core.ToggleSwitch('On', UI.Status);

	-- If the selection has collision disabled
	elseif Collision == false then
		Core.ToggleSwitch('Off', UI.Status);

	-- If the collision status varies, don't select a current switch
	elseif Collision == nil then
		Core.ToggleSwitch(nil, UI.Status);
	end;

end;

function HideUI()
	-- Hides the tool UI

	-- Make sure there's a UI
	if not UI then
		return;
	end;

	-- Hide the UI
	UI.Visible = false;

	-- Stop updating the UI
	UIUpdater:Stop();

end;

function SetProperty(Property, Value)

	-- Make sure the given value is valid
	if Value == nil or #Selection.Parts <= 0  then
		return;
	end;

	-- Start a history record
	TrackChange();

	-- Go through each part
	for _, Part in pairs(Selection.Parts) do

		-- Store the state of the part before modification
		table.insert(HistoryRecord.Before, { Part = Part, [Property] = Part[Property] });

		-- Create the change request for this part
		table.insert(HistoryRecord.After, { Part = Part, [Property] = Value });

	end;

	-- Register the changes
	RegisterChange();

end;

function BindShortcutKeys()
	-- Enables useful shortcut keys for this tool

	-- Track user input while this tool is equipped
	table.insert(Connections, Core.Services.UserInputService.InputBegan:Connect(function (InputInfo, GameProcessedEvent)

		-- Make sure this is an intentional event
		if GameProcessedEvent then
			return;
		end;

		-- Make sure this input is a key press
		if InputInfo.UserInputType ~= Enum.UserInputType.Keyboard then
			return;
		end;

		-- Make sure it wasn't pressed while typing
		if Core.Services.UserInputService:GetFocusedTextBox() then
			return;
		end;

		-- Check if the enter key was pressed
		if InputInfo.KeyCode == Enum.KeyCode.Return or InputInfo.KeyCode == Enum.KeyCode.KeypadEnter then

			-- Toggle the selection's collision status
			ToggleCollision();

		end;

	end));

end;

function ToggleCollision()
	-- Toggles the collision status of the selection

	-- Change the collision status to the opposite of the common collision status
	SetProperty('CanCollide', not Support.IdentifyCommonProperty(Selection.Parts, 'CanCollide'));

end;

function TrackChange()

	-- Start the record
	HistoryRecord = {
		Before = {};
		After = {};
		Selection = Selection.Items;

		Unapply = function (Record)
			-- Reverts this change

			-- Select the changed parts
			Selection.Replace(Record.Selection)

			-- Send the change request
			Core.SyncAPI:Invoke('SyncCollision', Record.Before);

		end;

		Apply = function (Record)
			-- Applies this change

			-- Select the changed parts
			Selection.Replace(Record.Selection)

			-- Send the change request
			Core.SyncAPI:Invoke('SyncCollision', Record.After);

		end;

	};

end;

function RegisterChange()
	-- Finishes creating the history record and registers it

	-- Make sure there's an in-progress history record
	if not HistoryRecord then
		return;
	end;

	-- Send the change to the server
	Core.SyncAPI:Invoke('SyncCollision', HistoryRecord.After);

	-- Register the record and clear the staging
	Core.History.Add(HistoryRecord);
	HistoryRecord = nil;

end;

-- Return the tool
return CollisionTool;
