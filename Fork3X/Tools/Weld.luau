local Tool = script.Parent.Parent
local Core = require(Tool.Core)
local Sounds = Tool:WaitForChild("Sounds")
local Vendor = Tool:WaitForChild('Vendor')
local UIFolder = Core.UIFolder
local Libraries = Tool.Libraries--Core.Libraries

local SnapTracking = require(Tool.Core.Snapping)

-- Libraries
local ListenForManualWindowTrigger = require(Tool.Core:WaitForChild('ListenForManualWindowTrigger'))
local ColorPicker = require(UIFolder:WaitForChild('ColorPicker'))
local Roact = require(Vendor:WaitForChild('Roact'))
local Signal = require(Libraries:WaitForChild('Signal'))
local BoundingBox = require(Tool.Core.BoundingBox)
local PropScan = require(Libraries.PropScan)
local Maid = require(Libraries:WaitForChild 'Maid')

-- Import relevant references
local Selection = Core.Selection
local Support = Core.Support
local Security = Core.Security
local Services = Support.ImportServices()

-- Services
local ContextActionService = game:GetService 'ContextActionService'
local UserInputService = game:GetService 'UserInputService'

local TextService = game:GetService("TextService")

local UI
local Dropdown

-- Initialize the tool
local WeldTool = {
	Name = 'Constraint Tool',
	Color = BrickColor.new 'Really black',
	CurrentType = 'Weld',


	-- Resource maid
	Maid = Maid.new();

	-- Signals
	OnTypeChanged = Signal.new(),
	OnActionChanged = Signal.new(),
	ConfirmSnapping = Signal.new(),
}

WeldTool.ManualText = [[<font weight="900" size="24"><u><i>Constraint Tool  🛠</i></u></font>
Allows you to attach parts to hold them together.<font size="6"><br /></font>

<font size="12" color="rgb(150, 150, 150)"><b>Using the tool</b></font>

The tool offers multiple constraints that attach parts differently.

Here are some of the default constraints that can be found in most cases in Fork3X:

   <font color="rgb(150, 150, 150)">•</font>  Weld: Simply holds multiple parts together like glue.
   <font color="rgb(150, 150, 150)">•</font>  RopeConstraint: Holds multiple parts together with a rope, so they can't go further than the rope's length.
   <font color="rgb(150, 150, 150)">•</font>  RopeConstraint: Holds multiple parts together with a stick, causing them to always remain at the same distance.
   <font color="rgb(150, 150, 150)">•</font>  HingeConstraint: Holds multiple parts together with a hinge, some sort of nail around which the part can spin. 

<font size="12" color="rgb(150, 150, 150)"><b>Quick attaching</b></font>

Instead of having to move attachments, you can also hold <b>R</b> and click on two parts' side to weld them together accurately and quickly.

Do note this doesn't work with welds, as there is no difference on where you weld.

<b>NOTE: </b>Welds may break if parts are individually moved.]]

-- Container for temporary connections (disconnected automatically)
local Connections = {}

local PropertiesUpdateSignal

local CommonProperties = {}

local PropertiesToSync = {}

local EveryProperty = {}

local PropertiesByType = {}

local PropertyToCategory = {}

local Categories = {}

local TypeToCategories = {}

