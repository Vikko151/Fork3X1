Tool = script.Parent.Parent;
Core = require(Tool.Core);
Sounds = Tool:WaitForChild("Sounds");
local Vendor = Tool:WaitForChild('Vendor')
local UI = Core.UIFolder
local Libraries = Core.Libraries

-- Libraries
local ListenForManualWindowTrigger = require(Tool.Core:WaitForChild('ListenForManualWindowTrigger'))
local Roact = require(Vendor:WaitForChild('Roact'))
local ColorPicker = require(UI:WaitForChild('ColorPicker'))
local Dropdown = require(UI:WaitForChild('Dropdown'))
local Signal = require(Libraries:WaitForChild('Signal'))

local TextService = game:GetService("TextService")
local TextSizeParams = Instance.new("GetTextBoundsParams")

local MinimalTextBoxSize
local Last


-- Import relevant references
Selection = Core.Selection;
Support = Core.Support;
Security = Core.Security;

-- Initialize the tool
local AttachmentTool = {
	Name = 'Attachment Tool';
	Color = BrickColor.new 'Lime green';

	-- State
	CurrentType = nil;

	-- Signals
	OnTypeChanged = Signal.new();
}

if table.find(Core.Options.ToolsBlacklist, AttachmentTool.Name) then
	return AttachmentTool
end


AttachmentTool.ManualText = [[<font weight="900" size="24"><u><i>Attachment Tool  ??</i></u></font>
The attachment tool allows you to create attachments. These are positions that can be used for constraints, particle emitters and for pivots.<font size="6"><br /></font>

<b>TIP:</b> The coordinates indicated with this tool are related to the part's position.

<b>TIP:</b> Remember! If you select your attachment first and that you use a movement tool on last, it can be used as a pivot!]]

-- Container for temporary connections (disconnected automatically)
local Connections = {};

function AttachmentTool.Equip()
	-- Enables the tool's equipped functionality

	-- Start up our interface
	ShowUI();

end;

