Tool = script.Parent.Parent;
Core = require(Tool.Core);
SnapTracking = require(Tool.Core.Snapping);
BoundingBox = require(Tool.Core.BoundingBox);
Sounds = Tool:WaitForChild("Sounds");

-- Services
local ContextActionService = game:GetService 'ContextActionService'
local Workspace = game:GetService 'Workspace'
local UserInputService = game:GetService('UserInputService')

-- Libraries
local Libraries = Core.Libraries
local Make = require(Libraries:WaitForChild 'Make')
local ListenForManualWindowTrigger = require(Tool.Core:WaitForChild('ListenForManualWindowTrigger'))

-- Import relevant references
Selection = Core.Selection;
Support = Core.Support;
Security = Core.Security;

-- Initialize the tool
local RotateTool = {
	Name = 'Rotate Tool';
	Color = BrickColor.new 'Bright green';
	FocusWise = false;

	-- Default options
	Increment = 15;
	Pivot = 'Center';
}

if table.find(Core.Options.ToolsBlacklist, RotateTool.Name) then
	return RotateTool
end

RotateTool.ManualText = [[<font weight="900" size="24"><u><i>Rotate Tool  🛠</i></u></font>
Allows you to rotate parts.<font size="12"><br /></font>
<font size="12" color="rgb(150, 150, 150)"><b>Pivot</b></font>
This option lets you choose what to rotate the parts around.<font size="6"><br /></font>
 <font color="rgb(150, 150, 150)">•</font>  <b>CENTER</b> <font color="rgb(150, 150, 150)">—</font> Relative to the <b>center of the selection</b>
 <font color="rgb(150, 150, 150)">•</font>  <b>LOCAL</b> <font color="rgb(150, 150, 150)">—</font> Each part around its <b>own center</b>
 <font color="rgb(150, 150, 150)">•</font>  <b>LAST</b> <font color="rgb(150, 150, 150)">—</font> Relative to the <b>center of the last part clicked</b><font size="6"><br /></font>

<b>TIP:</b> Click on any part to focus the handles on it.<font size="6"><br /></font>
<b>TIP: </b>Hit the <b>Enter</b> key to switch between Pivot modes quickly.<font size="12"><br /></font>

<font size="12" color="rgb(150, 150, 150)"><b>Increment</b></font>
Lets you choose how many degrees to rotate by.<font size="6"><br /></font>

<b>TIP: </b>Hit the – key to quickly type increments.<font size="6"><br /></font>

<b>TIP: </b>Use your number pad to rotate exactly by the current increment. Holding <b>Shift</b> reverses the increment.<font size="4"><br /></font>
   <font color="rgb(150, 150, 150)">•</font>  4 & 6 — Y axis (green)
   <font color="rgb(150, 150, 150)">•</font>  1 & 9 — Z axis (blue)
   <font color="rgb(150, 150, 150)">•</font>  2 & 8 — X axis (red)<font size="12"><br /></font>

<font size="12" color="rgb(150, 150, 150)"><b>Snapping</b></font>
Press <b><i>R</i></b> and click on a part's <b>snap point</b> to rotate around it.
]]

-- Container for temporary connections (disconnected automatically)
local Connections = {};

function RotateTool.Equip()
	-- Enables the tool's equipped functionality

	-- Start up our interface
	ShowUI();
	BindShortcutKeys();
	
	-- Set our current pivot mode
	SetPivot(RotateTool.Pivot);

end;

function RotateTool.Unequip()
	-- Disables the tool's equipped functionality

	-- Clear unnecessary resources
	HideUI();
	HideHandles();
	ClearConnections();
	BoundingBox.ClearBoundingBox();
	SnapTracking.StopTracking();

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
	if Connections[ConnectionKey] then
		Connection:Disconnect();
		Connections[ConnectionKey] = nil;
	end;

end;

