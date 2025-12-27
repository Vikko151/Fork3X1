Tool = script.Parent.Parent;
Core = require(Tool.Core);
Sounds = Tool:WaitForChild("Sounds");
local BoundingBox = require(Tool.Core.BoundingBox)

-- Libraries
local ListenForManualWindowTrigger = require(Tool.Core:WaitForChild('ListenForManualWindowTrigger'))

-- Import relevant references
Selection = Core.Selection;
Support = Core.Support;
Security = Core.Security;
Services = Core.Services;

-- Initialize the tool
local AnchorTool = {

	Name = 'Anchor Tool';
	Color = BrickColor.new 'Really black';

}

if table.find(Core.Options.ToolsBlacklist, AnchorTool.Name) then
	return AnchorTool
end


AnchorTool.ManualText = [[<font weight="900" size="24"><u><i>Anchor Tool  🛠</i></u></font>
Lets you anchor and unanchor parts.<font size="6"><br /></font>



<b>TIP:</b> Press <b>Enter</b> to toggle anchor quickly.]]

--[[

<font color="rgb(150, 150, 150)">•</font>  <b>PARTICLE EMITTERS </b> <font color="rgb(150, 150, 150)"></font><b>An extremely flexible effect</b> that emits particles that can be modified.<font size="6"><br /></font>
<font color="rgb(150, 150, 150)">•</font>  <b>HIGHLIGHTS </b> <font color="rgb(150, 150, 150)"></font><b>Makes the object marked with an outline and filling.</b> This effect works on every shapes and can be seen through walls.<font size="6"><br /></font>
<font color="rgb(150, 150, 150)">•</font>  <b>SELECTION BOX </b> <font color="rgb(150, 150, 150)"></font><b>Marks the object with a box-shaped outline.</b> This effect doesn't fits every shapes, but is useful on basic parts.<font size="6"><br /></font>

<b>TIP:</b> If your highlights don't show, it's because they reached their limit.
]]

-- Container for temporary connections (disconnected automatically)
local Connections = {};

function AnchorTool.Equip()
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

function AnchorTool.Unequip()
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
	UI = Core.Interfaces.BTAnchorToolGUI:Clone();
	UI.Parent = Core.UI;
	UI.Visible = true;

	-- References to UI elements
	local AnchorButton = UI.Status.Anchored.Button;
	local UnanchorButton = UI.Status.Unanchored.Button;

	-- Enable the anchor status switch
	AnchorButton.MouseButton1Click:Connect(function ()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Press"))
		SetProperty('Anchored', true);
	end);
	AnchorButton.MouseEnter:Connect(function ()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Hover"))
	end);
	UnanchorButton.MouseButton1Click:Connect(function ()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Press"))
		SetProperty('Anchored', false);
	end);
	UnanchorButton.MouseEnter:Connect(function ()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Hover"))
	end);

	-- Hook up manual triggering
	local SignatureButton = UI:WaitForChild('Title'):WaitForChild('Signature')
	ListenForManualWindowTrigger(AnchorTool.ManualText, AnchorTool.Color.Color, SignatureButton)

	-- Update the UI every 0.1 seconds
	UIUpdater = Support.ScheduleRecurringTask(UpdateUI, 0.1);

end;

function UpdateUI()
	-- Updates information on the UI

	-- Make sure the UI's on
	if not UI then
		return;
	end;

	-- Check the common anchor status of selection
	local Anchored = Support.IdentifyCommonProperty(Selection.Parts, 'Anchored');

	-- Update the anchor option switch
	if Anchored == true then
		Core.ToggleSwitch('Anchored', UI.Status);

	-- If the selection is unanchored
	elseif Anchored == false then
		Core.ToggleSwitch('Unanchored', UI.Status);

	-- If the anchor status varies, don't select a current switch
	elseif Anchored == nil then
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
	if Value == nil or #Selection.Parts <= 0 then
		return;
	end;

	-- Start a history record
	TrackChange();

	-- Go through each part
	for _, Part in pairs(Selection.Parts) do

		-- Store the state of the part before modification
		table.insert(HistoryRecord.Before, { Part = Part, [Property] = Part[Property], CFrame = Part.CFrame });

		-- Create the change request for this part
		table.insert(HistoryRecord.After, { Part = Part, [Property] = Value, CFrame = Part.CFrame });

	end;

	-- Register the changes
	RegisterChange();

end;

function BindShortcutKeys()
	-- Enables useful shortcut keys for this tool

	-- Track user input while this tool is equipped
	table.insert(Connections, Services.UserInputService.InputBegan:Connect(function (InputInfo, GameProcessedEvent)

		-- Make sure this is an intentional event
		if GameProcessedEvent then
			return;
		end;

		-- Make sure this input is a key press
		if InputInfo.UserInputType ~= Enum.UserInputType.Keyboard then
			return;
		end;

		-- Make sure it wasn't pressed while typing
		if Services.UserInputService:GetFocusedTextBox() then
			return;
		end;

		-- Check if the enter key was pressed
		if InputInfo.KeyCode == Enum.KeyCode.Return or InputInfo.KeyCode == Enum.KeyCode.KeypadEnter then

			-- Toggle the selection's anchor status
			ToggleAnchors();

		end;

	end));

end;

function ToggleAnchors()
	-- Toggles the anchor status of the selection

	-- Change the anchor status to the opposite of the common anchor status
	SetProperty('Anchored', not Support.IdentifyCommonProperty(Selection.Parts, 'Anchored'));

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
			Core.SyncAPI:Invoke('SyncAnchor', Record.Before);

		end;

		Apply = function (Record)
			-- Applies this change

			-- Select the changed parts
			Selection.Replace(Record.Selection)

			-- Send the change request
			Core.SyncAPI:Invoke('SyncAnchor', Record.After);

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
	Core.SyncAPI:Invoke('SyncAnchor', HistoryRecord.After);

	-- Register the record and clear the staging
	Core.History.Add(HistoryRecord);
	HistoryRecord = nil;

end;

-- Return the tool
return AnchorTool;
