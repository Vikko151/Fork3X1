Tool = script.Parent.Parent;
Core = require(Tool.Core);
Sounds = Tool:WaitForChild("Sounds");
local Vendor = Tool:WaitForChild('Vendor')
local UIFolder = Core.UIFolder
local Libraries = Core.Libraries

-- Libraries
local ListenForManualWindowTrigger = require(Tool.Core:WaitForChild('ListenForManualWindowTrigger'))
local ColorPicker = require(UIFolder:WaitForChild('ColorPicker'))
local Roact = require(Vendor:WaitForChild('Roact'))
local Signal = require(Libraries:WaitForChild('Signal'))
local BoundingBox = require(Tool.Core.BoundingBox)

-- Import relevant references
Selection = Core.Selection;
Support = Core.Support;
Security = Core.Security;
Support.ImportServices();

-- Initialize the tool
local WeldTool = {
	Name = 'Constraint Tool';
	Color = BrickColor.new 'Really black';
	CurrentType = 'Weld';

	OnTypeChanged = Signal.new();
	OnActionChanged = Signal.new();
}

local ActionList = {
	[Enum.ActuatorType.None] = "None",
	[Enum.ActuatorType.Motor] = "Motor",
	[Enum.ActuatorType.Servo] = "Servo"
}

WeldTool.ManualText = [[<font weight="900" size="24"><u><i>Constraint Tool  🛠</i></u></font>
Allows you to attach parts to hold them together.<font size="6"><br /></font>

The constraint tool allows you to create 4 kinds of attachments:

<font color="rgb(150, 150, 150)">•</font>  <b>WELDS</b> <font color="rgb(150, 150, 150)">—</font> Attaches parts together <b>without allowing modifications of the relative distance and rotation.</b>

<font color="rgb(150, 150, 150)">•</font>  <b>ROPES</b> <font color="rgb(150, 150, 150)">—</font> Attaches parts together <b>with a rope. The part(s) is/are only constrainted on having a max. distance with the other one.</b>

<font color="rgb(150, 150, 150)">•</font>  <b>RODS</b> <font color="rgb(150, 150, 150)">—</font> Attaches parts together <b>with a solid rope. The target part has a fixed distance with the other one(s) that can still spin around it like an axis.</b>

<font color="rgb(150, 150, 150)">•</font>  <b>HINGES</b> <font color="rgb(150, 150, 150)">—</font> Attaches parts together <b>with a hinge. Every parts will spin around it on a single axis.</b>

<b>NOTE: </b>Welds may break if parts are individually moved.]]

-- Container for temporary connections (disconnected automatically)
local Connections = {};

function WeldTool.Equip()
	-- Enables the tool's equipped functionality

	-- Start up our interface
	ShowUI();
	
	if Core.Options.HighlightFocus == false then
		EnableFocusHighlighting();
	end
	
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

function WeldTool.Unequip()
	-- Disables the tool's equipped functionality

	-- Clear unnecessary resources
	HideUI();
	ClearConnections();
	BoundingBox.ClearBoundingBox();

end;

function WeldTool:SetType(Type)
	WeldTool.CurrentType = Type
	WeldTool.OnTypeChanged:Fire(Type)
end

function ClearConnections()
	-- Clears out temporary connections

	for ConnectionKey, Connection in pairs(Connections) do
		Connection:Disconnect();
		Connections[ConnectionKey] = nil;
	end;

end;

