Tool = script.Parent.Parent;
Core = require(Tool.Core);
SnapTracking = require(Tool.Core.Snapping);
Sounds = Tool:WaitForChild("Sounds");

-- Services
local ContextActionService = game:GetService 'ContextActionService'
local Workspace = game:GetService 'Workspace'

-- Libraries
local Libraries = Core.Libraries
local Signal = require(Libraries:WaitForChild 'Signal')
local Make = require(Libraries:WaitForChild 'Make')
local ListenForManualWindowTrigger = require(Tool.Core:WaitForChild('ListenForManualWindowTrigger'))

-- Import relevant references
Selection = Core.Selection;
Support = Core.Support;
Security = Core.Security;
BoundingBox = require(Tool.Core.BoundingBox)
Services = Core.Services;

-- Initialize the tool
local ResizeTool = {
	Name = 'Resize Tool';
	Color = BrickColor.new 'Cyan';

	-- Default options
	Increment = 1;
	Directions = 'Normal';
	IncludeMeshes = true;
}

if table.find(Core.Options.ToolsBlacklist, ResizeTool.Name) then
	return ResizeTool
end

ResizeTool.ManualText = [[<font weight="900" size="24"><u><i>Resize Tool  🛠</i></u></font>
Allows you to resize parts.<font size="12"><br /></font>
<font size="12" color="rgb(150, 150, 150)"><b>Directions</b></font>
Lets you choose in which directions to resize the part.<font size="6"><br /></font>

<b>TIP: </b>Click on a part to focus the handles on it.<font size="6"><br /></font>

<b>TIP: </b>Hit <b>Enter</b> to switch between directions quickly.<font size="12"><br /></font>

<font size="12" color="rgb(150, 150, 150)"><b>Increment</b></font>
Lets you choose how many studs to resize by.<font size="6"><br /></font>

<b>TIP: </b>Hit the – key to quickly type increments.<font size="6"><br /></font>

<b>TIP: </b>Use your number pad to resize exactly by the current increment. Holding <b>Shift</b> reverses the increment.<font size="4"><br /></font>
   <font color="rgb(150, 150, 150)">•</font>  8 & 2 — up & down
   <font color="rgb(150, 150, 150)">•</font>  1 & 9 — back & forth
   <font color="rgb(150, 150, 150)">•</font>  4 & 6 — left & right<font size="12"><br /></font>

<font size="12" color="rgb(150, 150, 150)"><b>Snapping</b></font>
Hold the <b><i>R</i></b> key, and <b>click and drag the snap point</b> of a part (in the direction you want to resize) towards the snap point of another part, to resize up to that point.
]]

-- Mark Roblox's limitations.
local SamplePart = Instance.new("Part")
SamplePart.Size = Vector3.new(0, 0, 0)

local SmallestSize = math.min(0.001, SamplePart.Size.X)

SamplePart.Size = Vector3.new(999999999, 999999999, 999999999)
local BiggestSize = SamplePart.Size.X

local MaxDecimals = string.len(tostring(SmallestSize)) - 2

SamplePart:Destroy()

-- Container for temporary connections (disconnected automatically)
local Connections = {};

function ResizeTool.Equip()
	-- Enables the tool's equipped functionality

	-- Start up our interface
	ShowUI();
	ShowHandles();
	BindShortcutKeys();

end;

function ResizeTool.Unequip()
	-- Disables the tool's equipped functionality

	-- Clear unnecessary resources
	HideUI();
	HideHandles();
	ClearConnections();
	BoundingBox.ClearBoundingBox();
	SnapTracking.StopTracking();
	FinishSnapping();

end;

function ClearConnections()
	-- Clears out temporary connections

	for ConnectionKey, Connection in pairs(Connections) do
		Connection:Disconnect();
		Connections[ConnectionKey] = nil;
	end;

end;

function ClearConnection(ConnectionKey)
	-- Clears the given specific connection

	local Connection = Connections[ConnectionKey];

	-- Disconnect the connection if it exists
	if Connection then
		Connection:Disconnect();
		Connections[ConnectionKey] = nil;
	end;

end;

function ShowUI()
	
	-- Creates and reveals the UI

	-- Reveal UI if already created
	if ResizeTool.UI and ResizeTool.UI.Parent ~= nil then

		-- Reveal the UI
		ResizeTool.UI.Visible = true;

		-- Update the UI every 0.1 seconds
		UIUpdater = Support.ScheduleRecurringTask(UpdateUI, 0.1);

		-- Skip UI creation
		return;

	end;
	
	if ResizeTool.UI then
		ResizeTool.UI:Destroy()
	end

	-- Create the UI
	ResizeTool.UI = Core.Interfaces.BTResizeToolGUI:Clone();
	ResizeTool.UI.Parent = Core.UI;
	ResizeTool.UI.Visible = true;

	-- Add functionality to the directions option switch
	local DirectionsSwitch = ResizeTool.UI.DirectionsOption;
	DirectionsSwitch.Normal.Button.Activated:Connect(function ()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Press"))
		SetDirections('Normal');
	end);
	DirectionsSwitch.Normal.Button.MouseEnter:Connect(function ()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Hover"))
	end)
	DirectionsSwitch.Both.Button.Activated:Connect(function ()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Press"))
		SetDirections('Both');
	end);
	DirectionsSwitch.Both.Button.MouseEnter:Connect(function ()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Hover"))
	end)
	DirectionsSwitch.Scale.Button.Activated:Connect(function ()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Press"))
		SetDirections('Scale');
	end);
	DirectionsSwitch.Scale.Button.MouseEnter:Connect(function ()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Hover"))
	end)
	
	local MeshToggle = ResizeTool.UI.MeshOption.Check

	MeshToggle.Activated:Connect(function()
		ResizeTool.IncludeMeshes = not ResizeTool.IncludeMeshes
		UpdateToggleInput(MeshToggle, ResizeTool.IncludeMeshes)
	end)
	
	UpdateToggleInput(MeshToggle, ResizeTool.IncludeMeshes)

	-- Add functionality to the increment input
	local IncrementInput = ResizeTool.UI.IncrementOption.Increment.TextBox;
	IncrementInput.FocusLost:Connect(function (EnterPressed)
		ResizeTool.Increment = tonumber(IncrementInput.Text) or ResizeTool.Increment;
		IncrementInput.Text = Support.Round(ResizeTool.Increment, MaxDecimals + 1);
	end);

	-- Add functionality to the size inputs
	local XInput = ResizeTool.UI.Info.SizeInfo.X.TextBox;
	local YInput = ResizeTool.UI.Info.SizeInfo.Y.TextBox;
	local ZInput = ResizeTool.UI.Info.SizeInfo.Z.TextBox;
	XInput.FocusLost:Connect(function (EnterPressed)
		local NewSize = tonumber(XInput.Text);
		if NewSize then
			SetAxisSize('X', NewSize);
		end;
	end);
	YInput.FocusLost:Connect(function (EnterPressed)
		local NewSize = tonumber(YInput.Text);
		if NewSize then
			SetAxisSize('Y', NewSize);
		end;
	end);
	ZInput.FocusLost:Connect(function (EnterPressed)
		local NewSize = tonumber(ZInput.Text);
		if NewSize then
			SetAxisSize('Z', NewSize);
		end;
	end);

	-- Hook up manual triggering
	local SignatureButton = ResizeTool.UI:WaitForChild('Title'):WaitForChild('Signature')
	ListenForManualWindowTrigger(ResizeTool.ManualText, ResizeTool.Color.Color, SignatureButton)

	-- Update the UI every 0.1 seconds
	UIUpdater = Support.ScheduleRecurringTask(UpdateUI, 0.1);