function AttachmentTool.Unequip()
	-- Disables the tool's equipped functionality

	-- Clear unnecessary resources
	HideUI();
	ClearConnections();

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
	if AttachmentTool.UI and AttachmentTool.UI.Parent ~= nil then

		-- Reveal the UI
		AttachmentTool.UI.Visible = true;

		-- Update the UI every 0.1 seconds
		UIUpdater = Support.ScheduleRecurringTask(UpdateUI, 0.1);

		-- Skip UI creation
		return;

	end;
	
	if AttachmentTool.UI then
		AttachmentTool.UI:Destroy()
	end

	-- Create the UI
	AttachmentTool.UI = Core.Interfaces.BTAttachmentToolGUI:Clone();
	AttachmentTool.UI.Parent = Core.UI;
	AttachmentTool.UI.Visible = true;

	local AddButton = AttachmentTool.UI.AddButton;
	local RemoveButton = AttachmentTool.UI.RemoveButton;

	-- Enable the scale inputs
	local XPositionInput = AttachmentTool.UI.PositionOption.XInput.TextBox;
	local YPositionInput = AttachmentTool.UI.PositionOption.YInput.TextBox;
	local ZPositionInput = AttachmentTool.UI.PositionOption.ZInput.TextBox;
	local NameInput = AttachmentTool.UI.NameOption.TextInput.TextBox;
	
	XPositionInput.FocusLost:Connect(function (EnterPressed)
		local NewPosition = tonumber(XPositionInput.Text);
		SetAxisPosition('X', NewPosition);
	end);
	YPositionInput.FocusLost:Connect(function (EnterPressed)
		local NewPosition = tonumber(YPositionInput.Text);
		SetAxisPosition('Y', NewPosition);
	end);
	ZPositionInput.FocusLost:Connect(function (EnterPressed)
		local NewPosition = tonumber(ZPositionInput.Text);
		SetAxisPosition('Z', NewPosition);
	end);

	MinimalTextBoxSize = NameInput.AbsoluteSize

	TextSizeParams.Font = NameInput:GetStyled("FontFace")
	TextSizeParams.Size = NameInput:GetStyled("TextSize")
	TextSizeParams.Width = math.huge
	TextSizeParams.RichText = false
	
	-- Build the attachment list
	
	local Attachments = {}
	local AttachmentsName = {}
	
	local function UpdateAttachmentsList()
		-- Reset the current tables
		local Focus = Selection.Focus
		table.clear(Attachments)
		table.clear(AttachmentsName)
		
		if Focus then
			Attachments = Focus:QueryDescendants("Attachment")
			
			for Index, Attachment in Attachments do
				AttachmentsName[Index] = Attachment.Name
			end
		end
	end
	
	-- Create material dropdown
	local function BuildAttachmentsDropdown()
		return Roact.createElement(Dropdown, {
			Position = UDim2.new(0, 80, 0, 0);
			Size = UDim2.new(0, 90, 0, 25);
			Options = AttachmentsName;
			MaxRows = 6;
			CurrentOption = Selection.Focus and Selection.Focus:IsA("Attachment") and Selection.Focus.Name or "None";
			OnOptionSelected = function (Option, Index)
				-- Find the attachment
				local Attachment = Attachments[Index]
				
				if Attachment then
					Selection.Replace({Attachment})
				end
			end;
		})
	end
	
	UpdateAttachmentsList()
	
	-- Mount surface dropdown
	local AttachmentDropdownHandle = Roact.mount(BuildAttachmentsDropdown(), AttachmentTool.UI.AttachmentOption, 'Dropdown')
	
	local ChangeConnection = function()
		UpdateAttachmentsList()
		
		Roact.update(AttachmentDropdownHandle, BuildAttachmentsDropdown())
	end
	
	Selection.FocusChanged:Connect(ChangeConnection)

	-- Enable the mesh adding button
	AddButton.Button.MouseButton1Click:Connect(function ()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Add"))
		AddAttachments();
	end);
	AddButton.Button.MouseEnter:Connect(function ()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Hover"))
	end);
	RemoveButton.Button.MouseButton1Click:Connect(function ()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Remove"))
		RemoveAttachments();
	end);
	RemoveButton.Button.MouseEnter:Connect(function ()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Hover"))
	end);
	
	-- Enable the image ID input
	NameInput.FocusLost:Connect(function (EnterPressed)
		SetProperty("Name", NameInput.Text);
	end);

	-- Hook up manual triggering
	local SignatureButton = AttachmentTool.UI:WaitForChild('Title'):WaitForChild('Signature')
	ListenForManualWindowTrigger(AttachmentTool.ManualText, AttachmentTool.Color.Color, SignatureButton)

	-- Update the UI every 0.1 seconds
	UIUpdater = Support.ScheduleRecurringTask(UpdateUI, 0.1);

end;

local LastText = ""