function ShowUI()
	UIFolder = Core.UIFolder
	
	local ColorPicker = require(UIFolder:WaitForChild('ColorPicker'))
	
	local Dropdown = require(UIFolder:WaitForChild('Dropdown'))
	-- Creates and reveals the UI

	-- Reveal UI if already created
	if WeldTool.UI and WeldTool.UI.Parent ~= nil then

		-- Reveal the UI
		UI.Visible = true;
		
		-- Make the UI refreshing again
		WeldTool.StopUpdatingUI = Support.Loop(0.1, function ()
			WeldTool:UpdateUI()
		end)

		-- Skip UI creation
		return;

	end;
	
	if WeldTool.UI then
		WeldTool.UI:Destroy()
	end

	-- Create the UI
	UI = Core.Interfaces.BTWeldToolGUI:Clone();
	UI.Parent = Core.UI;
	UI.Visible = true;
	
	WeldTool.UI = UI;

	-- Hook up the buttons
	UI.Interface.WeldButton.MouseButton1Click:Connect(function()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Press"))
		CreateConstraints(WeldTool.CurrentType)
	end);
	UI.Interface.WeldButton.MouseEnter:Connect(function()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Hover"))
	end);
	UI.Interface.BreakWeldsButton.MouseButton1Click:Connect(function()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Press"))
		BreakConstraints(WeldTool.CurrentType)
	end);
	UI.Interface.BreakWeldsButton.MouseEnter:Connect(function()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Hover"))
	end);
	
	local ActuatorTypeList = Support.Values(ActionList);
	table.sort(ActionList);
	
	local ConstraintList = {
		"Weld",
		"RopeConstraint",
		"RodConstraint",
		"HingeConstraint"
	}
	
	for _, Type in Core.Options.ConstraintsBlacklist do
		local Index = table.find(ConstraintList, Type)
		if Index then
			table.remove(ConstraintList, Index)
		end
	end

	local function BuildTypeDropdown()
		return Roact.createElement(Dropdown, {
			Position = UDim2.new(0, 30, 0, 0);
			Size = UDim2.new(1, -45, 0, 25);
			Options = ConstraintList;
			MaxRows = #ConstraintList;
			CurrentOption = WeldTool.CurrentType;
			OnOptionSelected = function (Option)
				WeldTool:SetType(Option)
			end;
		})
	end
	
	local function BuildActionDropdown()
		return Roact.createElement(Dropdown, {
			Position = UDim2.new(0, 30, 0, 0);
			Size = UDim2.new(1, -45, 0, 25);
			Options = ActuatorTypeList;
			MaxRows = 3;
			CurrentOption = WeldTool.CurrentAction and WeldTool.CurrentAction.Name;
			OnOptionSelected = function (Option)
				SetProperty(WeldTool.CurrentType, 'ActuatorType', Support.FindTableOccurrence(ActionList, Option))
			end;
		})
	end

	local TypeDropdownHandle = Roact.mount(BuildTypeDropdown(), UI.TypeOption, 'Dropdown')
	local ActionDropdownHandle = Roact.mount(BuildActionDropdown(), UI.ActionOption, 'Dropdown')

	WeldTool.OnTypeChanged:Connect(function ()
		Roact.update(TypeDropdownHandle, BuildTypeDropdown())
	end)
	WeldTool.OnActionChanged:Connect(function ()
		Roact.update(ActionDropdownHandle, BuildActionDropdown())
	end)

	local ColorButton = UI:WaitForChild("ColorOption").HSVPicker
	local ThicknessInput = UI.ThicknessOption.Input.TextBox;
	local LengthInput = UI.LengthOption.Input.TextBox;
	local RadiusInput = UI.RadiusOption.Input.TextBox;
	local SpeedInput = UI.SpeedOption.Input.TextBox;
	local MaxSpeedInput = UI.MaxSpeedOption.Input.TextBox;
	local AngleInput = UI.AngleOption.Input.TextBox;
	local VisibleToggle = UI.VisibleOption.Check

	SyncInputToProperty('Thickness', ThicknessInput);
	SyncInputToProperty('Length', LengthInput);
	SyncInputToProperty('Radius', RadiusInput);
	SyncInputToProperty('Speed', SpeedInput);
	SyncInputToProperty('MaxSpeed', MaxSpeedInput);
	SyncInputToProperty('TargetAngle', AngleInput);
	
	VisibleToggle.Activated:Connect(function ()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Press"))
		if Support.IdentifyCommonProperty(GetConstraints(WeldTool.CurrentType), "Visible") == false then
			SetProperty(WeldTool.CurrentType, "Visible", true);
		else
			SetProperty(WeldTool.CurrentType, "Visible", false);	
		end
	end);

	local ColorPickerHandle = nil
	ColorButton.Activated:Connect(function ()
		local CommonColor = Support.IdentifyCommonProperty(GetConstraints(WeldTool.CurrentType), "Color")
		local ColorPickerElement = Roact.createElement(ColorPicker, {
			InitialColor = CommonColor.Color or Color3.fromRGB(255, 255, 255);
			SetPreviewColor = function (Color)
				if Color == nil then return end
				SetPreviewColor("Color", BrickColor.new(Color))
			end;
			OnConfirm = function (Color)
				SetProperty(WeldTool.CurrentType, "Color", BrickColor.new(Color))
				ColorPickerHandle = Roact.unmount(ColorPickerHandle)
			end;
			OnCancel = function ()
				ColorPickerHandle = Roact.unmount(ColorPickerHandle)
			end;
		})
		ColorPickerHandle = ColorPickerHandle and
			Roact.update(ColorPickerHandle, ColorPickerElement) or
			Roact.mount(ColorPickerElement, Core.UI, 'ColorPicker')
	end)

	-- Hook up manual triggering
	local SignatureButton = UI:WaitForChild('Title'):WaitForChild('Signature')
	ListenForManualWindowTrigger(WeldTool.ManualText, WeldTool.Color.Color, SignatureButton)

	WeldTool.StopUpdatingUI = Support.Loop(0.1, function ()
		WeldTool:UpdateUI()
	end)