end;

function HideUI()
	-- Hides the tool UI

	-- Make sure there's a UI
	if not ResizeTool.UI then
		return;
	end;

	-- Hide the UI
	ResizeTool.UI.Visible = false;

	-- Stop updating the UI
	UIUpdater:Stop();

end;

function UpdateUI()
	-- Updates information on the UI

	-- Make sure the UI's on
	if not ResizeTool.UI then
		return;
	end;

	-- Only show and calculate selection info if it's not empty
	if #Selection.Parts == 0 then
		ResizeTool.UI.Info.Visible = false;
		ResizeTool.UI.Size = UDim2.new(0, 300, 0, 90);
		return;
	else
		ResizeTool.UI.Info.Visible = true;
		ResizeTool.UI.Size = UDim2.new(0, 300, 0, 150);
	end;

	-----------------------------------------
	-- Update the size information indicators
	-----------------------------------------

	-- Identify common sizes across axes
	local XVariations, YVariations, ZVariations = {}, {}, {};
	for _, Part in pairs(Selection.Parts) do
		table.insert(XVariations, Support.Round(Part.Size.X, MaxDecimals));
		table.insert(YVariations, Support.Round(Part.Size.Y, MaxDecimals));
		table.insert(ZVariations, Support.Round(Part.Size.Z, MaxDecimals));
	end;
	local CommonX = Support.IdentifyCommonItem(XVariations);
	local CommonY = Support.IdentifyCommonItem(YVariations);
	local CommonZ = Support.IdentifyCommonItem(ZVariations);

	-- Shortcuts to indicators
	local XIndicator = ResizeTool.UI.Info.SizeInfo.X.TextBox;
	local YIndicator = ResizeTool.UI.Info.SizeInfo.Y.TextBox;
	local ZIndicator = ResizeTool.UI.Info.SizeInfo.Z.TextBox;

	-- Update each indicator if it's not currently being edited
	if not XIndicator:IsFocused() then
		XIndicator.Text = CommonX or '*';
	end;
	if not YIndicator:IsFocused() then
		YIndicator.Text = CommonY or '*';
	end;
	if not ZIndicator:IsFocused() then
		ZIndicator.Text = CommonZ or '*';
	end;

end;

function SetDirections(DirectionMode)
	-- Sets the given resizing direction mode

	-- Update setting
	
	local OldDirectionMode = ResizeTool.Directions
	
	ResizeTool.Directions = DirectionMode;
	
	--	HideHandles()
	if OldDirectionMode ~= DirectionMode then
		BoundingBox.ClearBoundingBox();
	end
	
	if OldDirectionMode ~= "Scale" and DirectionMode == "Scale" or OldDirectionMode == "Scale" and DirectionMode ~= "Scale" then
		ShowHandles()
	end

	-- Update the UI switch
	if ResizeTool.UI then
		Core.ToggleSwitch(DirectionMode, ResizeTool.UI.DirectionsOption);
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



-- Directions of resizing for each handle's dragged face
local AxisSizeMultipliers = {
	[Enum.NormalId.Top] = Vector3.new(0, 1, 0);
	[Enum.NormalId.Bottom] = Vector3.new(0, 1, 0);
	[Enum.NormalId.Front] = Vector3.new(0, 0, 1);
	[Enum.NormalId.Back] = Vector3.new(0, 0, 1);
	[Enum.NormalId.Left] = Vector3.new(1, 0, 0);
	[Enum.NormalId.Right] = Vector3.new(1, 0, 0);
};

-- Directions of positioning adjustment for each handle's dragged face
local AxisPositioningMultipliers = {
	[Enum.NormalId.Top] = Vector3.new(0, 1, 0);
	[Enum.NormalId.Bottom] = Vector3.new(0, -1, 0);
	[Enum.NormalId.Front] = Vector3.new(0, 0, -1);
	[Enum.NormalId.Back] = Vector3.new(0, 0, 1);
	[Enum.NormalId.Left] = Vector3.new(-1, 0, 0);
	[Enum.NormalId.Right] = Vector3.new(1, 0, 0);
};

-- Axis names corresponding to each face
local FaceAxisNames = {
	[Enum.NormalId.Top] = 'Y';
	[Enum.NormalId.Bottom] = 'Y';
	[Enum.NormalId.Front] = 'Z';
	[Enum.NormalId.Back] = 'Z';
	[Enum.NormalId.Left] = 'X';
	[Enum.NormalId.Right] = 'X';
};