function UpdateUI()
	-- Updates information on the UI

	-- Make sure the UI's on
	if not AttachmentTool.UI then
		return;
	end;

	-- Get all meshes
	local Attachments = Selection.Attachments;

	-- Check if there's a file mesh in the selection

	-- Identify common scales and offsets across axes
	local XPositionVariations, YPositionVariations, ZPositionVariations = {}, {}, {};
	for _, Attachment in pairs(Selection.Attachments) do
		table.insert(XPositionVariations, Support.Round(Attachment.CFrame.X, 3));
		table.insert(YPositionVariations, Support.Round(Attachment.CFrame.Y, 3));
		table.insert(ZPositionVariations, Support.Round(Attachment.CFrame.Z, 3));
	end;
	local CommonXPosition = Support.IdentifyCommonItem(XPositionVariations);
	local CommonYPosition = Support.IdentifyCommonItem(YPositionVariations);
	local CommonZPosition = Support.IdentifyCommonItem(ZPositionVariations);

	-- Shortcuts to updating UI elements
	local AddButton = AttachmentTool.UI.AddButton;
	local RemoveButton = AttachmentTool.UI.RemoveButton;
	local XPositionInput = AttachmentTool.UI.PositionOption.XInput.TextBox;
	local YPositionInput = AttachmentTool.UI.PositionOption.YInput.TextBox;
	local ZPositionInput = AttachmentTool.UI.PositionOption.ZInput.TextBox;
	local NameInput = AttachmentTool.UI.NameOption.TextInput.TextBox;
	-- Update the inputs

	AddButton.Visible = false;
	RemoveButton.Visible = false;
	AttachmentTool.UI.PositionOption.Visible = false;
	AttachmentTool.UI.AttachmentOption.Visible = false;
	AttachmentTool.UI.NameOption.Visible = false;

	-- Update the UI to display options depending on the mesh type
	local DisplayedItems;
	if #Attachments == 0 then
		DisplayedItems = { AttachmentTool.UI.AttachmentOption, AddButton };
		-- Each selected part has a mesh
	elseif #Attachments == #Selection.Items then
		DisplayedItems = { AttachmentTool.UI.NameOption, AttachmentTool.UI.PositionOption, RemoveButton };
		
		-- Only some selected parts have meshes
	elseif #Attachments ~= #Selection.Items then
		DisplayedItems = { AttachmentTool.UI.NameOption, AttachmentTool.UI.PositionOption, AddButton, RemoveButton };

	end;
	
	TextSizeParams.Text = NameInput.Text

	--BoundingBox.Text = TextInput.Text
	local Size = TextService:GetTextBoundsAsync(TextSizeParams)

	NameInput.Size = UDim2.new(0, math.max(Size.X, MinimalTextBoxSize.X), 1, -NameInput.Parent.ScrollBarThickness) 

	if NameInput.Text ~= LastText and NameInput:IsFocused() then
		NameInput.Parent.CanvasPosition = Vector2.new(NameInput.Parent.AbsoluteCanvasSize.X - MinimalTextBoxSize.X, 0)
	end
	
	UpdateDataInputs {
		[XPositionInput] = CommonXPosition or '*';
		[YPositionInput] = CommonYPosition or '*';
		[ZPositionInput] = CommonZPosition or '*';
		[AttachmentTool.UI.NameOption.TextInput.TextBox] = Support.IdentifyCommonProperty(Attachments, 'Name');
	};

	-- Display the relevant UI elements
	DisplayLinearLayout(DisplayedItems, AttachmentTool.UI, UDim2.new(0, 0, 0, 20), 10);
	
	LastText = NameInput.Text

end;

function HideUI()
	-- Hides the tool UI

	-- Make sure there's a UI
	if not AttachmentTool.UI then
		return;
	end;

	-- Hide the UI
	AttachmentTool.UI.Visible = false;

	-- Stop updating the UI
	UIUpdater:Stop();

end;

function UpdateToggleInput(Toggle, Data)
	-- Updates the data in the given buttons

	-- Go through the inputs and data
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

function DisplayLinearLayout(Items, Container, StartPosition, Padding)

	-- Keep track of the total vertical extents of all items
	local Sum = 0;

	-- Go through each item
	for ItemIndex, Item in ipairs(Items) do

		-- Make the item visible
		Item.Visible = true;

		-- Position this item underneath the past items
		Item.Position = StartPosition + UDim2.new(
			Item.Position.X.Scale,
			Item.Position.X.Offset,
			0,
			Sum + Padding
		);

		-- Update the sum of item heights
		Sum = Sum + Padding + Item.AbsoluteSize.Y;

	end;

	-- Resize the container to fit the new layout
	Container.Size = UDim2.new(0, 220, 0, 30 + Sum);

end;

