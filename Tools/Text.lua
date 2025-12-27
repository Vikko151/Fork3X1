Tool = script.Parent.Parent;
Core = require(Tool.Core);
local Vendor = Tool:WaitForChild('Vendor')
local UI = Tool:WaitForChild('UI')
local Libraries = Tool:WaitForChild('Libraries')
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
local TextTool = {
	Name = 'Text Tool';
	Color = BrickColor.new 'New Yeller';

	-- Default options
	Face = Enum.NormalId.Front;
	Font = nil;

	-- Signals
	OnFaceChanged = Signal.new();
	OnRichTextChanged = Signal.new();
	OnFontChanged = Signal.new();
}

TextTool.ManualText = [[<font weight="900" size="24"><u><i>Text Tool  ??</i></u></font>
Allows the player to create text on a part.

<b>TIP: Rich text</b> allows you to modify your text with more flexibility. To use them, you must <b>mark</b> the text lik ine the following example:

&lt;b&gt;Hi!&lt;/b&gt; = <b>Hi!</b>

Here are some basic mark-ups:

&lt;b&gt;YOUR TEXT HERE&lt;/b&gt; | Bold

&lt;font color="rgb(X,Y,Z)"&gt;YOUR TEXT HERE&lt;/font&gt; | Puts color in your text. X, Y and Z are values between 0 and 255.

&lt;font size="X"&gt;YOUR TEXT HERE&lt;/font&gt; | Changes your text's size. X can be anything, as long as it is a number.

&lt;font weight="X"&gt;YOUR TEXT HERE&lt;/font&gt; | Modifies your text's weight. X can be a number or a generic name such as 'Heavy', 'Light', etc...

&lt;stroke&gt;YOUR TEXT HERE&lt;/stroke&gt; | Creates an outline/stroke around your text. You can also put &lt;stroke color="rgb(X, Y, Z)"&gt; to change its color.

&lt;font transparency="X"&gt;YOUR TEXT HERE&lt;/font&gt; | Allows you to make a part of your text transparent, X being a value between 0 and 1 (0% and 100%).

&lt;i&gt;YOUR TEXT HERE&lt;/i&gt; | Italic

&lt;u&gt;YOUR TEXT HERE&lt;/u&gt; | Underline

YOUR TEXT HERE&lt;br /&gt;ANOTHER PART OF TEXT | Line break

Remember mark-ups can be stacked! e. g. : &lt;b&gt;&lt;i&gt;&lt;u&gt;Hi!&lt;/b&gt;&lt;/i&gt;&lt;/u&gt;

]]

local Fonts = {
	[Enum.Font.Legacy] = "Legacy";
	[Enum.Font.SourceSans] = "Source Sans";
	[Enum.Font.Bodoni] = "Bodoni";
	[Enum.Font.Garamond] = "Garamond";
	[Enum.Font.Cartoon] = "Cartoon";
	[Enum.Font.Code] = "Code";
	[Enum.Font.Highway] = "Highway";
	[Enum.Font.SciFi] = "Sci-Fi";
	[Enum.Font.Arcade] = "Arcade";
	[Enum.Font.Fantasy] = "Fantasy";
	[Enum.Font.Antique] = "Antique";
	[Enum.Font.Gotham] = "Gotham";
	[Enum.Font.AmaticSC] = "AmaticSC";
	[Enum.Font.Bangers] = "Bangers";
	[Enum.Font.Creepster] = "Creepster";
	[Enum.Font.DenkOne] = "DenkOne";
	[Enum.Font.Fondamento] = "Fondamento";
	[Enum.Font.FredokaOne] = "FredokaOne";
	[Enum.Font.GrenzeGotisch] = "Grenze Gotisch";
	[Enum.Font.IndieFlower] = "Indie Flower";
	[Enum.Font.JosefinSans] = "Josefin Sans";
	[Enum.Font.Jura] = "Jura";
	[Enum.Font.Kalam] = "Kalam";
	[Enum.Font.LuckiestGuy] = "Luckiest Guy";
	[Enum.Font.Merriweather] = "Merriweather";
	[Enum.Font.Michroma] = "Michroma";
	[Enum.Font.Nunito] = "Nunito";
	[Enum.Font.Oswald] = "Oswald";
	[Enum.Font.PatrickHand] = "Patrick Hand";
	[Enum.Font.PermanentMarker] = "Permanent Marker";
	[Enum.Font.Roboto] = "Roboto";
	[Enum.Font.Sarpanch] = "Sarpanch";
	[Enum.Font.SpecialElite] = "Special Elite";
	[Enum.Font.TitilliumWeb] = "Titillium Web";
	[Enum.Font.Ubuntu] = "Ubuntu";
	[Enum.Font.BuilderSans] = "Builder";
	[Enum.Font.Arimo] = "Arimo";
};