local TypeToTemplate = {
	Number = function(Data, Category, Option)
		local Configurator = Core.UIFolder.OptionsTemplates.ExampleConfigurators.Input:Clone()

		Configurator.Parent = Option

		local DataSettings = Data.Settings

		SyncInputToProperty(DataSettings.Property, "Number", Configurator.TextBox)

		PropertiesUpdateSignal:Connect(function()
			if DataSettings.VisibleWhen then
				Option.Visible = DataSettings.VisibleWhen()

				if not Option.Visible then
					return
				end
			end


			if not PropertiesToSync[DataSettings.Property] or Configurator.TextBox:IsFocused() then
				return
			end

			Configurator.TextBox.Text = CommonProperties[WeldTool.CurrentType][DataSettings.Property] and Support.Round( tonumber(CommonProperties[WeldTool.CurrentType][DataSettings.Property]), 3 ) or "*"
		end)

		return Configurator
	end,

	NumberSequence = function(Data, Category, Option)
		local Configurator = Core.UIFolder.OptionsTemplates.ExampleConfigurators.Input:Clone()

		Configurator.Size = UDim2.fromOffset(70, 25)
		Configurator.Parent = Option

		local DataSettings = Data.Settings

		SyncInputToProperty(DataSettings.Property, "NumberSequence", Configurator.TextBox)

		PropertiesUpdateSignal:Connect(function()
			if not PropertiesToSync[DataSettings.Property] or Configurator.TextBox:IsFocused()
				or not CommonProperties[WeldTool.CurrentType][DataSettings.Property] then

				return
			end

			if DataSettings.VisibleWhen then
				Option.Visible = DataSettings.VisibleWhen()

				if not Option.Visible then
					return
				end
			end

			local Value = CommonProperties[WeldTool.CurrentType][DataSettings.Property]

			if Value then
				local Values = Value.Keypoints
				local Output = ""

				if #Values == 2 and Values[1].Value == Values[2].Value then
					Output = Values[1].Value
				else
					for Index, Value in Values do
						if Index == 1 then
							Output ..= Support.Round( Value.Value, 3 )
						else
							Output ..= ", " .. Support.Round( Value.Value, 3 )
						end
					end
				end

				Configurator.TextBox.Text = Output
			else
				Configurator.TextBox.Text = "*"
			end

		end)

		return Configurator
	end,

	NumberRange = function(Data, Category, Option)
		local Configurator = Core.UIFolder.OptionsTemplates.ExampleConfigurators.Input:Clone()

		Configurator.Parent = Option

		local DataSettings = Data.Settings

		SyncInputToProperty(DataSettings.Property, "NumberRange", Configurator.TextBox)

		PropertiesUpdateSignal:Connect(function()
			if not PropertiesToSync[DataSettings.Property] or Configurator.TextBox:IsFocused() then

				return
			end

			if DataSettings.VisibleWhen then
				Option.Visible = DataSettings.VisibleWhen()

				if not Option.Visible then
					return
				end
			end

			local Value: NumberRange = CommonProperties[WeldTool.CurrentType][DataSettings.Property]

			if Value then
				local MinValue = Value.Min
				local MaxValue = Value.Max

				if MinValue == MaxValue then
					Configurator.TextBox.Text = Support.Round(MinValue, 3)
				else
					Configurator.TextBox.Text = Support.Round(MinValue, 3) .. ", " .. Support.Round(MaxValue, 3)
				end
			else
				Configurator.TextBox.Text = "*"
			end

		end)

		return Configurator
	end,

	Color = function(Data, Category, Option)
		local Configurator = Core.UIFolder.OptionsTemplates.ExampleConfigurators.ColorPicker:Clone()

		Configurator.Parent = Option

		local DataSettings = Data.Settings

		SyncInputToProperty(DataSettings.Property, "Color", Configurator.HSVPicker)

		PropertiesUpdateSignal:Connect(function()
			if not PropertiesToSync[DataSettings.Property] then
				return
			end

			if DataSettings.VisibleWhen then
				Option.Visible = DataSettings.VisibleWhen()

				if not Option.Visible then
					return
				end
			end

			local Color = CommonProperties[WeldTool.CurrentType][DataSettings.Property]

			if typeof(Color) == "ColorSequence" then
				Color = Color.Keypoints[2].Value
			end

			UpdateColorIndicator(Configurator.Indicator, Color)
		end)

		return Configurator
	end,

	Boolean = function(Data, Category, Option)
		local Configurator = Core.UIFolder.OptionsTemplates.ExampleConfigurators.Check:Clone()

		Configurator.Parent = Option

		local DataSettings = Data.Settings

		SyncInputToProperty(DataSettings.Property, "Boolean", Configurator)

		PropertiesUpdateSignal:Connect(function()
			if DataSettings.VisibleWhen then
				Option.Visible = DataSettings.VisibleWhen()

				if not Option.Visible then
					return
				end
			end

			if PropertiesToSync[DataSettings.Property] == nil then
				return
			end

			UpdateToggleInput(Configurator, CommonProperties[WeldTool.CurrentType][DataSettings.Property])
		end)

		return Configurator
	end,

	Vector2 = function(Data, Category, Option)
		local Configurator = Core.UIFolder.OptionsTemplates.ExampleConfigurators.Vector:Clone()

		Configurator.ZInput:Destroy()
		Configurator.Size = UDim2.fromOffset(96, 35)

		Configurator.Parent = Option

		local DataSettings = Data.Settings

		SyncInputToProperty(DataSettings.Property, "Vector2", Configurator)

		local Inputs = {
			X = Configurator.XInput.TextBox,
			Y = Configurator.YInput.TextBox,
		}

		PropertiesUpdateSignal:Connect(function()
			if not PropertiesToSync[DataSettings.Property] then
				return
			end

			if DataSettings.VisibleWhen then
				Option.Visible = DataSettings.VisibleWhen()

				if not Option.Visible then
					return
				end
			end

			local Value = CommonProperties[WeldTool.CurrentType][DataSettings.Property]

			for Coordinate, Input in Inputs do
				if not Input:IsFocused() then
					Input.Text = Value and Support.Round(Value[Coordinate], 3) or "*"
				end
			end
		end)

		return Configurator
	end,

	Vector3 = function(Data, Category, Option)
		local Configurator = Core.UIFolder.OptionsTemplates.ExampleConfigurators.Vector:Clone()

		Configurator.Parent = Option

		local DataSettings = Data.Settings

		SyncInputToProperty(DataSettings.Property, "Vector3", Configurator)

		local Inputs = {
			X = Configurator.XInput.TextBox,
			Y = Configurator.YInput.TextBox,
			Z = Configurator.ZInput.TextBox
		}

		PropertiesUpdateSignal:Connect(function()
			if not PropertiesToSync[DataSettings.Property] then
				return
			end

			if DataSettings.VisibleWhen then
				Option.Visible = DataSettings.VisibleWhen()

				if not Option.Visible then
					return
				end
			end

			local Value = CommonProperties[WeldTool.CurrentType][DataSettings.Property]

			for Coordinate, Input in Inputs do
				if not Input:IsFocused() then
					Input.Text = Value and Support.Round(Value[Coordinate], 3) or "*"
				end
			end
		end)

		return Configurator
	end,

	AssetId = function(Data, Category, Option)
		local Configurator = Core.UIFolder.OptionsTemplates.ExampleConfigurators.ID:Clone()

		Configurator.Parent = Option

		local DataSettings = Data.Settings
		local TextSizeParams = Instance.new("GetTextBoundsParams")

		local MinimalTextBoxSize = Configurator.AbsoluteSize
		local TextInput = Configurator.TextBox
		local LastText = ""

		TextSizeParams.Font = TextInput:GetStyled("FontFace")
		TextSizeParams.Size = TextInput:GetStyled("TextSize")
		TextSizeParams.Width = math.huge
		TextSizeParams.RichText = false

		TextInput.StyledPropertiesChanged:Connect(function()
			TextSizeParams.Font = TextInput:GetStyled("FontFace")
			TextSizeParams.Size = TextInput:GetStyled("TextSize")
		end)

		SyncInputToProperty(DataSettings.Property, "AssetId", TextInput)

		PropertiesUpdateSignal:Connect(function()
			if DataSettings.VisibleWhen then
				Option.Visible = DataSettings.VisibleWhen()

				if not Option.Visible then
					return
				end
			end

			TextSizeParams.Text = TextInput.Text

			local Size = TextService:GetTextBoundsAsync(TextSizeParams)

			local XAxis = math.max(Size.X, MinimalTextBoxSize.X)
			local YOffset = XAxis ~= MinimalTextBoxSize.X and -TextInput.Parent:GetStyled("ScrollBarThickness") or 0

			TextInput.Size = UDim2.new(0, math.max(Size.X, MinimalTextBoxSize.X), 1, YOffset)

			if TextInput.Text ~= LastText and TextInput:IsFocused() then
				TextInput.Parent.CanvasPosition = Vector2.new(TextInput.Parent.AbsoluteCanvasSize.X - MinimalTextBoxSize.X, 0)
			end

			LastText = TextInput.Text

			if not TextInput:IsFocused() and PropertiesToSync[DataSettings.Property] then
				-- Set the input's value
				TextInput.Text = CommonProperties[WeldTool.CurrentType][DataSettings.Property] and ParseAssetId(CommonProperties[WeldTool.CurrentType][DataSettings.Property]) 
					or CommonProperties[WeldTool.CurrentType][DataSettings.Property] or "*"
			end
		end)

		return Configurator
	end,

	Dropdown = function(Data, Category, Option)
		local Configurator = Roact.createElement( Dropdown, Data.Settings.DropdownConfiguration() )

		local DropdownHandle = Roact.mount( Configurator, Option, 'Dropdown' )

		local PreviousProperty

		PropertiesUpdateSignal:Connect(function()

			if Data.Settings.VisibleWhen then
				Option.Visible = Data.Settings.VisibleWhen()

				if not Option.Visible then
					return
				end
			end


			if not PropertiesToSync[Data.Settings.Property] 
				or PreviousProperty == CommonProperties[WeldTool.CurrentType][Data.Settings.Property] then

				return
			end

			PreviousProperty = CommonProperties[WeldTool.CurrentType][Data.Settings.Property]

			Roact.update( 
				DropdownHandle,
				Roact.createElement( Dropdown, Data.Settings.DropdownConfiguration( CommonProperties[WeldTool.CurrentType][Data.Settings.Property]) ) 
			)
		end)

		return Configurator
	end,
}

