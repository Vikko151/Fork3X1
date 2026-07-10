local Tool = script.Parent.Parent
local Core = require(Tool.Core)
local Sounds = Core.Sounds

local Vendor = Tool:WaitForChild('Vendor')
local Libraries = Core.Libraries

local HistoryRecord

-- Libraries
local ListenForManualWindowTrigger = require(Tool.Core:WaitForChild('ListenForManualWindowTrigger'))
local Roact = require(Vendor:WaitForChild('Roact'))
local Signal = require(Libraries:WaitForChild('Signal'))
local BoundingBox = require(Tool.Core.BoundingBox)

-- Import relevant references
local Selection = Core.Selection
local Support = Core.Support
local Security = Core.Security

-- Initialize the tool
local MaterialTool = {
	Name = 'Material Tool',
	Color = BrickColor.new 'Bright violet',

	-- State
	CurrentMaterial = nil,

	-- Signals
	OnMaterialChanged = Signal.new(),
}

if table.find(Core.Options.ToolsBlacklist, MaterialTool.Name) then
	return MaterialTool
end

local ToolMode = "Visual"

MaterialTool.ManualText = [[<font weight="900" size="24"><u><i>Material Tool  🛠</i></u></font>
Lets you change the material, transparency, and reflectance of parts.

<font size="12" color="rgb(150, 150, 150)"><b>Transparency</b></font>
Sets if the part is opaque, transparent or invisible.

<font size="11" color="rgb(200, 200, 200)"><i>- Properties</i></font>
<font color="rgb(150, 150, 150)">•</font>  A part that has over 0.01 of transparency will get occulted by other parts that are made of glass.
<font color="rgb(150, 150, 150)">•</font>  When the transparency of a part with forcefield as a material is set to -inf, it'll be invisible, but it'll act like an opaque part otherwisely.
<font color="rgb(150, 150, 150)">•</font>  You can apply a highlight to a glass part with over 1 of transparency to create faux reflections.
<font color="rgb(150, 150, 150)">•</font>  A glass part with its transparency to -inf will show strange artifacts.

<font size="12" color="rgb(150, 150, 150)"><b>Reflectance</b></font>
Makes the part reflecting the sky depending on the value. The higher it is, the more visible the sky is.

<font size="11" color="rgb(200, 200, 200)"><i>- Properties</i></font>
<font color="rgb(150, 150, 150)">•</font>  Reflectance can go above 1. Values over one will create strange high-contrasted effects
<font color="rgb(150, 150, 150)">•</font>  A part with its reflectance set to inf will be dark and won't be influenced.

<font size="12" color="rgb(150, 150, 150)"><b>Material</b></font>
Gives the part a texture that sometimes has special properties.

<font size="11" color="rgb(200, 200, 200)"><i>- Properties</i></font>
<font color="rgb(150, 150, 150)">•</font>  If the game allows it and on quality 3+, metal can slightly reflect the sky and even sometimes a part of the world.
<font color="rgb(150, 150, 150)">•</font>  On quality 6+, neon glows.
<font color="rgb(150, 150, 150)">•</font>  Forcefield will create a filter effect, making a mesh's texture "alive".

]]

-- Container for temporary connections (disconnected automatically)
local Connections = {}

function MaterialTool:Equip()
	-- Enables the tool's equipped functionality

	-- Start up our interface
	self:ShowUI()
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

function MaterialTool:Unequip()
	-- Disables the tool's equipped functionality

	-- Clear unnecessary resources
	self:HideUI()
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

