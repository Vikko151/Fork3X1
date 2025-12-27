Tool = script.Parent.Parent;
Core = require(Tool.Core);
local Vendor = Tool:WaitForChild('Vendor')
local UI = Core.UIFolder
local Libraries = Core.Libraries
local Sounds = Tool:WaitForChild("Sounds");

-- Libraries
local ListenForManualWindowTrigger = require(Tool.Core:WaitForChild('ListenForManualWindowTrigger'))
local Roact = require(Vendor:WaitForChild('Roact'))
local Signal = require(Libraries:WaitForChild('Signal'))
local ColorPicker = require(UI:WaitForChild('ColorPicker'))
local BoundingBox = require(Tool.Core.BoundingBox)

-- Import relevant references
Selection = Core.Selection;
Support = Core.Support;
Security = Core.Security;

local TextService = game:GetService("TextService")
local TextSizeParams = Instance.new("GetTextBoundsParams")

local MinimalTextBoxSize

-- Initialize the tool
local TextureTool = {
	Name = 'Texture Tool';
	Color = BrickColor.new 'Bright violet';

	-- Default options
	Type = 'Decal';
	Face = Enum.NormalId.Front;
	ThumbnailMode = "None";

	-- Signals
	OnFaceChanged = Signal.new();
	ThumbnailChanged = Signal.new();
}

local ThumbnailModeToSize = {
	["Asset"] = "w=420&h=420",
	["Avatar"] = "w=720&h=720",
	["AvatarHeadShot"] = "w=150&h=150",
	["BadgeIcon"] = "w=150&h=150",
	["BundleThumbnail"] = "w=420&h=420",
	["GameIcon"] = "w=150&h=150",
	["GamePass"] = "w=150&h=150",
	["GroupIcon"] = "w=420&h=420",
	["Outfit"] = "w=420&h=420"
}

TextureTool.ManualText = [[<font weight="900" size="24"><u><i>Texture Tool  🛠</i></u></font>
Lets you add decals and textures to parts. Decals are one image fitting the whole surface, whereas textures are repeated images.<font size="6"><br /></font>

<b>TIP: </b>IDs are codes you can find on Roblox's Creator Marketplace or with the marketplace tool<font size="6"><br /></font>

<b>TIP: </b>Click on any part's surface to quickly change a decal/texture's side.<font size="6"><br /></font>

<b>TIP: </b>You can paste the link to any decal and it'll automatically get the right image ID.<font size="6"><br /></font>

<b>TIP: </b>Fast mode uses rbxthumb to load images without experiencing F3X servers slowdowns. However, the quality of the image is twice lower.<font size="6"><br /></font>

<b>NOTE: </b>If HttpService isn't enabled, you must manually type an image's ID.]]

-- Container for temporary connections (disconnected automatically)
local Connections = {};

function TextureTool:Equip()
	-- Enables the tool's equipped functionality

	-- Start up our interface
	self:ShowUI()
	self:EnableSurfaceClickSelection()
	
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

	-- Set our current texture type and face
	self:SetTextureType(self.Type)
	self:SetFace(self.Face)

end;

function TextureTool:Unequip()
	-- Disables the tool's equipped functionality

	-- Clear unnecessary resources
	self:HideUI()
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