end;

function SyncInputToProperty(Property, Input)
	-- Enables `Input` to change the given property

	-- Enable inputs
	Input.FocusLost:Connect(function ()
		SetProperty(WeldTool.CurrentType, Property, Input.Text);
	end);

end;

local PreviewInitialState = nil

function SetPreviewColor(Property, Color)

	-- Reset colors to initial state if previewing is over
	if not Color and PreviewInitialState then
		for Text, State in pairs(PreviewInitialState) do
			Text[Property] = State[Property]
		end

		-- Clear initial state
		PreviewInitialState = nil

		-- Skip rest of function
		return

			-- Ensure valid color is given
	elseif not Color then
		return

			-- Save initial state if first time previewing
	elseif not PreviewInitialState then
		PreviewInitialState = {}
		for _, Text in pairs(GetConstraints(WeldTool.CurrentType)) do
			PreviewInitialState[Text] = { [Property] = Text[Property] }
		end
	end

	-- Apply preview color
	for Text in pairs(PreviewInitialState) do
		Text[Property] = Color
	end
end

function HideUI()
	-- Hides the tool UI

	-- Make sure there's a UI
	if not UI then
		return;
	end;

	-- Hide the UI
	UI.Visible = false;

	WeldTool.StopUpdatingUI()

end;

-- References to reduce indexing time
local GetConnectedParts = Instance.new('Part').GetConnectedParts;
local GetChildren = script.GetChildren;

function GetPartConstraint(Part, Type)
	-- Returns any BT-created ropes involving `Part`

	local Constraints = {};

	-- Get welds stored inside `Part`
	for Constraint in pairs(SearchConstraints(Part, Part, Type)) do
		Constraints[Constraint] = true;
	end;

	-- Get welds stored inside connected parts
	for _, ConnectedPart in pairs(Part:IsA("BasePart") and GetConnectedParts(Part) or GetConstraints(Part)) do
		for Constraint in pairs(SearchConstraints(ConnectedPart, Part, Type)) do
			Constraints[Constraint] = true;
		end;
	end;
	-- Return all found welds
	return Constraints;

end;

function SearchConstraints(Haystack, Part, Type)
	-- Searches for and returns BT-created welds in `Haystack` involving `Part`

	local Constraints = {};

	-- Search the haystack for welds involving `Part`
	for _, Item in pairs(GetChildren(Haystack)) do

		-- Check if this item is a BT-created weld involving the part
		if Item.Name == 'BT' .. Type and Item.ClassName == Type then
			if Type == 'Weld' and (Item.Part0 == Part or Item.Part1 == Part) then
				-- Store weld if valid
				Constraints[Item] = true;
			elseif not Item:IsA("Attachment") and (Item.Attachment0.Parent == Part or Item.Attachment1.Parent == Part) then
				Constraints[Item] = true;
			elseif (Item.Attachment0 == Part or Item.Attachment1 == Part) then
				Constraints[Item] = true;
			end
		end;

	end;

	-- Return the found welds
	return Constraints;