-- Designate a friendly name to each material
local Materials = {
	[Enum.Material.SmoothPlastic] = 'Smooth Plastic',
	[Enum.Material.Plastic] = 'Plastic',
	[Enum.Material.Brick] = 'Brick',
	[Enum.Material.Cobblestone] = 'Cobblestone',
	[Enum.Material.Concrete] = 'Concrete',
	[Enum.Material.CorrodedMetal] = 'Corroded Metal',
	[Enum.Material.DiamondPlate] = 'Diamond Plate',
	[Enum.Material.Fabric] = 'Fabric',
	[Enum.Material.Foil] = 'Foil',
	[Enum.Material.ForceField] = 'Forcefield',
	[Enum.Material.Granite] = 'Granite',
	[Enum.Material.Grass] = 'Grass',
	[Enum.Material.Ice] = 'Ice',
	[Enum.Material.Marble] = 'Marble',
	[Enum.Material.Metal] = 'Metal',
	[Enum.Material.Neon] = 'Neon',
	[Enum.Material.Pebble] = 'Pebble',
	[Enum.Material.Sand] = 'Sand',
	[Enum.Material.Slate] = 'Slate',
	[Enum.Material.Wood] = 'Wood',
	[Enum.Material.WoodPlanks] = 'Wood Planks',
	[Enum.Material.Glass] = 'Glass',
	[Enum.Material.Asphalt] = 'Asphalt',
	[Enum.Material.Basalt] = 'Basalt',
	[Enum.Material.CrackedLava] = 'Cracked Lava',
	[Enum.Material.Glacier] = 'Glacier',
	[Enum.Material.Ground] = 'Ground',
	[Enum.Material.LeafyGrass] = 'Leafy Grass',
	[Enum.Material.Limestone] = 'Limestone',
	[Enum.Material.Mud] = 'Mud',
	[Enum.Material.Pavement] = 'Pavement',
	[Enum.Material.Rock] = 'Rock',
	[Enum.Material.Salt] = 'Salt',
	[Enum.Material.Sandstone] = 'Sandstone',
	[Enum.Material.Snow] = 'Snow',
	[Enum.Material.Cardboard] = 'Cardboard',
	[Enum.Material.Carpet] = 'Carpet',
	[Enum.Material.CeramicTiles] = 'Ceramic Tiles',
	[Enum.Material.ClayRoofTiles] = 'Clay Roof Tiles',
	[Enum.Material.Leather] = 'Leather',
	[Enum.Material.RoofShingles] = 'Roof Shingles',
	[Enum.Material.Plaster] = 'Plaster',
	[Enum.Material.Rubber] = 'Rubber',
}

if Core.Options.AllowMaterialVariants then
	for _, MaterialVariant in game:GetService("MaterialService"):GetDescendants() do
		if MaterialVariant:IsA("MaterialVariant") then
			Materials[MaterialVariant.Name] = MaterialVariant.Name
		end
	end
end

-- Add materials in the options module
if Core.Options.ExtraMaterials then
	local ExtraMaterials = type(Core.Options.ExtraMaterials) == "function" and Core.Options.ExtraMaterials() or Core.Options.ExtraMaterials

	for TheMaterial, FriendlyName in ExtraMaterials do
		if not Materials[TheMaterial] then
			Materials[TheMaterial] = FriendlyName
		end
	end
end

function MaterialTool:UpdateToolMode()
	-- Make sure there's a UI
	if not self.UI then return end

	-- Tell whether the geometry interface will be visible
	local IsVisualVisible = ToolMode == "Visual"

	-- Tell whether the type interface will be visible
	local ArePhysicsVisible = ToolMode == "Physics"

	if not IsVisualVisible then
		-- Apply visibility changes to the Visual UI if requested
		for _, Object in self.UI.Visual:GetChildren() do
			Object.Visible = false
		end
	elseif not ArePhysicsVisible then
		-- Apply visibility changes to the Physics UI if requested
		for _, Object in self.UI.Physics:GetChildren() do
			Object.Visible = false
		end
	end
	
	-- Request Core to update the switch
	Core.ToggleSwitch(ToolMode, self.UI.ModeOption.Options)
	
	-- Update the UI
	--MaterialTool:UpdateUI()
end