function AddAttachments()

	-- Prepare the change request for the server
	local Changes = {};

	-- Go through the selection
	for _, Part in pairs(Selection.Parts) do

			-- Queue a mesh to be created for this part
			table.insert(Changes, { Part = Part });

	end;

	-- Send the change request to the server
	local Attachments = Core.SyncAPI:Invoke('CreateAttachments', Changes);

	-- Put together the history record
	local HistoryRecord = {
		Attachments = Attachments;
		Selection = Selection.Items;

		Unapply = function (Record)
			-- Reverts this change

			-- Select changed parts
			Selection.Replace(Record.Selection)

			-- Remove the meshes
			Core.SyncAPI:Invoke('Remove', Record.Attachments);

		end;

		Apply = function (Record)
			-- Reapplies this change

			-- Restore the meshes
			Core.SyncAPI:Invoke('UndoRemove', Record.Attachments);

			-- Select changed parts
			Selection.Replace(Record.Selection)

		end;

	};

	-- Register the history record
	Core.History.Add(HistoryRecord);

	Selection.Replace(Attachments)

end;

function RemoveAttachments()

	-- Get all the meshes in the selection
	local Attachments = Selection.Attachments;

	-- Create the history record
	local HistoryRecord = {
		Attachments = Attachments;
		Selection = Selection.Items;

		Unapply = function (Record)
			-- Reverts this change

			-- Restore the meshes
			Core.SyncAPI:Invoke('UndoRemove', Record.Attachments);

			-- Select changed parts
			Selection.Replace(Record.Selection)

		end;

		Apply = function (Record)
			-- Reapplies this change

			-- Select changed parts
			Selection.Replace(Record.Selection)

			-- Remove the meshes
			Core.SyncAPI:Invoke('Remove', Record.Attachments);

		end;

	};

	-- Send the removal request
	Core.SyncAPI:Invoke('Remove', Attachments);

	-- Register the history record
	Core.History.Add(HistoryRecord);

end;


function SetProperty(Property, Value)

	-- Make sure the given value is valid
	if not Value then
		return;
	end;

	-- Start a history record
	TrackChange();

	-- Go through each mesh
	for _, Attachment in pairs(Selection.Attachments) do

		-- Store the state of the mesh before modification
		table.insert(HistoryRecord.Before, { Attachment = Attachment, [Property] = Attachment[Property] });

		-- Create the change request for this mesh
		table.insert(HistoryRecord.After, { Attachment = Attachment, [Property] = Value });

	end;

	-- Register the changes
	RegisterChange();

end;

function SetAxisPosition(Axis, Position)
	-- Sets the selection's scale on axis `Axis` to `Scale`

	-- Start a history record
	TrackChange();

	-- Go through each mesh
	for _, Attachment in pairs(Selection.Attachments) do

		-- Store the state of the mesh before modification
		table.insert(HistoryRecord.Before, { Attachment = Attachment, Position = Attachment.CFrame.Position });

		-- Put together the changed scale
		local Position = Vector3.new(
			Axis == 'X' and Position or Attachment.CFrame.X,
			Axis == 'Y' and Position or Attachment.CFrame.Y,
			Axis == 'Z' and Position or Attachment.CFrame.Z
		);

		-- Create the change request for this mesh
		table.insert(HistoryRecord.After, { Attachment = Attachment, Position = Position });

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
			Core.SyncAPI:Invoke('SyncAttachments', Record.Before);

		end;

		Apply = function (Record)
			-- Applies this change

			-- Select the changed parts
			Selection.Replace(Record.Selection)

			-- Send the change request
			Core.SyncAPI:Invoke('SyncAttachments', Record.After);

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
	Core.SyncAPI:Invoke('SyncAttachments', HistoryRecord.After);

	-- Register the record and clear the staging
	Core.History.Add(HistoryRecord);
	HistoryRecord = nil;

end;

-- Return the tool
return AttachmentTool;