local LastFocus

function ShowHandles()
	-- Creates and automatically attaches handles to the currently focused part
	-- Autofocus handles on latest focused part
	if not Connections.AutofocusHandle then
		Connections.AutofocusHandle = Selection.FocusChanged:Connect(ShowHandles);
	end;
	

	if Selection.Focus and Selection.Focus:IsA("Attachment") then
		return
	end
	
--	BoundingBox.ClearBoundingBox();
	
	-- If handles already exist, only show them
	if ResizeTool.Handles then
		BoundingBox.ClearBoundingBox()
		LastFocus = Selection.Focus
		if ResizeTool.Directions ~= "Scale" or Selection.Focus == nil then
			ResizeTool.Handles:SetAdornee(Selection.Focus)
			BoundingBox.StartBoundingBox(function () end)
		elseif ResizeTool.Directions == "Scale" then
			BoundingBox.StartBoundingBox(function (BoundingBox)
				if ResizeTool.Handles then
					ResizeTool.Handles:SetAdornee(BoundingBox)
				end
			end)
		end
		return
	end
	
	local NewInitialState
	local InitialBoundingBoxSize
	local InitialBoundingBoxPosition

	local AreaPermissions
	local function OnHandleDragStart()
		-- Prepare for resizing parts when the handle is clicked

		-- Prevent selection
		Core.Targeting.CancelSelecting();

		-- Indicate resizing via handles
		ResizeTool.HandleResizing = true;

		-- Stop parts from moving, and capture the initial state of the parts

		NewInitialState = PreparePartsForResizing();
		
		if ResizeTool.Directions == "Scale" then
			local BoundingBoxPart = BoundingBox.GetBoundingBox()
			InitialBoundingBoxSize = BoundingBoxPart.Size
			InitialBoundingBoxPosition = BoundingBoxPart.Position
		end
		-- Track the change
		TrackChange();

		-- Cache area permissions information
		if Core.Mode == 'Tool' then
			AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Selection.Parts), Core.Player);
		end;

	end

	local function OnHandleDrag(Face, Distance)
		-- Update parts when the handles are moved

		-- Only resize if handle is enabled
		if not ResizeTool.HandleResizing then
			return;
		end;

		-- Calculate the increment-aligned drag distance
		Distance = GetIncrementMultiple(Distance, ResizeTool.Increment);
		
		-- Resize the parts on the selected faces by the calculated distance
		local Success, Adjustment = ResizePartsByFace(Face, Distance, ResizeTool.Directions, NewInitialState, InitialBoundingBoxSize, InitialBoundingBoxPosition);

		-- If the resizing did not succeed, resize according to the suggested adjustment
		if not Success then
			ResizePartsByFace(Face, Adjustment, ResizeTool.Directions, NewInitialState, InitialBoundingBoxSize, InitialBoundingBoxPosition);
		end;

		-- Update the "studs resized" indicator
		if ResizeTool.UI then
			ResizeTool.UI.Changes.Text.Text = 'resized ' .. Support.Round(math.abs(Adjustment or Distance), MaxDecimals) .. ' studs';
		end;

		-- Make sure we're not entering any unauthorized private areas
		if Core.Mode == 'Tool' and Security.ArePartsViolatingAreas(Selection.Parts, Core.Player, false, AreaPermissions) then
			for Part, State in pairs(NewInitialState) do
				Part.Size = State.Size;
				Part.CFrame = State.CFrame; 
			end;
		end;

	end

	local function OnHandleDragEnd()
		if not ResizeTool.HandleResizing then
			return
		end

		-- Disable resizing
		ResizeTool.HandleResizing = false;

		-- Prevent selection
		Core.Targeting.CancelSelecting();

		-- Make joints, restore original anchor and collision states
		for Part, State in pairs(NewInitialState) do
			if Part:IsA("BasePart") then
				Part:MakeJoints();
				Part.CanCollide = State.CanCollide;
				Part.Anchored = State.Anchored;
			end
		end;

		-- Register the change
		RegisterChange();
	end
	
	-- Create the handles
	local Handles = require(Libraries:WaitForChild(Core.Options.IgnoreHandlesWithCamera and not game:GetService("UserInputService").TouchEnabled and 'Handles' or 'OldHandles'))
	
	local function AttachHandles(Adornee)
		ResizeTool.Handles = Handles.new({
			Color = ResizeTool.Color.Color,
			Parent = Core.UI,
			Adornee = Adornee,
			OnDragStart = OnHandleDragStart,
			OnDrag = OnHandleDrag,
			OnDragEnd = OnHandleDragEnd
		})
	end
	
	if ResizeTool.Directions ~= "Scale" or Selection.Focus == nil then
		BoundingBox.StartBoundingBox(function () end)
		AttachHandles(Selection.Focus)
	else
		BoundingBox.StartBoundingBox(function (BoundingBox)
			AttachHandles(BoundingBox)
		end)
	end

end;

function HideHandles()
	-- Hides the resizing handles

	-- Make sure handles exist and are visible
	if not ResizeTool.Handles then
		return;
	end;

	-- Hide the handles
	ResizeTool.Handles = ResizeTool.Handles:Destroy()

	-- Clear unnecessary resources
	ClearConnection 'AutofocusHandle';

end;