function MaterialTool:ShowUI()
	local UI = Core.UIFolder
	
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
		return

	end
	
	if self.UI then
		self.UI:Destroy()
	end


	-- Create the UI
	self.UI = Core.Interfaces.BTMaterialToolGUI:Clone()
	self.UI.Parent = Core.UI
	self.UI.Visible = true

	-- References to inputs
	local TransparencyInput = self.UI.Visual.TransparencyOption.Input.TextBox
	local ReflectanceInput = self.UI.Visual.ReflectanceOption.Input.TextBox
	local MaxSpeedInput = self.UI.Physics.VehicleSeatOptions.Options.MaxSpeedOption.Input.TextBox
	local TurnSpeedInput = self.UI.Physics.VehicleSeatOptions.Options.TurnSpeedOption.Input.TextBox
	local TorqueInput = self.UI.Physics.VehicleSeatOptions.Options.TorqueOption.Input.TextBox
	
	-- Sort the material list
	local MaterialList = Support.Values(Materials)
	table.sort(MaterialList)

	-- Create material dropdown
	local function BuildMaterialDropdown()
		return Roact.createElement(Dropdown, {
			Position = UDim2.new(0, 50, 0, 0),
			Size = UDim2.new(0, 130, 0, 25),
			Options = MaterialList,
			MaxRows = 6,
			CurrentOption = self.CurrentMaterial and typeof(self.CurrentMaterial) == "EnumItem" and self.CurrentMaterial.Name or self.CurrentMaterial,
			ImagePreview = true,
			OnOptionSelected = function (Option)
				SetProperty('Material', Support.FindTableOccurrence(Materials, Option))
			end,
		})
	end
	

	local Toggle = self.UI.ModeOption
	local Buttons = Toggle.Options

	local VisualButton = Buttons.Visual.Button
	local PhysicsButton = Buttons.Physics.Button

	VisualButton.Activated:Connect(function()
		Core.PlaySound("Press")
		
		ToolMode = "Visual"

		self:UpdateToolMode()
	end)
	
	local function HoverSound()
		Core.PlaySound("Hover")
	end

	VisualButton.MouseEnter:Connect(HoverSound)

	PhysicsButton.Activated:Connect(function()
		Core.PlaySound("Press")
		
		ToolMode = "Physics"

		self:UpdateToolMode()
	end)

	PhysicsButton.MouseEnter:Connect(HoverSound)
	
	-- ===============================
	-- VISUAL CATEGORY
	-- ===============================
	
	-- Enable the cast shadows switch
	self.UI.Visual.CastShadowOption.Check.Activated:Connect(function ()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Press"))
		if Support.IdentifyCommonProperty(Selection.Parts, "CastShadow") == false then
			SetProperty("CastShadow", true)
		else
			SetProperty("CastShadow", false)	
		end
	end)

	-- Mount surface dropdown
	local MaterialDropdownHandle = Roact.mount(BuildMaterialDropdown(), self.UI.Visual.MaterialOption, 'Dropdown')
	self.OnMaterialChanged:Connect(function ()
		Roact.update(MaterialDropdownHandle, BuildMaterialDropdown())
	end)

	-- Enable the transparency and reflectance inputs
	SyncInputToProperty('Transparency', TransparencyInput)
	SyncInputToProperty('Reflectance', ReflectanceInput)
	
	-- If permitted, also sync the mass input
	if Core.Options.CustomPhysicalPropertiesEditing == true then
		local Category = self.UI.Physics.AdvancedOptions
		
		local CategoryName = Category:FindFirstChild("Name")
		local CategoryArrow = CategoryName.ArrowButton
		local CategoryOptions = Category.Options
		
		CategoryName.Activated:Connect(function()
			CategoryOptions.Visible = not CategoryOptions.Visible

			local TagMethod = CategoryOptions.Visible and script.AddTag or script.RemoveTag

			TagMethod(CategoryArrow, "STATE_Open")
			
			self:UpdateUI(true)
		end)
		
		local AdvancedOptions = self.UI.Physics.AdvancedOptions.Options
		
		local MassInput = self.UI.Physics.MassOption.Input.TextBox
		local DensityInput = AdvancedOptions.DensityOption.Input.TextBox
		local FrictionInput = AdvancedOptions.FrictionOption.Input.TextBox
		local ElasticityInput = AdvancedOptions.ElasticityOption.Input.TextBox
		local FrictionWeightInput = AdvancedOptions.FrictionWeightOption.Input.TextBox
		local ElasticityWeightInput = AdvancedOptions.ElasticityWeightOption.Input.TextBox
		local AcousticAbsorptionInput = AdvancedOptions.AbsorptionOption.Input.TextBox
		
		SyncInputToProperty('Density', DensityInput, SetPhysicalProperty)
		SyncInputToProperty('Friction', FrictionInput, SetPhysicalProperty)
		SyncInputToProperty('Elasticity', ElasticityInput, SetPhysicalProperty)
		SyncInputToProperty('FrictionWeight', FrictionWeightInput, SetPhysicalProperty)
		SyncInputToProperty('ElasticityWeight', ElasticityWeightInput, SetPhysicalProperty)
		SyncInputToProperty('AcousticAbsorption', AcousticAbsorptionInput, SetPhysicalProperty)
		
		SyncInputToProperty('Mass', MassInput, function(Name, Value)
			-- Make sure the given value is valid
			if Value == nil then
				return
			end

			-- Start a history record
			TrackChange()

			-- Go through each part
			for _, Part: BasePart in pairs(Selection.Parts) do
				
				-- Calculate the necessary density to reach this part
				
				-- Find the part's volume
				local Volume = Part.Size.X * Part.Size.Y * Part.Size.Z
				
				-- Figuring out Density = Mass / Volume, we can find Density
				local Density = Value / Volume
				
				-- Get the part's current physical properties
				local CurrentPhysicalProperties = Part.CurrentPhysicalProperties
				
				-- We can now create the custom physical properties for this part
				local NewPhysicalProperties = PhysicalProperties.new(
					Density,														-- Density
					CurrentPhysicalProperties.Friction,								-- Friction
					CurrentPhysicalProperties.Elasticity,							-- Elasticity
					CurrentPhysicalProperties.FrictionWeight,						-- FrictionWeight
					CurrentPhysicalProperties.ElasticityWeight,						-- ElasticityWeight
					CurrentPhysicalProperties.AcousticAbsorption					-- AcousticAbsorption
				)
				
				-- Store the state of the part before modification
				table.insert(HistoryRecord.Before, { Part = Part, CustomPhysicalProperties = Part.CurrentPhysicalProperties })

				-- Create the change request for this part
				table.insert(HistoryRecord.After, { Part = Part, CustomPhysicalProperties = NewPhysicalProperties })

			end

			-- Register the changes
			RegisterChange()

		end)
	end
	
	-- ===============================
	-- PHYSICS CATEGORY
	-- ===============================
	
	-- Enable the massless switch
	self.UI.Physics.MasslessOption.Check.Activated:Connect(function ()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Press"))
		if Support.IdentifyCommonProperty(Selection.Parts, "Massless") == false then
			SetProperty("Massless", true)
		else
			SetProperty("Massless", false)	
		end
	end)
	
	-- If allowed, sync the vehicle seat properties
	if Core.Options.AllowExtraVehicleSeatsSettings == true then
		local Category = self.UI.Physics.VehicleSeatOptions

		local CategoryName = Category:FindFirstChild("Name")
		local CategoryArrow = CategoryName.ArrowButton
		local CategoryOptions = Category.Options

		CategoryName.Activated:Connect(function()
			CategoryOptions.Visible = not CategoryOptions.Visible

			local TagMethod = CategoryOptions.Visible and script.AddTag or script.RemoveTag

			TagMethod(CategoryArrow, "STATE_Open")

			self:UpdateUI(true)
		end)
		
		SyncInputToProperty('MaxSpeed', MaxSpeedInput)
		SyncInputToProperty('TurnSpeed', TurnSpeedInput)
		SyncInputToProperty('Torque', TorqueInput)
	end
	
	-- Hook up manual triggering
	local SignatureButton = self.UI:WaitForChild('Title'):WaitForChild('Signature')
	ListenForManualWindowTrigger(MaterialTool.ManualText, MaterialTool.Color.Color, SignatureButton)

	-- Update the UI every 0.1 seconds
	self.StopUpdatingUI = Support.Loop(0.1, function ()
		self:UpdateUI()
	end)