end;

function CreateConstraints(Type)
	-- Creates constraints for every selected part to the focused part

	-- Determine constraint creating target
	local ConstraintTarget = (Selection.Focus:IsA 'BasePart' and Selection.Focus) or
		(Selection.Focus:IsA 'Model' and Selection.Focus.PrimaryPart) or
		(Selection.Focus:IsA 'Attachment' and Selection.Focus) or
		Selection.Focus:FindFirstChildWhichIsA('BasePart', true)

	-- Send the change request to the server API
	local Constraints = Core.SyncAPI:Invoke('CreateConstraints', Selection.Parts, Selection.Attachments, ConstraintTarget, Type)

	-- Update the UI with the number of welds created
	UI.Changes.Text.Text = ('created %s ' .. string.lower(Type) .. '%s'):format(#Constraints, #Constraints == 1 and '' or 's');

	-- Put together the history record
	local HistoryRecord = {
		Constraints = Constraints;
		Type = Type;

		Unapply = function (HistoryRecord)
			-- Reverts this change

			-- Remove the welds
			Core.SyncAPI:Invoke('RemoveConstraints', HistoryRecord.Constraints, HistoryRecord.Type);

		end;

		Apply = function (HistoryRecord)
			-- Reapplies this change

			-- Restore the welds
			Core.SyncAPI:Invoke('UndoRemovedConstraints', HistoryRecord.Constraints, HistoryRecord.Type);

		end;

	};

	-- Register the history record
	Core.History.Add(HistoryRecord);

end;

function BreakConstraints(Type)

-- Search for any selection-connecting, BT-created constraints and remove them

	local Constraints = {};

	-- Find welds in selected parts
	for _, Part in pairs(Selection.Parts) do
		for Constraint in pairs(GetPartConstraint(Part, Type)) do
			Constraints[Constraint] = true;
		end;
	end;

	for _, Attachment in pairs(Selection.Attachments) do
		for _, Constraint in pairs(GetPartConstraint(Attachment, Type)) do
			Constraints[Constraint] = true;
		end;
	end;

	-- Turn weld index into list
	Constraints = Support.Keys(Constraints);

	-- Send the change request to the server API
	local ConstraintsRemoved = Core.SyncAPI:Invoke('RemoveConstraints', Constraints, Type);

	-- Update the UI with the number of welds removed
	UI.Changes.Text.Text = ('removed %s ' .. string.lower(Type) .. '%s'):format(ConstraintsRemoved, Constraints == 1 and '' or 's');

	-- Put together the history record
	local HistoryRecord = {
		Constraints = Constraints;
		Type = Type;

		Unapply = function (HistoryRecord)
			-- Reverts this change

			-- Restore the welds
			Core.SyncAPI:Invoke('UndoRemovedConstraints', HistoryRecord.Constraints, HistoryRecord.Type);

		end;

		Apply = function (HistoryRecord)
			-- Reapplies this change

			-- Remove the welds
			Core.SyncAPI:Invoke('RemoveConstraints', HistoryRecord.Constraints, HistoryRecord.Type);

		end;

	};

	-- Register the history record
	Core.History.Add(HistoryRecord);

end;

function GetConstraints(Type)

	local Constraints = {};

	-- Get any textures from any selected parts
	for _, Part in pairs(Selection.Parts) do
		for _, Child in pairs(Part:GetChildren()) do
			if Child.ClassName == Type then
				table.insert(Constraints, Child)
			end
		end;
	end;
	
	for _, Attachment in pairs(Selection.Attachments) do
		for _, Child in pairs(Attachment:GetChildren()) do
			if Child.ClassName == Type then
				table.insert(Constraints, Child)
			end
		end;
	end;

	-- Return the found textures
	return Constraints;

end

local Layouts = {
	NoConstraints = { 'TypeOption', 'Interface', 'Changes' };
	Constraints = { 'TypeOption', 'ColorOption', 'LengthOption', 'ThicknessOption', 'VisibleOption', 'Interface', 'Changes' };
	Hinges = { 'TypeOption', 'ColorOption', 'RadiusOption', 'VisibleOption', 'ActionOption', 'Interface', 'Changes' };
	Motors = { 'TypeOption', 'ColorOption', 'RadiusOption', 'VisibleOption', 'ActionOption', 'SpeedOption', 'MaxSpeedOption', 'Interface', 'Changes' };
	Servos = { 'TypeOption', 'ColorOption', 'RadiusOption', 'VisibleOption', 'ActionOption', 'SpeedOption', 'MaxSpeedOption', 'AngleOption', 'Interface', 'Changes' };
};

-- List of UI elements
local UIElements = { 'TypeOption', 'ColorOption', 'LengthOption', 'ThicknessOption', 'RadiusOption', 'VisibleOption', 'ActionOption', 'SpeedOption', 'MaxSpeedOption', 'AngleOption', 'Interface', 'Changes' };

-- Current UI layout
local CurrentLayout;

local UpdatesBeforeLayout = 3

function WeldTool:ChangeLayout(Layout)
	-- Sets the UI to the given layout

	-- Make sure the new layout isn't already set
	if CurrentLayout == Layout and UpdatesBeforeLayout > 0 then
		return;
	end;
	
	UpdatesBeforeLayout = 3

	-- Set this as the current layout
	CurrentLayout = Layout;

	-- Reset the UI
	for _, ElementName in pairs(UIElements) do
		local Element = UI[ElementName]
		Element.Visible = false;
	end;

	-- Keep track of the total vertical extents of all items
	local Sum = 0;

	-- Go through each layout element
	for ItemIndex, ItemName in ipairs(Layout) do

		local Item = UI[ItemName]

		-- Make the item visible
		Item.Visible = true;

		-- Position this item underneath the past items
		Item.Position = UDim2.new(0, 0, 0, 15) + UDim2.new(
			Item.Position.X.Scale,
			Item.Position.X.Offset,
			0,
			Sum + 10
		);

		-- Update the sum of item heights
		Sum = Sum + 10 + Item.AbsoluteSize.Y;

	end;

	-- Resize the container to fit the new layout
	UI.Size = UDim2.new(0, 225, 0, Sum - 2)

end;

function WeldTool:UpdateUI()
	-- Updates information on the UI

	-- Make sure the UI's on
	if not UI then
		return;
	end;
	
	UpdatesBeforeLayout -= 1

	local Interface = UI.Interface

	if WeldTool.CurrentType == "Weld"  then
		self:ChangeLayout(Layouts.NoConstraints)
		Interface.BreakWeldsButton.Text = "BREAK WELDS"
		Interface.WeldButton.Text = "WELD TO LAST"
	return
	elseif WeldTool.CurrentType == "RopeConstraint" then
		Interface.BreakWeldsButton.Text = "BREAK ROPES"
		Interface.WeldButton.Text = "ROPE TO LAST"
	elseif WeldTool.CurrentType == "RodConstraint" then
		Interface.BreakWeldsButton.Text = "BREAK RODS"
		Interface.WeldButton.Text = "ROD TO LAST"
	elseif WeldTool.CurrentType == "HingeConstraint" then
		Interface.BreakWeldsButton.Text = "BREAK HINGES"
		Interface.WeldButton.Text = "HINGE TO LAST"
	end

	local Constraints = GetConstraints(WeldTool.CurrentType);

	-- Get the textures in the selection

	-- References to UI elements
	local ThicknessInput = UI.ThicknessOption.Input.TextBox;
	local ColorIndicator = UI.ColorOption.Indicator;
	local LengthInput = UI.LengthOption.Input.TextBox;
	local RadiusInput = UI.RadiusOption.Input.TextBox;
	local VisibleSwitch = UI.VisibleOption.Check;
	local SpeedInput = UI.SpeedOption.Input.TextBox;
	local MaxSpeedInput = UI.MaxSpeedOption.Input.TextBox;
	local AngleInput = UI.AngleOption.Input.TextBox;


	-----------------------
	-- Update the UI layout
	-----------------------


	-- Figure out the necessary UI layout

	-- When the selection has no textures
	if #Constraints <= 0 then
		self:ChangeLayout(Layouts.NoConstraints)
--		return;
	elseif #Constraints > 0 and self.CurrentType == "HingeConstraint" then
		if self.CurrentAction == Enum.ActuatorType.None then
			self:ChangeLayout(Layouts.Hinges)
		elseif self.CurrentAction == Enum.ActuatorType.Motor then
			self:ChangeLayout(Layouts.Motors)
		else
			self:ChangeLayout(Layouts.Servos)
		end
	else
		self:ChangeLayout(Layouts['Constraints'])
	end;

	------------------------
	-- Update UI information
	------------------------

	-- Get the common properties
	
	local Actuator = self.CurrentType == "HingeConstraint" and Support.IdentifyCommonProperty(Constraints, 'ActuatorType');
	local Radius = self.CurrentType == "HingeConstraint" and Support.IdentifyCommonProperty(Constraints, 'Radius');
	local Visible = self.CurrentType == "HingeConstraint" and Support.IdentifyCommonProperty(Constraints, 'Visible');
	local Speed = self.CurrentType == "HingeConstraint" and (self.CurrentAction == Enum.ActuatorType.Motor and Support.IdentifyCommonProperty(Constraints, 'AngularVelocity') or self.CurrentAction == Enum.ActuatorType.Servo and Support.IdentifyCommonProperty(Constraints, 'AngularSpeed'));
	local Thickness =  self.CurrentType ~= "HingeConstraint" and Support.IdentifyCommonProperty(Constraints, 'Thickness');
	local Length = self.CurrentType ~= "HingeConstraint" and Support.IdentifyCommonProperty(Constraints, 'Length');
	local MaxSpeed = self.CurrentType == "HingeConstraint" and (self.CurrentAction == Enum.ActuatorType.Motor and Support.IdentifyCommonProperty(Constraints, 'MotorMaxTorque') or self.CurrentAction == Enum.ActuatorType.Servo and Support.IdentifyCommonProperty(Constraints, 'ServoMaxTorque'));
	local TargetAngle = self.CurrentType == "HingeConstraint" and self.CurrentAction == Enum.ActuatorType.Servo and Support.IdentifyCommonProperty(Constraints, 'TargetAngle');
	
	if Actuator and self.CurrentAction ~= Actuator then
		self.CurrentAction = Actuator
		self.OnActionChanged:Fire(Actuator)
	end

	-- Update the common inputs
	UpdateColorIndicator(ColorIndicator, Support.IdentifyCommonProperty(Constraints, 'Color'));
	UpdateDataInputs {
		[ThicknessInput] = Thickness and Support.Round(Thickness, 3) or '*';
		[LengthInput] = Length and Support.Round(Length, 3) or '*';
		[RadiusInput] = Radius and Support.Round(Radius, 3) or '*';
		[SpeedInput] = Speed and Support.Round(Speed, 3) or '*';
	};
	UpdateToggleInput(VisibleSwitch, Support.IdentifyCommonProperty(Constraints, 'Visible'))

end;

function UpdateColorIndicator(Indicator, Brickcolor)
	-- Updates the given color indicator

	-- If there is a single color, just display it
	if Brickcolor then
		Indicator.BackgroundColor3 = Brickcolor.Color;
		Indicator.Varies.Text = '';

		-- If the colors vary, display a * on a gray background
	else
		Indicator.BackgroundColor3 = Color3.new(222/255, 222/255, 222/255); 
		Indicator.Varies.Text = '*';
	end;

end;

function UpdateDataInputs(Data)
	-- Updates the data in the given TextBoxes when the user isn't typing in them

	-- Go through the inputs and data
	for Input, UpdatedValue in pairs(Data) do

		-- Makwe sure the user isn't typing into the input
		if not Input:IsFocused() then

			-- Set the input's value
			Input.Text = tostring(UpdatedValue);
		end;

	end;

end;

function UpdateToggleInput(Toggle, Data)
	-- Updates the data in the given buttons

	-- Go through the inputs and data
	if Core.UIFolder:FindFirstChild("Version") and Core.UIFolder.Version.Value >= 2 then
		if Data == true then
			-- Clear every UI tags
			Toggle:AddTag("STATE_True")
			Toggle:RemoveTag("STATE_Multiple")

			--			ShadowsCheckbox.Image = Core.Assets.CheckedCheckbox;
		elseif Data == false then
			-- Clear every UI tags
			Toggle:RemoveTag("STATE_True")
			Toggle:RemoveTag("STATE_Multiple")

			--			ShadowsCheckbox.Image = Core.Assets.UncheckedCheckbox;
		elseif Data == nil then
			-- Clear every UI tags
			Toggle:RemoveTag("STATE_True")
			Toggle:AddTag("STATE_Multiple")

			--			ShadowsCheckbox.Image = Core.Assets.SemicheckedCheckbox;
		end;
	else
		if Data == true then
			Toggle.Mark.Visible = true
			Toggle.Multiple.Visible = false
		elseif Data == false then
			Toggle.Mark.Visible = false
			Toggle.Multiple.Visible = false
		else
			Toggle.Mark.Visible = false
			Toggle.Multiple.Visible = true
		end
	end

end;


function EnableFocusHighlighting()
	-- Enables automatic highlighting of the focused part in the selection

	-- Only enable focus highlighting in tool mode
	if Core.Mode ~= 'Tool' then
		return;
	end;

	-- Reset all outline colors
	Core.Selection.RecolorOutlines(Core.Selection.Color);

	-- Recolor current focused item
	if Selection.Focus and (#Selection.Parts > 1) then
		Core.Selection.RecolorOutline(Selection.Focus, BrickColor.new('Deep orange'))
	end;

	-- Recolor future focused items
	Connections.FocusHighlighting = Selection.FocusChanged:Connect(function (FocusedItem)

		-- Reset all outline colors
		Core.Selection.RecolorOutlines(Core.Selection.Color);

		-- Recolor newly focused item
		if FocusedItem and (#Selection.Parts > 1) then
			Core.Selection.RecolorOutline(FocusedItem, BrickColor.new('Deep orange'))
		end;

	end);

end;


function SetProperty(Type, Property, Value)
	-- Make sure the given value is valid
	if Value == nil then
		return;
	end;
	-- Start a history record
	TrackChange();

	-- Go through each texture
	for _, Constraint in pairs(GetConstraints(Type)) do
		
		local BeforeProperty
		
		if Property == "Speed" then
			BeforeProperty = (WeldTool.CurrentAction == Enum.ActuatorType.Motor and Constraint.AngularVelocity) or Constraint.AngularSpeed
		elseif Property == "MaxSpeed" then
			BeforeProperty = (WeldTool.CurrentAction == Enum.ActuatorType.Motor and Constraint.MotorMaxTorque) or Constraint.ServoMaxTorque
		else
			BeforeProperty = Constraint[Property]
		end

		-- Store the state of the texture before modification
		table.insert(HistoryRecord.Before, { Part = Constraint.Parent, Type = Type, [Property] = BeforeProperty });

		-- Create the change request for this texture
		table.insert(HistoryRecord.After, { Part = Constraint.Parent, Type = Type, [Property] = Value });
	end;

	-- Register the changes
	RegisterChange();

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
			Core.SyncAPI:Invoke('SyncConstraints', Record.Before);

		end;

		Apply = function (Record)
			-- Applies this change

			-- Select the changed parts
			Selection.Replace(Record.Selection)

			-- Send the change request
			Core.SyncAPI:Invoke('SyncConstraints', Record.After);

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
	print(HistoryRecord.After)
	Core.SyncAPI:Invoke('SyncConstraints', HistoryRecord.After);

	-- Register the record and clear the staging
	Core.History.Add(HistoryRecord);
	HistoryRecord = nil;

end;

-- Return the tool
return WeldTool;