function ResizePartsByFace(Face, Distance, Directions, InitialStates, BoundingBoxInitialSize, BoundingBoxInitialPosition)
	-- Resizes the selection on face `Face` by `Distance` studs, in the given `Directions`

	-- Adjust the size increment to the resizing direction mode
	if Directions == 'Both' then
		Distance = Distance * 2;
	end;

	-- Calculate the increment vector for this resizing
	local AxisSizeMultiplier = AxisSizeMultipliers[Face];
	local IncrementVector = Distance * AxisSizeMultiplier;

	-- Get name of axis the resize will occur on
	local AxisName = FaceAxisNames[Face];

	-- Check for any potential undersizing or oversizing
	local ShortestSize, ShortestPart, LongestSize, LongestPart;
	
	local ScaleFactor

	if Directions == "Scale" and BoundingBoxInitialSize then
	--	print(BoundingBoxInitialSize)
		local ScaledValue = BoundingBoxInitialSize[AxisName] + Distance
		ScaleFactor = ScaledValue / BoundingBoxInitialSize[AxisName]
	end
 
	for Part, InitialState in pairs(InitialStates) do
		if Part:IsA("BasePart") then
		-- Calculate target size for this resize
		local TargetSize = Directions == "Scale" and InitialState.Size[AxisName] * ScaleFactor or InitialState.Size[AxisName] + Distance;

		-- If target size is under 0.001, note if it's the shortest size
		if TargetSize < SmallestSize and (not ShortestSize or (ShortestSize and TargetSize < ShortestSize)) then
			ShortestSize, ShortestPart = TargetSize, Part;

			-- If target size is over 2048, note if it's the longest size
		elseif TargetSize > BiggestSize and (not LongestSize or (LongestSize and TargetSize > LongestSize)) then
			LongestSize, LongestPart = TargetSize, Part;
		end;
			
		end

	end;


	-- Return adjustment for undersized parts (snap to lowest possible valid increment multiple)
	if ShortestSize then
		local InitialSize = InitialStates[ShortestPart] and InitialStates[ShortestPart].Size[AxisName] or InitialStates.PartInitialState[ShortestPart].Size[AxisName];
		local TargetSize = InitialSize - ResizeTool.Increment * tonumber((tostring((InitialSize - SmallestSize) / ResizeTool.Increment):gsub('%..+', '')));
		return false, Distance + TargetSize - ShortestSize;
	end;

	-- Return adjustment for oversized parts (snap to highest possible valid increment multiple)
	if LongestSize then
		local TargetSize = ResizeTool.Increment * tonumber((tostring(BiggestSize / ResizeTool.Increment):gsub('%..+', '')));
		return false, Distance + TargetSize - LongestSize;
	end;
	
	--print(Distance)

	-- Resize each part
	--	for Item, InitialState in pairs(Directions ~= "Scale" and InitialStates or InitialStates.ItemInitialState) do
	for Item, InitialState in pairs(InitialStates) do

		-- Perform the size change depending on shape
			if Item:IsA 'Part' and Directions ~= "Scale" then

				-- Resize spheres on all axes
				if Item.Shape == Enum.PartType.Ball then
					Item.Size = InitialState.Size + Vector3.new(Distance, Distance, Distance);

					-- Resize cylinders on both Y & Z axes for circle sides
				elseif Item.Shape == Enum.PartType.Cylinder and AxisName ~= 'X' then
					
				--	print(Distance)
					
					Item.Size = InitialState.Size + Vector3.new(0, Distance, Distance);

					-- Resize block parts and cylinder lengths normally
				else
						Item.Size = InitialState.Size + IncrementVector;
				end;

				-- Perform the size change normally on all other parts
			elseif Item:IsA("BasePart") then
				if Directions == "Scale" then
					Item.Size = InitialState.Size * ScaleFactor;
				else
					Item.Size = InitialState.Size + IncrementVector;
				end
		elseif Item:IsA("DataModelMesh") and Item.MeshType == Enum.MeshType.FileMesh then
				local MeshRatio = Item.Parent.Size[AxisName] / InitialStates[Item.Parent].Size[AxisName]
			
				if Directions == "Scale" then
					Item.Scale = InitialState.Scale * MeshRatio
				else
				Item.Scale = Vector3.new(AxisName == "X" and InitialState.Scale.X * MeshRatio or InitialState.Scale.X, AxisName == "Y" and InitialState.Scale.Y * MeshRatio or InitialState.Scale.Y, AxisName == "Z" and InitialState.Scale.Z * MeshRatio or InitialState.Scale.Z);
				end
			end;

		-- Offset the part when resizing in the normal, one direction
		if Item:IsA("BasePart") then
			if Directions == 'Normal' then
				Item.CFrame = InitialState.CFrame * CFrame.new(AxisPositioningMultipliers[Face] * Distance / 2);

				-- Keep the part centered when resizing in both directions
			elseif Directions == 'Both' then
				Item.CFrame = InitialState.CFrame;
				
			elseif Directions == 'Scale' then
				print(BoundingBoxInitialPosition)
				
				Item.CFrame = (CFrame.new(AxisPositioningMultipliers[Face] * Distance / 2) + 
					BoundingBoxInitialPosition:Lerp(InitialState.CFrame.Position, ScaleFactor)) 
					* (Item.CFrame - Item.CFrame.Position);

			end;
		elseif Item:IsA("DataModelMesh") then
			Item.Offset = Vector3.new(InitialState.Offset.X * Item.Parent.Size.X / InitialStates[Item.Parent].Size.X, InitialState.Offset.Y * Item.Parent.Size.Y / InitialStates[Item.Parent].Size.Y, InitialState.Offset.Z * Item.Parent.Size.Z / InitialStates[Item.Parent].Size.Z)
		end
	end

	-- Indicate that the resizing happened successfully
	return true;
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

			-- Toggle the current directions mode
			if ResizeTool.Directions == 'Normal' then
				SetDirections('Both');
			elseif ResizeTool.Directions == 'Both' then
				SetDirections('Scale');
			elseif ResizeTool.Directions == "Scale" then
				SetDirections('Normal');
			end;

			-- Nudge up if the 8 button on the keypad is pressed
		elseif InputInfo.KeyCode == Enum.KeyCode.KeypadEight then
			NudgeSelectionByFace(Enum.NormalId.Top);

			-- Nudge down if the 2 button on the keypad is pressed
		elseif InputInfo.KeyCode == Enum.KeyCode.KeypadTwo then
			NudgeSelectionByFace(Enum.NormalId.Bottom);

			-- Nudge forward if the 9 button on the keypad is pressed
		elseif InputInfo.KeyCode == Enum.KeyCode.KeypadNine then
			NudgeSelectionByFace(Enum.NormalId.Front);

			-- Nudge backward if the 1 button on the keypad is pressed
		elseif InputInfo.KeyCode == Enum.KeyCode.KeypadOne then
			NudgeSelectionByFace(Enum.NormalId.Back);

			-- Nudge left if the 4 button on the keypad is pressed
		elseif InputInfo.KeyCode == Enum.KeyCode.KeypadFour then
			NudgeSelectionByFace(Enum.NormalId.Left);

			-- Nudge right if the 6 button on the keypad is pressed
		elseif InputInfo.KeyCode == Enum.KeyCode.KeypadSix then
			NudgeSelectionByFace(Enum.NormalId.Right);

			-- Start snapping when the R key is pressed down, and it's not the selection clearing hotkey
		elseif InputInfo.KeyCode == Enum.KeyCode.R and not Selection.Multiselecting then
			StartSnapping();

		end;

	end));

	-- Track ending user input while this tool is equipped
	table.insert(Connections, Services.UserInputService.InputEnded:Connect(function (InputInfo, GameProcessedEvent)

		-- Make sure this is an intentional event
		if GameProcessedEvent then
			return;
		end;

		-- Make sure this is input from the keyboard
		if InputInfo.UserInputType ~= Enum.UserInputType.Keyboard then
			return;
		end;

		-- Make sure it wasn't pressed while typing
		if Services.UserInputService:GetFocusedTextBox() then
			return;
		end;

		-- Finish snapping when the R key is released, and it's not the selection clearing hotkey
		if InputInfo.KeyCode == Enum.KeyCode.R and not Selection.Multiselecting then
			FinishSnapping();

			-- If - key was released, focus on increment input
		elseif (InputInfo.KeyCode.Name == 'Minus') or (InputInfo.KeyCode.Name == 'KeypadMinus') then
			if ResizeTool.UI then
				ResizeTool.UI.IncrementOption.Increment.TextBox:CaptureFocus()
			end
		end

	end));

