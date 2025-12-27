Tool = script.Parent.Parent;
Core = require(Tool.Core);
Sounds = Tool:WaitForChild("Sounds");
local Vendor = Tool:WaitForChild('Vendor')
local UI
local Libraries = Core.Libraries
local BoundingBox = require(Tool.Core.BoundingBox)

-- Libraries
local ListenForManualWindowTrigger = require(Tool.Core:WaitForChild('ListenForManualWindowTrigger'))
local Roact = require(Vendor:WaitForChild('Roact'))
local Signal = require(Libraries:WaitForChild('Signal'))

-- Import relevant references
Selection = Core.Selection;
Support = Core.Support;
Security = Core.Security;

local SoundService = game:GetService("SoundService")

-- Initialize the tool
local DecorateTool = {
	Name = 'Decorate Tool';
	Color = BrickColor.new 'Really black';
	
	CurrentOrientation = nil;
	OrientationChanged = Signal.new()
}

if table.find(Core.Options.ToolsBlacklist, DecorateTool.Name) then
	return DecorateTool
end

DecorateTool.ManualText = [[<font weight="900" size="24"><u><i>Decorate Tool  🛠</i></u></font>
Allows you to add smoke, fire, sparkles, particle emitter and other effects to parts.

]]

local Override -- Roblox hates HighlightDepthMode, so yea...
local Drag

-- Container for temporary connections (disconnected automatically)
local Connections = {};

function DecorateTool.Equip()
	-- Enables the tool's equipped functionality

	-- Start up our interface
	ShowUI();
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

function DecorateTool.Unequip()
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
	UI = Core.UIFolder
	-- Creates and reveals the UI

	-- Reveal UI if already created
	if DecorateTool.UI and DecorateTool.UI.Parent ~= nil then

		-- Reveal the UI
		DecorateTool.UI.Visible = true;

		-- Update the UI every 0.1 seconds
		UIUpdater = Support.ScheduleRecurringTask(UpdateUI, 0.1);

		-- Skip UI creation
		return;

	end;

	if DecorateTool.UI then
		DecorateTool.UI:Destroy()
	end

	-- Create the UI
	DecorateTool.UI = Core.Interfaces.BTDecorateToolGUI:Clone();
	DecorateTool.UI.Parent = Core.UI;
	DecorateTool.UI.Visible = true;

	-- Enable each decoration type UI
	EnableOptionsUI(DecorateTool.UI.Smoke);
	EnableOptionsUI(DecorateTool.UI.Fire);
	EnableOptionsUI(DecorateTool.UI.Sparkles);
	EnableOptionsUI(DecorateTool.UI.Highlight);
	EnableOptionsUI(DecorateTool.UI.SelectionBox);
	EnableOptionsUI(DecorateTool.UI.ParticleEmitter);

	-- Hook up manual triggering
	local SignatureButton = DecorateTool.UI:WaitForChild('Title'):WaitForChild('Signature')
	ListenForManualWindowTrigger(DecorateTool.ManualText, DecorateTool.Color.Color, SignatureButton)

	-- Update the UI every 0.1 seconds
	UIUpdater = Support.ScheduleRecurringTask(UpdateUI, 0.1);

end;

-- List of creatable decoration types
local DecorationTypes = { 'Smoke', 'Fire', 'Sparkles', 'Highlight', 'SelectionBox', 'ParticleEmitter' };