end

function MaterialTool:HideUI()
	-- Hides the tool UI

	-- Make sure there's a UI
	if not self.UI then
		return
	end

	-- Hide the UI
	self.UI.Visible = false

	-- Stop updating the UI
	self.StopUpdatingUI()

end

function SyncInputToProperty(Property, Input, Callback)
	-- Enables `Input` to change the given property

	-- Enable inputs
	Input.FocusLost:Connect(function ()
		if Callback then
			Callback( Property, tonumber(Input.Text) )
		else
			SetProperty(Property, tonumber(Input.Text))
		end
	end)

end

function SetProperty(Property, Value)

	-- Make sure the given value is valid
	if Value == nil then
		return
	end

	-- Start a history record
	TrackChange()

	-- Go through each part
	for _, Part in pairs(Selection.Parts) do

		-- Store the state of the part before modification
		table.insert(HistoryRecord.Before, { Part = Part, [Property] = Part[Property] })

		-- Create the change request for this part
		table.insert(HistoryRecord.After, { Part = Part, [Property] = Value })

	end

	-- Register the changes
	RegisterChange()

end

function SetPhysicalProperty(PhysicalProperty, Value)

	-- Make sure the given value is valid
	if Value == nil then
		return
	end

	-- Start a history record
	TrackChange()

	-- Go through each part
	for _, Part in pairs(Selection.Parts) do
		
		-- Get the part's current physical properties
		local CurrentPhysicalProperties = Part.CurrentPhysicalProperties
		
		-- Create a table to find where the property change must occur
		local NameToIndex = {
			Density = 1,
			Friction = 2,
			Elasticity = 3,
			FrictionWeight = 4,
			ElasticityWeight = 5,
			AcousticAbsorption = 6
		}
		
		-- Create a table with every property
		local PhysicalPropertiesTable = {
			CurrentPhysicalProperties.Density,
			CurrentPhysicalProperties.Friction,
			CurrentPhysicalProperties.Elasticity,
			CurrentPhysicalProperties.FrictionWeight,
			CurrentPhysicalProperties.ElasticityWeight,
			CurrentPhysicalProperties.AcousticAbsorption
		}
		
		-- Replace the given property
		PhysicalPropertiesTable[ NameToIndex[PhysicalProperty] ] = Value
		
		-- Set the physical properties with an unpacked version of the table's values
		local NewPhysicalProperties = PhysicalProperties.new( unpack( PhysicalPropertiesTable ) )

		-- Store the state of the part before modification
		table.insert(HistoryRecord.Before, { Part = Part, CustomPhysicalProperties = Part.CurrentPhysicalProperties })

		-- Create the change request for this part
		table.insert(HistoryRecord.After, { Part = Part, CustomPhysicalProperties = NewPhysicalProperties })
	end

	-- Register the changes
	RegisterChange()