function WeldTool.Equip()
	-- Enables the tool's equipped functionality

	-- Start up our interface
	ShowUI()

	if Core.Options.HighlightFocus == false then
		EnableFocusHighlighting()
	end

	if Selection.DisableHighlights then
		BoundingBox.StartBoundingBox(function () end)
	end

	WeldTool:BindShortcutKeys()

	Connections.BoundingBox = Selection.Changed:Connect(function()
		if Selection.DisableHighlights and not BoundingBox.GetBoundingBox() then
			BoundingBox.StartBoundingBox(function () end)
		elseif not Selection.DisableHighlights and BoundingBox.GetBoundingBox() then
			BoundingBox.ClearBoundingBox()
		end
	end)

end

function WeldTool.Unequip()
	-- Disables the tool's equipped functionality

	-- Clear unnecessary resources
	HideUI()
	ClearConnections()
	WeldTool.Maid:Destroy()
	BoundingBox.ClearBoundingBox()

end

function WeldTool:SetType(Type)
	WeldTool.CurrentType = Type

	-- Remove every property from their categories
	for Name, Option in EveryProperty do
		Option.Parent = nil
	end

	-- Remove every category
	for Name, Category in Categories do
		Category.Parent = nil
	end

	-- Clear the PropertiesToSync table
	table.clear(PropertiesToSync)

	if Type ~= "Weld" then
		-- Get every category from the type
		local TypeCategories = TypeToCategories[Type]

		-- Get the options container
		local OptionsContainer = UI.Options

		-- Get the properties
		local TypeProperties = PropertiesByType[Type]

		-- Get their categories
		local CategoryFromProperty = PropertyToCategory[Type]

		-- Go through each category
		for Index, Name in TypeCategories do
			-- Get the corresponding UI object
			local UIObject = Categories[Name]

			-- Parent it into the container
			UIObject.Parent = OptionsContainer

			-- Change its layout order
			UIObject.LayoutOrder = Index

			-- Create a table to put the necessary options
			local Options = {}

			-- Go through each property
			for PropertyName in TypeProperties do
				-- If it belongs to this category, add it
				if CategoryFromProperty[PropertyName] == Name then
					table.insert(Options, PropertyName)
				end
			end

			-- Sort them
			table.sort(Options)

			-- Add them to the category
			for Index, PropertyName in Options do
				EveryProperty[PropertyName].Parent = UIObject.Options
				EveryProperty[PropertyName].Visible = true
				EveryProperty[PropertyName].LayoutOrder = Index
			end
		end
	end

	--PropertiesToSync = PropertiesByType[Type] or {}

	WeldTool.OnTypeChanged:Fire(Type)
end

function ClearConnections()
	-- Clears out temporary connections

	for ConnectionKey, Connection in pairs(Connections) do
		Connection:Disconnect()
		Connections[ConnectionKey] = nil
	end

end

local BlacklistedProperties = {
	Archivable = true,
	LocalTransparencyModifier = true,
	Name = true
}

