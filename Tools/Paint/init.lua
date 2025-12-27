
Tool = script.Parent.Parent;
Core = require(Tool.Core);
Sounds = Tool:WaitForChild("Sounds");
local Vendor = Tool:WaitForChild('Vendor')
local UI = Core.UIFolder

-- Libraries
local Libraries = Core.Libraries
local Maid = require(Libraries:WaitForChild 'Maid')
local PaintHistoryRecord = require(script:WaitForChild 'PaintHistoryRecord')
local ListenForManualWindowTrigger = require(Tool.Core:WaitForChild('ListenForManualWindowTrigger'))
local Roact = require(Vendor:WaitForChild('Roact'))
local ColorPicker = require(UI:WaitForChild('ColorPicker'))
local BoundingBox = require(Tool.Core.BoundingBox)

-- Import relevant references
Selection = Core.Selection;
Support = Core.Support;
Security = Core.Security;

-- Initialize the tool
local PaintTool = {
	Name = 'Paint Tool';
	Color = BrickColor.new 'Really red';

	-- Default options
	BrickColor = nil;
}

if table.find(Core.Options.ToolsBlacklist, PaintTool.Name) then
	return PaintTool
end

PaintTool.ManualText = [[<font weight="900" size="24"><u><i>Paint Tool  🛠</i></u></font>
Lets you paint parts in different colors.<font size="6"><br /></font>

<font size="12" color="rgb(150, 150, 150)"><b>Palette</b></font>
This is what's shown directly when opening the Paint Tool. You can choose a color by clicking on one of the squares found in this window.<font size="6"><br /></font>

<font size="12" color="rgb(150, 150, 150)"><b>Color picker</b></font>
This is the most advanced way to pick a specific color. You can set your color:<font size="6"><br /></font>

 <font color="rgb(150, 150, 150)">•</font>  With the 3 sliders — the first for the hue (tint), second for the saturation (white or colorful) and third for the brightness/value.
 <font color="rgb(150, 150, 150)">•</font>  With HSV values — they work the same way as the sliders, this time with values.
 <font color="rgb(150, 150, 150)">•</font>  With RGB values — 0 is dark, 255 is colorful. Input 3 values which are respectively red, green and blue.
 
<font size="12" color="rgb(150, 150, 150)"><b>Coloring</b></font>

You can apply the selected color by selecting the part you want to color.

<b>TIP:</b> Press <b><i>R</i></b> while hovering over a part to copy its color.]]

local Connections = {}

function PaintTool:Equip()
	-- Enables the tool's equipped functionality

	-- Set up maid for cleanup
	self.Maid = Maid.new()
	
	-- Start up our interface
	ShowUI();
	self:BindShortcutKeys()
	self:EnableClickPainting()
	
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

function PaintTool:Unequip()
	-- Disables the tool's equipped functionality

	-- Hide UI
	HideUI()
	ClearConnections()
	BoundingBox.ClearBoundingBox();

	-- Clean up resources
	self.Maid = self.Maid:Destroy()

end;

function ClearConnections()
	-- Clears out temporary connections

	for ConnectionKey, Connection in pairs(Connections) do
		Connection:Disconnect();
		Connections[ConnectionKey] = nil;
	end;

end;