function ShowUI()
	-- Creates and reveals the UI

	-- Reveal UI if already created
	if RotateTool.UI and RotateTool.UI.Parent ~= nil then

		-- Reveal the UI
		RotateTool.UI.Visible = true;

		-- Update the UI every 0.1 seconds
		UIUpdater = Support.ScheduleRecurringTask(UpdateUI, 0.1);

		-- Skip UI creation
		return;

	end;
	
	if RotateTool.UI then
		RotateTool.UI:Destroy()
	end

	-- Create the UI
	RotateTool.UI = Core.Interfaces.BTRotateToolGUI:Clone();
	RotateTool.UI.Parent = Core.UI;
	RotateTool.UI.Visible = true;

	-- Add functionality to the pivot option switch
	local PivotSwitch = RotateTool.UI.PivotOption;
	PivotSwitch.Center.Button.MouseButton1Down:Connect(function ()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Press"))
		SetPivot('Center');
	end);
	PivotSwitch.Center.Button.MouseEnter:Connect(function ()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Hover"))
	end);
	PivotSwitch.Local.Button.MouseButton1Down:Connect(function ()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Press"))
		SetPivot('Local');
	end);
	PivotSwitch.Local.Button.MouseEnter:Connect(function ()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Hover"))
	end);
	PivotSwitch.Last.Button.MouseButton1Down:Connect(function ()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Press"))
		SetPivot('Last');
	end);
	PivotSwitch.Last.Button.MouseEnter:Connect(function ()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Hover"))
	end);
	
	local FocusToggle = RotateTool.UI.FocusOption.Check

	FocusToggle.Activated:Connect(function()
		RotateTool.FocusWise = not RotateTool.FocusWise
		UpdateToggleInput(FocusToggle, RotateTool.FocusWise)
	end)

	UpdateToggleInput(FocusToggle, RotateTool.FocusWise)
	
	-- Add functionality to the increment input
	local IncrementInput = RotateTool.UI.IncrementOption.Increment.TextBox;
	IncrementInput.FocusLost:Connect(function (EnterPressed)
		RotateTool.Increment = tonumber(IncrementInput.Text) or RotateTool.Increment;
		IncrementInput.Text = Support.Round(RotateTool.Increment, 4);
	end);

	-- Add functionality to the rotation inputs
	local XInput = RotateTool.UI.Info.RotationInfo.X.TextBox;
	local YInput = RotateTool.UI.Info.RotationInfo.Y.TextBox;
	local ZInput = RotateTool.UI.Info.RotationInfo.Z.TextBox;
	XInput.FocusLost:Connect(function (EnterPressed)
		local NewAngle = tonumber(XInput.Text);
		if NewAngle then
			SetAxisAngle('X', NewAngle);
		end;
	end);
	YInput.FocusLost:Connect(function (EnterPressed)
		local NewAngle = tonumber(YInput.Text);
		if NewAngle then
			SetAxisAngle('Y', NewAngle);
		end;
	end);
	ZInput.FocusLost:Connect(function (EnterPressed)
		local NewAngle = tonumber(ZInput.Text);
		if NewAngle then
			SetAxisAngle('Z', NewAngle);
		end;
	end);

	-- Hook up manual triggering
	local SignatureButton = RotateTool.UI:WaitForChild('Title'):WaitForChild('Signature')
	ListenForManualWindowTrigger(RotateTool.ManualText, RotateTool.Color.Color, SignatureButton)

	-- Update the UI every 0.1 seconds
	UIUpdater = Support.ScheduleRecurringTask(UpdateUI, 0.1);

end;

function UpdateToggleInput(Toggle, Data)
	-- Updates the data in the given buttons

	-- Go through the inputs and data
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

end;

function HideUI()
	-- Hides the tool UI

	-- Make sure there's a UI
	if not RotateTool.UI then
		return;
	end;

	-- Hide the UI
	RotateTool.UI.Visible = false;

	-- Stop updating the UI
	UIUpdater:Stop();

end;

function UpdateUI()
	-- Updates information on the UI

	-- Make sure the UI's on
	if not RotateTool.UI then
		return;
	end;
	
	-- Display the focus wise option only when available
	RotateTool.UI.FocusOption.Visible = RotateTool.Pivot == "Last" and true or false
	
	-- Only show and calculate selection info if it's not empty
	if #Selection.Parts == 0 and #Selection.Attachments == 0 then
		RotateTool.UI.Info.Visible = false;
		RotateTool.UI.Size = UDim2.new(0, 245, 0, 90);
		return;
	else
		RotateTool.UI.Info.Visible = true;
		RotateTool.UI.Size = UDim2.new(0, 245, 0, 150);
	end;

	-----------------------------------------
	-- Update the size information indicators
	-----------------------------------------

	local CommonX --= Support.IdentifyCommonItem(XVariations)
	local CommonY --= Support.IdentifyCommonItem(YVariations)
	local CommonZ --= Support.IdentifyCommonItem(ZVariations)

	-- Identify common positions across axes
	if RotateTool.FocusWise == false or RotateTool.Pivot ~= "Last" then
		local XVariations, YVariations, ZVariations = {}, {}, {}

		for _, Part in pairs(Selection.Parts) do
			table.insert(XVariations, Support.Round(Part.Orientation.X, 3))
			table.insert(YVariations, Support.Round(Part.Orientation.Y, 3))
			table.insert(ZVariations, Support.Round(Part.Orientation.Z, 3))
		end
		for _, Attachment in pairs(Selection.Attachments) do
			table.insert(XVariations, Support.Round(Attachment.WorldOrientation.X, 3))
			table.insert(YVariations, Support.Round(Attachment.WorldOrientation.Y, 3))
			table.insert(ZVariations, Support.Round(Attachment.WorldOrientation.Z, 3))
		end

		CommonX = Support.IdentifyCommonItem(XVariations)
		CommonY = Support.IdentifyCommonItem(YVariations)
		CommonZ = Support.IdentifyCommonItem(ZVariations)
	else
		-- Just output the focus/bounding box's position
		local FocusedObject = Selection.Focus

		if FocusedObject:IsA("BasePart") then
			CommonX = Support.Round(FocusedObject.Orientation.X, 3)
			CommonY = Support.Round(FocusedObject.Orientation.Y, 3)
			CommonZ = Support.Round(FocusedObject.Orientation.Z, 3)
		else
			CommonX = Support.Round(FocusedObject.WorldOrientation.X, 3)
			CommonY = Support.Round(FocusedObject.WorldOrientation.Y, 3)
			CommonZ = Support.Round(FocusedObject.WorldOrientation.Z, 3)
		end
	end

	-- Shortcuts to indicators
	local XIndicator = RotateTool.UI.Info.RotationInfo.X.TextBox;
	local YIndicator = RotateTool.UI.Info.RotationInfo.Y.TextBox;
	local ZIndicator = RotateTool.UI.Info.RotationInfo.Z.TextBox;

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