function ShowUI()
	UIFolder = Core.UIFolder

	local ColorPicker = require(UIFolder:WaitForChild('ColorPicker'))

	Dropdown = require(UIFolder:WaitForChild('Dropdown'))

	-- Creates and reveals the UI

	-- Reveal UI if already created
	if WeldTool.UI and WeldTool.UI.Parent ~= nil then

		-- Reveal the UI
		UI.Visible = true

		-- Make the UI refreshing again
		WeldTool.StopUpdatingUI = Support.Loop(0.1, function ()
			WeldTool:UpdateUI()
		end)

		-- Skip UI creation
		return

	end

	if WeldTool.UI then
		WeldTool.UI:Destroy()
	end

	-- Destroy the former signal
	if PropertiesUpdateSignal then
		PropertiesUpdateSignal:DisconnectAll()
	end

	-- Create a signal
	PropertiesUpdateSignal = Signal.new()

	-- Create the UI
	UI = Core.Interfaces.BTWeldToolGUI:Clone()
	UI.Parent = Core.UI
	UI.Visible = true

	WeldTool.UI = UI

	-- Hook up the buttons
	UI.Interface.WeldButton.MouseButton1Click:Connect(function()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Press"))
		CreateConstraints(WeldTool.CurrentType)
	end)
	UI.Interface.WeldButton.MouseEnter:Connect(function()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Hover"))
	end)
	UI.Interface.BreakWeldsButton.MouseButton1Click:Connect(function()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Press"))
		BreakConstraints(WeldTool.CurrentType)
	end)
	UI.Interface.BreakWeldsButton.MouseEnter:Connect(function()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Hover"))
	end)

	-- Clear every table we don't need anymore
	-- Also use table.clear because we'll likely get the same amount of arrays/dictionaries in those tables (which means better performance)
	table.clear(CommonProperties)
	table.clear(PropertiesToSync)
	table.clear(EveryProperty)
	table.clear(PropertiesByType)
	table.clear(PropertyToCategory)
	table.clear(Categories)
	table.clear(TypeToCategories)

	local ConstraintList = Support.Keys(Core.Options.AvailableConstraints)

	for _, Type in Core.Options.ConstraintsBlacklist do
		ConstraintList[Type] = nil
	end

	local OptionTemplate = Core.UIFolder.OptionsTemplates.ExampleOption
	local CategoryTemplate = Core.UIFolder.OptionsTemplates.ExampleCategory

	for _, ConstraintType in ConstraintList do
		-- Make sure the type isn't a weld before loading properties
		if ConstraintType ~= "Weld" then
			-- Use PropScan to fetch the type's properties
			local Success, PropertiesWithCategories = pcall(PropScan.GetPropertiesOfClass, ConstraintType, true)

			-- If the type doesn't exist, skip this type
			if not Success then
				warn("[FORK3X]: The type '" .. ConstraintType .. "' doesn't exist. Please make sure there isn't any typo in the name.")
				continue
			end

			-- Get every property without the categories
			local PropertiesWithoutCategories = Support.ExtractValues(PropertiesWithCategories)

			-- Make sure it's valid by checking both Attachment0 and Attachment1
			local Attachment0 = table.find(PropertiesWithoutCategories, "Attachment0")
			local Attachment1 = table.find(PropertiesWithoutCategories, "Attachment1")

			-- Abort if at least one of them is missing
			if not Attachment0 or not Attachment1 then
				warn("[FORK3X]: The type '" .. ConstraintType .. "' doesn't have the necessary Attachment0 and Attachment1 properties.")
				continue
			end

			-- Create a table to put the type's properties
			PropertiesByType[ConstraintType] = {}

			-- Create a table to find the category from which a property belongs
			PropertyToCategory[ConstraintType] = {}

			-- Make sure we get the correct handler's name
			local TypeToHandler = {
				Color3 = "Color",
				ColorSequence = "Color",
				BrickColor = "Color",
				boolean = "Boolean",
				number = "Number",
				EnumItem = "Dropdown",
				string = "AssetId"
			}

			-- Go through each property
			for Category, Properties in PropertiesWithCategories do

				local CategoryHandler = Categories[Category]

				if not CategoryHandler then
					CategoryHandler = CategoryTemplate:Clone()
					local CategoryName = CategoryHandler:FindFirstChild("Name")
					local CategoryArrow = CategoryName.ArrowButton
					local CategoryOptions = CategoryHandler.Options

					CategoryName.Text = Category
					CategoryHandler.Name = Category

					CategoryName.Activated:Connect(function()
						CategoryOptions.Visible = not CategoryOptions.Visible

						local TagMethod = CategoryOptions.Visible and script.AddTag or script.RemoveTag

						TagMethod(CategoryArrow, "STATE_Open")

						for Property, CategoryOfTheProperty in PropertyToCategory[WeldTool.CurrentType] do
							if CategoryOfTheProperty == Category then
								PropertiesToSync[Property] = CategoryOptions.Visible or nil
							end
						end

						WeldTool:UpdateUI(true)
					end)

					Categories[Category] = CategoryHandler
				end

				if not TypeToCategories[ConstraintType] then
					TypeToCategories[ConstraintType] = {}
				end

				local HasProperties = false

				for _, PropertyName in Properties do

					-- Get the type of the property and the type of its handler
					local Type = PropScan.GetPropertyType(ConstraintType, PropertyName)
					local HandlerType = Type

					if TypeToHandler[Type] then
						HandlerType = TypeToHandler[Type]
					end

					-- If the type can be modified, create an option for this property
					if TypeToTemplate[HandlerType] then
						-- If the property has already been initialised for another type, just use the same handler
						if EveryProperty[PropertyName] then
							HasProperties = true

							PropertyToCategory[ConstraintType][PropertyName] = Category

							PropertiesByType[ConstraintType][PropertyName] = EveryProperty[PropertyName]

							continue
						elseif BlacklistedProperties[PropertyName] then
							continue
						end

						-- Tell that this category can be modified
						HasProperties = true

						-- Inflate a table with the necessary data
						local PropertyData = {}

						PropertyData.Name = PropertyName
						PropertyData.Type = HandlerType
						PropertyData.Settings = { Property = PropertyName }

						if HandlerType == "Dropdown" then
							local Options = {}

							if Type == "EnumItem" then
								local EnumType = PropScan.GetDefaultValueOfType(ConstraintType, PropertyName).EnumType

								local EnumItems = EnumType:GetEnumItems()

								for _, EnumItem in EnumItems do
									table.insert(Options, EnumItem.Name)
								end

								PropertyData.Settings.DropdownConfiguration = function(Current)
									return {
										AnchorPoint = Vector2.new(1, 0.5),
										Position = UDim2.new(1, 0, 0.5, 0),
										Size = UDim2.new(0, 0, 0, 25),
										AutomaticXSize = true,
										Options = Options,
										MaxRows = 4,
										NoClipping = true,
										CurrentOption = Current and Current.Name or "*",
										OnOptionSelected = function (Option)
											SetProperty(ConstraintType, PropertyName, EnumType[Option])
										end,
									} 
								end
							end
						end

						CommonProperties[ConstraintType] = {}

						local Option = OptionTemplate:Clone()

						Option.Name = PropertyData.Settings.Property .. "Option"

						Option.Label.Text = PropertyData.Name

						TypeToTemplate[HandlerType](PropertyData, PropertyName, Option, ConstraintType)

						Option.Parent = UI

						Option.Visible = false

						EveryProperty[PropertyName] = Option

						PropertyToCategory[ConstraintType][PropertyName] = Category

						PropertiesByType[ConstraintType][PropertyName] = Option
					end
				end

				if HasProperties then
					table.insert(TypeToCategories[ConstraintType], Category)
				end
			end

			-- Sort the categories
			table.sort(TypeToCategories[ConstraintType])
		end
	end

	--	UIElements = Support.ConcatTable({ 'TypeOption', 'Interface', 'Changes' }, UIElementsList)

	local function BuildTypeDropdown()
		return Roact.createElement(Dropdown, {
			Position = UDim2.new(0, 30, 0, 0),
			Size = UDim2.new(1, -45, 0, 25),
			Options = ConstraintList,
			MaxRows = #ConstraintList,
			CurrentOption = WeldTool.CurrentType,
			OnOptionSelected = function (Option)
				WeldTool:SetType(Option)
			end,
		})
	end

	local TypeDropdownHandle = Roact.mount(BuildTypeDropdown(), UI.TypeOption, 'Dropdown')

	WeldTool.OnTypeChanged:Connect(function ()
		Roact.update(TypeDropdownHandle, BuildTypeDropdown())
	end)

	-- Hook up manual triggering
	local SignatureButton = UI:WaitForChild('Title'):WaitForChild('Signature')
	ListenForManualWindowTrigger(WeldTool.ManualText, WeldTool.Color.Color, SignatureButton)

	WeldTool.StopUpdatingUI = Support.Loop(0.1, function ()
		WeldTool:UpdateUI()
	end)
end