end



function UpdateDataInputs(Data)
	-- Updates the data in the given TextBoxes when the user isn't typing in them

	-- Go through the inputs and data
	for Input, UpdatedValue in pairs(Data) do

		-- Makwe sure the user isn't typing into the input
		if not Input:IsFocused() then

			-- Set the input's value
			Input.Text = tostring(UpdatedValue)

		end

	end

end

-- List of UI layouts
local Layouts = {
	Visual = {
		UIElements = { 'SelectNote', 'MaterialOption', 'TransparencyOption', 'ReflectanceOption', 'CastShadowOption', 'VehicleSeatNote' },
		EmptySelection = { 'SelectNote' },
		Normal = { 'MaterialOption', 'TransparencyOption', 'ReflectanceOption', 'CastShadowOption' },
		VehicleSeats = { 'VehicleSeatNote' },
	},
	Physics = {
		UIElements = { 'SelectNote', 'MasslessOption', 'MassOption', 'AdvancedOptions', 'VehicleSeatOptions' },
		EmptySelection = { 'SelectNote' },
		Normal = { 'MasslessOption' },
		VehicleSeats = { 'VehicleSeatOptions' },
	},
}

-- If allowed, also display the physical properties options
if Core.Options.CustomPhysicalPropertiesEditing == true then
	table.insert(Layouts.Physics.Normal, 'MassOption')
	table.insert(Layouts.Physics.Normal, 'AdvancedOptions')
end

-- Current UI layout
local CurrentLayout

function MaterialTool:ChangeLayout(Layout, ForceLayoutChange)
	-- Sets the UI to the given layout

	-- Make sure the new layout isn't already set
	if not ForceLayoutChange and CurrentLayout == Layout then
		return
	end

	-- Set this as the current layout
	CurrentLayout = Layout

	-- Reset the UI
	for _, ElementName in pairs(Layouts[ToolMode].UIElements) do
		local Element = self.UI[ToolMode][ElementName]
		Element.Visible = false
	end

	-- Keep track of the total vertical extents of all items
	local Sum = 0

	-- Go through each layout element
	for ItemIndex, ItemName in ipairs(Layout) do

		local Item = self.UI[ToolMode][ItemName]

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
	self.UI.Size = UDim2.new(0, 200, 0, 85 + Sum)