end;

function SetAxisSize(Axis, Size)
	-- Sets the selection's size on axis `Axis` to `Size`

	-- Track this change
	TrackChange();

	-- Prepare parts to be resized
	local InitialStates = PreparePartsForResizing();

	-- Update each part
	for Item, InitialState in pairs(InitialStates) do
		
		if Item:IsA("BasePart") then
		-- Set the part's new size
		Item.Size = Vector3.new(
			Axis == 'X' and Size or Item.Size.X,
			Axis == 'Y' and Size or Item.Size.Y,
			Axis == 'Z' and Size or Item.Size.Z
		);

		-- Keep the part in place
			Item.CFrame = InitialState.CFrame;
		elseif Item:IsA("DataModelMesh") then
			local Parent = Item.Parent
			local ParentInitialSize = InitialStates[Parent] and InitialStates[Parent].Size or Vector3.new()
			local SizeRatio = ParentInitialSize / Size

			Item.Scale = Vector3.new(
				Axis == 'X' and Item.Scale.X / ParentInitialSize.X * Size or Item.Scale.X,
				Axis == 'Y' and Item.Scale.Y / ParentInitialSize.Y * Size or Item.Scale.Y,
				Axis == 'Z' and Item.Scale.Z / ParentInitialSize.Z * Size or Item.Scale.Z
			);
			
			Item.Offset = InitialState.Offset;
		end

	end;
	
	-- Cache up permissions for all private areas
	local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Selection.Parts), Core.Player);

	-- Revert changes if player is not authorized to resize parts towards the end destination
	if Core.Mode == 'Tool' and Security.ArePartsViolatingAreas(Selection.Parts, Core.Player, false, AreaPermissions) then
		for Part, State in pairs(InitialStates) do
			Part.Size = State.Size;
			Part.CFrame = State.CFrame;
		end;
	end;

	-- Restore the parts' original states
	for Part, State in pairs(InitialStates) do
		if Part:IsA("BasePart") then
			Part:MakeJoints();
			Part.CanCollide = State.CanCollide;
			Part.Anchored = State.Anchored;
		end
	end;

	ShowHandles()

	-- Register the change
	RegisterChange();

end;

function NudgeSelectionByFace(Face)
	-- Nudges the size of the selection in the direction of the given face

	-- Get amount to nudge by
	local NudgeAmount = ResizeTool.Increment;

	-- Reverse nudge amount if shift key is held while nudging
	local PressedKeys = Support.FlipTable(Support.GetListMembers(Services.UserInputService:GetKeysPressed(), 'KeyCode'));
	if PressedKeys[Enum.KeyCode.LeftShift] or PressedKeys[Enum.KeyCode.RightShift] then
		NudgeAmount = -NudgeAmount;
	end;

	-- Track this change
	TrackChange();

	-- Prepare parts to be resized
	InitialState = PreparePartsForResizing();
	
	local BoundingBoxPart
	local BoundingBoxSize
	local BoundingBoxCFrame
	
	if ResizeTool.Directions == "Scale" then
		BoundingBoxPart = BoundingBox.GetBoundingBox()
		BoundingBoxSize = BoundingBoxPart.Size
		BoundingBoxCFrame = BoundingBoxPart.CFrame.Position
	end
	
	-- Perform the resizing
	local Success, Adjustment = ResizePartsByFace(Face, NudgeAmount, ResizeTool.Directions, InitialState, BoundingBoxSize, BoundingBoxCFrame);

	-- If the resizing did not succeed, resize according to the suggested adjustment
	if not Success then
		ResizePartsByFace(Face, Adjustment, ResizeTool.Directions, InitialState, BoundingBoxSize, BoundingBoxCFrame);
	end;

	-- Update "studs resized" indicator
	if ResizeTool.UI then
		ResizeTool.UI.Changes.Text.Text = 'resized ' .. Support.Round(Adjustment or NudgeAmount, MaxDecimals) .. ' studs';
	end;

	-- Cache up permissions for all private areas
	local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Selection.Parts), Core.Player);

	-- Revert changes if player is not authorized to resize parts towards the end destination
	if Core.Mode == 'Tool' and Security.ArePartsViolatingAreas(Selection.Parts, Core.Player, false, AreaPermissions) then
		for Part, State in pairs(InitialState) do
			Part.Size = State.Size;
			Part.CFrame = State.CFrame;
		end;
	end;

	-- Restore the parts' original states
	for Part, State in pairs(InitialState) do
		Part:MakeJoints();
		Part.CanCollide = State.CanCollide;
		Part.Anchored = State.Anchored;
	end;

	-- Register the change
	RegisterChange();