function SyncInputToProperty(Property, InputType, Input)
	-- Enables `Input` to change the given property
	local ColorPicker = require(UIFolder:WaitForChild('ColorPicker'))

	-- Enable inputs
	if InputType == 'Color' then
		local ColorPickerHandle = nil

		Input.MouseEnter:Connect(function()
			Core.PlaySound("Hover")
		end)

		Input.MouseButton1Click:Connect(function ()
			Core.PlaySound("Press")

			local CommonColor = GetColor(Support.IdentifyCommonProperty(GetConstraints(WeldTool.CurrentType), Property))
			local ColorPickerElement = Roact.createElement(ColorPicker, {
				InitialColor = CommonColor or Color3.fromRGB(255, 255, 255),
				SetPreviewColor = function (Color)
					SetPreviewColor(Property, Color)
				end,
				OnConfirm = function (Color)
					SetProperty(WeldTool.CurrentType, Property, Color)
					ColorPickerHandle = Roact.unmount(ColorPickerHandle)
				end,
				OnCancel = function ()
					ColorPickerHandle = Roact.unmount(ColorPickerHandle)
				end,
			})
			ColorPickerHandle = ColorPickerHandle and
				Roact.update(ColorPickerHandle, ColorPickerElement) or
				Roact.mount(ColorPickerElement, Core.UI, 'ColorPicker')
		end)
	elseif InputType == 'Vector3' then
		local XInput = Input.XInput.TextBox
		local YInput = Input.YInput.TextBox
		local ZInput = Input.ZInput.TextBox

		XInput.FocusLost:Connect(function ()
			SetProperty(WeldTool.CurrentType, Property, Vector3.new(XInput.Text, CommonProperties[WeldTool.CurrentType][Property].Y, CommonProperties[WeldTool.CurrentType][Property].Z))
		end)

		YInput.FocusLost:Connect(function ()
			SetProperty(WeldTool.CurrentType, Property, Vector3.new(CommonProperties[WeldTool.CurrentType][Property].X, YInput.Text, CommonProperties[WeldTool.CurrentType][Property].Z))
		end)

		ZInput.FocusLost:Connect(function ()
			SetProperty(WeldTool.CurrentType, Property, Vector3.new(CommonProperties[WeldTool.CurrentType][Property].X, CommonProperties[WeldTool.CurrentType][Property].Y, ZInput.Text))
		end)
	elseif InputType == 'Vector2' then
		local XInput = Input.XInput.TextBox
		local YInput = Input.YInput.TextBox

		XInput.FocusLost:Connect(function ()
			SetProperty(WeldTool.CurrentType, Property, Vector2.new(XInput.Text, CommonProperties[WeldTool.CurrentType][Property].Y))
		end)

		YInput.FocusLost:Connect(function ()
			SetProperty(WeldTool.CurrentType, Property, Vector2.new(CommonProperties[WeldTool.CurrentType][Property].X, YInput.Text))
		end)

	elseif InputType == 'Boolean' then

		Input.Activated:Connect(function ()
			Core.PlaySound("Press")

			SetProperty(WeldTool.CurrentType, Property, not CommonProperties[WeldTool.CurrentType][Property])
		end)

	elseif InputType == 'AssetId' then
		Input.FocusLost:Connect(function ()

			local Input = Input.Text

			local ID = tonumber(Input) and 'rbxassetid://' .. Input or Input

			local Changes

			if tonumber(Input) then
				-- Attempt an image extraction on the given asset
				Core.Try(Core.SyncAPI.Invoke, Core.SyncAPI, 'ExtractImageFromDecal', Input )
					:Then(function (ExtractedImage)
						ID = 'rbxassetid://' .. ExtractedImage
					end)
			end

			SetProperty(WeldTool.CurrentType, Property, ID)
		end)

		-- Enable number inputs
	else
		Input.FocusLost:Connect(function ()

			SetProperty(WeldTool.CurrentType, Property, Input.Text)
		end)
	end

end

function GetColor(Color)
	return typeof(Color) == "BrickColor" and Color.Color
		or typeof(Color) == "ColorSequence" and Color.Keypoints[2].Value
		or Color
end

local PreviewInitialState = nil

function SetPreviewColor(Property, Color)

	-- Get the Color's required type for further conversion
	local FinalColorType = PropScan.GetPropertyType(WeldTool.CurrentType, Property)

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

	-- From the color's type, create a compatible counterpart to set it as the property

	-- Create the final value's variable
	local FinalValue

	if FinalColorType == "BrickColor" then
		-- If it's a BrickColor, get the nearest value from it
		FinalValue = BrickColor.new(Color)
	elseif FinalColorType == "ColorSequence" then
		-- If it's a ColorSequence, make a ColorSequence with 2 keypoints of the same value
		FinalValue = ColorSequence.new(Color)
	else
		-- Just set the current value as the preview
		FinalValue = Color
	end

	-- Apply preview color
	for Text in pairs(PreviewInitialState) do
		Text[Property] = FinalValue
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

	WeldTool.StopUpdatingUI()

end

-- References to reduce indexing time
local GetConnectedParts = Instance.new('Part').GetJoints
local GetChildren = script.GetChildren
local QueryDescendants = script.QueryDescendants

--[[
function GetPartConstraint(Part, Type)
	-- Returns any BT-created ropes involving `Part`

	local Constraints = {}

	-- Get welds stored inside `Part`
	for Constraint in pairs(SearchConstraints(Part, Part, Type)) do
		Constraints[Constraint] = true
	end

	-- Get welds stored inside connected parts
	for _, ConnectedPart in pairs(Part:IsA("BasePart") and GetConnectedParts(Part) or GetConstraints(Part)) do
		for Constraint in pairs(SearchConstraints(ConnectedPart, Part, Type)) do
			Constraints[Constraint] = true
		end
	end
	-- Return all found welds
	return Constraints

end]]

local function CheckConstraint(Constraint, Part, Type)
	if Core.Options.ManipulateAnyConstraint == false and Constraint:HasTag("BTConstraint")
		or Core.Options.ManipulateAnyConstraint == true then

		if Type == 'Weld' and (Constraint.Part0 == Part or Constraint.Part1 == Part) then
			return true
		elseif not Constraint:IsA("Attachment") and (Constraint.Attachment0.Parent == Part or Constraint.Attachment1.Parent == Part) then
			return true
		elseif (Constraint.Attachment0 == Part or Constraint.Attachment1 == Part) then
			return true
		end
	end

	return false
end

function GetPartConstraint(Part, Type)
	-- Returns any BT-created constraint (welds, ropes, etc...) involving `Part`

	local Constraints = {}

	--local Scope = Part.ClassName == "Attachment" and Type == "Weld" and Part.Parent or Part
	local GetConnectedParts = Part:IsA("BasePart") and Instance.new('Part').GetJoints or Instance.new("Attachment").GetConstraints

	-- Get constraints that are stored directly inside our object
	for _, Constraint in QueryDescendants(Part, ">" .. Type) do
		if CheckConstraint(Constraint, Part, Type) then
			Constraints[Constraint] = true
		end
	end

	-- Get constraints that are connected to the object
	for _, Constraint in GetConnectedParts(Part) do
		if Constraint:IsA(Type) and CheckConstraint(Constraint, Part, Type) then
			Constraints[Constraint] = true
		end
	end

	-- Return all found welds
	return Constraints

end

function SearchConstraints(Haystack, Part, Type)
	-- Searches for and returns BT-created constraints in `Haystack` involving `Part`

	local Constraints = {}

	-- Search the haystack for welds involving `Part`
	for _, Item in GetChildren(Haystack) do

		-- Check if this item is a BT-created constraint involving the part
		if (if Core.Options.ManipulateAnyConstraint == false then Item:HasTag("BTConstraint") else true) 
			and Item.ClassName == Type then

			if Type == 'Weld' and (Item.Part0 == Part or Item.Part1 == Part) then
				-- Store weld if valid
				Constraints[Item] = true
			elseif not Item:IsA("Attachment") and (Item.Attachment0.Parent == Part or Item.Attachment1.Parent == Part) then
				Constraints[Item] = true
			elseif (Item.Attachment0 == Part or Item.Attachment1 == Part) then
				Constraints[Item] = true
			end
		end

	end

	-- Return the found welds
	return Constraints

end