function TextureTool:ShowUI()
	UI = Core.UIFolder
	ColorPicker = require(UI:WaitForChild('ColorPicker'))
	
	local Dropdown = require(UI:WaitForChild('Dropdown'))
	-- Creates and reveals the UI

	-- Reveal UI if already created
	if self.UI and self.UI.Parent ~= nil then

		-- Reveal the UI
		self.UI.Visible = true

		-- Update the UI every 0.1 seconds
		self.StopUpdatingUI = Support.Loop(0.1, function ()
			self:UpdateUI()
		end)

		-- Skip UI creation
		return;

	end;
	
	if self.UI then
		self.UI:Destroy()
	end

	-- Create the UI
	self.UI = Core.Interfaces.BTTextureToolGUI:Clone()
	self.UI.Parent = Core.UI
	self.UI.Visible = true
	
	-- Remove any deprecated option if using an older version of the UI
	if self.UI:FindFirstChild("FastLoadOption") then
		self.UI.FastLoadOption:Destroy()
	end
	if self.UI.ImageIDOption.TextInput:FindFirstChild("BoundingBox") then
		self.UI.ImageIDOption.TextInput.BoundingBox.TextBox.Parent = self.UI.ImageIDOption.TextInput
		self.UI.ImageIDOption.TextInput.BoundingBox:Destroy()
	end

	-- References to UI elements
	local AddButton = self.UI.AddButton
	local RemoveButton = self.UI.RemoveButton
	local DecalModeButton = self.UI.ModeOption.Decal.Button
	local TextureModeButton = self.UI.ModeOption.Texture.Button
	local ImageIdInput = self.UI.ImageIDOption.TextInput.TextBox
	local TransparencyInput = self.UI.TransparencyOption.Input.TextBox
	local RepeatXInput = self.UI.RepeatOption.XInput.TextBox
	local RepeatYInput = self.UI.RepeatOption.YInput.TextBox
	local ColorButton = self.UI.ColorOption.HSVPicker
	local ColorIndicator = self.UI.ColorOption.Indicator
	
	MinimalTextBoxSize = ImageIdInput.AbsoluteSize

	TextSizeParams.Font = ImageIdInput:GetStyled("FontFace")
	TextSizeParams.Size = ImageIdInput:GetStyled("TextSize")
	TextSizeParams.Width = math.huge
	TextSizeParams.RichText = false
	
	-- Enable the texture type switch
	DecalModeButton.MouseButton1Click:Connect(function ()
		self:SetTextureType('Decal')
	end);
	TextureModeButton.MouseButton1Click:Connect(function ()
		self:SetTextureType('Texture')
	end);

	-- Create the face selection dropdown
	local Faces = {
		'Top';
		'Bottom';
		'Front';
		'Back';
		'Left';
		'Right'
	};
	
	local Thumbnails = {
		'None';
		'Asset';
		'Avatar';
		'AvatarHeadShot';
		'BadgeIcon';
		'BundleThumbnail';
		'GameIcon';
		'GamePass';
		'GroupIcon';
		'Outfit'
	};
	
	local function BuildFaceDropdown(OptionsTable, X, CurrentOption, OptionSelected)
		return Roact.createElement(Dropdown, {
			Position = UDim2.new(0, X, 0, 0);
			Size = UDim2.new(1, -15 - X, 0, 25);
			Options = OptionsTable;
			MaxRows = 6;
			CurrentOption = CurrentOption;
			OnOptionSelected = OptionSelected;
		})
	end

	-- Mount type dropdown
	local FaceDropdownHandle = Roact.mount(BuildFaceDropdown(Faces, 30, self.Face.Name, function(Option) self:SetFace(Enum.NormalId[Option]) end), self.UI.SideOption, 'Dropdown')
	self.OnFaceChanged:Connect(function (Option)
		Roact.update(FaceDropdownHandle, BuildFaceDropdown(Faces, 30, Option.Name, function(Option) self:SetFace(Enum.NormalId[Option]) end))
	end)
	local ThumbnailDropdownHandle = Roact.mount(BuildFaceDropdown(Thumbnails, 110, self.ThumbnailMode, function(Option) self.ThumbnailChanged:Fire(Option) end), self.UI.ThumbnailOption, 'Dropdown')
	self.ThumbnailChanged:Connect(function (Option)
		self.ThumbnailMode = Option
		Roact.update(ThumbnailDropdownHandle, BuildFaceDropdown(Thumbnails, 110, self.ThumbnailMode, function(Option) self.ThumbnailChanged:Fire(Option) end))
	end)
	