end;

function GetMeshes()
	-- Returns all the meshes in the selection

	local Meshes = {};

	-- Get any meshes from any selected parts
	for _, Part in pairs(Selection.Parts) do
		table.insert(Meshes, Support.GetChildOfClass(Part, 'SpecialMesh'));
	end;

	-- Return the meshes
	return Meshes;
end;

function TrackChange()

	-- Start the record
	HistoryRecord = {
		Parts = Support.CloneTable(Selection.Parts);
		Meshes = GetMeshes();
		BeforeSize = {};
		AfterSize = {};
		BeforeScale = {};
		AfterScale = {};
		BeforeCFrame = {};
		AfterCFrame = {};
		BeforeOffset = {};
		AfterOffset = {};
		Selection = Selection.Items;

		Unapply = function (Record)
			-- Reverts this change

			-- Select the changed parts
			Selection.Replace(Record.Selection)

			-- Put together the change request
			local Changes = {};
			for _, Part in pairs(Record.Parts) do
				table.insert(Changes, { Part = Part, Size = Record.BeforeSize[Part], CFrame = Record.BeforeCFrame[Part] });
			end;
			for _, Mesh in pairs(Record.Meshes) do
				table.insert(Changes, { Mesh = Mesh, Scale = Record.BeforeScale[Mesh], Offset = Record.BeforeOffset[Mesh] });
			end;

			-- Send the change request
			Core.SyncAPI:Invoke('SyncResize', Changes);

		end;

		Apply = function (Record)
			-- Applies this change

			-- Select the changed parts
			Selection.Replace(Record.Selection)

			-- Put together the change request
			local Changes = {};
			for _, Part in pairs(Record.Parts) do
				table.insert(Changes, { Part = Part, Size = Record.AfterSize[Part], CFrame = Record.AfterCFrame[Part] });
			end;
			for _, Mesh in pairs(Record.Meshes) do
				table.insert(Changes, { Mesh = Mesh, Scale = Record.AfterScale[Mesh], Offset = Record.AfterOffset[Mesh] });
			end;


			-- Send the change request
			Core.SyncAPI:Invoke('SyncResize', Changes);

		end;

	};

	-- Collect the selection's initial state
	for _, Part in pairs(HistoryRecord.Parts) do
		HistoryRecord.BeforeSize[Part] = Part.Size;
		HistoryRecord.BeforeCFrame[Part] = Part.CFrame;
	end;
	
	for _, Mesh in pairs(HistoryRecord.Meshes) do
		HistoryRecord.BeforeScale[Mesh] = Mesh.Scale;
		HistoryRecord.BeforeOffset[Mesh] = Mesh.Offset;
	end;

end;

function RegisterChange()
	-- Finishes creating the history record and registers it

	-- Make sure there's an in-progress history record
	if not HistoryRecord then
		return;
	end;

	-- Collect the selection's final state
	local Changes = {};
	for _, Part in pairs(HistoryRecord.Parts) do
		HistoryRecord.AfterSize[Part] = Part.Size;
		HistoryRecord.AfterCFrame[Part] = Part.CFrame;
		table.insert(Changes, { Part = Part, Size = Part.Size, CFrame = Part.CFrame });
	end;
	
	for _, Mesh in pairs(HistoryRecord.Meshes) do
		HistoryRecord.AfterScale[Mesh] = Mesh.Scale;
		HistoryRecord.AfterOffset[Mesh] = Mesh.Offset;
		table.insert(Changes, { Mesh = Mesh, Scale = Mesh.Scale, Offset = Mesh.Offset });
	end;

	-- Send the change to the server
	Core.SyncAPI:Invoke('SyncResize', Changes);

	-- Register the record and clear the staging
	Core.History.Add(HistoryRecord);
	HistoryRecord = nil;

end;

function PreparePartsForResizing()
	-- Prepares parts for resizing and returns the initial state of the parts

	local InitialState = {};
	
	-- Stop parts from moving, and capture the initial state of the parts
	for _, Part: BasePart in pairs(Selection.Parts) do
		InitialState[Part] = { Anchored = Part.Anchored, CanCollide = Part.CanCollide, Size = Part.Size, CFrame = Part.CFrame };
		Part.Anchored = true;
		Part.CanCollide = false;
		Part:BreakJoints();
		Part.AssemblyLinearVelocity = Vector3.new();
		Part.AssemblyAngularVelocity = Vector3.new();
		
		if ResizeTool.IncludeMeshes == true then
			if Part:FindFirstChildWhichIsA("DataModelMesh") then
				local Mesh = Part:FindFirstChildWhichIsA("DataModelMesh")
				InitialState[Mesh] = { Scale = Mesh.Scale, Offset = Mesh.Offset };
			end
		end	
	end;

	return InitialState;
end;


function GetIncrementMultiple(Number, Increment)

	-- Get how far the actual distance is from a multiple of our increment
	local MultipleDifference = Number % Increment;

	-- Identify the closest lower and upper multiples of the increment
	local LowerMultiple = Number - MultipleDifference;
	local UpperMultiple = Number - MultipleDifference + Increment;

	-- Calculate to which of the two multiples we're closer
	local LowerMultipleProximity = math.abs(Number - LowerMultiple);
	local UpperMultipleProximity = math.abs(Number - UpperMultiple);

	-- Use the closest multiple of our increment as the distance moved
	if LowerMultipleProximity <= UpperMultipleProximity then
		Number = LowerMultiple;
	else
		Number = UpperMultiple;
	end;

	return Number;
end;

-- Event that fires when a new point is snapped
PointSnapped = Signal.new()

