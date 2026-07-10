local Tool = script.Parent.Parent
local Core = require(Tool.Core)
local Sounds = Tool:WaitForChild("Sounds")

-- Libraries
local ListenForManualWindowTrigger = require(Tool.Core:WaitForChild('ListenForManualWindowTrigger'))

-- Import relevant references
local Selection = Core.Selection
local Support = Core.Support
local Security = Core.Security

local BoundingBox = require(Tool.Core.BoundingBox)

local Roact = require(Tool.Vendor.Roact)
local NotificationDialog = require(Tool.UI.GroupDialog)
local Signal = require(Tool.Libraries.Signal)

local UI, UIUpdater

-- Initialize the tool
local TransformationTool = {
	Name = 'Transformation Tool',
	Color = BrickColor.new 'Bright orange',
	
	Split = false,
}

local NegativeParts = {}

TransformationTool.ManualText = [[<font weight="900" size="24"><u><i>Union Tool  🛠</i></u></font>
Allows you to create unions with this tool.<font size="6"><br /></font>

<font size="12" color="rgb(150, 150, 150)"><b>Negate</b></font>

When pressing the negate button, every selected parts will turn slightly red. This means that once the union will be created, every other non-negative selected parts in the negative parts will get truncated. 

<font size="12" color="rgb(150, 150, 150)"><b>Union</b></font>

Once the union button is pressed, every parts selected will be put together. Negative parts will turn what they intersect into void. There is only <b>one</b> final object.

<font size="12" color="rgb(150, 150, 150)"><b>Separate</b></font>

The separation is useful to revert an union. This will revert the part to its original state, perfect if you want to change something afterwards.

<b>NOTE:</b> Separating multiple assemblies (part created when clicking the assemble button) might create duplicate parts!

]]

local Connections = {}
local NegativePartsConnections = {}

local AreMeshPartsSupported = false

task.spawn(function()
	local SampleMeshPart = Instance.new("MeshPart")
	
	AreMeshPartsSupported = pcall( game:GetService("GeometryService").UnionAsync, game:GetService("GeometryService"), SampleMeshPart, {} )
end)


local Shapes = {
	'Block',
	'Wedge',
	'CornerWedge',
	'Cylinder',
	'Ball',
}

local Types = {
	Part = 'Part',
	Seat = 'Seat',
	VehicleSeat = 'VehicleSeat',
	SpawnLocation = 'Spawn',
	MeshPart = 'MeshPart'
}

local MeshTypesBlacklist = {
	[Enum.MeshType.Head] = true,
	[Enum.MeshType.Torso] = true,
	[Enum.MeshType.FileMesh] = true,
}

local HighlightPool = require(Core.Libraries.InstancePool).new(20, function ()
	return Core.Make('Highlight')({
		DepthMode = Enum.HighlightDepthMode.Occluded,
		FillColor = Color3.new(1, 0, 0),
		FillTransparency = 0.7,
		OutlineTransparency = 1,
		Parent = Core.UI,
	})
end)

function TransformationTool.Equip()
	-- Enables the tool's equipped functionality

	-- Start up our interface
	ShowUI()
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

end

function TransformationTool.Unequip()
	-- Disables the tool's equipped functionality

	-- Clear unnecessary resources
	HideUI()
	ClearConnections()
	BoundingBox.ClearBoundingBox()

end

function ClearConnections()
	-- Clears out temporary connections

	for ConnectionKey, Connection in pairs(Connections) do
		Connection:Disconnect()
		Connections[ConnectionKey] = nil
	end

end

local Dropdowns = {}

local ToolMode = "Geometry"

local CustomPartTypes = type(Core.Options.CustomPartTypes) == "function" 
	and Core.Options.CustomPartTypes()
	or Core.Options.CustomPartTypes

local SubTypes = {}
local SubTypesClasses = {}

for Name, Data in CustomPartTypes do

	if type(Data) == "table" and Data.CanBeConverted == true then

		SubTypes[Name] = Data
	end
end

local function GetSubTypeFromPart(Part)
	return Part:GetAttribute("BTSubType") or "Default"
end