function ShowUI()
	
	UI = Core.UIFolder
	ColorPicker = require(UI:WaitForChild('ColorPicker'))
	-- Creates and reveals the UI

	-- Reveal UI if already created
	if PaintTool.UI and PaintTool.UI.Parent ~= nil then

		-- Reveal the UI
		PaintTool.UI.Visible = true;

		-- Update the UI every 0.1 seconds
		UIUpdater = Support.ScheduleRecurringTask(UpdateUI, 0.1);

		-- Skip UI creation
		return;

	end;
	
	if PaintTool.UI then
		PaintTool.UI:Destroy()
	end

	-- Create the UI
	PaintTool.UI = Core.Interfaces.BTPaintToolGUI:Clone();
	PaintTool.UI.Parent = Core.UI;
	PaintTool.UI.Visible = true;

	-- Track palette buttons
	PaletteButtons = {};

	-- Enable the palette
	for _, Column in pairs(PaintTool.UI.Palette:GetChildren()) do
		for _, Button in pairs(Column:GetChildren()) do
			if Button.ClassName == 'TextButton' then

				-- Recolor the selection when the button is clicked
				Button.MouseButton1Click:Connect(function ()
					game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Press"))
					SetColor(BrickColor.new(Button.Name).Color);
				end);

				-- Register the button
				PaletteButtons[Button.Name] = Button;

			end;
		end;
	end;

	-- Paint selection when current color indicator is clicked
	PaintTool.UI.Controls.LastColorButton.MouseButton1Click:Connect(PaintParts);

	-- Enable color picker button
	local ColorPickerHandle = nil
	PaintTool.UI.Controls.ColorPickerButton.MouseButton1Click:Connect(function ()
		local CommonColor = Support.IdentifyCommonProperty(Selection.Parts, 'Color')
		local ColorPickerElement = Roact.createElement(ColorPicker, {
			InitialColor = CommonColor or Color3.fromRGB(255, 255, 255);
			SetPreviewColor = PreviewColor;
			OnConfirm = function (Color)
				SetColor(Color)
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
	local SignatureButton = PaintTool.UI:WaitForChild('Title'):WaitForChild('Signature')
	ListenForManualWindowTrigger(PaintTool.ManualText, PaintTool.Color.Color, SignatureButton)

	-- Update the UI every 0.1 seconds
	UIUpdater = Support.ScheduleRecurringTask(UpdateUI, 0.1);

end;

function HideUI()
	-- Hides the tool UI

	-- Make sure there's a UI
	if not PaintTool.UI then
		return;
	end;

	-- Hide the UI
	PaintTool.UI.Visible = false;

	-- Stop updating the UI
	UIUpdater:Stop();

end;

function UpdateUI()
	-- Updates information on the UI

	-- Make sure the UI's on
	if not PaintTool.UI then
		return;
	end;

	-----------------------------------------
	-- Update the color information indicator
	-----------------------------------------

	-- Clear old color indicators
	for Color, Button in pairs(PaletteButtons) do
		Button.Text = '';
	end;

	-- Indicate the variety of colors in the selection
	for _, Part in pairs(Selection.Parts) do
		if PaletteButtons[Part.BrickColor.Name] and Part.Color == Part.BrickColor.Color then
			PaletteButtons[Part.BrickColor.Name].Text = '+';
		end;
	end;

	-- Update the color picker button's background
	local CommonColor = Support.IdentifyCommonProperty(Selection.Parts, 'Color');
	PaintTool.UI.Controls.ColorPickerButton.ImageColor3 = CommonColor or PaintTool.BrickColor or Color3.new(1, 0, 0);
	PaintTool.UI.Controls.ColorPickerButton.BackgroundColor3 = CommonColor or PaintTool.BrickColor or Color3.new(1, 0, 0);
end;

function SetColor(Color)
	-- Changes the color option to `Color`

	-- Set the color option
	PaintTool.BrickColor = Color;

	-- Use BrickColor name if color matches one
	local EquivalentBrickColor = BrickColor.new(Color);
	local RGBText = ('(%d, %d, %d)'):format(Color.r * 255, Color.g * 255, Color.b * 255);
	local ColorText = (EquivalentBrickColor.Color == Color) and EquivalentBrickColor.Name or RGBText;

	-- Shortcuts to color indicators
	local ColorLabel = PaintTool.UI.Controls.LastColorButton.ColorName;
	local ColorSquare = ColorLabel.ColorSquare;

	-- Update the indicators
	ColorLabel.Visible = true;
	ColorLabel.Text = ColorText;
	ColorSquare.BackgroundColor3 = Color;
--	ColorSquare.Position = UDim2.new(1, -ColorLabel.TextBounds.X - 18, 0.2, 1);

	-- Paint currently selected parts
	PaintParts();

end;

function PaintParts()
	-- Recolors the selection with the selected color

	-- Make sure painting is possible
	if (not PaintTool.BrickColor) or (#Selection.Parts == 0) then
		return
	end

	-- Create history record
	local Record = PaintHistoryRecord.new()
	Record.TargetColor = PaintTool.BrickColor

	-- Perform action
	Record:Apply(true)

	-- Register history record
	Core.History.Add(Record)

end

function PreviewColor(Color)
	-- Previews the given color on the selection

	-- Reset colors to initial state if previewing is over
	if not Color and InitialState then
		for Part, State in pairs(InitialState) do

			-- Reset part color
			Part.Color = State.Color;

			-- Update union coloring options
			if Part:IsA("PartOperation") then
				Part.UsePartColor = State.UsePartColor;
			end;
		end;

		-- Clear initial state
		InitialState = nil;

		-- Skip rest of function
		return;

	-- Ensure valid color is given
	elseif not Color then
		return;

	-- Save initial state if first time previewing
	elseif not InitialState then
		InitialState = {};
		for _, Part in pairs(Selection.Parts) do
			InitialState[Part] = { Color = Part.Color, UsePartColor = (Part.ClassName == 'UnionOperation') and Part.UsePartColor or nil };
		end;
	end;

	-- Apply preview color
	for _, Part in pairs(Selection.Parts) do
		Part.Color = Color;

		-- Enable union coloring
		if Part.ClassName == 'UnionOperation' then
			Part.UsePartColor = true;
		end;
	end;

end;

function PaintTool:BindShortcutKeys()
	-- Enables useful shortcut keys for this tool

	-- Track user input while this tool is equipped
	self.Maid.Hotkeys = Support.AddUserInputListener('Began', 'Keyboard', false, function (Input)

		-- Paint selection if Enter is pressed
		if (Input.KeyCode.Name == 'Return') or (Input.KeyCode.Name == 'KeypadEnter') then
			return PaintParts()
		end

		-- Check if the R key was pressed, and it wasn't the selection clearing hotkey
		if (Input.KeyCode.Name == 'R') and (not Selection.Multiselecting) then

			-- Set the current color to that of the current mouse target (if any)
			if Core.Mouse.Target then
				SetColor(Core.Mouse.Target.Color);
			end;

		end;

	end)

end;

function PaintTool:EnableClickPainting()
	-- Allows the player to paint parts by clicking on them

	-- Watch out for clicks on selected parts
	self.Maid.ClickPainting = Selection.FocusChanged:Connect(function (Focus)
		local Target, ScopeTarget = Core.Targeting:UpdateTarget()
		if Selection.IsSelected(ScopeTarget) then

			-- Paint the selected parts
			PaintParts();

		end;
	end);

end;

-- Return the tool
return PaintTool;