function SetPivot(PivotMode)
	-- Sets the given rotation pivot mode

	-- Update setting
	RotateTool.Pivot = PivotMode;

	-- Update the UI switch
	if RotateTool.UI then
		Core.ToggleSwitch(PivotMode, RotateTool.UI.PivotOption);
	end;

	-- Disable any unnecessary bounding boxes
	BoundingBox.ClearBoundingBox();

	-- For center mode, use bounding box handles
	if PivotMode == 'Center' then
			BoundingBox.StartBoundingBox(function (BoundingBox)
				AttachHandles(BoundingBox, nil)
			end)

	-- For local mode, use focused part handles
	elseif PivotMode == 'Local' then
		BoundingBox.StartBoundingBox(function () end)
		
		AttachHandles(Selection.Focus, true); 

	-- For last mode, use focused part handles
	elseif PivotMode == 'Last' then
		BoundingBox.StartBoundingBox(function () end)
		
		AttachHandles(CustomPivotPoint and (RotateTool.Handles and RotateTool.Handles.Adornee) or Selection.Focus, true);
	end;

end;

function AttachHandles(Part, Autofocus, IsGlobal)
	
	if not UIUpdater or UIUpdater.Running ~= true then return end
	-- Creates and attaches handles to `Part`, and optionally automatically attaches to the focused part

	-- Enable autofocus if requested and not already on
	if Autofocus and not Connections.AutofocusHandle then
		Connections.AutofocusHandle = Selection.FocusChanged:Connect(function ()
			
			if RotateTool.Pivot == "Center" and #Selection.Attachments > 0 and Selection.Focus:IsA("Attachment") then
				AttachHandles(Selection.Focus, true, true)
			elseif RotateTool.Pivot == "Center" then
				AttachHandles(BoundingBox.GetBoundingBox(), true, false)
				return
			end
			
			AttachHandles(Selection.Focus, true, false);
		end);

	-- Disable autofocus if not requested and on
	elseif not Autofocus and Connections.AutofocusHandle then
		ClearConnection 'AutofocusHandle';
	end;

	-- Clear previous pivot point
	CustomPivotPoint = nil

	-- Just attach and show the handles if they already exist
	if RotateTool.Handles then
		RotateTool.Handles:BlacklistObstacle(BoundingBox.GetBoundingBox())
		RotateTool.Handles:SetAdornee(Part, IsGlobal)
		return
	end

	local AreaPermissions
	local function OnHandleDragStart()
		-- Prepare for rotating parts when the handle is clicked

		-- Prevent selection
		Core.Targeting.CancelSelecting();

		-- Indicate rotating via handle
		RotateTool.HandleRotating = true;

		-- Freeze bounding box extents while rotating
		if BoundingBox.GetBoundingBox() then
			InitialExtentsSize, InitialExtentsCFrame = BoundingBox.CalculateExtents(Selection.Parts, Selection.Attachments, BoundingBox.StaticExtents)
