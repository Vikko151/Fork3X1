Tool = script.Parent.Parent;
Core = require(Tool.Core);
local Vendor = Tool:WaitForChild('Vendor')
local UI = Core.UIFolder
local Libraries = Core.Libraries

local Options = Tool:WaitForChild("Options", 1) and require(Tool.Options)

-- Services
local CollectionService = game:GetService('CollectionService')
local ContextActionService = game:GetService 'ContextActionService'

-- Libraries
local ListenForManualWindowTrigger = require(Tool.Core:WaitForChild('ListenForManualWindowTrigger'))
local Roact = require(Vendor:WaitForChild('Roact'))
local Signal = require(Libraries:WaitForChild('Signal'))

-- Import relevant references
Selection = Core.Selection;
Support = Core.Support;
Security = Core.Security;

-- Initialize the tool
local NewPartTool = {
	Name = 'New Part Tool';
	Color = BrickColor.new 'Really black';

	-- Default options
	Type = 'Normal';

	-- Signals
	OnTypeChanged = Signal.new();
}

if table.find(Core.Options.ToolsBlacklist, NewPartTool.Name) then
	return NewPartTool
end

NewPartTool.ManualText = [[<font weight="900" size="24"><u><i>New Part Tool  🛠</i></u></font>
Lets you create new parts.<font size="6"><br /></font>

<b>TIP:</b> Click and drag where you want your part to be.]]

-- Container for temporary connections (disconnected automatically)
local Connections = {};

function NewPartTool:Equip()
	-- Enables the tool's equipped functionality

	-- Start up our interface
	self:ShowUI()
	EnableClickCreation();

	-- Set our current type
	self:SetType(NewPartTool.Type)

end;

function NewPartTool:Unequip()
	-- Disables the tool's equipped functionality

	-- Clear unnecessary resources
	self:HideUI()
	ClearConnections();
	ContextActionService:UnbindAction('BT: Create part')

end;

function ClearConnections()
	-- Clears out temporary connections

	for ConnectionKey, Connection in pairs(Connections) do
		Connection:Disconnect();
		Connections[ConnectionKey] = nil;
	end;

end;

function NewPartTool:ShowUI()
	UI = Core.UIFolder
	
	local Dropdown = require(UI:WaitForChild('Dropdown'))
	
	-- Creates and reveals the UI

	-- Reveal UI if already created
	if self.UI and self.UI.Parent ~= nil then

		-- Reveal the UI
		self.UI.Visible = true;

		-- Skip UI creation
		return;

	end;
	
	if self.UI then
		self.UI:Destroy()
	end

	-- Create the UI
	self.UI = Core.Interfaces.BTNewPartToolGUI:Clone()
	self.UI.Parent = Core.UI
	self.UI.Visible = true

	-- Creatable part types
	Types = {
		'Normal';
		'Truss';
		'Wedge';
		'Corner';
		'Cylinder';
		'Ball';
		'Seat';
		'Vehicle Seat';
		'Spawn';
		'Tool';
	}
	
	local CustomPartTypes = type(Options.CustomPartTypes) == "function" and Options.CustomPartTypes() or Options.CustomPartTypes
	
	for Type, _ in CustomPartTypes do
		table.insert(Types, Type)
	end
	
	for _, Type in Options.InstanceBlacklist do
		local Index = table.find(Types, Type)
		if Index then
			table.remove(Types, Index)
		end
	end
	


	-- Create type dropdown
	local function BuildTypeDropdown()
		return Roact.createElement(Dropdown, {
			Position = UDim2.new(0, 70, 0, 0);
			Size = UDim2.new(0, 140, 0, 25);
			Options = Types;
			MaxRows = 5;
			CurrentOption = self.Type;
			OnOptionSelected = function (Option)
				self:SetType(Option)
			end;
		})
	end

	-- Mount type dropdown
	local TypeDropdownHandle = Roact.mount(BuildTypeDropdown(), self.UI.TypeOption, 'Dropdown')
	self.OnTypeChanged:Connect(function ()
		Roact.update(TypeDropdownHandle, BuildTypeDropdown())
	end)

	-- Hook up manual triggering
	local SignatureButton = self.UI:WaitForChild('Title'):WaitForChild('Signature')
	ListenForManualWindowTrigger(NewPartTool.ManualText, NewPartTool.Color.Color, SignatureButton)
end

function NewPartTool:HideUI()
	-- Hides the tool UI

	-- Make sure there's a UI
	if not self.UI then
		return
	end

	-- Hide the UI
	self.UI.Visible = false

end;

function NewPartTool:SetType(Type)
	if self.Type ~= Type then
		self.Type = Type
		self.OnTypeChanged:Fire(Type)
	end
end

function EnableClickCreation()
	-- Allows the user to click anywhere and create a new part

	local function CreateAtTarget(Action, State, Input)

		-- Drag new parts
		if State.Name == 'Begin' then
			DragNewParts = true
			Core.Targeting.CancelSelecting()

			-- Create new part
			CreatePart(NewPartTool.Type)

		-- Disable dragging on release
		elseif State.Name == 'End' then
			DragNewParts = nil
		end

	end

	-- Register input handler
	ContextActionService:BindAction('BT: Create part', CreateAtTarget, false,
		Enum.UserInputType.MouseButton1,
		Enum.UserInputType.Touch
	)

end;

function CreatePart(Type)

	-- Send the creation request to the server
	local Part, replicationTag = Core.SyncAPI:Invoke('CreatePart', Type, CFrame.new(Core.Mouse.Hit.p), Core.Targeting.Scope)

	-- Use the replication tag to wait for the part if it's not ready
	if (Part == nil) and replicationTag then
		local existingMarker = CollectionService:GetTagged(replicationTag)[1]
		if existingMarker then
			Part = existingMarker.Parent
		else
			Part = CollectionService:GetInstanceAddedSignal(replicationTag):Wait().Parent
		end
	end

	-- Make sure the part creation succeeds
	if not Part then
		return;
	end;

	-- Put together the history record
	local HistoryRecord = {
		Part = Part;

		Unapply = function (HistoryRecord)
			-- Reverts this change

			-- Remove the part
			Core.SyncAPI:Invoke('Remove', { HistoryRecord.Part });

		end;

		Apply = function (HistoryRecord)
			-- Reapplies this change

			-- Restore the part
			Core.SyncAPI:Invoke('UndoRemove', { HistoryRecord.Part });

		end;

	};

	-- Register the history record
	Core.History.Add(HistoryRecord);

	-- Select the part
	Selection.Replace({ Part });

	-- Switch to the move tool if it's whitelisted
	if not table.find(Core.Options.ToolsBlacklist, "Move Tool") then
		local MoveTool = require(Core.Tools.Move);
		Core.EquipTool(MoveTool);
		-- Enable dragging to allow easy positioning of the created part
		if DragNewParts then
			MoveTool.FreeDragging:SetUpDragging(Part)
		end;
	end
	
end;

-- Return the tool
return NewPartTool;