function StartSnapping()

	-- Make sure snapping isn't already enabled
	if SnappingStage or SnapTracking.Enabled then
		return;
	end;

	-- Start first snapping stage
	SnappingStage = 'Starting';

	-- Only enable corner snapping
	SnapTracking.TrackEdgeMidpoints = false;
	SnapTracking.TrackFaceCentroids = false;
	SnapTracking.TargetFilter = function (Target)
		return Selection.PartIndex[Target]
	end

	-- Trigger the PointSnapped event when a new point is snapped
	SnapTracking.StartTracking(function (NewPoint)
		if NewPoint and NewPoint.p ~= SnappedPoint then
			SnappedPoint = NewPoint.p;
			PointSnapped:Fire(NewPoint.p);
		end;
	end);

	-- Listen for when the user starts dragging while in snap mode
	Connections.SnapDragStart = Support.AddUserInputListener('Began', 'MouseButton1', false, function (Input)

		-- Initialize snapping state
		SnappingStage = 'Direction';
		SnappingStartAim = Vector2.new(Input.Position.X, Input.Position.Y);
		SnappingStartPoint = SnappedPoint;
		SnappingStartTarget = SnapTracking.Target;
		SnappingStartDirections = GetFaceOffsetsFromCorner(SnappingStartTarget, SnappingStartPoint);
		
		SnappingStartSelectionState = PreparePartsForResizing();
		AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Selection.Parts), Core.Player);

		-- Pause snapping
		SnapTracking.StopTracking();

		-- Start a direction line
		DirectionLine = Core.Tool.Interfaces.SnapLine:Clone();
		DirectionLine.Parent = Core.UI;
		DirectionLine.Visible = false;

		-- Track changes for history
		TrackChange();

		-- Listen for when the user drags
		Connections.SnapDrag = Support.AddUserInputListener('Changed', 'MouseMovement', true, function (Input)

			-- Update the latest aim
			SnappingEndAim = Vector2.new(Input.Position.X, Input.Position.Y);
			ScreenSnappedPoint = Workspace.CurrentCamera:WorldToScreenPoint(SnappingStartPoint);
			ScreenSnappedPoint = Vector2.new(ScreenSnappedPoint.X, ScreenSnappedPoint.Y);

			-- Calculate direction setting length
			local DirectionSettingLength = math.min(50, math.max(50, (SnappingStartAim - ScreenSnappedPoint).magnitude * 1.5));

			-- Use the mouse position to figure out the resize direction (until after direction setting length)
			if SnappingStage == 'Direction' then

				-- Get current angle from snap point
				local DragAngle = math.deg(math.atan2(SnappingEndAim.Y - ScreenSnappedPoint.Y, SnappingEndAim.X - ScreenSnappedPoint.X));
				DragAngle = (DragAngle > 0) and (DragAngle - 360) or DragAngle;

				-- Go through corner offsets representing the possible directions
				local Directions = {};
				for _, Direction in pairs(SnappingStartDirections) do

					-- Map the corner & corner offset to screen points
					local ScreenOffsetPoint = Workspace.CurrentCamera:WorldToScreenPoint(Direction.Offset);

					-- Get direction angle from snap point
					local DirectionAngle = math.deg(math.atan2(ScreenOffsetPoint.Y - ScreenSnappedPoint.Y, ScreenOffsetPoint.X - ScreenSnappedPoint.X));
					DirectionAngle = (DirectionAngle > 0) and (DirectionAngle - 360) or DirectionAngle;

					-- Calculate delta between drag and direction angles
					local AngleDelta = math.abs(DragAngle - DirectionAngle) % 180;
					AngleDelta = (AngleDelta > 90) and (180 - AngleDelta) or AngleDelta;

					-- Insert the potential direction
					table.insert(Directions, {
						Face = Direction.Face,
						AngleDelta = AngleDelta,
						DirectionAngle = DirectionAngle,
						Offset = Direction.Offset
					});

				end;

				-- Get the direction most similar to the dragging angle
				table.sort(Directions, function (A, B)
					return A.AngleDelta < B.AngleDelta;
				end);

				-- Center direction line at snap point
				DirectionLine.Position = UDim2.new(0, ScreenSnappedPoint.X, 0, ScreenSnappedPoint.Y);

				-- Orient direction line towards drag direction
				if math.abs(DragAngle - Directions[1].DirectionAngle) <= 90 then
					DirectionLine.Rotation = Directions[1].DirectionAngle;
				else
					DirectionLine.Rotation = 180 + Directions[1].DirectionAngle;
				end;

				-- Show the direction line
				DirectionLine.PointMarker.Rotation = -DirectionLine.Rotation;
				DirectionLine.SnapProgress.Size = UDim2.new(0, DirectionSettingLength, 2, 0);
				DirectionLine.Visible = true;

				-- Check if drag has passed direction setting length
				local Length = (SnappingEndAim - ScreenSnappedPoint).magnitude;
				if Length < DirectionSettingLength then
					return;
				end;

				-- Clear the direction line
				DirectionLine:Destroy()

				-- Select the resizing direction that was closest to the mouse drag
				SnappingDirection = Directions[1].Face;
				SnappingDirectionOffset = Directions[1].Offset;

				-- Move to the destination-picking stage of snapping
				SnappingStage = 'Destination';

				-- Set destination-stage snapping options
				SnapTracking.TrackEdgeMidpoints = true;
				SnapTracking.TrackFaceCentroids = true;
				SnapTracking.TargetFilter = function (Target) return not Target.Locked; end;
				SnapTracking.TargetBlacklist = Selection.Items;

				-- Start a distance alignment line
				AlignmentLine = Core.Tool.Interfaces.SnapLineSegment:Clone();
				AlignmentLine.Visible = false;
				AlignmentLine.Parent = Core.UI;

				-- Re-enable snapping to select destination
				SnapTracking.StartTracking(function (NewPoint)
					if NewPoint and NewPoint.p ~= SnappedPoint then
						SnappedPoint = NewPoint.p;
						PointSnapped:Fire(NewPoint.p);
					end;
				end);

			end;

		end);

		-- Listen for when a new point is snapped
		Connections.Snap = PointSnapped:Connect(function (SnappedPoint)

			-- Resize to snap point if in the destination stage of snapping
			if SnappingStage == 'Destination' then

				-- Calculate direction and distance to resize towards
				local BoundingBoxPart
				local BoundingBoxSize
				local BoundingBoxCFrame

				if ResizeTool.Directions == "Scale" then
					BoundingBoxPart = BoundingBox.GetBoundingBox()
					BoundingBoxSize = BoundingBoxPart.Size
					BoundingBoxCFrame = BoundingBoxPart.CFrame
				end
				
				local Direction = (SnappingDirectionOffset - SnappingStartPoint).unit;
				local Distance = (SnappedPoint - SnappingStartPoint):Dot(Direction);

				-- Resize the parts on the selected faces by the calculated distance
				local Success = ResizePartsByFace(SnappingDirection, Distance, 'Normal', SnappingStartSelectionState, BoundingBoxSize, BoundingBoxCFrame);

				-- Update the UI on resize success
				if Success then

					-- Update "studs resized" indicator
					if ResizeTool.UI then
						ResizeTool.UI.Changes.Text.Text = 'resized ' .. Support.Round(Distance, MaxDecimals) .. ' studs';
					end;

					-- Get snap point and destination point screen positions for UI alignment
					local ScreenStartPoint = Workspace.CurrentCamera:WorldToScreenPoint(SnappingStartPoint + (Direction * Distance));
					ScreenStartPoint = Vector2.new(ScreenStartPoint.X, ScreenStartPoint.Y);
					local ScreenDestinationPoint = Workspace.CurrentCamera:WorldToScreenPoint(SnappedPoint);
					ScreenDestinationPoint = Vector2.new(ScreenDestinationPoint.X, ScreenDestinationPoint.Y)

					-- Update the distance alignment line
					local AlignmentAngle = math.deg(math.atan2(ScreenDestinationPoint.Y - ScreenStartPoint.Y, ScreenDestinationPoint.X - ScreenStartPoint.X));
					local AlignmentCenter = ScreenStartPoint:Lerp(ScreenDestinationPoint, 0.5);
					AlignmentLine.Position = UDim2.new(0, AlignmentCenter.X, 0, AlignmentCenter.Y);
					AlignmentLine.Rotation = AlignmentAngle;
					AlignmentLine.Size = UDim2.new(0, (ScreenDestinationPoint - ScreenStartPoint).magnitude, 0, 1);
					AlignmentLine.PointMarkerA.Rotation = -AlignmentAngle;
					AlignmentLine.Visible = true;

				end;

				-- Make sure we're not entering any unauthorized private areas
				if Core.Mode == 'Tool' and Security.ArePartsViolatingAreas(Selection.Parts, Core.Player, false, AreaPermissions) then
					for Part, State in pairs(SnappingStartSelectionState) do
						Part.Size = State.Size;
						Part.CFrame = State.CFrame;
					end;
				end;

			end;

		end);

	end);