--			BoundingBox.PauseMonitoring();
		end;

		-- Stop parts from moving, and capture the initial state of the parts
		InitialPartStates, InitialModelStates, InitialAttachmentsStates = PrepareSelectionForRotating()

		-- Track the change
		TrackChange();

		-- Cache area permissions information
		if Core.Mode == 'Tool' then
			AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Selection.Parts), Core.Player);
		end;

		-- Set the pivot point to the center of the selection if in Center mode
		if RotateTool.Pivot == 'Center' and #Selection.Parts > 0 and BoundingBox.GetBoundingBox() then
			
			PivotPoint = BoundingBox.GetBoundingBox().CFrame;
			
		elseif RotateTool.Pivot == 'Center' and #Selection.Attachments > 0 and Selection.Focus:IsA("Attachment") then
			
			PivotPoint = CFrame.new(Selection.Focus.WorldCFrame.Position);
			
		-- Set the pivot point to the center of the focused part if in Last mode
		elseif RotateTool.Pivot == 'Last' and not CustomPivotPoint then
			if Selection.Focus:IsA 'BasePart' then
				PivotPoint = Selection.Focus.CFrame
			elseif Selection.Focus:IsA 'Model' then
				PivotPoint = Selection.Focus:GetPivot()
			elseif Selection.Focus:IsA 'Attachment' then
				PivotPoint = Selection.Focus.WorldCFrame
			end
		end;

	end

	local function OnHandleDrag(Axis, Rotation)
		-- Update parts when the handles are moved

		-- Only rotate if handle is enabled
		if not RotateTool.HandleRotating then
			return;
		end;

		-- Turn the rotation amount into degrees
		Rotation = math.deg(Rotation);

		-- Calculate the increment-aligned rotation amount
		Rotation = GetIncrementMultiple(Rotation, RotateTool.Increment) % 360;

		-- Get displayable rotation delta
		local DisplayedRotation = GetHandleDisplayDelta(Rotation);

		-- Perform the rotation
		RotateSelectionAroundPivot(RotateTool.Pivot, PivotPoint, Axis, Rotation, InitialPartStates, InitialModelStates, InitialAttachmentsStates)

		-- Make sure we're not entering any unauthorized private areas
		if Core.Mode == 'Tool' and Security.ArePartsViolatingAreas(Selection.Parts, Core.Player, false, AreaPermissions) then
			for Part, State in pairs(InitialPartStates) do
				Part.CFrame = State.CFrame;
			end;
			for Model, State in pairs(InitialModelStates) do
				Model.WorldPivot = State.Pivot
			end
			for Attachment, State in pairs(InitialAttachmentsStates) do
				Attachment.WorldCFrame = State.WorldCFrame
			end

			-- Reset displayed rotation delta
			DisplayedRotation = 0;
		end;

		-- Update the "degrees rotated" indicator
		if RotateTool.UI then
			RotateTool.UI.Changes.Text.Text = 'rotated ' .. DisplayedRotation .. ' degrees';
		end;

	end

	local function OnHandleDragEnd()
		if not RotateTool.HandleRotating then
			return
		end

		-- Prevent selection
		Core.Targeting.CancelSelecting();

		-- Disable rotating
		RotateTool.HandleRotating = false;

		-- Clear this connection to prevent it from firing again
		ClearConnection 'HandleRelease';

		-- Clear change indicator states
		HandleDirection = nil;
		HandleFirstAngle = nil;
		LastDisplayedRotation = nil;

		-- Make joints, restore original anchor and collision states
		for Part, State in pairs(InitialPartStates) do
			Part:MakeJoints();
			Core.RestoreJoints(State.Joints);
			Part.CanCollide = State.CanCollide;
			Part.Anchored = State.Anchored;
		end;

		-- Register the change
		RegisterChange();

		-- Resume normal bounding box updating
--		BoundingBox.RecalculateStaticExtents();
--		BoundingBox.ResumeMonitoring();

	end

	-- Create the handles
	local ArcHandles = require(Libraries:WaitForChild(Core.Options.IgnoreHandlesWithCamera and not game:GetService("UserInputService").TouchEnabled and 'ArcHandles' or 'OldArcHandles'))
	RotateTool.Handles = ArcHandles.new({
		Color = RotateTool.Color.Color,
		Parent = Core.UI,
		Adornee = Part,
		ObstacleBlacklist = { BoundingBox.GetBoundingBox() },
		OnDragStart = OnHandleDragStart,
		OnDrag = OnHandleDrag,
		OnDragEnd = OnHandleDragEnd
	})
end

function HideHandles()
	-- Hides the resizing handles

	-- Make sure handles exist and are visible
	if not RotateTool.Handles then
		return;
	end;

	-- Hide the handles
	RotateTool.Handles = RotateTool.Handles:Destroy()

	-- Disable handle autofocus if enabled
	ClearConnection 'AutofocusHandle';

end;