function CreateConstraints(Type, Parts, Attachments, Focus)
	-- Creates constraints for every selected part to the focused part

	-- Determine constraint creating target
	local ConstraintTarget = if Focus ~= nil then Focus else 
		Selection.Focus and ( 
			(Selection.Focus:IsA 'BasePart' and Selection.Focus) or
			(Selection.Focus:IsA 'Model' and Selection.Focus.PrimaryPart) or
			(Selection.Focus:IsA 'Attachment' and Selection.Focus) or
			Selection.Focus:FindFirstChildWhichIsA('BasePart', true) 
		)

	-- Send the change request to the server API
	local Constraints = Core.SyncAPI:Invoke('CreateConstraints', Parts or Selection.Parts, Attachments or Selection.Attachments, ConstraintTarget, Type)

	-- Update the UI with the number of welds created
	if Constraints then
		UI.Changes.Text.Text = ('created %s ' .. Type .. '%s'):format(#Constraints, #Constraints == 1 and '' or 's')
	end

	-- Put together the history record
	local HistoryRecord = {
		Constraints = Constraints,
		Type = Type,

		Unapply = function (HistoryRecord)
			-- Reverts this change

			-- Remove the welds
			Core.SyncAPI:Invoke('RemoveConstraints', HistoryRecord.Constraints, HistoryRecord.Type)

		end,

		Apply = function (HistoryRecord)
			-- Reapplies this change

			-- Restore the welds
			Core.SyncAPI:Invoke('UndoRemovedConstraints', HistoryRecord.Constraints, HistoryRecord.Type)

		end,

	}

	-- Register the history record
	Core.History.Add(HistoryRecord)

end

function BreakConstraints(Type)

	-- Search for any selection-connecting, BT-created constraints and remove them

	local Constraints = GetConstraints(Type)

	-- Turn weld index into list
	--Constraints = Support.Keys(Constraints)

	-- Send the change request to the server API
	local ConstraintsRemoved = Core.SyncAPI:Invoke('RemoveConstraints', Constraints, Type)

	-- Update the UI with the number of welds removed
	UI.Changes.Text.Text = ('removed %s ' .. string.lower(Type) .. '%s'):format(ConstraintsRemoved, Constraints == 1 and '' or 's')

	-- Put together the history record
	local HistoryRecord = {
		Constraints = Constraints,
		Type = Type,

		Unapply = function (HistoryRecord)
			-- Reverts this change

			-- Restore the welds
			Core.SyncAPI:Invoke('UndoRemovedConstraints', HistoryRecord.Constraints, HistoryRecord.Type)

		end,

		Apply = function (HistoryRecord)
			-- Reapplies this change

			-- Remove the welds
			Core.SyncAPI:Invoke('RemoveConstraints', HistoryRecord.Constraints, HistoryRecord.Type)

		end,

	}

	-- Register the history record
	Core.History.Add(HistoryRecord)

end

function GetConstraints(Type)

	local Constraints = {}

	local function SearchInAttachment(Attachment)
		for _, Constraint in pairs(Attachment:GetConstraints()) do
			if Constraint.ClassName == Type and Constraint.Parent ~= nil then
				table.insert(Constraints, Constraint)
			end
		end

		for _, Child in pairs(Attachment:GetChildren()) do
			if Child.ClassName == Type and not table.find(Constraints, Child) then
				table.insert(Constraints, Child)
			end
		end
	end

	-- Get any textures from any selected parts
	for _, Part in pairs(Selection.Parts) do
		for _, Child in pairs(Part:GetChildren()) do
			if Child.ClassName == Type then
				table.insert(Constraints, Child)
			elseif Child.ClassName == "Attachment" then
				SearchInAttachment(Child)
			end
		end

		for _, Weld in Part:GetJoints() do
			if Weld.ClassName == Type and not table.find(Constraints, Weld) and Weld.Parent ~= nil then
				table.insert(Constraints, Weld)
			end
		end
	end

	for _, Attachment in pairs(Selection.Attachments) do
		SearchInAttachment(Attachment)
	end

	-- Return the found textures
	return Constraints

end

-- Current UI layout
local CurrentLayout

local UpdatesBeforeLayout = 3

local NoConstraintsLayout = { 'TypeOption', 'Interface', 'Changes' }
local ConstraintsLayout = { "TypeOption", "Options", "Interface", "Changes" }

-- List of UI elements
local UIElements = { 'TypeOption', "Options", 'Interface', 'Changes' }

function WeldTool:ChangeLayout(Layout, ForceChange)
	-- Sets the UI to the given layout

	-- Make sure the new layout isn't already set
	if CurrentLayout == Layout and not ForceChange and UpdatesBeforeLayout > 0 then
		return
	end

	UpdatesBeforeLayout = 3

	-- Set this as the current layout
	CurrentLayout = Layout

	local Options = UI.Options

	Options.Size = UDim2.new(1, -14, 0, Options.UIListLayout.AbsoluteContentSize.Y + 5)
	Options.CanvasSize = UDim2.new(0, 0, 0, Options.UIListLayout.AbsoluteContentSize.Y + 5)

	-- Reset the UI
	for _, ElementName in pairs(UIElements) do
		local Element = UI[ElementName]
		Element.Visible = false
	end

	-- Keep track of the total vertical extents of all items
	local Sum = 0

	-- Go through each layout element
	for ItemIndex, ItemName in ipairs(Layout) do

		local Item = UI[ItemName]

		-- Make the item visible
		Item.Visible = true

		-- Position this item underneath the past items
		Item.Position = UDim2.new(0, 0, 0, 15) + UDim2.new(
			Item.Position.X.Scale,
			Item.Position.X.Offset,
			0,
			Sum + 10
		)

		-- Update the sum of item heights
		Sum = Sum + 10 + Item.AbsoluteSize.Y

	end

	-- Resize the container to fit the new layout
	UI.Size = UDim2.new(0, 245, 0, Sum - 2)

end

function WeldTool:UpdateUI(ForceChange)
	-- Updates information on the UI

	-- Make sure the UI's on
	if not UI then
		return
	end

	UpdatesBeforeLayout -= 1

	local Interface = UI.Interface

	if WeldTool.CurrentType == "Weld"  then
		self:ChangeLayout(NoConstraintsLayout, ForceChange)
		return
	end

	local Constraints = GetConstraints(WeldTool.CurrentType)

	-- Get the textures in the selection

	-- References to UI elements
	--[[
	local ThicknessInput = UI.ThicknessOption.Input.TextBox
	local ColorIndicator = UI.ColorOption.Indicator
	local LengthInput = UI.LengthOption.Input.TextBox
	local RadiusInput = UI.RadiusOption.Input.TextBox
	local VisibleSwitch = UI.VisibleOption.Check
	local SpeedInput = UI.SpeedOption.Input.TextBox
	local MaxSpeedInput = UI.MaxSpeedOption.Input.TextBox
	local AngleInput = UI.AngleOption.Input.TextBox]]


	-----------------------
	-- Update the UI layout
	-----------------------


	-- Figure out the necessary UI layout

	-- When the selection has no textures
	if #Constraints <= 0 then
		self:ChangeLayout(NoConstraintsLayout, ForceChange)
		--		return
	else
		self:ChangeLayout(ConstraintsLayout, ForceChange)
	end

	------------------------
	-- Update UI information
	------------------------

	-- Get the common properties
	for Property in PropertiesToSync do
		CommonProperties[WeldTool.CurrentType][Property] = Support.IdentifyCommonProperty(Constraints, Property)
	end

	PropertiesUpdateSignal:Fire()

	--[[
	local Actuator = self.CurrentType == "HingeConstraint" and Support.IdentifyCommonProperty(Constraints, 'ActuatorType')
	local Radius = self.CurrentType == "HingeConstraint" and Support.IdentifyCommonProperty(Constraints, 'Radius')
	local Visible = self.CurrentType == "HingeConstraint" and Support.IdentifyCommonProperty(Constraints, 'Visible')
	local Speed = self.CurrentType == "HingeConstraint" and (self.CurrentAction == Enum.ActuatorType.Motor and Support.IdentifyCommonProperty(Constraints, 'AngularVelocity') or self.CurrentAction == Enum.ActuatorType.Servo and Support.IdentifyCommonProperty(Constraints, 'AngularSpeed'))
	local Thickness =  self.CurrentType ~= "HingeConstraint" and Support.IdentifyCommonProperty(Constraints, 'Thickness')
	local Length = self.CurrentType ~= "HingeConstraint" and Support.IdentifyCommonProperty(Constraints, 'Length')
	local MaxSpeed = self.CurrentType == "HingeConstraint" and (self.CurrentAction == Enum.ActuatorType.Motor and Support.IdentifyCommonProperty(Constraints, 'MotorMaxTorque') or self.CurrentAction == Enum.ActuatorType.Servo and Support.IdentifyCommonProperty(Constraints, 'ServoMaxTorque'))
	local TargetAngle = self.CurrentType == "HingeConstraint" and self.CurrentAction == Enum.ActuatorType.Servo and Support.IdentifyCommonProperty(Constraints, 'TargetAngle')

	if Actuator and self.CurrentAction ~= Actuator then
		self.CurrentAction = Actuator
		self.OnActionChanged:Fire(Actuator)
	end

	-- Update the common inputs
	UpdateColorIndicator(ColorIndicator, Support.IdentifyCommonProperty(Constraints, 'Color'))
	UpdateDataInputs {
		[ThicknessInput] = Thickness and Support.Round(Thickness, 3) or '*',
		[LengthInput] = Length and Support.Round(Length, 3) or '*',
		[RadiusInput] = Radius and Support.Round(Radius, 3) or '*',
		[SpeedInput] = Speed and Support.Round(Speed, 3) or '*',
	}
	UpdateToggleInput(VisibleSwitch, Support.IdentifyCommonProperty(Constraints, 'Visible'))]]

end

local NormalVectorReference = Instance.new("Part")

local NormalVectorRaycastParams = RaycastParams.new()
NormalVectorRaycastParams.IncludeInstances = {NormalVectorReference}

local VisualiserFrom = Instance.new("Attachment")
local VisualiserTo = Instance.new("Attachment")

local ConstraintVisualiser = Core.Make("Beam")({
	Color = ColorSequence.new(Color3.fromRGB(255, 126, 238)),
	Width0 = 0.05,
	Width1 = 0.05,
	Transparency = NumberSequence.new(0),
	LightInfluence = 0,
	FaceCamera = true,
	Parent = VisualiserTo,
	Attachment0 = VisualiserFrom,
	Attachment1 = VisualiserTo
})

function WeldTool:AttachWithSnapping()
	-- Starts tracking snap points nearest to the mouse

	local Target
	local TargetCFrame = CFrame.new(0, 0, 0)

	local FromTarget
	local FromCFrame = CFrame.new(0, 0, 0)

	-- Because we can only create constraints on selectable parts, filter what can be targetted by the snapping utility
	SnapTracking.TargetFilter = function(TargetPart)
		return Core.IsSelectable( {TargetPart} )
	end

	-- Start tracking the closest snapping point
	SnapTracking.StartTracking(function (NewPoint)

		-- Fire `SnappedPoint` and update `SnappedPoint` when there is a new snap point in focus
		if NewPoint then

			Target = SnapTracking.Target

			local TargetPointPosition = NewPoint.Position
			local RelativeTargetPointPosition = TargetPointPosition - Target.Position

			-- Transfer the current part's important properties to the reference part
			NormalVectorReference.CFrame = Target.CFrame
			NormalVectorReference.Size = Target.Size

			-- Find the normal vector that passes by the snapping point

			-- Get the direction of this vector
			local Direction = (Target.Position - TargetPointPosition).Unit--(Target.Position - TargetPointPosition).Unit

			-- Find the ray's origin by simply putting it further
			local Origin = TargetPointPosition - Direction

			-- Perform the raycast and get the normal vector
			local Normal = workspace:Raycast(Origin, Direction * 99999) --, NormalVectorRaycastParams

			-- We can now get the final CFrame
			TargetCFrame = CFrame.lookAlong(RelativeTargetPointPosition, Normal and -Normal.Normal or Target.CFrame.LookVector) * CFrame.fromEulerAnglesXYZ(0, math.rad(-90), 0)

			if FromTarget then
				-- Handle the hinge exception, where the normal's direction might hamper the result
				if WeldTool.CurrentType == "HingeConstraint" then
					TargetCFrame = CFrame.lookAlong(RelativeTargetPointPosition, Normal and Normal.Normal or Target.CFrame.LookVector) * CFrame.fromEulerAnglesXYZ(0, math.rad(-90), 0)
				end

				VisualiserFrom.WorldCFrame = FromTarget.CFrame * FromCFrame
				VisualiserTo.WorldCFrame = Target.CFrame * TargetCFrame
			end
		end

	end)

	SnappingConnection = self.ConfirmSnapping:Connect(function()
		if not FromTarget then
			FromTarget = Target
			FromCFrame = TargetCFrame

			VisualiserFrom.Parent = workspace.Terrain
			VisualiserTo.Parent = workspace.Terrain
		else
			SnapTracking.StopTracking();

			VisualiserFrom.Parent = nil
			VisualiserTo.Parent = nil

			SnappingConnection:Disconnect()
			SnappingConnection = nil
			
			-- Reset the target filter we changed
			SnapTracking.TargetFilter = nil
			
			local Parts = {
				{ CFrame = TargetCFrame, Part = Target },
				{ CFrame = FromCFrame, Part = FromTarget },
			}

			CreateConstraints(WeldTool.CurrentType, Parts, {}, false)
		end
	end)

end

function WeldTool:BindShortcutKeys()
	-- Enables useful shortcut keys for this tool

	-- Track user input while this tool is equipped
	self.Maid.HotkeyStart = UserInputService.InputBegan:Connect(function (InputInfo, GameProcessedEvent)
		if GameProcessedEvent then
			return
		end

		-- Make sure this input is a key press
		--if InputInfo.UserInputType ~= Enum.UserInputType.Keyboard then
		--	return;
		--end;

		-- Make sure it wasn't pressed while typing
		if UserInputService:GetFocusedTextBox() then
			return;
		end;

		-- Check if the R key was pressed down, and it's not the selection clearing hotkey
		if InputInfo.KeyCode == Enum.KeyCode.R and not Selection.Multiselecting and WeldTool.CurrentType ~= "Weld" then

			-- Start tracking snap points nearest to the mouse
			self:AttachWithSnapping()

		elseif InputInfo.UserInputType == Enum.UserInputType.MouseButton1 then

			-- Stop snapping point tracking if it was enabled
			--SnapTracking.StopTracking();

			self.ConfirmSnapping:Fire()

			--[[
			-- Nudge up if the 8 button on the keypad is pressed
		elseif InputInfo.KeyCode == Enum.KeyCode.KeypadEight then
			self:NudgeSelectionByFace(Enum.NormalId.Top)

			-- Nudge down if the 2 button on the keypad is pressed
		elseif InputInfo.KeyCode == Enum.KeyCode.KeypadTwo then
			self:NudgeSelectionByFace(Enum.NormalId.Bottom)

			-- Nudge forward if the 9 button on the keypad is pressed
		elseif InputInfo.KeyCode == Enum.KeyCode.KeypadNine then
			self:NudgeSelectionByFace(Enum.NormalId.Front)

			-- Nudge backward if the 1 button on the keypad is pressed
		elseif InputInfo.KeyCode == Enum.KeyCode.KeypadOne then
			self:NudgeSelectionByFace(Enum.NormalId.Back)

			-- Nudge left if the 4 button on the keypad is pressed
		elseif InputInfo.KeyCode == Enum.KeyCode.KeypadFour then
			self:NudgeSelectionByFace(Enum.NormalId.Left)

			-- Nudge right if the 6 button on the keypad is pressed
		elseif InputInfo.KeyCode == Enum.KeyCode.KeypadSix then
			self:NudgeSelectionByFace(Enum.NormalId.Right)

			-- Align the selection to the current target surface if T is pressed
		elseif (InputInfo.KeyCode == Enum.KeyCode.T) and (not Selection.Multiselecting) then
			self.FreeDragging:AlignSelectionToTarget()]]
		end
	end)

	-- Track ending user input while this tool is equipped
	self.Maid.HotkeyRelease = UserInputService.InputEnded:Connect(function (InputInfo, GameProcessedEvent)
		if GameProcessedEvent then
			return
		end

		-- Make sure this is input from the keyboard
		if InputInfo.UserInputType ~= Enum.UserInputType.Keyboard then
			return;
		end;

		-- Check if the R key was let go
		if InputInfo.KeyCode == Enum.KeyCode.R then

			-- Make sure it wasn't pressed while typing
			if UserInputService:GetFocusedTextBox() then
				return;
			end;

			-- Stop snapping point tracking if it was enabled
			SnapTracking.StopTracking();

			-- Prevent any further input from triggering any action related to snapping
			if SnappingConnection then
				SnappingConnection:Disconnect()
				SnappingConnection = nil
			end
			
			-- Reset the target filter we changed
			SnapTracking.TargetFilter = nil

			-- Parent the visual aid to nil
			VisualiserFrom.Parent = nil
			VisualiserTo.Parent = nil

			-- If - key was released, focus on increment input
		elseif (InputInfo.KeyCode.Name == 'Minus') or (InputInfo.KeyCode.Name == 'KeypadMinus') then
			--self.UIController:FocusIncrementInput()
		end
	end)

end

function UpdateColorIndicator(Indicator, Color)
	-- Updates the given color indicator

	-- If there is a single color, just display it
	if Color then
		local OutputColor = GetColor(Color)

		Indicator.BackgroundColor3 = OutputColor
		Indicator.Varies.Text = ''

		-- If the colors vary, display a * on a gray background
	else
		Indicator.BackgroundColor3 = Color3.new(222/255, 222/255, 222/255) 
		Indicator.Varies.Text = '*'
	end

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

function ParseAssetId(Input)
	-- Returns the intended asset ID for the given input

	-- Get the ID number from the input
	local Id = tonumber(Input)
		or tonumber(Input:lower():match('%?id=([0-9]+)'))
		or tonumber(Input:match('/([0-9]+)/'))
		or tonumber(Input:lower():match('rbxassetid://([0-9]+)'))

	-- Return the ID
	return Id
end

function EnableFocusHighlighting()
	-- Enables automatic highlighting of the focused part in the selection

	-- Only enable focus highlighting in tool mode
	if Core.Mode ~= 'Tool' then
		return
	end

	-- Reset all outline colors
	Core.Selection.RecolorOutlines(Core.Selection.Color)

	-- Recolor current focused item
	if Selection.Focus and (#Selection.Parts > 1) then
		Core.Selection.RecolorOutline(Selection.Focus, BrickColor.new('Deep orange'))
	end

	-- Recolor future focused items
	Connections.FocusHighlighting = Selection.FocusChanged:Connect(function (FocusedItem)

		-- Reset all outline colors
		Core.Selection.RecolorOutlines(Core.Selection.Color)

		-- Recolor newly focused item
		if FocusedItem and (#Selection.Parts > 1) then
			Core.Selection.RecolorOutline(FocusedItem, BrickColor.new('Deep orange'))
		end

	end)

end


function SetProperty(Type, Property, Value)
	-- Make sure the given value is valid
	if Value == nil then
		return
	end
	-- Start a history record
	TrackChange()

	-- Go through each texture
	for _, Constraint in pairs(GetConstraints(Type)) do
		--[[
		local BeforeProperty

		if Property == "Speed" then
			BeforeProperty = (WeldTool.CurrentAction == Enum.ActuatorType.Motor and Constraint.AngularVelocity) or Constraint.AngularSpeed
		elseif Property == "MaxSpeed" then
			BeforeProperty = (WeldTool.CurrentAction == Enum.ActuatorType.Motor and Constraint.MotorMaxTorque) or Constraint.ServoMaxTorque
		else]]
		local BeforeProperty = Constraint[Property]
		--	end

		-- Store the state of the texture before modification
		table.insert(HistoryRecord.Before, { Constraint = Constraint, Part = Constraint.Parent, Type = Type, [Property] = BeforeProperty })

		-- Create the change request for this texture
		table.insert(HistoryRecord.After, { Constraint = Constraint, Part = Constraint.Parent, Type = Type, [Property] = Value })
	end

	print(HistoryRecord)

	-- Register the changes
	RegisterChange()

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
			Core.SyncAPI:Invoke('SyncConstraints', Record.Before)

		end,

		Apply = function (Record)
			-- Applies this change

			-- Select the changed parts
			Selection.Replace(Record.Selection)

			-- Send the change request
			Core.SyncAPI:Invoke('SyncConstraints', Record.After)

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
	Core.SyncAPI:Invoke('SyncConstraints', HistoryRecord.After)

	-- Register the record and clear the staging
	Core.History.Add(HistoryRecord)
	HistoryRecord = nil

end

-- Return the tool
return WeldTool