end

function MaterialTool:UpdateUI(ForceLayoutChange)
	-- Updates information on the UI

	-- Make sure the UI's on
	if not self.UI then
		return
	end

	-- References to inputs
	local TransparencyInput = self.UI.Visual.TransparencyOption.Input.TextBox
	local ReflectanceInput = self.UI.Visual.ReflectanceOption.Input.TextBox
	local MaxSpeedInput = self.UI.Physics.VehicleSeatOptions.Options.MaxSpeedOption.Input.TextBox
	local TurnSpeedInput = self.UI.Physics.VehicleSeatOptions.Options.TurnSpeedOption.Input.TextBox
	local TorqueInput = self.UI.Physics.VehicleSeatOptions.Options.TorqueOption.Input.TextBox
	
	-----------------------
	-- Update the UI layout
	-----------------------
	
	local VehicleSeats = Core.Options.AllowExtraVehicleSeatsSettings and Support.FilterArray(Selection.Parts, function(Value, Key) return Value:IsA("VehicleSeat") end) or {}
	
	local NewLayout = {}
	
	-- Figure out the necessary UI layout
	if #Selection.Parts == 0 then
		self:ChangeLayout(Layouts[ToolMode].EmptySelection, ForceLayoutChange)
		return
	else
		-- When the selection isn't empty
		NewLayout = table.clone(Layouts[ToolMode].Normal)
	end
	
	-- When the selection has vehicle seats
	if Core.Options.AllowExtraVehicleSeatsSettings == true and #VehicleSeats ~= 0 then
		Support.ConcatTable(NewLayout, Layouts[ToolMode].VehicleSeats)
	end
	
	self:ChangeLayout(NewLayout, ForceLayoutChange)

	-- Get the common properties
	local Material = Support.IdentifyCommonProperty(Selection.Parts, 'Material')
	local MaterialVariant = Support.IdentifyCommonProperty(Selection.Parts, 'MaterialVariant')
	
	if MaterialVariant ~= "" then
		Material = MaterialVariant
	end
	
	local Transparency = Support.IdentifyCommonProperty(Selection.Parts, 'Transparency')
	local Reflectance = Support.IdentifyCommonProperty(Selection.Parts, 'Reflectance')
	local Massless = Support.IdentifyCommonProperty(Selection.Parts, 'Massless')
	local CastShadow = Support.IdentifyCommonProperty(Selection.Parts, 'CastShadow')
	local Mass = Support.IdentifyCommonProperty(Selection.Parts, 'Mass')

	-- Update the material dropdown
	if self.CurrentMaterial ~= Material then
		self.CurrentMaterial = Material
		self.OnMaterialChanged:Fire(Material)
	end
	
	local DataInputs = {
		[TransparencyInput] = Transparency and Support.Round(Transparency, 2) or '*',
		[ReflectanceInput] = Reflectance and Support.Round(Reflectance, 2) or '*',
	}
	
	if Core.Options.CustomPhysicalPropertiesEditing == true then
		local AdvancedOptions = self.UI.Physics.AdvancedOptions.Options

		local MassInput = self.UI.Physics.MassOption.Input.TextBox
		local DensityInput = AdvancedOptions.DensityOption.Input.TextBox
		local FrictionInput = AdvancedOptions.FrictionOption.Input.TextBox
		local ElasticityInput = AdvancedOptions.ElasticityOption.Input.TextBox
		local FrictionWeightInput = AdvancedOptions.FrictionWeightOption.Input.TextBox
		local ElasticityWeightInput = AdvancedOptions.ElasticityWeightOption.Input.TextBox
		local AcousticAbsorptionInput = AdvancedOptions.AbsorptionOption.Input.TextBox
		
		local Mass = Support.IdentifyCommonProperty(Selection.Parts, 'Mass')
		
		local CommonPhysicalProperties = {}
		
		-- Look for common physical properties
		if AdvancedOptions.Visible then
			for Index, Part in Selection.Parts do
				local UnpackedProperties = string.split( tostring(Part.CurrentPhysicalProperties), "," )

				if Index == 1 then
					for Index, Value in UnpackedProperties do
						CommonPhysicalProperties[Index] = Support.Round(tonumber(Value), 3)
					end
				else
					if Support.CountKeys(CommonPhysicalProperties) == 0 then
						break
					end

					for Index, Value in UnpackedProperties do
						if Support.CountKeys(CommonPhysicalProperties) == 0 then
							break
						end

						local FinalValue = Support.Round(tonumber(Value), 3)

						CommonPhysicalProperties[Index] = if CommonPhysicalProperties[Index] ~= FinalValue then nil else CommonPhysicalProperties[Index]
					end
				end
			end
		end
		
		-- Update inputs
		DataInputs[MassInput] = Mass and Support.Round(Mass, 3) or '*'
		DataInputs[DensityInput] = CommonPhysicalProperties[1] and Support.Round(CommonPhysicalProperties[1], 3) or '*'
		DataInputs[FrictionInput] = CommonPhysicalProperties[2] and Support.Round(CommonPhysicalProperties[2], 3) or '*'
		DataInputs[ElasticityInput] = CommonPhysicalProperties[3] and Support.Round(CommonPhysicalProperties[3], 3) or '*'
		DataInputs[FrictionWeightInput] = CommonPhysicalProperties[4] and Support.Round(CommonPhysicalProperties[4], 3) or '*'
		DataInputs[ElasticityWeightInput] = CommonPhysicalProperties[5] and Support.Round(CommonPhysicalProperties[5], 3) or '*'
		DataInputs[AcousticAbsorptionInput] = CommonPhysicalProperties[6] and Support.Round(CommonPhysicalProperties[6], 3) or '*'
	end
	
	if Core.Options.AllowExtraVehicleSeatsSettings == true then
		local MaxSpeed = Support.IdentifyCommonProperty(VehicleSeats, 'MaxSpeed')
		local TurnSpeed = Support.IdentifyCommonProperty(VehicleSeats, 'TurnSpeed')
		local Torque = Support.IdentifyCommonProperty(VehicleSeats, 'Torque')
		
		DataInputs[MaxSpeedInput] = MaxSpeed and Support.Round(MaxSpeed, 2) or '*'
		DataInputs[TurnSpeedInput] = TurnSpeed and Support.Round(TurnSpeed, 2) or '*'
		DataInputs[TorqueInput] = Torque and Support.Round(Torque, 2) or '*'
	end
	
	-- Update inputs
	UpdateDataInputs(DataInputs)
	UpdateToggleInput(self.UI.Physics.MasslessOption.Check, Massless)
	UpdateToggleInput(self.UI.Visual.CastShadowOption.Check, CastShadow)

end

function UpdateToggleInput(Toggle, Data)
	-- Updates the data in the given buttons
	
	-- Go through the inputs and data
	if Core.UIFolder:FindFirstChild("Version") and Core.UIFolder.Version.Value >= 2 then
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

end


function TrackChange()

	-- Start the record
	HistoryRecord = {
		Before = {},
		After = {},
		Selection = Selection.Items,

		Unapply = function (Record)
			-- Reverts this change

			-- Select the changed parts
			Selection.Replace(Record.Selection)

			-- Send the change request
			Core.SyncAPI:Invoke('SyncMaterial', Record.Before)

		end,

		Apply = function (Record)
			-- Applies this change

			-- Select the changed parts
			Selection.Replace(Record.Selection)

			-- Send the change request
			Core.SyncAPI:Invoke('SyncMaterial', Record.After)

		end,

	}

end

function RegisterChange()
	-- Finishes creating the history record and registers it

	-- Make sure there's an in-progress history record
	if not HistoryRecord then
		return
	end

	-- Send the change to the server
	Core.SyncAPI:Invoke('SyncMaterial', HistoryRecord.After)

	-- Register the record and clear the staging
	Core.History.Add(HistoryRecord)
	HistoryRecord = nil

end

-- Return the tool
return MaterialTool