function RotateSelectionAroundPivot(PivotMode, PivotPoint, Axis, Rotation, InitialPartStates, InitialModelStates, InitialAttachmentsStates)
	-- Rotates the given selection around `PivotMode` (using `PivotPoint` if applicable)'s `Axis` by `Rotation`

	-- Create a CFrame that increments rotation by `Rotation` around `Axis`
	local RotationCFrame = CFrame.fromAxisAngle(Vector3.FromAxis(Axis), math.rad(Rotation));
	
	local Parts = {}
	local PartsCFrames = {}
	
	-- Calculate the focused part's rotation
	local RelativeTo
	
	if PivotPoint then
		RelativeTo = PivotPoint * RotationCFrame;
	end
	
	-- Rotate each part
	for Part, InitialState in InitialPartStates do
		table.insert(Parts, Part)
		
		-- Rotate around the selection's center, or the currently focused part
		if PivotMode == 'Center' or PivotMode == 'Last' then

			-- Calculate this part's offset from the focused part's rotation
			local Offset = PivotPoint:Inverse() * InitialState.CFrame;

			-- Rotate relative to the focused part by this part's offset from it
			
			table.insert(PartsCFrames, RelativeTo * Offset);

		-- Rotate around the part's center
		elseif RotateTool.Pivot == 'Local' then
			table.insert(PartsCFrames, InitialState.CFrame * RotationCFrame)

		end;

	end;

	-- Rotate each model's pivot
	for Model, InitialState in InitialModelStates do
		
		-- Rotate around the selection's center, or the currently focused part
		if (PivotMode == 'Center') or (PivotMode == 'Last') then

			-- Calculate this part's offset from the focused part's rotation
			local Offset = PivotPoint:Inverse() * InitialState.Pivot

			-- Rotate relative to the focused part by this model's offset from it
			Model.WorldPivot = RelativeTo * Offset
		end
	end
	
	for Attachment, InitialState in InitialAttachmentsStates do

		-- Rotate around the selection's center, or the currently focused part
		if PivotMode == 'Center' or PivotMode == 'Last' then

			-- Calculate this part's offset from the focused part's rotation
			local Offset = PivotPoint:Inverse() * InitialState.WorldCFrame;

			-- Rotate relative to the focused part by this part's offset from it
			Attachment.WorldCFrame = RelativeTo * Offset;

			-- Rotate around the part's center
		elseif RotateTool.Pivot == 'Local' or PivotMode == 'Center' and #Selection.Attachments > 0 then
			Attachment.WorldCFrame = InitialState.WorldCFrame * RotationCFrame;

		end;
		
	end
	
	game.Workspace:BulkMoveTo(Parts, PartsCFrames)

end;

function GetHandleDisplayDelta(HandleRotation)
	-- Returns a human-friendly version of the handle's rotation delta

	-- Prepare to capture first angle
	if HandleFirstAngle == nil then
		HandleFirstAngle = true;
		HandleDirection = true;

	-- Capture first angle
	elseif HandleFirstAngle == true then

		-- Determine direction based on first angle
		if math.abs(HandleRotation) > 180 then
			HandleDirection = false;
		else
			HandleDirection = true;
		end;

		-- Disable first angle capturing
		HandleFirstAngle = false;

	end;

	-- Determine the rotation delta to display
	local DisplayedRotation;
	if HandleDirection == true then
		DisplayedRotation = (360 - HandleRotation) % 360;
	else
		DisplayedRotation = HandleRotation % 360;
	end;

	-- Switch delta calculation direction if crossing directions
	if LastDisplayedRotation and (
	   (LastDisplayedRotation <= 120 and DisplayedRotation >= 240) or
	   (LastDisplayedRotation >= 240 and DisplayedRotation <= 120)) then
		HandleDirection = not HandleDirection;
	end;

	-- Update displayed rotation after direction correction
	if HandleDirection == true then
		DisplayedRotation = (360 - HandleRotation) % 360;
	else
		DisplayedRotation = HandleRotation % 360;
	end;

	-- Store this last display rotation
	LastDisplayedRotation = DisplayedRotation;

	-- Return updated display delta
	
	print(DisplayedRotation)
	return DisplayedRotation;

end;

function BindShortcutKeys()
	-- Enables useful shortcut keys for this tool

	-- Track user input while this tool is equipped
	table.insert(Connections, UserInputService.InputBegan:Connect(function (InputInfo, GameProcessedEvent)

		-- Make sure this is an intentional event
		if GameProcessedEvent then
			return;
		end;

		-- Make sure this input is a key press
		if InputInfo.UserInputType ~= Enum.UserInputType.Keyboard then
			return;
		end;

		-- Make sure it wasn't pressed while typing
		if UserInputService:GetFocusedTextBox() then
			return;
		end;

		-- Check if the enter key was pressed
		if InputInfo.KeyCode == Enum.KeyCode.Return or InputInfo.KeyCode == Enum.KeyCode.KeypadEnter then

			-- Toggle the current axis mode
			if RotateTool.Pivot == 'Center' then
				SetPivot('Local');

			elseif RotateTool.Pivot == 'Local' then
				SetPivot('Last');

			elseif RotateTool.Pivot == 'Last' then
				SetPivot('Center');
			end;

		-- Nudge around X axis if the 8 button on the keypad is pressed
		elseif InputInfo.KeyCode == Enum.KeyCode.KeypadEight then
			NudgeSelectionByAxis(Enum.Axis.X, 1);

		-- Nudge around X axis if the 2 button on the keypad is pressed
		elseif InputInfo.KeyCode == Enum.KeyCode.KeypadTwo then
			NudgeSelectionByAxis(Enum.Axis.X, -1);

		-- Nudge around Z axis if the 9 button on the keypad is pressed
		elseif InputInfo.KeyCode == Enum.KeyCode.KeypadNine then
			NudgeSelectionByAxis(Enum.Axis.Z, 1);

		-- Nudge around Z axis if the 1 button on the keypad is pressed
		elseif InputInfo.KeyCode == Enum.KeyCode.KeypadOne then
			NudgeSelectionByAxis(Enum.Axis.Z, -1);

		-- Nudge around Y axis if the 4 button on the keypad is pressed
		elseif InputInfo.KeyCode == Enum.KeyCode.KeypadFour then
			NudgeSelectionByAxis(Enum.Axis.Y, -1);

		-- Nudge around Y axis if the 6 button on the keypad is pressed
		elseif InputInfo.KeyCode == Enum.KeyCode.KeypadSix then
			NudgeSelectionByAxis(Enum.Axis.Y, 1);

		-- Start snapping when the R key is pressed down, and it's not the selection clearing hotkey
		elseif (InputInfo.KeyCode == Enum.KeyCode.R) and not Selection.Multiselecting then
			StartSnapping();

		-- Start snapping when T key is pressed down (alias)
		elseif (InputInfo.KeyCode == Enum.KeyCode.T) and (not Selection.Multiselecting) then
			StartSnapping();

		end;

	end));

	-- Track ending user input while this tool is equipped
	Connections.HotkeyRelease = UserInputService.InputEnded:Connect(function (InputInfo, GameProcessedEvent)
		if GameProcessedEvent then
			return
		end

		-- Make sure this is input from the keyboard
		if InputInfo.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end

		-- If - key was released, focus on increment input
		if (InputInfo.KeyCode.Name == 'Minus') or (InputInfo.KeyCode.Name == 'KeypadMinus') then
			if RotateTool.UI then
				RotateTool.UI.IncrementOption.Increment.TextBox:CaptureFocus()
			end
		end
	end)