--	FastLoadToggle.Activated:Connect(function()
--		self.FastLoad = not self.FastLoad
--		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Press"))
--		UpdateToggleInput(FastLoadToggle, self.FastLoad)
--	end)

	-- Enable the image ID input
	ImageIdInput.FocusLost:Connect(function (EnterPressed)
		SetTextureId(TextureTool.Type, TextureTool.Face, tonumber(ParseAssetId(ImageIdInput.Text)) or ImageIdInput.Text);
	end);

	-- Enable other inputs
	SyncInputToProperty('Transparency', TransparencyInput);
	SyncInputToProperty('StudsPerTileU', RepeatXInput);
	SyncInputToProperty('StudsPerTileV', RepeatYInput);

	-- Enable the texture adding button
	AddButton.Button.MouseButton1Click:Connect(function ()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Add"))
		AddTextures(TextureTool.Type, TextureTool.Face);
	end);
	AddButton.Button.MouseEnter:Connect(function ()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Hover"))
	end);
	RemoveButton.Button.MouseButton1Click:Connect(function ()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Remove"))
		RemoveTextures(TextureTool.Type, TextureTool.Face);
	end);
	RemoveButton.Button.MouseEnter:Connect(function ()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Hover"))
	end);
	
	local ColorPickerHandle = nil
	ColorButton.MouseButton1Click:Connect(function ()
		local CommonColor = Support.IdentifyCommonProperty(GetTextures(TextureTool.Type, TextureTool.Face), "Color3")
		local ColorPickerElement = Roact.createElement(ColorPicker, {
			InitialColor = CommonColor or Color3.fromRGB(255, 255, 255);
			SetPreviewColor = function (Color)
				SetPreviewColor(TextureTool.Type, "Color3", Color)
			end;
			OnConfirm = function (Color)
				SetProperty(TextureTool.Type, TextureTool.Face, "Color3", Color)
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
	local SignatureButton = self.UI:WaitForChild('Title'):WaitForChild('Signature')
	ListenForManualWindowTrigger(TextureTool.ManualText, TextureTool.Color.Color, SignatureButton)
	
	TextureTool:ChangeLayout(Layouts.EmptySelection)

	-- Update the UI every 0.1 seconds
	self.StopUpdatingUI = Support.Loop(0.1, function ()
		self:UpdateUI()
	end)

end;

function SyncInputToProperty(Property, Input)
	-- Enables `Input` to change the given property

	-- Enable inputs
	Input.FocusLost:Connect(function ()
		SetProperty(TextureTool.Type, TextureTool.Face, Property, tonumber(Input.Text));
	end);

end;

function TextureTool:EnableSurfaceClickSelection()
	-- Allows for the setting of the current face by clicking

	-- Clear out any existing connection
	if Connections.SurfaceClickSelection then
		Connections.SurfaceClickSelection:Disconnect();
		Connections.SurfaceClickSelection = nil;
	end;

	-- Add the new click connection
	Connections.SurfaceClickSelection = Core.Mouse.Button1Down:Connect(function ()
		local _, ScopeTarget = Core.Targeting:UpdateTarget()
		if Selection.IsSelected(ScopeTarget) then
			self:SetFace(Core.Mouse.TargetSurface)
		end
	end)

end;

local PreviewInitialState = nil

function SetPreviewColor(TextType, Property, Color)

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
		for _, Text in pairs(GetTextures(TextType, TextureTool.Face)) do
			PreviewInitialState[Text] = { [Property] = Text[Property] }
		end
	end

	-- Apply preview color
	for Text in pairs(PreviewInitialState) do
		Text[Property] = Color
	end
end

function UpdateColorIndicator(Indicator, Color)
	-- Updates the given color indicator

	-- If there is a single color, just display it
	if Color then
		Indicator.BackgroundColor3 = Color;
		Indicator.Varies.Text = '';

		-- If the colors vary, display a * on a gray background
	else
		Indicator.BackgroundColor3 = Color3.new(222/255, 222/255, 222/255);
		Indicator.Varies.Text = '*';
	end;

end;

function TextureTool:HideUI()
	-- Hides the tool UI

	-- Make sure there's a UI
	if not self.UI then
		return;
	end;

	-- Hide the UI
	self.UI.Visible = false

	-- Stop updating the UI
	self.StopUpdatingUI()

end;

function GetTextures(TextureType, Face)
	-- Returns all the textures in the selection

	local Textures = {};

	-- Get any textures from any selected parts
	for _, Part in pairs(Selection.Parts) do
		for _, Child in pairs(Part:GetChildren()) do

			-- If this child is texture we're looking for, collect it
			if Child.ClassName == TextureType and Child.Face == Face then
				table.insert(Textures, Child);
			end;

		end;
	end;

	-- Return the found textures
	return Textures;

end;

-- List of creatable textures
local TextureTypes = { 'Decal', 'Texture' };

-- List of UI layouts
Layouts = {
	EmptySelection = { 'SelectNote' };
	NoTextures = { 'ModeOption', 'SideOption', 'ThumbnailOption', 'AddButton' };
	SomeDecals = { 'ModeOption', 'SideOption', 'ThumbnailOption', 'ImageIDOption', 'TransparencyOption', 'ColorOption', 'AddButton',  'RemoveButton' };
	AllDecals = { 'ModeOption', 'SideOption', 'ThumbnailOption', 'ImageIDOption', 'TransparencyOption', 'ColorOption', 'RemoveButton'};
	SomeTextures = { 'ModeOption', 'SideOption', 'ThumbnailOption', 'ImageIDOption', 'TransparencyOption', 'RepeatOption', 'ColorOption', 'AddButton', 'RemoveButton' };
	AllTextures = { 'ModeOption', 'SideOption', 'ThumbnailOption', 'ImageIDOption', 'TransparencyOption', 'RepeatOption', 'ColorOption', 'RemoveButton' };
};

-- List of UI elements
local UIElements = { 'SelectNote', 'ColorOption', 'ThumbnailOption', 'ModeOption', 'SideOption', 'ImageIDOption', 'TransparencyOption', 'RepeatOption', 'AddButton', 'RemoveButton' };

-- Current UI layout
local CurrentLayout;

function TextureTool:ChangeLayout(Layout)
	-- Sets the UI to the given layout

	-- Make sure the new layout isn't already set
	if CurrentLayout == Layout then
		return;
	end;

	-- Set this as the current layout
	CurrentLayout = Layout;

	-- Reset the UI
	for _, ElementName in pairs(UIElements) do
		local Element = self.UI[ElementName]
		Element.Visible = false;
	end;

	-- Keep track of the total vertical extents of all items
	local Sum = 0;

	-- Go through each layout element
	for ItemIndex, ItemName in ipairs(Layout) do

		local Item = self.UI[ItemName]

		-- Make the item visible
		Item.Visible = true;

		-- Position this item underneath the past items
		Item.Position = UDim2.new(0, 0, 0, 20) + UDim2.new(
			Item.Position.X.Scale,
			Item.Position.X.Offset,
			0,
			Sum + 10
		);

		-- Update the sum of item heights
		Sum = Sum + 10 + Item.AbsoluteSize.Y;

	end;

	-- Resize the container to fit the new layout
	self.UI.Size = UDim2.new(0, 240, 0, 30 + Sum)

end;

local LastText = ""

function TextureTool:UpdateUI()
	-- Updates information on the UI

	-- Make sure the UI's on
	if not self.UI then
		return;
	end;

	-- Get the textures in the selection
	local Textures = GetTextures(TextureTool.Type, TextureTool.Face);

	-- References to UI elements
	local ImageIdInput = self.UI.ImageIDOption.TextInput.TextBox;
	local TransparencyInput = self.UI.TransparencyOption.Input.TextBox;
	local ColorIndicator = self.UI.ColorOption.Indicator;

	-----------------------
	-- Update the UI layout
	-----------------------

	-- Get the plural version of the current texture type
	local PluralTextureType = TextureTool.Type .. 's';

	-- Figure out the necessary UI layout
	if #Selection.Parts == 0 then
		self:ChangeLayout(Layouts.EmptySelection)
		return;

	-- When the selection has no textures
	elseif #Textures == 0 then
		self:ChangeLayout(Layouts.NoTextures)
		return;

	-- When only some selected items have textures
	elseif #Selection.Parts ~= #Textures then
		self:ChangeLayout(Layouts['Some' .. PluralTextureType])

	-- When all selected items have textures
	elseif #Selection.Parts == #Textures then
		self:ChangeLayout(Layouts['All' .. PluralTextureType])
	end;

	------------------------
	-- Update UI information
	------------------------

	-- Get the common properties
	local ImageId = Support.IdentifyCommonProperty(Textures, 'Texture');
	local Transparency = Support.IdentifyCommonProperty(Textures, 'Transparency');
	local Color = Support.IdentifyCommonProperty(Textures, 'Color3');

	-- Update the common inputs
	UpdateDataInputs {
		[ImageIdInput] = ImageId and ParseAssetId(ImageId) or ImageId or '*';
		[TransparencyInput] = Transparency and Support.Round(Transparency, 3) or '*';
	};

	-- Update texture-specific information on UI
	if TextureTool.Type == 'Texture' then

		-- Get texture-specific UI elements
		local RepeatXInput = self.UI.RepeatOption.XInput.TextBox
		local RepeatYInput = self.UI.RepeatOption.YInput.TextBox

		-- Get texture-specific common properties
		local RepeatX = Support.IdentifyCommonProperty(Textures, 'StudsPerTileU');
		local RepeatY = Support.IdentifyCommonProperty(Textures, 'StudsPerTileV');

		-- Update inputs
		UpdateColorIndicator(ColorIndicator, Support.IdentifyCommonProperty(Textures, 'Color3'));
		UpdateDataInputs {
			[RepeatXInput] = RepeatX and Support.Round(RepeatX, 3) or '*';
			[RepeatYInput] = RepeatY and Support.Round(RepeatY, 3) or '*';
		};

	end;
	
	TextSizeParams.Text = ImageIdInput.Text

	--BoundingBox.Text = TextInput.Text
	local Size = TextService:GetTextBoundsAsync(TextSizeParams)

	ImageIdInput.Size = UDim2.new(0, math.max(Size.X, MinimalTextBoxSize.X), 1, -ImageIdInput.Parent.ScrollBarThickness) 

	if ImageIdInput.Text ~= LastText and ImageIdInput:IsFocused() then
		ImageIdInput.Parent.CanvasPosition = Vector2.new(ImageIdInput.Parent.AbsoluteCanvasSize.X - MinimalTextBoxSize.X, 0)
	end

	LastText = ImageIdInput.Text

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

function ParseAssetId(Input)
	-- Returns the intended asset ID for the given input

	-- Get the ID number from the input
	local Id = tonumber(Input)
		or tonumber(Input:lower():match('%?id=([0-9]+)'))
		or tonumber(Input:match('/([0-9]+)/'))
		or tonumber(Input:lower():match('rbxassetid://([0-9]+)'))

	-- Return the ID
	return Id;
end;

function TextureTool:SetFace(Face)
	self.Face = Face
	self.OnFaceChanged:Fire(Face)
end

function TextureTool:SetTextureType(TextureType)

	-- Update the tool option
	self.Type = TextureType

	-- Update the UI
	Core.ToggleSwitch(TextureType, self.UI.ModeOption);
	if self.UI.AddButton.Button:IsA("TextButton") then
	self.UI.AddButton.Button.Text = 'ADD ' .. TextureType:upper();
	end
	if self.UI.RemoveButton.Button:IsA("TextButton") then
	self.UI.RemoveButton.Button.Text = 'REMOVE ' .. TextureType:upper();
	end

end;

function SetProperty(TextureType, Face, Property, Value)

	-- Make sure the given value is valid
	if not Value then
		return;
	end;

	-- Start a history record
	TrackChange();

	-- Go through each texture
	for _, Texture in pairs(GetTextures(TextureType, Face)) do

		-- Store the state of the texture before modification
		table.insert(HistoryRecord.Before, { Part = Texture.Parent, TextureType = TextureType, Face = Face, [Property] = Texture[Property] });

		-- Create the change request for this texture
		table.insert(HistoryRecord.After, { Part = Texture.Parent, TextureType = TextureType, Face = Face, [Property] = Value });

	end;

	-- Register the changes
	RegisterChange();

end;

function SetTextureId(TextureType, Face, AssetId)
	-- Sets the textures in the selection to the intended, given image asset

	-- Make sure the given asset ID is valid
	if not AssetId then
		return;
	end;
	
	local Changes
	local SearchForImage = false
	
	-- Prepare the change request
	if tonumber(AssetId) == nil then
		Changes = {
			Texture = AssetId;
		};
	elseif TextureTool.ThumbnailMode ~= "None" then
		Changes = {
			Texture = string.format("rbxthumb://type=%s&id=%d&%s", TextureTool.ThumbnailMode, AssetId, ThumbnailModeToSize[TextureTool.ThumbnailMode]);
		};
	else
		SearchForImage = true
		Changes = {
			Texture = 'rbxassetid://' .. AssetId;
		};
	end

	-- Attempt an image extraction on the given asset
	if SearchForImage == true then
	Core.Try(Core.SyncAPI.Invoke, Core.SyncAPI, 'ExtractImageFromDecal', AssetId)
		:Then(function (ExtractedImage)
			Changes.Texture = 'rbxassetid://' .. ExtractedImage;
		end);
	end

	-- Start a history record
	TrackChange();

	-- Go through each texture
	for _, Texture in pairs(GetTextures(TextureType, Face)) do

		-- Create the history change requests for this texture
		local Before, After = { Part = Texture.Parent, TextureType = TextureType, Face = Face }, { Part = Texture.Parent, TextureType = TextureType, Face = Face };

		-- Gather change information to finish up the history change requests
		for Property, Value in pairs(Changes) do
			Before[Property] = Texture[Property];
			After[Property] = Value;
		end;

		-- Store the state of the texture before modification
		table.insert(HistoryRecord.Before, Before);

		-- Create the change request for this texture
		table.insert(HistoryRecord.After, After);

	end;

	-- Register the changes
	RegisterChange();

end;

function AddTextures(TextureType, Face)

	-- Prepare the change request for the server
	local Changes = {};

	-- Go through the selection
	for _, Part in pairs(Selection.Parts) do

		-- Make sure this part doesn't already have a texture of the same type
		local HasTextures;
		for _, Child in pairs(Part:GetChildren()) do
			if Child.ClassName == TextureType and Child.Face == Face then
				HasTextures = true;
			end;
		end;

		-- Queue a texture to be created for this part, if not already existent
		if not HasTextures then
			table.insert(Changes, { Part = Part, TextureType = TextureType, Face = Face });
		end;

	end;

	-- Send the change request to the server
	local Textures = Core.SyncAPI:Invoke('CreateTextures', Changes);

	-- Put together the history record
	local HistoryRecord = {
		Textures = Textures;
		Selection = Selection.Items;

		Unapply = function (Record)
			-- Reverts this change

			-- Select changed parts
			Selection.Replace(Record.Selection)

			-- Remove the textures
			Core.SyncAPI:Invoke('Remove', Record.Textures);

		end;

		Apply = function (Record)
			-- Reapplies this change

			-- Restore the textures
			Core.SyncAPI:Invoke('UndoRemove', Record.Textures);

			-- Select changed parts
			Selection.Replace(Record.Selection)

		end;

	};

	-- Register the history record
	Core.History.Add(HistoryRecord);

end;

function RemoveTextures(TextureType, Face)

	-- Get all the textures in the selection
	local Textures = GetTextures(TextureType, Face);

	-- Create the history record
	local HistoryRecord = {
		Textures = Textures;
		Selection = Selection.Items;

		Unapply = function (Record)
			-- Reverts this change

			-- Restore the textures
			Core.SyncAPI:Invoke('UndoRemove', Record.Textures);

			-- Select changed parts
			Selection.Replace(Record.Selection)

		end;

		Apply = function (Record)
			-- Reapplies this change

			-- Select changed parts
			Selection.Replace(Record.Selection)

			-- Remove the textures
			Core.SyncAPI:Invoke('Remove', Record.Textures);

		end;

	};

	-- Send the removal request
	Core.SyncAPI:Invoke('Remove', Textures);

	-- Register the history record
	Core.History.Add(HistoryRecord);

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
			Core.SyncAPI:Invoke('SyncTexture', Record.Before);

		end;

		Apply = function (Record)
			-- Applies this change

			-- Select the changed parts
			Selection.Replace(Record.Selection)

			-- Send the change request
			Core.SyncAPI:Invoke('SyncTexture', Record.After);

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
	Core.SyncAPI:Invoke('SyncTexture', HistoryRecord.After);

	-- Register the record and clear the staging
	Core.History.Add(HistoryRecord);
	HistoryRecord = nil;

end;

-- Return the tool
return TextureTool;