local function UpdateToolMode()
	-- Make sure there's a UI
	if not UI then return end
	
	-- Tell whether the geometry interface will be visible
	local IsGeometryVisible = ToolMode == "Geometry"
	
	-- Tell whether the type interface will be visible
	local IsTypeVisible = ToolMode == "Type"
	
	-- Apply visibility changes to the Geometry UI
	for _, Object in UI.Geometry:GetChildren() do
		Object.Visible = IsGeometryVisible
	end
	
	if not IsTypeVisible then
		-- Apply visibility changes to the Type UI if requested
		for _, Object in UI.Type:GetChildren() do
			Object.Visible = false
		end
	end
	
	-- If we're in Geometry mode, also resize the interface
	if IsGeometryVisible then
		-- Fetch the new size
		local GeometryModeSize = Core.Mode == "Plugin" and UDim2.new(0, 225, 0, 211) or UDim2.new(0, 225, 0, 178)
		
		-- Resize the UI
		UI.Size = GeometryModeSize
	end
	
	-- Request Core to update the switch
	Core.ToggleSwitch(ToolMode, UI.Toggle.Options)
	
	UpdateUI()
end

function ShowUI()
	-- Creates and reveals the UI
	local Dropdown = require(Core.UIFolder.Dropdown)

	-- Reveal UI if already created
	if TransformationTool.UI and TransformationTool.UI.Parent ~= nil then

		-- Reveal the UI
		UI.Visible = true
		
		-- Show the highlights
		for _, Highlight in NegativeParts do
			Highlight.Enabled = true
		end

		UIUpdater = Support.ScheduleRecurringTask(UpdateUI, 0.1)
		
		-- Skip UI creation
		return

	end
	
	if TransformationTool.UI then
		TransformationTool.UI:Destroy()
	end

	-- Create the UI
	UI = Core.Interfaces.BTTransformationToolGUI:Clone()
	UI.Parent = Core.UI
	UI.Visible = true
	
	TransformationTool.UI = UI
	
	local function HoverSound()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Hover"))
	end

	-- ===============================
	-- TOGGLE
	-- ===============================
	
	local Toggle = UI.Toggle
	local Buttons = Toggle.Options
	
	local GeometryButton = Buttons.Geometry.Button
	local TypeButton = Buttons.Type.Button
	
	GeometryButton.Activated:Connect(function()
		Core.PlaySound("Press")
		
		ToolMode = "Geometry"
		
		UpdateToolMode()
	end)
	
	GeometryButton.MouseEnter:Connect(HoverSound)
	
	TypeButton.Activated:Connect(function()
		Core.PlaySound("Press")
		
		ToolMode = "Type"

		UpdateToolMode()
	end)

	TypeButton.MouseEnter:Connect(HoverSound)
	
	-- ===============================
	-- GEOMETRY CATEGORY
	-- ===============================
	
	local GeometryUI = UI.Geometry
	
	-- Apply changes for deprecated UIs (if the difference doesn't seem intentional)
	if UI:FindFirstChild("Warning") and Core.Options.UseOldUnionSystem then
		UI.Warning.Position = UDim2.new(0, 10, 1, 0)
		UI.Warning.Text = "WARNING: Fork3X is set to use the old union system. Saving and separating aren't available."
	end

	if Core.Options.UseOldUnionSystem then
		GeometryUI.Interface.SeparateButton.Visible = false
		GeometryUI.Interface.IntersectButton.Position = UI.Interface.SeparateButton.Position
		GeometryUI.Interface.IntersectButton.AnchorPoint = UI.Interface.SeparateButton.AnchorPoint
	end

	if GeometryUI.Interface.Size == UDim2.new(1, -10, 0, 25) then
		GeometryUI.Interface.Size = UDim2.new(1, -10, 0, 58)
	end
	
	if UI.Size == UDim2.new(0, 220, 0, 220) then
		UI.Size = UDim2.new(0, 225, 0, 133)
	end
	
	if UI.Changes.Position == UDim2.new(0, 5, 0, 100) then
		UI.Changes.Position = UDim2.new(0, 5, 1, 0)
	end	
	
	-- Hook up the buttons
	GeometryUI.Interface.NegateButton.Activated:Connect(function()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Press"))
		NegateParts(Selection.Parts)
	end)
	GeometryUI.Interface.NegateButton.MouseEnter:Connect(HoverSound)
	
	GeometryUI.Interface.UnionButton.Activated:Connect(function()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Press"))
		CreateUnion(false)
	end)
	GeometryUI.Interface.UnionButton.MouseEnter:Connect(HoverSound)
	
	GeometryUI.Interface.SeparateButton.Activated:Connect(function()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Press"))
		SeparateUnion()
	end)
	GeometryUI.Interface.SeparateButton.MouseEnter:Connect(HoverSound)
	
	GeometryUI.Interface.IntersectButton.Activated:Connect(function()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Press"))
		CreateUnion(true)
	end)
	GeometryUI.Interface.IntersectButton.MouseEnter:Connect(HoverSound)
	
	-- Add the "To Fork3X" button when using the plugin
	if Core.Mode == "Plugin" then
		UI.Size = UDim2.new(0, 225, 0, 166)
		GeometryUI.Interface.Size = UDim2.new(1, -10, 0, 91)
		
		GeometryUI.Interface.ConvertButton.Visible = true
		
		GeometryUI.Interface.ConvertButton.Activated:Connect(function()
			game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Press"))
			ConvertUnion()
		end)
		GeometryUI.Interface.ConvertButton.MouseEnter:Connect(HoverSound)
	end

	local SplitToggle = GeometryUI.SplitOption.Check

	SplitToggle.Activated:Connect(function()
		TransformationTool.Split = not TransformationTool.Split
		UpdateToggleInput(SplitToggle, TransformationTool.Split)
	end)

	UpdateToggleInput(SplitToggle, TransformationTool.Split)
	
	-- ===============================
	-- TYPE CATEGORY
	-- ===============================
	
	local TypeUI = UI.Type
	
	local ShapeOption = TypeUI.ShapeOption
	local PartTypeOption = TypeUI.PartTypeOption
	local SubTypeOption = TypeUI.SubTypeOption
	
	-- In case the UI got deleted, clean the dropdown registry
	table.clear(Dropdowns)
	
	-- Create a function that inflates the Shape dropdown
	local function BuildShapeDropdown()
		local CommonProperty = Support.IdentifyCommonProperty( Support.FilterArray(Selection.Parts, function(Value, Key) return Value:IsA("Part") end), "Shape" )
		
		return Roact.createElement(Dropdown, {
			Position = UDim2.new(1, 0, 0, 0),
			OptionsPosition = UDim2.new(1, 5, 0, 0),
			AnchorPoint = Vector2.new(1, 0),
			Size = UDim2.new(0, 91, 0, 25),
			Options = Shapes,
			MaxRows = 4,
			CurrentOption = CommonProperty and CommonProperty.Name or "*",
			OnOptionSelected = function (Option)
				SetShape(Enum.PartType[Option])
			end,
		})
	end
	
	-- Subscribe the dropdown to UI updates
	Dropdowns[ShapeOption] = {
		Handler = Roact.mount(BuildShapeDropdown(), ShapeOption, 'Dropdown'),
		Create = BuildShapeDropdown
	}
	
	-- Create a function that inflates the Part Type dropdown
	local function BuildPartTypeDropdown()
		return Roact.createElement(Dropdown, {
			Position = UDim2.new(1, 0, 0, 0),
			OptionsPosition = UDim2.new(1, 5, 0, 0),
			AnchorPoint = Vector2.new(1, 0),
			Size = UDim2.new(0, 91, 0, 25),
			Options = Support.Values(Types),
			MaxRows = 4,
			CurrentOption = Support.IdentifyCommonProperty( Selection.Parts, "ClassName" ) or "*",
			OnOptionSelected = function (Option)
				SetPartType(Option)
			end,
		})
	end

	-- Subscribe the dropdown to UI updates
	Dropdowns[PartTypeOption] = {
		Handler = Roact.mount(BuildPartTypeDropdown(), PartTypeOption, 'Dropdown2'),
		Create = BuildPartTypeDropdown
	}
	
	-- Create a function that inflates the Part Type dropdown
	local function BuildSubTypeDropdown()
		
		local EligibleParts = Support.FilterArray(Selection.Parts, function(Value, Key)
			return Types[Value.ClassName] ~= nil
		end)
		
		local TypesPresent = {}
		local SubTypesList = {"Default"}
		local CommonSubType = EligibleParts[1] and GetSubTypeFromPart(EligibleParts[1]) or nil
		
		for _, Part in EligibleParts do
			if CommonSubType == nil then
				continue
			end
			
			TypesPresent[Part.ClassName] = true
			
			local SubType = GetSubTypeFromPart(Part)
			
			CommonSubType = CommonSubType == SubType and CommonSubType or nil
		end
		
		for Name, Data in SubTypes do
			
			local AllowedClasses = Data.ClassName
			
			if not AllowedClasses or AllowedClasses == true then
				
				table.insert(SubTypesList, Name)
			elseif type(AllowedClasses) == "string" then
				
				if TypesPresent[AllowedClasses] == true then
					table.insert(SubTypesList, Name)
				end
			elseif type(AllowedClasses) == "table" then
				
				for _, AllowedClass in AllowedClasses do
					
					if TypesPresent[AllowedClass] == true then
						
						table.insert(SubTypesList, Name)
						
						break
					end
				end
			end
		end
		
		return Roact.createElement(Dropdown, {
			Position = UDim2.new(1, 0, 0, 0),
			OptionsPosition = UDim2.new(1, 5, 0, 0),
			AnchorPoint = Vector2.new(1, 0),
			Size = UDim2.new(0, 91, 0, 25),
			Options = SubTypesList,
			MaxRows = 4,
			CurrentOption = CommonSubType or "*",
			OnOptionSelected = function (Option)
				SetSubType(Option)
			end,
		})
	end

	-- Subscribe the dropdown to UI updates
	Dropdowns[SubTypeOption] = {
		Handler = Roact.mount(BuildSubTypeDropdown(), SubTypeOption, 'Dropdown2'),
		Create = BuildSubTypeDropdown
	}
	
	--[[
	-- Create a function that inflates the Shape dropdown
	local function BuildSubTypeDropdown()
		return Roact.createElement(Dropdown, {
			Position = UDim2.new(0, 30, 0, 0),
			Size = UDim2.new(0, 91, 0, 25),
			Options = Shapes,
			MaxRows = 4,
			CurrentOption = Support.IdentifyCommonProperty( Support.FilterArray(Selection.Parts, function(Value, Key) return Value:IsA("Part") end), "Shape" ).Name,
			OnOptionSelected = function (Option)
				SetSubType(Option)
			end,
		})
	end

	-- Subscribe the dropdown to UI updates
	Dropdowns[SubTypeOption] = {
		Handler = Roact.mount(BuildShapeDropdown(), SubTypeOption, 'Dropdown'),
		Create = BuildShapeDropdown
	}
	]]
	-- Hook up manual triggering
	local SignatureButton = UI:WaitForChild('Title'):WaitForChild('Signature')
	ListenForManualWindowTrigger(TransformationTool.ManualText, TransformationTool.Color.Color, SignatureButton)
	
	-- Update the interface
	UpdateToolMode()
	
	UIUpdater = Support.ScheduleRecurringTask(UpdateUI, 0.1)
end

-- List of UI elements
local UIElements = { 'SelectNote', 'ShapeOption', 'PartTypeOption', 'SubTypeOption' }

-- Current UI layout
local CurrentLayout

function ChangeLayout(Layout)
	-- Sets the UI to the given layout

	-- Make sure the new layout isn't already set
	if CurrentLayout == Layout then
		return
	end

	-- Set this as the current layout
	CurrentLayout = Layout

	-- Reset the UI
	for _, ElementName in pairs(UIElements) do
		local Element = TransformationTool.UI[ToolMode][ElementName]
		Element.Visible = false
	end

	-- Keep track of the total vertical extents of all items
	local Sum = 0

	-- Go through each layout element
	for ItemIndex, ItemName in ipairs(Layout) do

		local Item = TransformationTool.UI[ToolMode][ItemName]

		-- Make the item visible
		Item.Visible = true

		-- Position this item underneath the past items
		Item.Position = UDim2.new(0, 0, 0, 65) + UDim2.new(
			Item.Position.X.Scale,
			Item.Position.X.Offset,
			0,
			Sum + 10
		)

		-- Update the sum of item heights
		Sum = Sum + 10 + Item.AbsoluteSize.Y

	end

	-- Resize the container to fit the new layout
	TransformationTool.UI.Size = UDim2.new(0, 225, 0, 75 + Sum)

end

function UpdateUI()
	-- Only update is the current mode set is Type
	if ToolMode == "Type" then
		for _, Data in Dropdowns do
			Roact.update( Data.Handler, Data.Create() )
		end
		
		local Layout = {}
		
		if #Selection.Parts == 0 then
			Layout = { "SelectNote" }
			
			ChangeLayout(Layout)
			
			return
		end
		
		for _, Part in Selection.Parts do
			-- If at least one part is a `Part`, let the user configure the shape
			if Part:IsA("Part") and not Layout.ShapeOption then
				Layout.ShapeOption = Support.CountKeys(Layout) + 1
			end
			
			if Types[Part.ClassName] and not Layout.PartTypeOption then
				Layout.PartTypeOption = Support.CountKeys(Layout) + 1
			end
			
			if Types[Part.ClassName] and Support.CountKeys(SubTypes) >= 1 then
				Layout.SubTypeOption = Support.CountKeys(Layout) + 1
			end
		end
		
		ChangeLayout(Support.FlipTable(Layout))
		
	end
end

function UpdateToggleInput(Toggle, Data)
	-- Updates the data in the given buttons

	-- Go through the inputs and data
	if Data == true then
		-- Clear every UI tags
		Toggle:AddTag("STATE_True")
		Toggle:RemoveTag("STATE_Multiple")

		--			ShadowsCheckbox.Image = Core.Assets.CheckedCheckbox
	elseif Data == false then
		-- Clear every UI tags
		Toggle:RemoveTag("STATE_True")
		Toggle:RemoveTag("STATE_Multiple")

		--			ShadowsCheckbox.Image = Core.Assets.UncheckedCheckbox
	elseif Data == nil then
		-- Clear every UI tags
		Toggle:RemoveTag("STATE_True")
		Toggle:AddTag("STATE_Multiple")

		--			ShadowsCheckbox.Image = Core.Assets.SemicheckedCheckbox
	end

end

function HideUI()
	-- Hides the tool UI

	-- Make sure there's a UI
	if not UI then
		return
	end

	-- Hide the UI
	UI.Visible = false
	
	for _, Highlight in NegativeParts do
		Highlight.Enabled = false
	end
	
	UIUpdater:Stop()
	
	--for _, Highlight in pairs(script.Highlights:GetChildren()) do
	--	Highlight.Enabled = false
	--end

end

-- ===============================
-- GEOMETRY FUNCTIONS
-- ===============================

function CreateUnion(Intersect)
	local NormalParts = {}
	local Negative = {}
	
	local CanUseNormalMethod = true
	
	for _, Part in Selection.Parts do
		if Part:IsA("MeshPart") and not AreMeshPartsSupported then
			local Notice = [[At the moment, unioning with MeshParts is still in beta. This error has occurred because the beta isn't enabled, or you're trying to do this in-game.
			
			In the meantime, please attempt to recreate the shape with simple blocks so unioning can be done.]]

			Core.AddNotification:Fire({
				ThemeColor = Color3.new(0.1, 0.4, 1);
				NoticeText = "Unions with MeshParts aren't supported at the moment.";
				DetailText = Notice;
				TextXAlignment = Enum.TextXAlignment.Left
			})
			
			return
		elseif Part:FindFirstChildOfClass("SpecialMesh") and MeshTypesBlacklist[Part:FindFirstChildOfClass("SpecialMesh").MeshType] then
			local Notice = [[It is sadly unlikely those shapes get supported by Roblox in the future. If unions with MeshParts are possible, try to use them instead of parts with meshes.]]

			Core.AddNotification:Fire({
				ThemeColor = Color3.new(1, 0, 0);
				NoticeText = "You attempted to union parts with a Mesh set to Head/File. These cannot be unioned at the moment.";
				DetailText = Notice;
				TextXAlignment = Enum.TextXAlignment.Left
			})

			return
		end
		
		-- Let's class parts in two sections: Negative ones and normal ones.
		if Part:IsA("TriangleMeshPart") and not Part:GetAttribute("BTUnionData") then
			CanUseNormalMethod = false
			
			if Core.AddNotification then
				local Notice = [[Own this game? Install the Fork3X plugin (check the GitHub for more information to set up the plugin), select your game's unions, and press "To Fork3X" with the Transformation tool to allow tracking to be.]]
				
				Core.AddNotification:Fire({
					ThemeColor = Color3.new(0.1, 0.4, 1);
					NoticeText = "The union you just created won't be able to be saved nor separated.";
					DetailText = Notice;
					TextXAlignment = Enum.TextXAlignment.Left
				})
			end
		end
		
		if NegativeParts[Part] then
			table.insert(Negative, Part)
		else
			table.insert(NormalParts, Part)
		end
	end
	
	local ActionName = (Core.Options.UseOldUnionSystem or CanUseNormalMethod == false) and 'OldCreateUnion' or 'CreateUnion'
	
	local Unions = Core.SyncAPI:Invoke(ActionName, NormalParts, Negative, TransformationTool.Split, Intersect)
	
	if type(Unions) == "table" then
		for _, Union in pairs(Unions) do
			if NormalParts[Union] then
				NormalParts[Union] = nil
			end
		end
	elseif Unions ~= nil then
		if NormalParts[Unions] then
			NormalParts[Unions] = nil
		end
	elseif Unions == nil then
		return
	end
	
	local HistoryRecord = {
		Unions = type(Unions) == "table" and Unions or {Unions},
		NormalParts = NormalParts,
		Negative = Negative,

		Unapply = function (HistoryRecord)
			-- Reverts this change

			-- Remove the welds
			task.spawn(Core.SyncAPI.Invoke, Core.SyncAPI, 'Remove', HistoryRecord.Unions)
			Core.SyncAPI:Invoke('UndoRemove', Support.ConcatTable(HistoryRecord.NormalParts, HistoryRecord.Negative))

			Selection.Replace(Support.ConcatTable(HistoryRecord.NormalParts, HistoryRecord.Negative), false)

			NegateParts(HistoryRecord.Negative)
		end,

		Apply = function (HistoryRecord)
			-- Reapplies this change

			-- Restore the welds
			task.spawn(Core.SyncAPI.Invoke, Core.SyncAPI, 'Remove', Support.ConcatTable(HistoryRecord.NormalParts, HistoryRecord.Negative))
			Core.SyncAPI:Invoke('UndoRemove', HistoryRecord.Unions)

			Selection.Replace(HistoryRecord.Unions, false)
		end,
	}

	Core.History.Add(HistoryRecord)

	Core.SyncAPI:Invoke('Remove', Support.ConcatTable(HistoryRecord.NormalParts, HistoryRecord.Negative))

	UI.Changes.Text.Text = "The union has been successfully created."

	Selection.Replace(type(Unions) == "table" and Unions or {Unions}, false)
	
	HighlightPool:ReleaseAll()
	
	for ConnectionKey, Connection in NegativePartsConnections do
		Connection:Disconnect()
		Connections[ConnectionKey] = nil
	end
	
	table.clear(NegativeParts)
end

function ConvertUnion()
	if not Core.Plugin then
		return
	end
	
	local Unions = {}
	
	for _, Part in Selection.Parts do
		if Part:IsA("PartOperation") and not Part:GetAttribute("BTUnionData") then
			table.insert(Unions, Part)
		end
	end
	
	Core.SyncAPI:Invoke('ConvertUnion', Unions)
	
	local NewAttributes = {}
	
	for _, Union in Unions do
		NewAttributes[Union] = Union:GetAttribute("BTUnionData")
	end

	local HistoryRecord = {
		Unions = Unions,
		UnionDatas = NewAttributes,

		Unapply = function (HistoryRecord)
			-- Reverts this change

			-- Remove the BTUnionData
			for _, Union in HistoryRecord.Unions do
				Union:SetAttribute("BTUnionData", nil)
			end
		end,

		Apply = function (HistoryRecord)
			-- Reapplies this change

			for _, Union in HistoryRecord.Unions do
				Union:SetAttribute("BTUnionData", HistoryRecord.UnionDatas[Union])
			end
		end,
	}

	Core.History.Add(HistoryRecord)

	UI.Changes.Text.Text = "The unions have been succesfully converted."
end

function SeparateUnion()
	
	local Unions = {}

	for _, Part in pairs(Selection.Parts) do								-- Let's class parts in two sections: Negative ones and normal ones.
		if Part:IsA("MeshPart") and not AreMeshPartsSupported then
			local Notice = [[At the moment, unioning with MeshParts is still in beta. This error has occurred because the beta isn't enabled, or you're trying to do this in-game.
			
In the meantime, please attempt to recreate the shape with simple blocks so unioning can be done.]]

			Core.AddNotification:Fire({
				ThemeColor = Color3.new(0.1, 0.4, 1);
				NoticeText = "MeshParts cannot be separated at the moment.";
				DetailText = Notice;
				TextXAlignment = Enum.TextXAlignment.Left
			})

			return
		end
		
		if Part:IsA("TriangleMeshPart") and Part:GetAttribute("BTUnionData") then
			table.insert(Unions, Part)
		end
	end

	local Parts, TheNegativeParts = Core.SyncAPI:Invoke('SeparateUnion', Unions)

	local HistoryRecord = {
		Unions = Unions,
		Parts = Parts,
		NegativeParts = TheNegativeParts,

		Unapply = function (HistoryRecord)
			-- Reverts this change

			-- Remove the welds
			task.spawn(Core.SyncAPI.Invoke, Core.SyncAPI, 'Remove', Support.ConcatTable(HistoryRecord.Parts, HistoryRecord.NegativeParts))
			Core.SyncAPI:Invoke('UndoRemove', HistoryRecord.Unions)
			
			
			Selection.Replace(HistoryRecord.Unions)
		end,

		Apply = function (HistoryRecord)
			-- Reapplies this change

			-- Restore the welds
			task.spawn(Core.SyncAPI.Invoke, Core.SyncAPI, 'Remove', HistoryRecord.Unions)
			Core.SyncAPI:Invoke('UndoRemove', Support.ConcatTable(HistoryRecord.Parts, HistoryRecord.NegativeParts))
			
			Selection.Replace(Support.ConcatTable(HistoryRecord.Parts, HistoryRecord.NegativeParts))
			
			NegateParts(HistoryRecord.NegativeParts)
		end,

	}
	
	if Parts ~= {} then
		UI.Changes.Text.Text = "The union has been successfully separated."
		
		Core.History.Add(HistoryRecord)
		
		task.spawn(Core.SyncAPI.Invoke, Core.SyncAPI, 'Remove', Unions)
		
		Selection.Replace(Parts, false)
		
		Selection.Add(TheNegativeParts, false)
		
		NegateParts(TheNegativeParts)
	else
		UI.Changes.Text.Text = "The selection doesn't have any union or you're not allowed to separate unions (you should use the built-in tools in Studio)."
	end
end

function NegateParts(Parts)
	
	for _, Part in Parts do
		-- Check if the part has a file mesh (which isn't and will never be supported)
		local PotentialMesh = Part:FindFirstChildOfClass("SpecialMesh")
		
		if PotentialMesh and MeshTypesBlacklist[PotentialMesh.MeshType] then
			continue
		elseif Part:IsA("MeshPart") and not AreMeshPartsSupported then
			continue
		end
		
		local IsNegated = NegativeParts[Part]
		
		if IsNegated then
			local Highlight = NegativeParts[Part]
			
			HighlightPool:Release(Highlight)
			
			NegativePartsConnections[Part]:Disconnect()
			NegativePartsConnections[Part] = nil
			
			NegativeParts[Part] = nil
		else
			local Highlight = HighlightPool:Get()
			
			Highlight.Adornee = Part
			
			NegativeParts[Part] = Highlight
			
			NegativePartsConnections[Part] = Part.Destroying:Connect(function()
				local Highlight = NegativeParts[Part]

				HighlightPool:Release(Highlight)
				
				NegativePartsConnections[Part]:Disconnect()
				NegativePartsConnections[Part] = nil

				NegativeParts[Part] = nil
			end)
		end
	end
	
	--[[
	for _, Part in pairs(Parts or Selection.Parts) do
		if Support.GetChildOfClass(Part, "SpecialMesh") then continue end
		
		if table.find(NegativeParts, Part) then
			table.remove(NegativeParts, table.find(NegativeParts, Part))
			for _, Highlight in pairs(script.Highlights:GetChildren()) do
				if Highlight.Adornee == Part then
					Highlight:Destroy()
				end
			end
			continue
		end
		table.insert(NegativeParts, Part)
		local PartHighlight = NegateHighlight:Clone()
		PartHighlight.Adornee = Part
		PartHighlight.Parent = HighlightsFolder
	end]]
end

-- ===============================
-- TYPE CATEGORY
-- ===============================

function SetShape(Shape)
	-- Prepare the history record
	local HistoryRecord = {
		Selection = Selection.Items,
		
		Before = {},
		After = {},
		
		Unapply = function(Record)
			Core.SyncAPI:Invoke("SyncTransform", Record.Before)
			
			Selection.Replace(Record.Selection, false)
		end,
		
		Apply = function(Record)
			Core.SyncAPI:Invoke("SyncTransform", Record.After)

			Selection.Replace(Record.Selection, false)
		end,
	}
	
	-- Prepare the parts for transformation
	for _, Part in Selection.Parts do
		if Part:IsA("Part") then
			local BeforeChanges = { Part = Part }
			local AfterChanges = { Part = Part }
		
			-- Store the state of the part before modification
			BeforeChanges.Shape = Part.Shape
			
			-- Apply the change locally
			Part.Shape = Shape
			
			-- Insert the new value to the history record
			AfterChanges.Shape = Shape
			
			-- Add the changes to the history record
			table.insert(HistoryRecord.Before, BeforeChanges)
			table.insert(HistoryRecord.After, AfterChanges)
		end
	end
	
	-- Apply the changes to the server
	Core.SyncAPI:Invoke("SyncTransform", HistoryRecord.After)
	
	-- Add the record to the history
	Core.History.Add(HistoryRecord)
end

function SetPartType(Type)
	local CurrentSelection = Selection.Items
	local CurrentParts = Selection.Parts
	
	-- Already track the changes
	local Before = {}
	local After = {}
	
	-- Prepare the parts for transformation
	for _, Part in CurrentParts do
		local BeforeChanges = { Part = Part }
		local AfterChanges = { Part = Part }
		
		local CurrentType

		-- Check to which type the current object belongs
		for PartType in Types do
			if Part.ClassName == PartType then
				CurrentType = PartType
			end
		end

		-- If no type is found (unsupported part type) or it's the same, abort
		if not CurrentType or CurrentType == Type then
			continue
		end

		-- Store the part's previous type
		BeforeChanges.Type = CurrentType
		
		-- Insert the new type to the changes
		AfterChanges.Type = Type
		
		-- Store both changes tables in their respective categories
		table.insert(Before, BeforeChanges)
		table.insert(After, AfterChanges)
	end
	
	-- Apply the changes to the server and get the modified parts
	local NewParts = Core.SyncAPI:Invoke("SyncTransform", After)
	
	-- Now we have enough information to track this action, create the history record
	local HistoryRecord = {
		Selection = CurrentSelection,
		Parts = CurrentParts,
		NewParts = NewParts,

		Before = Before,
		After = After,

		Unapply = function (Record)
			-- Reverts this change

			-- Remove the parts we converted (parallel as we don't depend on these parts)
			task.spawn(Core.SyncAPI.Invoke, Core.SyncAPI, 'Remove', Record.NewParts)

			-- Restore the former parts
			Core.SyncAPI:Invoke('UndoRemove', Record.Parts)

			-- Revert the selection
			Selection.Replace(Record.Selection, false)

		end,

		Apply = function (Record)
			-- Applies this change
			
			-- Restore the original selection so only the modified parts must be substituted
			Selection.Replace(Record.Selection, false)

			-- Remove the parts before conversion (parallel as we don't depend on these parts)
			task.spawn(Core.SyncAPI.Invoke, Core.SyncAPI, 'Remove', Record.Parts)

			-- Restore the converted parts
			Core.SyncAPI:Invoke('UndoRemove', Record.NewParts)

			-- Add these objects to the selection
			Selection.Add(Record.NewParts, false)

		end,

	}
	
	Selection.Add(NewParts, false)
	
	-- Add the record to the history
	Core.History.Add(HistoryRecord)
end

function SetSubType(Type)
	local CurrentSelection = Selection.Items
	local CurrentParts = Selection.Parts

	-- Already track the changes
	local Before = {}
	local After = {}

	-- Prepare the parts for transformation
	for _, Part in CurrentParts do
		local BeforeChanges = { Part = Part }
		local AfterChanges = { Part = Part }

		local CurrentSubType = GetSubTypeFromPart(Part)

		-- If no type is found (unsupported part type) or it's the same, abort
		if CurrentSubType == Type then
			continue
		end

		-- Store the part's previous type
		BeforeChanges.SubType = CurrentSubType

		-- Insert the new type to the changes
		AfterChanges.SubType = Type

		-- Store both changes tables in their respective categories
		table.insert(Before, BeforeChanges)
		table.insert(After, AfterChanges)
	end

	-- Apply the changes to the server and get the modified parts
	local NewParts = Core.SyncAPI:Invoke("SyncTransform", After)

	-- Now we have enough information to track this action, create the history record
	local HistoryRecord = {
		Selection = CurrentSelection,
		Parts = CurrentParts,
		NewParts = NewParts,

		Before = Before,
		After = After,

		Unapply = function (Record)
			-- Reverts this change

			-- Remove the parts we converted (parallel as we don't depend on these parts)
			task.spawn(Core.SyncAPI.Invoke, Core.SyncAPI, 'Remove', Record.NewParts)

			-- Restore the former parts
			Core.SyncAPI:Invoke('UndoRemove', Record.Parts)

			-- Revert the selection
			Selection.Replace(Record.Selection, false)

		end,

		Apply = function (Record)
			-- Applies this change

			-- Restore the original selection so only the modified parts must be substituted
			Selection.Replace(Record.Selection, false)

			-- Remove the parts before conversion (parallel as we don't depend on these parts)
			task.spawn(Core.SyncAPI.Invoke, Core.SyncAPI, 'Remove', Record.Parts)

			-- Restore the converted parts
			Core.SyncAPI:Invoke('UndoRemove', Record.NewParts)

			-- Add these objects to the selection
			Selection.Add(Record.NewParts, false)

		end,

	}

	Selection.Add(NewParts, false)

	-- Add the record to the history
	Core.History.Add(HistoryRecord)
end

-- Return the tool
return TransformationTool