end;

function StartSnapping()

	-- Make sure snapping isn't already enabled
	if SnapTracking.Enabled then
		return;
	end;

	-- Listen for snapped points
	SnapTracking.StartTracking(function (NewPoint)
		SnappedPoint = NewPoint;
	end);

	-- Select the snapped pivot point upon clicking
	Connections.SelectSnappedPivot = Core.Mouse.Button1Down:Connect(function ()

		-- Disable unintentional selection
		Core.Targeting.CancelSelecting();

		-- Ensure there is a snap point
		if not SnappedPoint then
			return;
		end;

		-- Disable snapping
		SnapTracking.StopTracking();

		-- Attach the handles to a part at the snapped point
		local Part = Make 'Part' {
			CFrame = SnappedPoint,
			Size = Vector3.new(5, 1, 5)
		};
		SetPivot 'Last';
		AttachHandles(Part, true);

		-- Maintain the part in memory to prevent garbage collection
		GCBypass = { Part };

		-- Set the pivot point
		PivotPoint = SnappedPoint;
		CustomPivotPoint = true;

		-- Disconnect snapped pivot point selection listener
		ClearConnection 'SelectSnappedPivot';

	end);

end;

function SetAxisAngle(Axis, Angle)
	-- Sets the selection's angle on axis `Axis` to `Angle`

	-- Turn the given angle from degrees to radians
	local Angle = math.rad(Angle);

	-- Track this change
	TrackChange();

	-- Prepare parts to be moved
	local InitialPartStates, InitialModelStates, InitialAttachmentsStates = PrepareSelectionForRotating()
	
	local FocusedObjectCFrame
	local NewRotation

	if RotateTool.FocusWise == true and RotateTool.Pivot == "Last" then
		local FocusedObject = Selection.Focus

		-- Calculate our focused object's new CFrame
		if FocusedObject:IsA("BasePart") then
			FocusedObjectCFrame = FocusedObject.CFrame
			
			NewRotation = CFrame.new(FocusedObject.Position) * CFrame.fromEulerAnglesXYZ(
				Axis == 'X' and Angle or FocusedObject.CFrame.Rotation.X,
				Axis == 'Y' and Angle or FocusedObject.CFrame.Rotation.Y,
				Axis == 'Z' and Angle or FocusedObject.CFrame.Rotation.Z
			);
		else
			FocusedObjectCFrame = FocusedObject.WorldCFrame
			
			NewRotation = CFrame.new(FocusedObject.WorldPosition) * CFrame.fromEulerAnglesXYZ(
				Axis == 'X' and Angle or FocusedObject.WorldCFrame.Rotation.X,
				Axis == 'Y' and Angle or FocusedObject.WorldCFrame.Rotation.Y,
				Axis == 'Z' and Angle or FocusedObject.WorldCFrame.Rotation.Z
			);
		end

	end
	
	-- Update each part
	for Part, State in pairs(InitialPartStates) do
		
		if RotateTool.FocusWise == true and RotateTool.Pivot == "Last" then
			-- Get the part's delta to the focused object
			local RotationDelta = FocusedObjectCFrame:Inverse() * Part.CFrame

			-- Apply the delta to the focused object's new position
			Part.CFrame = NewRotation * RotationDelta;
		else
			-- Set the part's new CFrame
			Part.CFrame = CFrame.new(Part.Position) * CFrame.fromEulerAnglesXYZ(
				Axis == 'X' and Angle or Part.CFrame.Rotation.X,
				Axis == 'Y' and Angle or Part.CFrame.Rotation.Y,
				Axis == 'Z' and Angle or Part.CFrame.Rotation.Z
			);
		end

	end;
	
	for Attachment, State in pairs(InitialAttachmentsStates) do
		
		if RotateTool.FocusWise == true and RotateTool.Pivot == "Last" then
			-- Get the attachment's delta to the focused object
			local RotationDelta = FocusedObjectCFrame:Inverse() * Attachment.WorldCFrame

			-- Apply the delta to the focused object's new position
			Attachment.WorldCFrame = NewRotation * RotationDelta
		else
			-- Set the attachment's new CFrame
			Attachment.WorldCFrame = CFrame.new(Attachment.WorldPosition) * CFrame.fromEulerAnglesXYZ(
				Axis == 'X' and Angle or Attachment.WorldCFrame.Rotation.X,
				Axis == 'Y' and Angle or Attachment.WorldCFrame.Rotation.Y,
				Axis == 'Z' and Angle or Attachment.WorldCFrame.Rotation.Z
			);
		end
		

	end;

	-- Cache up permissions for all private areas
	local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Selection.Parts), Core.Player);

	-- Revert changes if player is not authorized to move parts to target destination
	if Core.Mode == 'Tool' and Security.ArePartsViolatingAreas(Selection.Parts, Core.Player, false, AreaPermissions) then
		for Part, State in pairs(InitialPartStates) do
			Part.CFrame = State.CFrame;
		end;
	end;

	-- Restore the parts' original states
	for Part, State in pairs(InitialPartStates) do
		Part:MakeJoints();
		Core.RestoreJoints(State.Joints);
		Part.CanCollide = State.CanCollide;
		Part.Anchored = State.Anchored;
	end;

	-- Register the change
	RegisterChange();