function UpdateUI()
	-- Updates information on the UI

	-- Make sure the UI's on
	if not DecorateTool.UI then
		return;
	end;

	-- Go through each decoration type and update each options UI
	for _, DecorationType in pairs(DecorationTypes) do

		local Decorations = GetDecorations(DecorationType, false);
		local DecorationSettingsUI = DecorateTool.UI[DecorationType];

		-- Option input references
		local Options = DecorationSettingsUI.Options;

		-- Add/remove button references
		local AddButton = DecorationSettingsUI.Buttons.AddButton;
		local RemoveButton = DecorationSettingsUI.Buttons.RemoveButton;

		-- Hide option UIs for decoration types not present in the selection
		if #Decorations == 0 and not DecorationSettingsUI.ClipsDescendants then
			CloseOptions();
		end;

		-------------------------------------------
		-- Show and hide "ADD" and "REMOVE" buttons
		-------------------------------------------

		-- If no selected parts have decorations
		if #Decorations == 0 then

			-- Show add button only
			AddButton.Visible = true;
			AddButton.Position = UDim2.new(1, -AddButton.AbsoluteSize.X - 5, 0, 3);
			RemoveButton.Visible = false;

			-- If only some selected parts have decorations
		elseif (#Decorations < #Selection.Parts) or (#Decorations < #Selection.Items) then

			-- Show both add and remove buttons
			AddButton.Visible = true;
			AddButton.Position = UDim2.new(1, -AddButton.AbsoluteSize.X - 5, 0, 3);
			RemoveButton.Visible = true;
			RemoveButton.Position = UDim2.new(1, -AddButton.AbsoluteSize.X - 5 - RemoveButton.AbsoluteSize.X - 2, 0, 3);

			-- If all selected parts have decorations
		elseif (#Decorations == #Selection.Parts) or (#Decorations == #Selection.Items) then

			-- Show remove button
			RemoveButton.Visible = true;
			RemoveButton.Position = UDim2.new(1, -RemoveButton.AbsoluteSize.X - 5, 0, 3);
			AddButton.Visible = false;

		end;

		--------------------
		-- Update each input
		--------------------

		-- Update smoke inputs
		if DecorationType == 'Smoke' then

			-- Get the inputs
			local SizeInput = Options.SizeOption.Input.TextBox;
			local VelocityInput = Options.VelocityOption.Input.TextBox;
			local OpacityInput = Options.OpacityOption.Input.TextBox;
			local ColorIndicator = Options.ColorOption.Indicator;

			-- Update the inputs
			UpdateDataInputs {
				[SizeInput] = Support.Round(Support.IdentifyCommonProperty(Decorations, 'Size'), 2) or '*';
				[VelocityInput] = Support.Round(Support.IdentifyCommonProperty(Decorations, 'RiseVelocity'), 2) or '*';
				[OpacityInput] = Support.Round(Support.IdentifyCommonProperty(Decorations, 'Opacity'), 2) or '*';
			};
			UpdateColorIndicator(ColorIndicator, Support.IdentifyCommonProperty(Decorations, 'Color'));

			-- Update fire inputs
		elseif DecorationType == 'Fire' then

			-- Get the inputs
			local SizeInput = Options.SizeOption.Input.TextBox;
			local HeatInput = Options.HeatOption.Input.TextBox;
			local SecondaryColorIndicator = Options.SecondaryColorOption.Indicator;
			local ColorIndicator = Options.ColorOption.Indicator;

			-- Update the inputs
			UpdateColorIndicator(ColorIndicator, Support.IdentifyCommonProperty(Decorations, 'Color'));
			UpdateColorIndicator(SecondaryColorIndicator, Support.IdentifyCommonProperty(Decorations, 'SecondaryColor'));
			UpdateDataInputs {
				[HeatInput] = Support.Round(Support.IdentifyCommonProperty(Decorations, 'Heat'), 2) or '*';
				[SizeInput] = Support.Round(Support.IdentifyCommonProperty(Decorations, 'Size'), 2) or '*';
			};

			-- Update sparkle inputs
		elseif DecorationType == 'Sparkles' then
			-- Get the inputs
			local ColorIndicator = Options.ColorOption.Indicator;

			-- Update the inputs
			UpdateColorIndicator(ColorIndicator, Support.IdentifyCommonProperty(Decorations, 'SparkleColor'));

		elseif DecorationType == 'ParticleEmitter' then

			-- Get the inputs
			local ColorIndicator = Options.ColorOption.Indicator;
			local DragSwitch = Options.DragOption.Check;
			local CountInput = Options.CountOption.Input.TextBox;
			local SizeInput = Options.SizeOption.Input.TextBox;
			local SpeedInput = Options.SpeedOption.Input.TextBox;
			local RotationInput = Options.RotateOption.Input.TextBox;
			local OpacityInput = Options.OpacityOption.Input.TextBox;
			local SpreadInput = Options.SpreadOption.Input.TextBox;
			local LifetimeInput = Options.LifetimeOption.Input.TextBox;
			local ParticleIDInput = Options.ParticleIDOption:FindFirstChild("TextBox") or Options.ParticleIDOption.Input.TextBox
			local OrientationOption = Options.OrientationOption;
			local WeightInput = Options.WeightOption.Input.TextBox;
			local RSpeedInput = Options.RSpeedOption.Input.TextBox;

			Drag = Support.IdentifyCommonProperty(Decorations, 'LockedToPart')

			-- Update the inputs
			UpdateColorIndicator(ColorIndicator, Support.IdentifyCommonProperty(Decorations, 'Color'));
			UpdateToggleInput(DragSwitch, Support.IdentifyCommonProperty(Decorations, 'LockedToPart'));
			UpdateDataInputs({
				[SpeedInput] = Support.IdentifyCommonProperty(Decorations, 'Speed') or '*';
				[SizeInput] = Support.IdentifyCommonProperty(Decorations, 'Size') or '*';
				[CountInput] = Support.IdentifyCommonProperty(Decorations, 'Rate') or '*';
				[OpacityInput] = Support.IdentifyCommonProperty(Decorations, 'Transparency') or '*';
				[RotationInput] = Support.IdentifyCommonProperty(Decorations, 'Rotation') or '*';
				[SpreadInput] = Support.IdentifyCommonProperty(Decorations, 'SpreadAngle') or '*';
				[LifetimeInput] = Support.IdentifyCommonProperty(Decorations, 'Lifetime') or '*';
				[WeightInput] = Support.IdentifyCommonProperty(Decorations, 'Acceleration') or '*';
				[RSpeedInput] = Support.IdentifyCommonProperty(Decorations, 'RotSpeed') or '*';
				[ParticleIDInput] = Support.IdentifyCommonProperty(Decorations, 'Texture') and ParseAssetId(Support.IdentifyCommonProperty(Decorations, 'Texture')) or Support.IdentifyCommonProperty(Decorations, 'Texture') or '*';	
			}, 2);
			if OrientationOption:FindFirstChild("FacingCamera") then
				UpdateEnumInput(OrientationOption, Support.IdentifyCommonProperty(Decorations, 'Orientation'), false, nil)
			else
				DecorateTool.CurrentOrientation = Support.IdentifyCommonProperty(Decorations, 'Orientation')
				DecorateTool.OrientationChanged:Fire()
			end

		--[[	local TranslatedNumeralProperty
			if OrientationInput.Text == "1" then
				TranslatedNumeralProperty = "Camera"
			elseif OrientationInput.Text == "2" then
				TranslatedNumeralProperty = "Mixed"
			elseif OrientationInput.Text == "3" then
				TranslatedNumeralProperty = "VPar"
			elseif OrientationInput.Text == "4" then
				TranslatedNumeralProperty = "VPer"
			elseif OrientationInput.Text == "*" then
				TranslatedNumeralProperty = "None"
			end
			local OrientationOptions = Options.OrientationOption:GetChildren()
			for i = 1, #OrientationOptions do
				if OrientationOptions[i].Name == TranslatedNumeralProperty then
					OrientationOptions[i].SelectedIndicator.BackgroundTransparency = 0
					OrientationOptions[i].Background.Image = "http://www.roblox.com/asset/?id=127774197"
				else
					if OrientationOptions[i]:FindFirstChild("SelectedIndicator") then
						OrientationOptions[i].SelectedIndicator.BackgroundTransparency = 1
						OrientationOptions[i].Background.Image = "http://www.roblox.com/asset/?id=127772502"
					end
				end
			end]]
		elseif DecorationType == 'SelectionBox' then

			local NewDecorations = GetDecorations(DecorationType, true);

			-- Get the inputs
			local SizeInput = Options.SizeOption.Input.TextBox;
			local OpacityInput = Options.OpacityOption.Input.TextBox;
			local SurfaceOpacityInput = Options.SOOption.Input.TextBox;
			local OutlineColorIndicator = Options.OCOption.Indicator;
			local SurfaceColorIndicator = Options.ICOption.Indicator;

			-- Update the inputs
			UpdateColorIndicator(OutlineColorIndicator, Support.IdentifyCommonProperty(NewDecorations, 'Color3'));
			UpdateColorIndicator(SurfaceColorIndicator, Support.IdentifyCommonProperty(NewDecorations, 'SurfaceColor3'));
			UpdateDataInputs {
				[OpacityInput] = Support.Round(Support.IdentifyCommonProperty(NewDecorations, 'Transparency'), 3) or '*';
				[SizeInput] = Support.Round(Support.IdentifyCommonProperty(NewDecorations, 'LineThickness'), 3) or '*';
				[SurfaceOpacityInput] = Support.Round(Support.IdentifyCommonProperty(NewDecorations, 'SurfaceTransparency'), 3) or '*';
			};
		elseif DecorationType == 'Highlight' then

			local NewDecorations = GetDecorations(DecorationType, true);

			-- Get the inputs
			local OpacityInput = Options.OpacityOption.Input.TextBox;
			local SurfaceOpacityInput = Options.SOOption.Input.TextBox;
			local OutlineColorIndicator = Options.OCOption.Indicator;
			local SurfaceColorIndicator = Options.ICOption.Indicator;
			local OverrideInput = Options.OverrideOption.Check;

			Override = Support.IdentifyCommonProperty(NewDecorations, 'DepthMode')

			-- Update the inputs
			UpdateColorIndicator(OutlineColorIndicator, Support.IdentifyCommonProperty(NewDecorations, 'OutlineColor'));
			UpdateColorIndicator(SurfaceColorIndicator, Support.IdentifyCommonProperty(NewDecorations, 'FillColor'));
			UpdateToggleInput(OverrideInput, Override)
			--		UpdateEnumInput(OverrideInput, Support.IdentifyCommonProperty(Decorations, 'DepthMode'), true, true)
			UpdateDataInputs {
				[OpacityInput] = Support.IdentifyCommonProperty(NewDecorations, 'OutlineTransparency', 3) or '*';
				[SurfaceOpacityInput] = Support.Round(Support.IdentifyCommonProperty(NewDecorations, 'FillTransparency'), 3) or '*';
			}; 
		end;

	end;

end;

function HideUI()
	-- Hides the tool UI

	-- Make sure there's a UI
	if not DecorateTool.UI then
		return;
	end;

	-- Hide the UI
	DecorateTool.UI.Visible = false;

	-- Stop updating the UI
	UIUpdater:Stop();

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


function GetDecorations(DecorationType)
	-- Returns all the decorations of the given type in the selection

	local Decorations = {};

	-- Get any decorations from any selected parts
	for _, Part in pairs(DecorationType ~= "Highlight" and DecorationType ~= "SelectionBox" and Selection.Parts or Selection.Items) do
		if not Part:IsA("Attachment") then
			table.insert(Decorations, Support.GetChildOfClass(Part, DecorationType));
		end
	end;

	if DecorationType ~= "Highlight" and DecorationType ~= "SelectionBox" then
		for _, Attachment in pairs(Selection.Attachments) do
			table.insert(Decorations, Support.GetChildOfClass(Attachment, DecorationType));
		end;
	end

	-- Return the decorations
	return Decorations;

end;

function UpdateColorIndicator(Indicator, Color)

	-- If there is a single color, just display it
	if Color then
		Indicator.BackgroundColor3 = SimplifyValue(Color);
		Indicator.Varies.Text = '';

		-- If the colors vary, display a * on a gray background
	else
		Indicator.BackgroundColor3 = Color3.new(222/255, 222/255, 222/255);
		Indicator.Varies.Text = '*';
	end;

end;

function UpdateEnumInput(Input, Value, IsBoolean, PositiveValue)

	if IsBoolean == false then
		for _, Button in Input:GetChildren() do
			if not Button:FindFirstChild("SelectedIndicator") then continue end

			if typeof(Value) == "EnumItem" and Value.Name == Button.Name then
				Button.SelectedIndicator.BackgroundTransparency = 0
				Button.Background.Image = "http://www.roblox.com/asset/?id=127774197"
			else
				Button.SelectedIndicator.BackgroundTransparency = 1
				Button.Background.Image = "http://www.roblox.com/asset/?id=127772502"
			end
		end
	elseif PositiveValue then	-- No need to check if IsBoolean is true since we checked it before.
		UpdateToggleInput(Input, Value == PositiveValue and true or false)
	end

end;


function SimplifyValue(Value)
	-- Updates the given color indicator

	if typeof(Value) == "ColorSequence"then
		return Value.Keypoints[2].Value
	elseif typeof(Value) == "NumberRange" then
		return Value.Max == Value.Min and Value.Max or Value.Max .. "," .. Value.Min
	elseif typeof(Value) == "NumberSequence" then
		return Value.Keypoints[1].Value == Value.Keypoints[2].Value and Value.Keypoints[2].Value or Value.Keypoints[1].Value .. "," .. Value.Keypoints[2].Value
	elseif typeof(Value) == "Vector2" then
		return Value.X
	elseif typeof(Value) == "Vector3" then
		return Value.Y * -1
	else
		return Value
	end

end;



function UpdateDataInputs(Data, Round)
	-- Updates the data in the given TextBoxes when the user isn't typing in them

	-- Go through the inputs and data
	for Input, UpdatedValue in pairs(Data) do

		-- Make sure the user isn't typing into the input
		if not Input:IsFocused() then

			local UsedValue = SimplifyValue(UpdatedValue)

			if type(UsedValue) == "number" then
				UsedValue = Support.Round(UsedValue, Round or 3)
			end

			-- Set the input's value
			Input.Text = tostring(UsedValue);

		end;

	end;

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
			Core.SyncAPI:Invoke('SyncDecorate', Record.Before);

		end;

		Apply = function (Record)
			-- Applies this change

			-- Select the changed parts
			Selection.Replace(Record.Selection)

			-- Send the change request
			Core.SyncAPI:Invoke('SyncDecorate', Record.After);

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
	Core.SyncAPI:Invoke('SyncDecorate', HistoryRecord.After);

	-- Register the record and clear the staging
	Core.History.Add(HistoryRecord);
	HistoryRecord = nil;

end;

function EnableOptionsUI(SettingsUI)

	local UIFolder = Core.UIFolder

	local Dropdown = require(UIFolder:WaitForChild('Dropdown'))

	-- Sets up the UI for the given decoration type settings UI

	-- Get the type of decoration this options UI is for
	local DecorationType = SettingsUI.Name;
	local Decorations = GetDecorations(DecorationType, false);

	-- Option input references
	local Options = SettingsUI.Options;

	-- Add/remove/show button references
	local AddButton = SettingsUI.Buttons.AddButton;
	local RemoveButton = SettingsUI.Buttons.RemoveButton;
	local ShowButton = SettingsUI.ArrowButton;

	local IncludeModels = false

	-- Enable options for smoke decorations
	if DecorationType == 'Smoke' then
		SyncInputToProperty('Color', DecorationType, 'Color', Options.ColorOption.HSVPicker);
		SyncInputToProperty('Size', DecorationType, 'Number', Options.SizeOption.Input.TextBox);
		SyncInputToProperty('RiseVelocity', DecorationType, 'Number', Options.VelocityOption.Input.TextBox);
		SyncInputToProperty('Opacity', DecorationType, 'Number', Options.OpacityOption.Input.TextBox);

		-- Enable options for fire decorations
	elseif DecorationType == 'Fire' then
		SyncInputToProperty('Color', DecorationType, 'Color', Options.ColorOption.HSVPicker);
		SyncInputToProperty('SecondaryColor', DecorationType, 'Color', Options.SecondaryColorOption.HSVPicker);
		SyncInputToProperty('Size', DecorationType, 'Number', Options.SizeOption.Input.TextBox);
		SyncInputToProperty('Heat', DecorationType, 'Number', Options.HeatOption.Input.TextBox);

		-- Enable options for sparkle decorations
	elseif DecorationType == 'Sparkles' then
		SyncInputToProperty('SparkleColor', DecorationType, 'Color', Options.ColorOption.HSVPicker);

	elseif DecorationType == 'ParticleEmitter' then
		local IDInput = Options.ParticleIDOption:FindFirstChild("TextBox") or Options.ParticleIDOption.TextBox
		
		SyncInputToProperty('Color', DecorationType, 'Color', Options.ColorOption.HSVPicker);
		SyncInputToProperty('Size', DecorationType, 'Number', Options.SizeOption.Input.TextBox);
		SyncInputToProperty('Rate', DecorationType, 'Number', Options.CountOption.Input.TextBox);
		SyncInputToProperty('Speed', DecorationType, 'Number', Options.SpeedOption.Input.TextBox);
		SyncInputToProperty('Transparency', DecorationType, 'Number', Options.OpacityOption.Input.TextBox);
		SyncInputToProperty('SpreadAngle', DecorationType, 'Number', Options.SpreadOption.Input.TextBox);
		SyncInputToProperty('Rotation', DecorationType, 'Number', Options.RotateOption.Input.TextBox);
		SyncInputToProperty('Lifetime', DecorationType, 'Number', Options.LifetimeOption.Input.TextBox);
		SyncInputToProperty('Texture', DecorationType, 'Number', IDInput);
		--		SyncInputToProperty('Orientation', DecorationType, 'Number', Options.OrientationOption.TextBox);
		SyncInputToProperty('Acceleration', DecorationType, 'Number', Options.WeightOption.Input.TextBox);
		SyncInputToProperty('RotSpeed', DecorationType, 'Number', Options.RSpeedOption.Input.TextBox);

		if Options.OrientationOption:FindFirstChild("FacingCamera") then
			for _, Button in Options.OrientationOption:GetChildren() do
				if Button:FindFirstChild("Button") then
					Button.Button.Activated:Connect(function()
						SoundService:PlayLocalSound(Sounds:WaitForChild("Press"))
						SetProperty("ParticleEmitter", "Orientation", Enum.ParticleOrientation[Button.Name]);
					end)
				end
			end
		else
			local List = {
				"FacingCamera",
				"FacingCameraWorldUp",
				"VelocityParallel",
				"VelocityPerpendicular"
			}
			
			-- Create the orientation's dropdown
			local function BuildOrientationDropdown()
				return Roact.createElement(Dropdown, {
					AnchorPoint = Vector2.new(1, 0.5);
					Position = UDim2.new(1, 0, 0.5, 0);
					Size = UDim2.new(1, -60, 1, 0);
					Options = List;
					MaxRows = 4;
					NoClipping = true;
					CurrentOption = DecorateTool.CurrentOrientation and typeof(DecorateTool.CurrentOrientation) == "EnumItem" and DecorateTool.CurrentOrientation.Name or "*";
					OnOptionSelected = function (Option)
						SetProperty("ParticleEmitter", "Orientation", Enum.ParticleOrientation[Option]);
					end;
				})
			end
			
			-- Mount orientation dropdown
			local MaterialDropdownHandle = Roact.mount(BuildOrientationDropdown(), Options.OrientationOption, 'Dropdown')
			DecorateTool.OrientationChanged:Connect(function ()
				Roact.update(MaterialDropdownHandle, BuildOrientationDropdown())
			end)
		end

		Options.DragOption.Check.Activated:Connect(function ()
			SoundService:PlayLocalSound(Sounds:WaitForChild("Press"))
			if Drag == false then
				SetProperty("ParticleEmitter", "LockedToPart", true);
			else
				SetProperty("ParticleEmitter", "LockedToPart", false);	
			end
		end);
		
		IDInput.FocusLost:Connect(function ()
			SetProperty(DecorationType, "Texture", tonumber(ParseAssetId(Options.ParticleIDOption.TextBox.Text)) or Options.ParticleIDOption.TextBox.Text)
		end)

	elseif DecorationType == 'SelectionBox' then
		SyncInputToProperty('Color3', DecorationType, 'Color', Options.OCOption.HSVPicker);
		SyncInputToProperty('SurfaceColor3', DecorationType, 'Color', Options.ICOption.HSVPicker);
		SyncInputToProperty('Transparency', DecorationType, 'Number', Options.OpacityOption.Input.TextBox);
		SyncInputToProperty('SurfaceTransparency', DecorationType, 'Number', Options.SOOption.Input.TextBox);
		SyncInputToProperty('LineThickness', DecorationType, 'Number', Options.SizeOption.Input.TextBox);
	elseif DecorationType == 'Highlight' then
		IncludeModels = true

		SyncInputToProperty('OutlineColor', DecorationType, 'Color', Options.OCOption.HSVPicker);
		SyncInputToProperty('FillColor', DecorationType, 'Color', Options.ICOption.HSVPicker);
		SyncInputToProperty('OutlineTransparency', DecorationType, 'Number', Options.OpacityOption.Input.TextBox);
		SyncInputToProperty('FillTransparency', DecorationType, 'Number', Options.SOOption.Input.TextBox);

		Options.OverrideOption.Check.Activated:Connect(function ()
			SoundService:PlayLocalSound(Sounds:WaitForChild("Press"))
			if Override == false then
				SetProperty("Highlight", "DepthMode", Enum.HighlightDepthMode.AlwaysOnTop);
			else
				SetProperty("Highlight", "DepthMode", Enum.HighlightDepthMode.Occluded);	
			end
		end);
	end;

	-- Enable decoration addition button
	AddButton.MouseButton1Click:Connect(function ()
		AddDecorations(DecorationType, IncludeModels);
		SoundService:PlayLocalSound(Sounds:WaitForChild("Add"))
	end);

	AddButton.MouseEnter:Connect(function ()
		SoundService:PlayLocalSound(Sounds:WaitForChild("Hover"))
	end);

	-- Enable decoration removal button
	RemoveButton.MouseButton1Click:Connect(function ()
		RemoveDecorations(DecorationType);
		SoundService:PlayLocalSound(Sounds:WaitForChild("Remove"))
	end);

	RemoveButton.MouseEnter:Connect(function ()
		SoundService:PlayLocalSound(Sounds:WaitForChild("Hover"))
	end);

	-- Enable decoration options UI show button
	ShowButton.MouseButton1Click:Connect(function ()
		OpenOptions(DecorationType);
		SoundService:PlayLocalSound(Sounds:WaitForChild("Press"))
	end);

end;

function OpenOptions(DecorationType)
	-- Opens the options UI for the given decoration type

	-- Get the UI
	local UI = DecorateTool.UI[DecorationType];
	local UITemplate = Core.Interfaces.BTDecorateToolGUI[DecorationType];

	-- Close up all decoration option UIs
	CloseOptions(DecorationType);

	-- Calculate how much to expand this options UI by
	local HeightExpansion = UDim2.new(0, 0, 0, UITemplate.Options.Size.Y.Offset);
	-- Start the options UI size from 0
	UI.Options.Size = UDim2.new(UI.Options.Size.X.Scale, UI.Options.Size.X.Offset, UI.Options.Size.Y.Scale, 0);

	-- Allow the options UI to be seen
	UI.ClipsDescendants = false;

	-- Perform the options UI resize animation
	UI.Options:TweenSize(
		UI.Options.Size + HeightExpansion,
		Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true,
		function ()

			-- Allow visibility of overflowing UIs within the options UI
			if UI.Options:IsA("ScrollingFrame") then
				UI.Options.ClipsDescendants = true;
			else
				UI.Options.ClipsDescendants = false;	
			end

		end
	);

	-- Expand the main UI to accommodate the expanded options UI
	--	if UI.Options:IsA("Frame") then
	DecorateTool.UI:TweenSize(
		Core.Interfaces.BTDecorateToolGUI.Size + HeightExpansion,
		Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true
	);
	--	else
	--		DecorateTool.UI:TweenSize(
	--			Core.Tool.Interfaces.BTDecorateToolGUI.Size + HeightExpansion + HeightExpansion,
	--			Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true
	--		);
	--	end

	-- Push any UIs below this one downwards
	local DecorationTypeIndex = Support.FindTableOccurrence(DecorationTypes, DecorationType);
	-- Calculate how much to expand this options UI by
	for DecorationTypeIndex = DecorationTypeIndex + 1, #DecorationTypes do

		-- Get the UI
		local DecorationType = DecorationTypes[DecorationTypeIndex];
		local UI = DecorateTool.UI[DecorationType];

		-- Perform the position animation
		--		if UI.Options:IsA("Frame") then
		UI:TweenPosition(
			UDim2.new(
				UI.Position.X.Scale,
				UI.Position.X.Offset,
				UI.Position.Y.Scale,
				30 + 30 * (DecorationTypeIndex - 1) + HeightExpansion.Y.Offset
			),
			Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true
		);
		--		else
		--			UI:TweenPosition(
		--				UDim2.new(
		--					UI.Position.X.Scale,
		--					UI.Position.X.Offset,
		--					UI.Position.Y.Scale,
		--					30 + 30 * (DecorationTypeIndex - 1) + (HeightExpansion.Y.Offset * 2)
		--				),
		--				Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true
		--			);
		--		end

	end;

end;

function CloseOptions(Exception)
	-- Closes all decoration options, except the one for the given decoration type

	-- Go through each decoration type
	for DecorationTypeIndex, DecorationType in pairs(DecorationTypes) do

		-- Get the UI for each decoration type
		local UI = DecorateTool.UI[DecorationType];
		local UITemplate = Core.Interfaces.BTDecorateToolGUI[DecorationType];

		-- Remember the initial size for each options UI
		local InitialSize = UITemplate.Options.Size;

		-- Move each decoration type UI to its starting position
		UI:TweenPosition(
			UDim2.new(
				UI.Position.X.Scale,
				UI.Position.X.Offset,
				UI.Position.Y.Scale,
				30 + 30 * (DecorationTypeIndex - 1)
			),
			Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true
		);

		-- Make sure to not resize the exempt decoration type UI
		if not Exception or Exception and DecorationType ~= Exception then

			-- Allow the options UI to be resized
			UI.Options.ClipsDescendants = true;

			-- Perform the resize animation to close up
			UI.Options:TweenSize(
				UDim2.new(UI.Options.Size.X.Scale, UI.Options.Size.X.Offset, UI.Options.Size.Y.Scale, 0),
				Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true,
				function ()

					-- Hide the option UI
					UI.ClipsDescendants = true;

					-- Set the options UI's size to its initial size (for reexpansion)
					UI.Options.Size = InitialSize;

				end
			);

		end;

	end;

	-- Contract the main UI if no option UIs are being opened
	if not Exception then
		DecorateTool.UI:TweenSize(
			Core.Interfaces.BTDecorateToolGUI.Size,
			Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true
		);
	end;

end;

function SyncInputToProperty(Property, DecorationType, InputType, Input)
	-- Enables `Input` to change the given property
	local ColorPicker = require(UI:WaitForChild('ColorPicker'))

	-- Enable inputs
	if InputType == 'Color' then
		local ColorPickerHandle = nil
		Input.MouseButton1Click:Connect(function ()
			local CommonColor = Support.IdentifyCommonProperty(GetDecorations(DecorationType), Property)
			local ColorPickerElement = Roact.createElement(ColorPicker, {
				InitialColor = CommonColor or Color3.fromRGB(255, 255, 255);
				SetPreviewColor = function (Color)
					SetPreviewColor(DecorationType, Property, Color)
				end;
				OnConfirm = function (Color)
					SetProperty(DecorationType, Property, Color)
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

		-- Enable number inputs
	elseif InputType == 'Number' then
		Input.FocusLost:Connect(function ()

			SetProperty(DecorationType, Property, Input.Text);
		end);
	 --[[ elseif InputType == 'NumberRange' then
		Input.FocusLost:Connect(function ()
			SetProperty(DecorationType, Property, NumberRange.new(tonumber(Input.Text), tonumber(Input.Text)));
		end);
	elseif InputType == 'NumberSequence' then
		Input.FocusLost:Connect(function ()
			SetProperty(DecorationType, Property, NumberSequence.new(tonumber(Input.Text), tonumber(Input.Text)));
		end);]]
	end;

end;

local PreviewInitialState = nil

function SetPreviewColor(DecorationType, Property, Color)

	local TheColor
	-- Previews the given color on the selection
	if DecorationType == "ParticleEmitter" and Color ~= nil then
		TheColor = ColorSequence.new{
			ColorSequenceKeypoint.new(0, Color),
			ColorSequenceKeypoint.new(1, Color),
		}
	else
		TheColor = Color
	end

	-- Reset colors to initial state if previewing is over
	if not TheColor and PreviewInitialState then
		for Decoration, State in pairs(PreviewInitialState) do
			Decoration[Property] = State[Property]
		end

		-- Clear initial state
		PreviewInitialState = nil

		-- Skip rest of function
		return

			-- Ensure valid color is given
	elseif not TheColor then
		return

			-- Save initial state if first time previewing
	elseif not PreviewInitialState then
		PreviewInitialState = {}
		for _, Decoration in pairs(GetDecorations(DecorationType)) do
			PreviewInitialState[Decoration] = { [Property] = Decoration[Property] }
		end
	end

	-- Apply preview color
	for Decoration in pairs(PreviewInitialState) do
		Decoration[Property] = TheColor
	end
end

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

function SetProperty(DecorationType, Property, Value)

	-- Make sure the given value is valid
	if not Value and Value ~= false then
		return;
	end;

	if Property == "Texture" then
		local Changes
		if tonumber(Value) == nil then
			Changes = {
				Texture = Value;
			};
		else
			Changes = {
				Texture = 'rbxassetid://' .. Value;
			};
		end

		-- Attempt an image extraction on the given asset
		Core.Try(Core.SyncAPI.Invoke, Core.SyncAPI, 'ExtractImageFromDecal', Value)
			:Then(function (ExtractedImage)
				Changes.Texture = 'rbxassetid://' .. ExtractedImage;
			end);

		Value = Changes.Texture
	end


	-- Start a history record
	TrackChange();

	-- Go through each decoration
	for _, Decoration in pairs(GetDecorations(DecorationType)) do

		-- Store the state of the decoration before modification
		table.insert(HistoryRecord.Before, { Part = Decoration.Parent, DecorationType = DecorationType, [Property] = Decoration[Property] });

		-- Create the change request for this decoration
		table.insert(HistoryRecord.After, { Part = Decoration.Parent, DecorationType = DecorationType, [Property] = Value });

	end;

	-- Register the changes
	RegisterChange();

end;

function AddDecorations(DecorationType)

	-- Prepare the change request for the server
	local Changes = {};

	-- Go through the selection
	for _, Part in pairs(DecorationType ~= "Highlight" and DecorationType ~= "SelectionBox" and Selection.Parts or Selection.Items) do

		-- Make sure this part doesn't already have a decoration
		if not Support.GetChildOfClass(Part, DecorationType) and not Part:IsA("Attachment") then

			-- Queue a decoration to be created for this part
			table.insert(Changes, { Part = Part, DecorationType = DecorationType });

		end;

	end;

	if DecorationType ~= "Highlight" and DecorationType ~= "SelectionBox" then
		for _, Attachment in pairs(Selection.Attachments) do

			-- Make sure this part doesn't already have a decoration
			if not Support.GetChildOfClass(Attachment, DecorationType) then

				-- Queue a decoration to be created for this part
				table.insert(Changes, { Part = Attachment, DecorationType = DecorationType });

			end;

		end;
	end

	-- Send the change request to the server
	local Decorations = Core.SyncAPI:Invoke('CreateDecorations', Changes);

	-- Put together the history record
	local HistoryRecord = {
		Decorations = Decorations;
		Selection = Selection.Items;

		Unapply = function (Record)
			-- Reverts this change

			-- Select changed parts
			Selection.Replace(Record.Selection)

			-- Remove the decorations
			Core.SyncAPI:Invoke('Remove', Record.Decorations);

		end;

		Apply = function (Record)
			-- Reapplies this change

			-- Restore the decorations
			Core.SyncAPI:Invoke('UndoRemove', Record.Decorations);

			-- Select changed parts
			Selection.Replace(Record.Selection)

		end;

	};

	-- Register the history record
	Core.History.Add(HistoryRecord);

	-- Open the options UI for this decoration type
	OpenOptions(DecorationType);

end;

function RemoveDecorations(DecorationType)

	-- Get all the decorations in the selection
	local Decorations = GetDecorations(DecorationType);

	-- Create the history record
	local HistoryRecord = {
		Decorations = Decorations;
		Selection = Selection.Items;

		Unapply = function (Record)
			-- Reverts this change

			-- Restore the decorations
			Core.SyncAPI:Invoke('UndoRemove', Record.Decorations);

			-- Select changed parts
			Selection.Replace(Record.Selection)

		end;

		Apply = function (Record)
			-- Reapplies this change

			-- Select changed parts
			Selection.Replace(Record.Selection)

			-- Remove the decorations
			Core.SyncAPI:Invoke('Remove', Record.Decorations);

		end;

	};

	-- Send the removal request
	Core.SyncAPI:Invoke('Remove', Decorations);

	-- Register the history record
	Core.History.Add(HistoryRecord);

end;

-- Return the tool
return DecorateTool;