--[[
-- Check if any new font is present
for _, TheFont in Enum.Font:GetEnumItems() do
	if not Fonts[TheFont] then
		Fonts[TheFont] = TheFont.Name
	end
end]]

-- Filter out fonts the developers don't want
if Core.Options.ExtraFonts then
	local ExtraFonts = type(Core.Options.ExtraFonts) == "function" and Core.Options.ExtraFonts() or Core.Options.ExtraFonts
	
	for TheFont, FriendlyName in ExtraFonts do
		if not Fonts[TheFont] then
			Fonts[TheFont] = FriendlyName
		end
	end
end

-- Container for temporary connections (disconnected automatically)
local Connections = {};

function TextTool:Equip()
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

	-- Set our current text type and face
	self:SetFace(self.Face)

end;

function TextTool:Unequip()
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

function TextTool:ShowUI()
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
	self.UI = Core.Interfaces.BTTextToolGUI:Clone()
	self.UI.Parent = Core.UI
	self.UI.Visible = true
	
	if self.UI.TextOption.TextInput:FindFirstChild("BoundingBox") then
		self.UI.TextOption.TextInput.BoundingBox.TextBox.Parent = self.UI.TextOption.TextInput
		self.UI.TextOption.TextInput.BoundingBox:Destroy()
	end

	-- References to UI elements
	local AddButton = self.UI.AddButton
	local RemoveButton = self.UI.RemoveButton
	local TextInput = self.UI.TextOption.TextInput.TextBox
	local TransparencyInput = self.UI.TransparencyOption.Input.TextBox
	local RichTextToggle = self.UI.RichOption
	local ColorButton = self.UI.ColorOption.HSVPicker
	local ColorIndicator = self.UI.ColorOption.Indicator
	
	MinimalTextBoxSize = TextInput.Parent.AbsoluteSize
	
	TextSizeParams.Font = TextInput:GetStyled("FontFace")
	TextSizeParams.Size = TextInput:GetStyled("TextSize")
	TextSizeParams.Width = MinimalTextBoxSize.X - TextInput.Parent:GetStyled("ScrollBarThickness")
	
	local FontList = Support.Values(Fonts);
	table.sort(FontList);

	-- Enable the text type switch
	RichTextToggle.Check.MouseButton1Click:Connect(function ()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Press"))
		if Support.IdentifyCommonProperty(GetTexts("TextLabel", TextTool.Face), "RichText") == false then
			SetProperty("TextLabel", TextTool.Face, "RichText", true);
		else
			SetProperty("TextLabel", TextTool.Face, "RichText", false);	
		end
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
	local function BuildFaceDropdown()
		return Roact.createElement(Dropdown, {
			Position = UDim2.new(0, 30, 0, 0);
			Size = UDim2.new(1, -45, 0, 25);
			Options = Faces;
			MaxRows = 6;
			CurrentOption = self.Face and self.Face.Name;
			OnOptionSelected = function (Option)
				self:SetFace(Enum.NormalId[Option])
			end;
		})
	end
	
	local function BuildFontDropdown()
		return Roact.createElement(Dropdown, {
			Position = UDim2.new(0, 30, 0, 0);
			Size = UDim2.new(1, -45, 0, 25);
			Options = FontList;
			MaxRows = 6;
			CurrentOption = self.Font and self.Font.Name;
			TextPreview = true;
			OccurrenceOptions = Fonts;
			OnOptionSelected = function (Option)
				SetProperty('TextLabel', self.Face, "Font", Support.FindTableOccurrence(Fonts, Option))
			end;
		})
	end

	-- Mount type dropdown
	local FaceDropdownHandle = Roact.mount(BuildFaceDropdown(), self.UI.SideOption, 'Dropdown')
	self.OnFaceChanged:Connect(function ()
		Roact.update(FaceDropdownHandle, BuildFaceDropdown())
	end)
	
	local FontDropdownHandle = Roact.mount(BuildFontDropdown(), self.UI.FontOption, 'Dropdown')
	self.OnFontChanged:Connect(function ()
		Roact.update(FontDropdownHandle, BuildFontDropdown())
	end)

	-- Enable other inputs
	SyncInputToProperty('TextTransparency', TransparencyInput);
	SyncInputToProperty('Text', TextInput);

	-- Enable the text adding button
	AddButton.Button.MouseButton1Click:Connect(function ()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Add"))
		AddTexts("TextLabel", TextTool.Face);
	end); 
	AddButton.Button.MouseEnter:Connect(function ()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Hover"))
	end);
	RemoveButton.Button.MouseButton1Click:Connect(function ()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Remove"))
		RemoveTexts("TextLabel", TextTool.Face);
	end);
	RemoveButton.Button.MouseEnter:Connect(function ()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Hover"))
	end);

	local ColorPickerHandle = nil
	ColorButton.MouseButton1Click:Connect(function ()
		local CommonColor = Support.IdentifyCommonProperty(GetTexts("TextLabel", TextTool.Face), "TextColor3")
		local ColorPickerElement = Roact.createElement(ColorPicker, {
			InitialColor = CommonColor or Color3.fromRGB(255, 255, 255);
			SetPreviewColor = function (Color)
				SetPreviewColor("TextLabel", "TextColor3", Color)
			end;
			OnConfirm = function (Color)
				SetProperty("TextLabel", TextTool.Face, "TextColor3", Color)
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
	ListenForManualWindowTrigger(TextTool.ManualText, TextTool.Color.Color, SignatureButton)

	-- Update the UI every 0.1 seconds
	self.StopUpdatingUI = Support.Loop(0.1, function ()
		self:UpdateUI()
	end)

end;

function SyncInputToProperty(Property, Input)
	-- Enables `Input` to change the given property

	-- Enable inputs
	Input.FocusLost:Connect(function ()
		SetProperty("TextLabel", TextTool.Face, Property, Input.Text);
	end);

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
		for _, Text in pairs(GetTexts(TextType, TextTool.Face)) do
			PreviewInitialState[Text] = { [Property] = Text[Property] }
		end
	end

	-- Apply preview color
	for Text in pairs(PreviewInitialState) do
		Text[Property] = Color
	end
end

function TextTool:EnableSurfaceClickSelection()
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

function TextTool:HideUI()
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

function GetTexts(TextType, Face)
	-- Returns all the texts in the selection

	local Texts = {};

	-- Get any texts from any selected parts
	for _, Part in pairs(Selection.Parts) do
		for _, Child in pairs(Part:GetChildren()) do
			if Child.ClassName == "SurfaceGui" and Child.Face == Face and TextType == "TextLabel" then
			for _, Text in pairs(Child:GetChildren()) do

				-- If this child is text we're looking for, collect it
				if Text.ClassName == TextType then
					table.insert(Texts, Text);
				end;

			end;
			elseif Child.ClassName == "SurfaceGui" and Child.Face == Face and TextType == "SurfaceGui" then
				table.insert(Texts, Child);
			end;
		end;
	end;

	-- Return the found texts
	return Texts;

end;

-- List of creatable textures
-- local TextureTypes = { 'Decal', 'Texture' };

-- List of UI layouts
local Layouts = {
	EmptySelection = { 'SelectNote' };
	NoTexts = { 'SideOption', 'AddButton' };
	SomeTexts = { 'SideOption', 'RichOption', 'FontOption', 'TextOption', 'TransparencyOption', 'ColorOption', 'RemoveButton', 'AddButton' };
	AllTexts = { 'SideOption', 'RichOption', 'FontOption', 'TextOption', 'TransparencyOption', 'ColorOption', 'RemoveButton' };
};

-- List of UI elements
local UIElements = { 'SelectNote', 'FontOption', 'RichOption', 'SideOption', 'TextOption', 'TransparencyOption', 'ColorOption', 'AddButton', 'RemoveButton' };

-- Current UI layout
local CurrentLayout;

function TextTool:ChangeLayout(Layout)
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
	self.UI.Size = UDim2.new(0, 255, 0, 30 + Sum)

end;

local LastText = ""

function TextTool:UpdateUI()
	-- Updates information on the UI

	-- Make sure the UI's on
	if not self.UI then
		return;
	end;
	
	-- Get the texts in the selection
	local SurfaceGUIs = GetTexts("SurfaceGui", TextTool.Face);
	local Texts = GetTexts("TextLabel", TextTool.Face);

	-- References to UI elements
	local TextInput = self.UI.TextOption.TextInput.TextBox;
	local TransparencyInput = self.UI.TransparencyOption.Input.TextBox;
	local ColorIndicator = self.UI.ColorOption.Indicator;
	local RichTextSwitch = self.UI.RichOption.Check;

	-----------------------
	-- Update the UI layout
	-----------------------

	-- Get the plural version of the current text type
	local PluralTextType = 'Texts';

	-- Figure out the necessary UI layout
	if #Selection.Parts == 0 then
		self:ChangeLayout(Layouts.EmptySelection)
		return;

		-- When the selection has no text
	elseif #Texts == 0 then
		self:ChangeLayout(Layouts.NoTexts)
		return;

		-- When only some selected items have texts
	elseif #Selection.Parts ~= #Texts then
		self:ChangeLayout(Layouts['Some' .. PluralTextType])

		-- When all selected items have texts
	elseif #Selection.Parts == #Texts then
		self:ChangeLayout(Layouts['All' .. PluralTextType])
	end;

	------------------------
	-- Update UI information
	------------------------

	-- Get the common properties
	local Text = Support.IdentifyCommonProperty(Texts, 'Text');
	local Transparency = Support.IdentifyCommonProperty(Texts, 'TextTransparency');
	local Color = Support.IdentifyCommonProperty(Texts, 'TextColor3');
	local RichText = Support.IdentifyCommonProperty(Texts, 'RichText');
	local Font = Support.IdentifyCommonProperty(Texts, 'Font');
	local Face = Support.IdentifyCommonProperty(SurfaceGUIs, 'Face');
	
	if self.Face ~= Face then
		self.Face = Face
		self.OnFaceChanged:Fire(Face)
	end
	
	if self.Font ~= Font then
		self.Font = Font
		self.OnFontChanged:Fire(Font)
	end

	-- Update the common inputs
	UpdateColorIndicator(ColorIndicator, Support.IdentifyCommonProperty(Texts, 'TextColor3'));
	UpdateToggleInput(RichTextSwitch, Support.IdentifyCommonProperty(Texts, 'RichText'));
	UpdateDataInputs {
		[TextInput] = Text or "*";
		[TransparencyInput] = Transparency and Support.Round(Transparency, 3) or '*';
	};
	
	TextSizeParams.RichText = not TextInput:IsFocused()
	TextSizeParams.Text = TextInput.Text
	
	--BoundingBox.Text = TextInput.Text
	local Size = TextService:GetTextBoundsAsync(TextSizeParams)
	
	TextInput.Size = UDim2.new(1, -TextInput.Parent:GetStyled("ScrollBarThickness"), 0, math.max(Size.Y, MinimalTextBoxSize.Y)) 
	
	if TextInput.Text ~= LastText and TextInput:IsFocused() then
		TextInput.Parent.CanvasPosition = Vector2.new(0, TextInput.Parent.AbsoluteCanvasSize.Y - MinimalTextBoxSize.Y)
	end
	
	LastText = TextInput.Text
end;

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

function UpdateDataInputs(Data)
	-- Updates the data in the given TextBoxes when the user isn't typing in them

	-- Go through the inputs and data
	for Input, UpdatedValue in pairs(Data) do

		-- Makwe sure the user isn't typing into the input
		if not Input:IsFocused() then

			-- Set the input's value
			Input.Text = tostring(UpdatedValue);
			Input.RichText = true
		else
			Input.RichText = false
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



function ParseAssetId(Input)
	-- Returns the intended asset ID for the given input

	-- Get the ID number from the input
	local Id = tonumber(Input)
		or tonumber(Input:lower():match('%?id=([0-9]+)'))
		or tonumber(Input:match('/([0-9]+)/'))
		or tonumber(Input:lower():match('rbxassetid://([0-9]+)'));

	-- Return the ID
	return Id;
end;

function TextTool:SetFace(Face)
	self.Face = Face
	self.OnFaceChanged:Fire(Face)
end

function TextTool:SetFont(Font)
	self.Font = Font
	self.OnFontChanged:Fire(Font)
end

function SetProperty(TextType, Face, Property, Value)
	-- Make sure the given value is valid
	if Value == nil then
		return;
	end;
	-- Start a history record
	TrackChange();

-- Go through each text
	for _, Text in pairs(GetTexts(TextType, Face)) do

		-- Store the state of the text before modification
		table.insert(HistoryRecord.Before, { Part = Text.Parent, TextType = TextType, Face = Face, [Property] = Text[Property] });

		-- Create the change request for this text
		table.insert(HistoryRecord.After, { Part = Text.Parent, TextType = TextType, Face = Face, [Property] = Value });
	end;

	-- Register the changes
	RegisterChange();

end;

function AddTexts(TextType, Face)

	-- Prepare the change request for the server
	local Changes = {};

	-- Go through the selection
	for _, Part in pairs(Selection.Parts) do

		-- Make sure this part doesn't already have a text of the same type
		local HasTexts;
		for _, Child in pairs(Part:GetChildren()) do
			if Child.ClassName == "SurfaceGui" and Child.Face == Face then
				for _, Text in pairs(Child:GetChildren()) do
					if Text.ClassName == TextType then
						HasTexts = true;
					end;

				end;
			end;
		end;

		-- Queue a text to be created for this part, if not already existent
		if not HasTexts then
			table.insert(Changes, { Part = Part, TextType = TextType, Face = Face });
		end;

	end;

	-- Send the change request to the server
	local Texts = Core.SyncAPI:Invoke('CreateText', Changes);

	-- Put together the history record
	local HistoryRecord = {
		Texts = Texts;
		Selection = Selection.Items;

		Unapply = function (Record)
			-- Reverts this change

			-- Select changed parts
			Selection.Replace(Record.Selection)

			-- Remove the texts
			Core.SyncAPI:Invoke('Remove', Record.Texts);

		end;

		Apply = function (Record)
			-- Reapplies this change

			-- Restore the texts
			Core.SyncAPI:Invoke('UndoRemove', Record.Texts);

			-- Select changed parts
			Selection.Replace(Record.Selection)

		end;

	};

	-- Register the history record
	Core.History.Add(HistoryRecord);

end;

function RemoveTexts(TextType, Face)

	-- Get all the texts in the selection
	local Texts = GetTexts(TextType, Face);

	-- Create the history record
	local HistoryRecord = {
		Texts = Texts;
		Selection = Selection.Items;

		Unapply = function (Record)
			-- Reverts this change

			-- Restore the texts
			Core.SyncAPI:Invoke('UndoRemove', Record.Texts);

			-- Select changed parts
			Selection.Replace(Record.Selection)

		end;

		Apply = function (Record)
			-- Reapplies this change

			-- Select changed parts
			Selection.Replace(Record.Selection)

			-- Remove the texts
			Core.SyncAPI:Invoke('Remove', Record.Texts);

		end;

	};

	-- Send the removal request
	Core.SyncAPI:Invoke('Remove', Texts);

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
			Core.SyncAPI:Invoke('SyncText', Record.Before);

		end;

		Apply = function (Record)
			-- Applies this change
			
			-- Select the changed parts
			Selection.Replace(Record.Selection)

			-- Send the change request
			Core.SyncAPI:Invoke('SyncText', Record.After);

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
	Core.SyncAPI:Invoke('SyncText', HistoryRecord.After);

	-- Register the record and clear the staging
	Core.History.Add(HistoryRecord);
	HistoryRecord = nil;

end;

-- Return the tool
return TextTool;