end;

function NudgeSelectionByAxis(Axis, Direction)
	-- Nudges the rotation of the selection in the direction of the given axis

	-- Ensure selection is not empty
	if #Selection.Parts == 0 then
		return;
	end;

	-- Get amount to nudge by
	local NudgeAmount = RotateTool.Increment;

	-- Reverse nudge amount if shift key is held while nudging
	local PressedKeys = Support.FlipTable(Support.GetListMembers(UserInputService:GetKeysPressed(), 'KeyCode'));
	if PressedKeys[Enum.KeyCode.LeftShift] or PressedKeys[Enum.KeyCode.RightShift] then
		NudgeAmount = -NudgeAmount;
	end;

	-- Track the change
	TrackChange();

	-- Stop parts from moving, and capture the initial state of the parts
	local InitialPartStates, InitialModelStates, InitialAttachmentsStates = PrepareSelectionForRotating()

	-- Set the pivot point to the center of the selection if in Center mode
	if RotateTool.Pivot == 'Center' and #Selection.Parts ~= 0 then
		local BoundingBoxSize, BoundingBoxCFrame = BoundingBox.CalculateExtents(Selection.Parts);
		PivotPoint = BoundingBoxCFrame;

	-- Set the pivot point to the center of the focused part if in Last mode
	elseif RotateTool.Pivot == 'Last' and not CustomPivotPoint then
		if Selection.Focus:IsA 'BasePart' then
			PivotPoint = Selection.Focus.CFrame
		elseif Selection.Focus:IsA 'Model' then
			PivotPoint = Selection.Focus:GetPivot()
		elseif Selection.Focus:IsA 'Attachment' then
			PivotPoint = Selection.Focus.WorldCFrame
		end
	end;

	-- Perform the rotation
	RotateSelectionAroundPivot(RotateTool.Pivot, PivotPoint, Axis, NudgeAmount * (Direction or 1), InitialPartStates, InitialModelStates, InitialAttachmentsStates)

	-- Update the "degrees rotated" indicator
	if RotateTool.UI then
		RotateTool.UI.Changes.Text.Text = 'rotated ' .. (NudgeAmount * (Direction or 1)) .. ' degrees';
	end;

	-- Cache area permissions information
	local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Selection.Parts), Core.Player);

	-- Make sure we're not entering any unauthorized private areas
	if Core.Mode == 'Tool' and Security.ArePartsViolatingAreas(Selection.Parts, Core.Player, false, AreaPermissions) then
		for Part, State in pairs(InitialPartStates) do
			Part.CFrame = State.CFrame;
		end;
		for Model, State in pairs(InitialModelStates) do
			Model.WorldPivot = State.Pivot
		end
		for Attachment, State in pairs(InitialAttachmentsStates) do
			Attachment.WorldCFrame = State.WorldCFrame;
		end;
	end;

	-- Make joints, restore original anchor and collision states
	for Part, State in pairs(InitialPartStates) do
		Part:MakeJoints();
		Core.RestoreJoints(State.Joints);
		Part.CanCollide = State.CanCollide;
		Part.Anchored = State.Anchored;
	end;

	-- Register the change
	RegisterChange();