end;

-- Stop snapping whenever mouse is released
Support.AddUserInputListener('Ended', 'MouseButton1', true, function (Input)

	-- Ensure snapping is ongoing
	if not SnappingStage then
		return;
	end;

	-- Finish snapping
	FinishSnapping();

end);


function FinishSnapping()
	-- Cleans up and finalizes the snapping operation

	-- Ensure snapping is ongoing
	if not SnappingStage then
		return;
	end;

	-- Restore the selection's original state if stage was reached
	if SnappingStartSelectionState then
		for Part, State in pairs(SnappingStartSelectionState) do
			Part:MakeJoints();
			Part.CanCollide = State.CanCollide;
			Part.Anchored = State.Anchored;
		end;
	end;

	-- Disable any snapping stage
	SnappingStage = nil;

	-- Stop snap point tracking
	SnapTracking.StopTracking();

	-- Clear any UI
	if DirectionLine then
		DirectionLine:Destroy();
		DirectionLine = nil;
	end;
	if AlignmentLine then
		AlignmentLine:Destroy();
		AlignmentLine = nil;
	end;

	-- Register any change
	if HistoryRecord then
		RegisterChange();
	end;

	-- Disconnect snapping listeners
	ClearConnection 'SnapDragStart';
	ClearConnection 'SnapDrag';
	ClearConnection 'Snap';
	ClearConnection 'SnapDragEnd';

end;


function GetFaceOffsetsFromCorner(Part, Point)
	-- Returns offsets of the given corner point in the direction of its intersecting faces

	local Offsets = {};

	-- Go through each face the corner intersects
	local Faces = GetFacesFromCorner(Part, Point);
	for _, Face in pairs(Faces) do

		-- Calculate the offset from the corner in the direction of the face
		local FaceOffset = (Vector3.FromNormalId(Face) * Part.Size) / 2;
		local Offset = CFrame.new(Point) * CFrame.Angles(Part.CFrame:toEulerAnglesXYZ()) * FaceOffset;
		table.insert(Offsets, { Face = Face, Offset = Offset });

	end;

	-- Return the list of offsets
	return Offsets;
end;

function GetFacesFromCorner(Part, Point)
	-- Returns the 3 faces that the given corner point intersects

	local Faces = {};

	-- Get all the face centers of the part
	for _, FaceEnum in pairs(Enum.NormalId:GetEnumItems()) do
		local Face = Part.CFrame * (Part.Size / 2 * Vector3.FromNormalId(FaceEnum));

		-- Get the face's proximity to the point
		local Proximity = (Point - Face).magnitude;

		-- Keep track of the proximity to the point
		table.insert(Faces, { Proximity = Proximity, Face = FaceEnum });
	end;

	-- Find the closest faces to the point
	table.sort(Faces, function (A, B)
		return A.Proximity < B.Proximity;
	end);

	-- Return the 3 closest faces
	return { Faces[1].Face, Faces[2].Face, Faces[3].Face };
end;

-- Return the tool
return ResizeTool;