end;

function TrackChange()

	-- Start the record
	HistoryRecord = {
		Parts = Support.CloneTable(Selection.Parts);
		Models = Support.CloneTable(Selection.Models);
		Attachments = Support.CloneTable(Selection.Attachments);
		BeforeCFrame = {};
		AfterCFrame = {};
		Selection = Selection.Items;

		Unapply = function (Record)
			-- Reverts this change

			-- Select the changed parts
			Selection.Replace(Record.Selection)

			-- Put together the change request
			local Changes = {};
			for _, Part in pairs(Record.Parts) do
				table.insert(Changes, {
					Part = Part;
					CFrame = Record.BeforeCFrame[Part];
				})
			end;
			for _, Model in pairs(Record.Models) do
				table.insert(Changes, {
					Model = Model;
					Pivot = Record.BeforeCFrame[Model];
				})
			end
			for _, Attachment in pairs(Record.Attachments) do
				table.insert(Changes, {
					Attachment = Attachment;
					Pivot = Record.BeforeCFrame[Attachment];
				})
			end

			-- Send the change request
			Core.SyncAPI:Invoke('SyncRotate', Changes);

		end;

		Apply = function (Record)
			-- Applies this change

			-- Select the changed parts
			Selection.Replace(Record.Selection)

			-- Put together the change request
			local Changes = {};
			for _, Part in pairs(Record.Parts) do
				table.insert(Changes, {
					Part = Part;
					CFrame = Record.AfterCFrame[Part];
				})
			end;
			for _, Model in pairs(Record.Models) do
				table.insert(Changes, {
					Model = Model;
					Pivot = Record.AfterCFrame[Model];
				})
			end
			for _, Attachment in pairs(Record.Attachments) do
				table.insert(Changes, {
					Attachment = Attachment;
					Pivot = Record.AfterCFrame[Attachment];
				})
			end

			-- Send the change request
			Core.SyncAPI:Invoke('SyncRotate', Changes);

		end;

	};

	-- Collect the selection's initial state
	for _, Part in pairs(HistoryRecord.Parts) do
		HistoryRecord.BeforeCFrame[Part] = Part.CFrame;
	end;
	for _, Model in pairs(HistoryRecord.Models) do
		HistoryRecord.BeforeCFrame[Model] = Model:GetPivot()
	end
	for _, Attachment in pairs(HistoryRecord.Attachments) do
		HistoryRecord.BeforeCFrame[Attachment] = Attachment.WorldCFrame;
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
		HistoryRecord.AfterCFrame[Part] = Part.CFrame;
		table.insert(Changes, {
			Part = Part;
			CFrame = Part.CFrame;
		})
	end;
	for _, Model in pairs(HistoryRecord.Models) do
		HistoryRecord.AfterCFrame[Model] = Model:GetPivot()
		table.insert(Changes, {
			Model = Model;
			Pivot = Model:GetPivot();
		})
	end
	for _, Attachment in pairs(HistoryRecord.Attachments) do
		HistoryRecord.AfterCFrame[Attachment] = Attachment.WorldCFrame;
		table.insert(Changes, {
			Attachment = Attachment;
			WorldCFrame = Attachment.WorldCFrame;
		})
	end;

	-- Send the change to the server
	Core.SyncAPI:Invoke('SyncRotate', Changes);

	-- Register the record and clear the staging
	Core.History.Add(HistoryRecord);
	HistoryRecord = nil;

end;

function PrepareSelectionForRotating()
	-- Prepares parts for rotating and returns the initial state of the parts

	local InitialPartStates = {}
	local InitialModelStates = {}
	local InitialAttachmentsStates = {}

	-- Get index of parts
	local PartIndex = Support.FlipTable(Selection.Parts);

	-- Stop parts from moving, and capture the initial state of the parts
	for _, Part in pairs(Selection.Parts) do
		InitialPartStates[Part] = {
			Anchored = Part.Anchored;
			CanCollide = Part.CanCollide;
			CFrame = Part.CFrame;
		}
		Part.Anchored = true;
		Part.CanCollide = false;
		InitialPartStates[Part].Joints = Core.PreserveJoints(Part, PartIndex);
		Part:BreakJoints();
		Part.Velocity = Vector3.new();
		Part.RotVelocity = Vector3.new();
	end;

	-- Record model pivots
	-- (temporarily pcalled due to pivot API being in beta)
	for _, Model in pairs(Selection.Models) do
		InitialModelStates[Model] = {
			Pivot = Model:GetPivot();
		}
	end
	
	for _, Attachment in pairs(Selection.Attachments) do
		InitialAttachmentsStates[Attachment] = {
			WorldCFrame = Attachment.WorldCFrame;
		}
	end

	return InitialPartStates, InitialModelStates, InitialAttachmentsStates
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

-- Return the tool
return RotateTool;
