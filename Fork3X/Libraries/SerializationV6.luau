local Serialization = {};

-- Import services
local Tool = script.Parent.Parent
local Support = require(Tool.Libraries.SupportLibrary);
local GeometryService = game:GetService("GeometryService")
local AssetService = game:GetService("AssetService")

local Services = Support.ImportServices();
local PropScan = require(Tool.Libraries.PropScan)

local HttpService = Services.HttpService

local OptionsModule = Tool:FindFirstChild("Options") or Tool.Tool.Value:FindFirstChild("Options")

local ToolOptions = OptionsModule and require(OptionsModule)

if ToolOptions == nil then error("Failed to load Building Tools by F3X: options module is missing!") end

local Options = require(Tool.Libraries.LTSOptions)(ToolOptions)

local Parameters = {
	CollisionFidelity = Options.CollisionFidelity,
	RenderFidelity = Options.PartRenderFidelity,
	FluidFidelity = Enum.FluidFidelity.UseCollisionGeometry,
	SplitApart = false
}

local Types = {
	Part = 0,
	WedgePart = 1,
	CornerWedgePart = 2,
	VehicleSeat = 3,
	Seat = 4,
	TrussPart = 5,
	SpecialMesh = 6,
	Texture = 7,
	Decal = 8,
	PointLight = 9,
	SpotLight = 10,
	SurfaceLight = 11,
	Smoke = 12,
	Fire = 13,
	Sparkles = 14,
	Model = 15,
	ParticleEmitter = 16,
	SurfaceGui = 17,
	Folder = 18,
	Attachment = 19,
	SelectionBox = 20,
	Highlight = 21,
	UnionOperation = 22,
	IntersectOperation = 23,
	TextLabel = 24,
	RopeConstraint = 25,
	RodConstraint = 26,
	HingeConstraint = 27,
	PartOperation = 28,
	MeshPart = 29,
	Constraint = 30,
};

-- Put each properties we want for each class/type (IsA)
-- (you can also change the ReflectionService setting if you don't need specificity)

local TypeToProperties = {
	MeshPart = {
		"SERIALIZEFUNC_MeshId",
		"SERIALIZEFUNC_UnionData",
		"TextureID"
	};
	
	PartOperation = {
		"CFrame",
		"SERIALIZEFUNC_UnionData",
		"UsePartColor"
	};
	
	BasePart = {
		"Name",
		"Size",
		"CFrame",
		"Color",
		"Material",
		"MaterialVariant",
		"CanCollide",
		"Reflectance",
		"Transparency",
		"Massless",
		"CastShadow",
		"TopSurface",
		"BottomSurface",
		"FrontSurface",
		"BackSurface",
		"LeftSurface",
		"RightSurface",
		"SERIALIZEFUNC_PhysicalProperties",
		"SERIALIZEFUNC_SubType",
	};
	
	Part = {
		"Shape"
	};
	
	VehicleSeat = {
		"MaxSpeed",
		"Torque",
		"TurnSpeed"
	};
	
	Truss = {
		"Style"
	};
	
	SpecialMesh = {
		"MeshType",
		"MeshId",
		"TextureId",
		"Offset",
		"Scale",
		"VertexColor"
	};
	
	Decal = {
		"Texture",
		"Transparency",
		"Face",
		"Color3"
	};
	
	Texture = {
		"StudsPerTileU",
		"StudsPerTileV",
		"OffsetStudsU",
		"OffsetStudsV"
	};
	
	Light = {
		"Brightness",
		"Color",
		"Shadows",
		"Range",
	};
	
	SpotLight = {
		"Angle",
		"Face"
	};
	
	SurfaceLight = {
		"Angle",
		"Face"
	};
	
	Smoke = {
		"Color",
		"Size",
		"RiseVelocity",
		"Opacity"
	};
	
	Fire = {
		"Color",
		"SecondaryColor",
		"Heat",
		"Size"
	};
	
	Sparkles = {
		"SparkleColor"
	};
	
	ParticleEmitter = {
		"Brightness",
		"Color",
		"LightEmission",
		"LightInfluence",
		"Orientation",
		"Size",
		"Squash",
		"Texture",
		"Transparency",
		"ZOffset",
		"Lifetime",
		"Rate",
		"Rotation",
		"RotSpeed",
		"Speed",
		"SpreadAngle",
		"Shape",
		"ShapeInOut",
		"ShapePartial",
		"ShapeStyle",
		"FlipbookLayout",
		"FlipbookBlendFrames",
		"FlipbookFramerate",
		"FlipbookMode",
		"FlipbookSizeX",
		"FlipbookSizeY",
		"FlipbookStartRandom",
		"Acceleration",
		"Drag",
		"LockedToPart",
		"TimeScale",
	},
	
	SurfaceGui = {
		"Face"
	};
	
	TextLabel = {
		"Text",
		"TextTransparency",
		"TextColor3",
		"RichText",
		"Font"
	};
	
	Attachment = {
		"Name",
		"CFrame"
	};
	
	SelectionBox = {
		"Color3",
		"LineThickness",
		"SurfaceColor3",
		"SurfaceTransparency",
		"Transparency",
		"SERIALIZEFUNC_GetAdornee",
	};
	
	Highlight = {
		"FillColor",
		"FillTransparency",
		"OutlineColor",
		"OutlineTransparency",
		"DepthMode"
	};
	
	--[[
	Constraint = {
		--"SERIALIZEFUNC_GetAttachments",
	},
	
	
	RopeConstraint = {
		"Thickness",
		"Length"
	},
	
	RodConstraint = {
		"Thickness",
		"Length"
	},
	
	HingeConstraint = {
		"Radius",
		"Speed",
		"MaxSpeed",
		"TargetAngle",
		"ActuatorType"
	},]]
	
	Model = {
		"Name",
	};
	
	Folder = {
		"Name"
	};
}

local DefaultProperties = {
	BasePart = {			
		Anchored = true,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
		Size = vector.create(4, 1, 2),
	},
	
	SurfaceGui = {
		Name = "F3XSurfaceGui",
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 60,
	},
	
	TextLabel = {
		BackgroundTransparency = 1;
		Size = UDim2.new(1, 0, 1, 0);
		TextScaled = true;
		RichText = false;
		Font = Enum.Font.Arimo;
		Text = "Use the text tool to edit me.";
		TextTransparency = 0;
		TextColor3 = Color3.fromRGB(255, 255, 255);
	}
}

-- Add every available constraint to the system
for Name, Properties in Options.AvailableConstraints do
	DefaultProperties[Name] = Properties
	
	local ConstraintProperties = PropScan.GetPropertiesOfClass(Name, false)

	local AllowedTypes = {
		Color3 = true,
		ColorSequence = true,
		BrickColor = true,
		boolean = true,
		NumberSequence = true,
		NumberRange = true,
		number = true,
		string = true,
		EnumItem = true,
		Vector2 = true,
		Vector3 = true
	}

	local BlacklistedProperties = {
		Archivable = true,
		LocalTransparencyModifier = true,
		Name = true
	}
	
	local FinalProperties = {}
	
	for _, PropertyName in ConstraintProperties do
		local PropertyType = PropScan.GetPropertyType(Name, PropertyName)

		if not BlacklistedProperties[PropertyName] and AllowedTypes[PropertyType] then
			table.insert(FinalProperties, PropertyName)
		end
	end
	
	table.insert(FinalProperties, "SERIALIZEFUNC_GetAttachments")
	
	TypeToProperties[Name] = FinalProperties
	
end

local function ParseAssetId(Input)
	-- Returns the intended asset ID for the given input

	-- Get the ID number from the input
	local Id = tonumber(Input)
		or tonumber(Input:lower():match('%?id=([0-9]+)'))
		or tonumber(Input:match('/([0-9]+)/'))
		or tonumber(Input:lower():match('rbxassetid://([0-9]+)'))

	-- Return the ID
	return Id
end

local function CanSubTypeBeConverted(SubType)
	return Options.CustomPartTypes and type(Options.CustomPartTypes[SubType]) == "table"
		and Options.CustomPartTypes[SubType].CanBeConverted or false
end

local function GetTypeNumber(Object)
	if Object.ClassName == "Weld" then
		return
	end
	
	return Types[Object.ClassName] or Options.AvailableConstraints[Object.ClassName] and Object.ClassName
end

local MeshParts = {}

local SerializationFunctions = {
	UnionData = function(Part, Data)
		local DataUnions = Data.Unions

		local UnionData = Part:GetAttribute("BTUnionData")

		if not UnionData then return nil end

		if table.find(DataUnions, UnionData) then
			return table.find(DataUnions, UnionData)
		else
			table.insert(DataUnions, UnionData)
			return #DataUnions
		end
	end,
	
	SubType = function(Part, Data)
		local SubType = Part:GetAttribute("BTSubType")

		if CanSubTypeBeConverted(SubType) then
			
			return SubType
		end
		
		return nil
	end,
	
	MeshId = function(Part, Data)
		if Options.ManipulateAnyMeshPart == false and not Part:HasTag("BT_CanModifyMeshPart") then
			return nil
		end
		
		local MeshId = ParseAssetId(Part.MeshId)

		return MeshId and tostring( MeshId ) or Part.MeshId ~= "" and Part.MeshId or nil
	end,
	

	PhysicalProperties = function(Part, Data)
		-- Make sure the physical properties aren't the same
		if PhysicalProperties.new(Part.Material) == Part.CurrentPhysicalProperties then
			return nil
		end
		
		-- Use string.split to get the unpacked versions of the physical properties
		local DefaultPhysicalProperties = string.split( tostring( PhysicalProperties.new(Part.Material) ), "," )
		local PartPhysicalProperties = string.split( tostring( Part.CurrentPhysicalProperties ), "," )

		-- Prepare the final physical properties to serialise
		local FinalPhysicalProperties = {}

		for Index, Value in PartPhysicalProperties do
			-- Convert the value to a number
			Value = tonumber(Value)

			if Value ~= tonumber(DefaultPhysicalProperties[Index]) then
				-- If they aren't the same, save a rounded version of the value (it's to improve readability and the save/load size estimation, not the storage size itself)
				FinalPhysicalProperties[Index] = Support.Round(Value, 3)
			else
				-- If they're the same, save 0 as a value to prevent index issues (which is impossible with physical properties, and so isn't a problem to ignore)
				FinalPhysicalProperties[Index] = 0
			end
		end

		-- Return the encoded version of the physical properties
		return HttpService:JSONEncode(FinalPhysicalProperties)
	end,
	
	GetAttachments = function(Constraint, Data, Keys)
		local Attachment0, Attachment1 = Keys[Constraint.Attachment0], Keys[Constraint.Attachment1]

		if Attachment0 and Attachment1 then
			return {Attachment0, Attachment1}
		else
			return nil
		end
	end,
	
	GetAdornee = function(SelectionBox, Data, Keys)
		local Adornee = Keys[SelectionBox.Adornee]
		
		return Adornee
	end,
}

-- For each function:
-- First table argument is the function.
-- Second table argument is whether the function must be called during or after inflation

local function TransferPropertiesToObjectFromObject(Object, SampleObject)
	local PartCustomProperties = PropScan.GetCustomPropertiesOfObject(SampleObject)
	
	local PropertiesBlacklist = {
		BrickColor = true,
	}
	
	for Name, Value in PartCustomProperties do
		if PropertiesBlacklist[Name] then
			continue
		end
		
		Object[Name] = Value
	end
end

local ClassToProperties = {}

-- PS: If you want to get every single properties, use game:GetService("ReflectionService"):GetPropertiesOfClass()
local function GetSelectedPropertiesForInstance(Object: Instance)
	if ClassToProperties[Object.ClassName] then
		return ClassToProperties[Object.ClassName]
	else
		local PropertiesToReturn = {}

		for Type, Properties in TypeToProperties do
			if Object:IsA(Type) then
				Support.ConcatTable(PropertiesToReturn, Properties)
			end
		end

		ClassToProperties[Object.ClassName] = PropertiesToReturn

		return PropertiesToReturn
	end
end 

local BuildingFunctions = {
	UnionData = {function(Part, SerializedProperty, Data)
		local JSONUnionData = Data.Unions[SerializedProperty]
		
		--print(Data.Unions, SerializedProperty)

		local UnionData = JSONUnionData--HttpService:JSONDecode(JSONUnionData)
		
		local Union
		
		if UnionData.Version == 2 then
			local CSGTree = Serialization.CSGTreeV2
			local Method = CSGTree.CreateUnionFromTree
			
			Union = Method(UnionData, Part.CFrame, Parameters)[1]
		else
			local CSGTree = Serialization.CSGTreeV1
			local Method = CSGTree.CreateFromTree
			
			Union = Method(UnionData, Parameters, Part.CFrame)
		end
		
		if not Union then
			warn("[FORK3X]: The union failed to generate. Here's its data: ", UnionData)
			return Part
		end
		
		TransferPropertiesToObjectFromObject(Union, Part)
		
		Part:Destroy()
		
		Union:SetAttribute("BTUnionData", HttpService:JSONEncode(UnionData))

		return Union
	end, false},
	
	MeshId = {function(Part, SerializedProperty, Data)
		local MeshPart = MeshParts[SerializedProperty] and MeshParts[SerializedProperty]:Clone()
		
		if not MeshPart then
			local IsID = SerializedProperty ~= nil and SerializedProperty ~= ""
			
			if IsID then
				--print(type(SerializedProperty))
				MeshParts[SerializedProperty] = AssetService:CreateMeshPartAsync(Content.fromUri(tonumber(SerializedProperty)
					and "rbxassetid://" .. SerializedProperty or SerializedProperty), {
						CollisionFidelity = Options.CollisionFidelity,
						RenderFidelity = Options.PartRenderFidelity,
					})
				
				MeshPart = MeshParts[SerializedProperty]:Clone()
			else
				MeshPart = Instance.new("MeshPart")
			end
		end
		
		TransferPropertiesToObjectFromObject(MeshPart, Part)
		
		MeshPart:AddTag("BT_CanModifyMeshPart")

		return MeshPart
	end, false},

	SubType = {function(Part, SerializedProperty, Data, Objects, Player)

		if not CanSubTypeBeConverted(SerializedProperty) then
			return Part
		end
		
		-- Get the sub-type's reference part
		local Reference = Options.CustomPartTypes[SerializedProperty].Create(Player)
		
		-- Only transfer the serialised properties to the reference
		local SerializedProperties = GetSelectedPropertiesForInstance(Part)
		
		for _, Property in SerializedProperties do
			if string.sub(Property, 1, 14) ~= "SERIALIZEFUNC_" then
				Reference[Property] = Part[Property]
			end
		end
		
		-- Also ensure the part is anchored
		Reference.Anchored = true
		
		-- Remove any child that can be serialised to prevent conflicts
		for _, Object in Reference:GetChildren() do
			
			if GetTypeNumber(Object) then
				Object:Destroy()
			end
		end

		-- Return the reference, and let the serialiser add back the removed children
		return Reference
	end, true},

	
	PhysicalProperties = {function(Part, SerializedProperty, Data)
		-- Use string.split to get the unpacked versions of the physical properties
		local DefaultPhysicalProperties = string.split( tostring( PhysicalProperties.new(Part.Material) ), "," )
		local PartPhysicalProperties = HttpService:JSONDecode(SerializedProperty)
		
		for Index, Value in PartPhysicalProperties do
			if Value == 0 then
				PartPhysicalProperties[Index] = tonumber( DefaultPhysicalProperties[Index] )
			end
		end
		
		Part.CustomPhysicalProperties = PhysicalProperties.new( unpack(PartPhysicalProperties) )
		
		return Part
	end, true},
	
	GetAttachments = {function(Constraint, SerializedProperty, Data, Objects)
		local Attachment0, Attachment1 = Objects[SerializedProperty[1]], Objects[SerializedProperty[2]]
		
		--print(Attachment0, Attachment1)
		
		if Attachment0 and Attachment1 then
			Constraint.Attachment0 = Attachment0
			Constraint.Attachment1 = Attachment1
		end
		
		return Constraint
	end, true},
	
	GetAdornee = {function(SelectionBox, SerializedProperty, Data, Objects)
		local Adornee = Objects[SerializedProperty]
		
		if Adornee then
			SelectionBox.Adornee = Adornee
		end

		return SelectionBox
	end, true},
}

local SerialEncodingFunctions = {
	["string"] = function(Value: string, Property, Class)
		if PropScan.DoesPropertyExpectID(Class, Property) then
			local ID = ParseAssetId(Value)
			
			return ID and tostring( ID ) or Value ~= "" and Value or nil
		end
		
		return Value
	end,
	
	["CFrame"] = function(Value: CFrame)
		
		local RX, RY, RZ = Value:ToEulerAnglesXYZ()
		
		local Table = {Value.Position.X, Value.Position.Y, Value.Position.Z, math.deg(RX), math.deg(RY), math.deg(RZ)}
		
		for Index, Number in Table do
			Table[Index] = Support.Round(Number, 3)
			
			if Table[Index] == -0 then
				Table[Index] = 0
			end
		end
	
		return HttpService:JSONEncode(Table)
	end,

	["Vector3"] = function(Value: vector)
		local Table = {Value.X, Value.Y, Value.Z}
		
		for Index, Number in Table do
			Table[Index] = Support.Round(Number, 3)
			
			if Table[Index] == -0 then
				Table[Index] = 0
			end
		end
		
		return HttpService:JSONEncode(Table)
	end,
	
	["number"] = function(Value: number)
		return Support.Round(Value, 3)
	end,

	["Color3"] = function(Value: Color3)
		return Value:ToHex()
	end,
	
	["BrickColor"] = function(Value: BrickColor)
		return Value.Number
	end,

	["boolean"] = function(Value: boolean)
		return Value == true and 1 or 0
	end,

	["EnumItem"] = function(Value: EnumItem)
		return Value.Value
	end,

	["ColorSequence"] = function(Value: ColorSequence)
		local Keypoints = Value.Keypoints

		local FirstKeypoint = Keypoints[1].Value
		local LastKeypoint = Keypoints[#Keypoints].Value

		if LastKeypoint == FirstKeypoint then
			LastKeypoint = nil
		end

		return HttpService:JSONEncode({FirstKeypoint:ToHex(), LastKeypoint and LastKeypoint:ToHex() or nil})
	end,

	["NumberSequence"] = function(Value: NumberSequence)
		local Keypoints = Value.Keypoints
		
		local Sequence = {}
		
		for Index, Value in Keypoints do
			
			Sequence[Index] = Support.Round(Value.Value, 3)
		end

		--[[
		local FirstKeypoint = Keypoints[1].Value
		local LastKeypoint = Keypoints[#Keypoints].Value

		if LastKeypoint == FirstKeypoint then
			LastKeypoint = nil
		end]]

		return HttpService:JSONEncode(Sequence) --{FirstKeypoint, LastKeypoint}
	end,

	["NumberRange"] = function(Value: NumberRange)
		local Min = Value.Min
		local Max = Value.Max
		
		if Max == Min then
			Max = nil
		end
		
		--print(HttpService:JSONEncode({Min, Max}))

		return HttpService:JSONEncode({Min, Max})
	end,
	
	["Vector2"] = function(Value: NumberRange)
		local Table = {Value.X, Value.Y}

		for Index, Number in Table do
			Table[Index] = Support.Round(Number, 3)
		end

		return HttpService:JSONEncode(Table)
	end,
}

local SerialDecodingFunctions = {
	["string"] = function(Value: string, Property, Class)
		if PropScan.DoesPropertyExpectID(Class, Property) and tonumber(Value) then
			return "rbxassetid://" .. Value
		end

		return Value
	end,
	
	["CFrame"] = function(Value)
		
		if type(Value) == "string" then
			local DecodedValue = HttpService:JSONDecode(Value)
			
			local PosX, PosY, PosZ, RotX, RotY, RotZ = unpack( DecodedValue )
			
			Value = CFrame.new(PosX, PosY, PosZ) * CFrame.fromEulerAnglesXYZ(math.rad(RotX), math.rad(RotY), math.rad(RotZ))
		end
		
--		print(CFrame.fromEulerAnglesXYZ(math.rad(RotX), math.rad(RotY), math.rad(RotZ)))
		
		return Value
	end,

	["Vector3"] = function(Value)
		
		if type(Value) == "string" then
			Value = vector.create( unpack( HttpService:JSONDecode(Value) ) )
		end
		
		return Value
	end,

	["Color3"] = function(Value)
		
		if type(Value) == "string" then
			Value = Color3.fromHex(Value)
		end
		
		return Value
	end,

	["boolean"] = function(Value)
		
		if type(Value) ~= "boolean" then
			Value = tonumber(Value) == 1 and true or false
		end
		
		return Value
	end,
	
	["BrickColor"] = function(Value)
		
		if type(Value) == "number" then
			Value = BrickColor.new(Value)
		end
		
		return Value
	end,

	["EnumItem"] = function(Value, EnumType)
		
		if not tonumber(Value) then
			warn("[FORK3X]: This message appears because an EnumItem didn't get saved correctly. Please report this issue to the creator of Fork3X.")
		end
		
		if type(Value) == "number" then
			Value = EnumType:FromValue( tonumber(Value) or 0 )
		end
		
		return Value
	end,

	["ColorSequence"] = function(Value)
		
		if type(Value) == "string" then
			local DecodedValue = HttpService:JSONDecode(Value)
			
			local FirstColor, SecondColor = unpack(DecodedValue)

			if FirstColor then
				FirstColor = Color3.fromHex(FirstColor)
			end

			if SecondColor then
				SecondColor = Color3.fromHex(SecondColor)
			end
			
			Value = ColorSequence.new(FirstColor, SecondColor)
		end
		
		return Value
	end,

	["NumberSequence"] = function(Value)
		
		if type(Value) == "string" then
			local Sequence = HttpService:JSONDecode(Value)

			if #Sequence == 1 then
				return NumberSequence.new(Sequence[1])
			end

			local FinalNumberSequence = {}

			local Factor = 1 / (#Sequence - 1)

			for Index, Value in Sequence do
				local Position = Factor * (Index - 1)

				FinalNumberSequence[Index] = NumberSequenceKeypoint.new( Position, Value )
			end

			Value = NumberSequence.new(FinalNumberSequence)
		end

		return Value
	end,

	["NumberRange"] = function(Value)
		
		if type(Value) == "string" then
			Value = NumberRange.new( unpack( HttpService:JSONDecode(Value) ) ) 
		end
		
		return Value
	end,
	
	["Vector2"] = function(Value)
		
		if type(Value) == "string" then
			Value = Vector2.new( unpack( HttpService:JSONDecode(Value) ) )
		end
		
		return Value
	end,
}

local DefaultInstancesMemory = {}

--[[
local function PropScan.GetDefaultValueOfType(ClassName, Property)
	local DefaultInstance = DefaultInstancesMemory[ClassName]

	if not DefaultInstance then
		DefaultInstancesMemory[ClassName] = Instance.new(ClassName)
		
		for Type, Properties in DefaultProperties do
			if DefaultInstancesMemory[ClassName]:IsA(Type) then
				for Name, Value in Properties do
					DefaultInstancesMemory[ClassName][Name] = Value
				end
			end
		end
		
		DefaultInstance = DefaultInstancesMemory[ClassName]
	end
	
	return DefaultInstance[Property]
end]]

local function EncodeValue(Value, ...)
	local Type = typeof(Value)
	
	return SerialEncodingFunctions[Type] and SerialEncodingFunctions[Type](Value, ...) or Value
end

local function DecodeValue(Value, Type, ...)
	return if SerialDecodingFunctions[Type] then SerialDecodingFunctions[Type](Value, ...) else Value
end

local function GetPropertyWithBlank(Object: Instance, Property)
	local ClassName = Object.ClassName

	local DefaultProperty = PropScan.GetDefaultValueOfType(ClassName, Property)

	if DefaultProperty == Object[Property] then
		return nil
	else
		return Object[Property]
	end
end

function Serialization.SerializeModel(Items, RelativePoint)
	-- Returns a serialized version of the given model
	
	-- Filter out non-serializable items in `Items`
	local SerializableItems = {};
	
	for Index, Item in Items do
		table.insert(SerializableItems, GetTypeNumber(Item) and Item or nil);
	end;
	
	-- Group items of similar type to improve compression
	table.sort(SerializableItems, function(A, B)
		-- If one type is a constraint, then automatically pick the one which isn't a constraint
		
		-- Figuring out constraints are saved with their name, use tonumber to check
		if not tonumber( GetTypeNumber(A) ) and tonumber( GetTypeNumber(B) )
			or tonumber( GetTypeNumber(A) ) and not tonumber( GetTypeNumber(B) )
		then
			return if tonumber( GetTypeNumber(A) ) then false else true
		end
		
		return GetTypeNumber(A) < GetTypeNumber(B)
	end)
	
	Items = SerializableItems;
	
	-- Get a snapshot of the content
	local Keys = Support.FlipTable(Items);
	
	local Data = {};
	Data.Version = 6;
	Data.Items = {};
	Data.Unions = {}
	
	local ParticleCount = 0
	
	-- Serialize each item in the model
	for _, Item in Items do
		
		-- Add the necessary tables only now as it would be useless bloat if there was no item
		if not Data.Items.Type then
			Data.Items.Type = {}
		end
		
		if not Data.Items.Parent then
			Data.Items.Parent = {}
		end
		
		-- Create a list of each properties we want to serialize
		local Index = #Data.Items.Type + 1
		local NecessaryProperties = GetSelectedPropertiesForInstance(Item)
		
		-- Add the essential properties inside Data.Items
		Data.Items.Type[Index] = GetTypeNumber(Item)
		Data.Items.Parent[Index] = Keys[Item.Parent]
		
		-- Save each property with blanks when set to the default value
		for _, Property in NecessaryProperties do
			local Value
			
			if string.sub(Property, 1, 14) == "SERIALIZEFUNC_" and SerializationFunctions[string.gsub(Property, "SERIALIZEFUNC_", "", 1)] then
				Value = SerializationFunctions[string.gsub(Property, "SERIALIZEFUNC_", "", 1)](Item, Data, Keys)
			elseif Item:IsA("BasePart") and Property == "CFrame" then
				Value = RelativePoint and RelativePoint:ToObjectSpace(Item[Property]) or Item[Property]
			else
				Value = GetPropertyWithBlank(Item, Property)
			end
			
			if Value ~= nil then
				local PropertyTable = Data.Items[Property]
				
				if not PropertyTable then
					Data.Items[Property] = {}
					PropertyTable = Data.Items[Property]
				end
				
				PropertyTable[Index] = EncodeValue(Value, Property, Item.ClassName)
			end
		end
	end;
	
	--[[
	for Property, Table in Data.Items do
		Data.Items[Property] = Support.TableToDictionary(Table)
	end]]
	
	-- Decode each union tables to allow datastores compression
	for Number, UnionData in Data.Unions do
		Data.Unions[Number] = HttpService:JSONDecode(UnionData)
	end
	
	local Treated = 0
	
	-- Attempt to reduce the save's size by compressing a bit
	for _, Table in Data.Items do
		Treated += 1
		
		local LastRestart
		local LastIndex
		local LastValue
		local PreviousValue
		local ConsecutiveRepetitions = 0
		
		for Index, Value in Table do
			LastValue = Value
			
			if Value == PreviousValue and Index == LastIndex + 1 then
				ConsecutiveRepetitions += 1
			else
				if ConsecutiveRepetitions >= 2 then
					local RepeatedValue = Table[LastRestart]
					
					for i = LastRestart, LastRestart + ConsecutiveRepetitions do
						Table[i] = nil
					end
					
					local ConcatenationSeparator = type(PreviousValue) == "number" and "!" or "_"
					
					Table[LastRestart] = "_COMP_" .. LastRestart + ConsecutiveRepetitions .. ConcatenationSeparator .. RepeatedValue
				end
				
				LastRestart = Index
				PreviousValue = Value
				ConsecutiveRepetitions = 0
			end
			
			LastIndex = Index
		end
		
		if ConsecutiveRepetitions >= 2 then
			local RepeatedValue = Table[LastRestart]

			for i = LastRestart, LastRestart + ConsecutiveRepetitions do
				Table[i] = nil
			end

			local ConcatenationSeparator = type(PreviousValue) == "number" and "!" or "_"

			Table[LastRestart] = "_COMP_" .. LastRestart + ConsecutiveRepetitions .. ConcatenationSeparator .. RepeatedValue
		end
	end
	
	local NewData = Support.ToStringIndexes(Data)
	
	-- Return the serialized data
	return NewData
end;

function Serialization.InflateBuildData(BuildData, IgnoreParents, RelativePoint, Player)
	-- Returns an inflated version of the given build data
	
	local Build = {};
	local Instances = {};

	if not RelativePoint then
	--	RelativePoint = CFrame.new(table.unpack(Data.Relative))
	end
	
--	local Offset = Data.Offset and CFrame.new(table.unpack(Data.Offset)) or CFrame.new(0, 0, 0)
	
--	RelativePoint *= Offset
	
--	print(RelativePoint)
	
	if not BuildData.Items.Type then
		return Build
	end

	--[[
	-- Convert back each entries' dictionaries into normal tables.
	for Property, Dictionary in Data.Items do
		Data.Items[Property] = Support.DictionaryToTable(Dictionary)
	end]]
	
	local SerializationFunctionsOnHold = {}
	
	local Data = Support.ToNumeralIndexes(BuildData)
	
	local Treated = 0
	
	-- Revert compression
	local function RevertCompression(RealTable, Table, PropertyName, Decode)
		for Index, Value in Table do

			if type(Value) == "string" and Value:sub(1, 6) == '_COMP_' then

				local IsANumber = false

				local FirstSeparation = Value:find("_", 7)

				if not FirstSeparation then
					IsANumber = true
					FirstSeparation = Value:find("!", 7)
				end

				local RepeatTo = Value:sub( 7, FirstSeparation - 1 )
				local FinalValue = Value:sub( FirstSeparation + 1, #Value )
				
				if Decode == true then
					local Type = Support.FindTableOccurrence( Types, Data.Items.Type[Index] ) or Options.AvailableConstraints[ Data.Items.Type[Index] ] and Data.Items.Type[Index]
					
					if not Type then
						continue
					end
					
					if PropertyName == "CFrame" then
						FinalValue = DecodeValue(FinalValue, "CFrame")
						
						if RelativePoint then
							FinalValue = RelativePoint * FinalValue
						end
					else
						local DefaultProperty = PropScan.GetDefaultValueOfType(Type, PropertyName)
						local Type = typeof(DefaultProperty)

						--			print(DecodeValue(PropertyTable[Index], Type, Type == "EnumItem" and DefaultProperty.EnumType))
						local DecodedValue = DecodeValue(FinalValue, Type, Type == "EnumItem" and DefaultProperty.EnumType or PropertyName, Type)
						
						if DefaultProperty ~= DecodedValue then
							FinalValue = DecodedValue
						end
					end
				end

				for i = Index, RepeatTo do
					RealTable[i] = IsANumber and tonumber(FinalValue) or FinalValue
				end
			end
		end
	end
	
	local NewItems = Support.CloneTable(Data.Items, true)
	
	RevertCompression(Data.Items.Type, NewItems.Type, nil, false)
	
	for Name, Table in NewItems do
		if Name ~= "Type" then
			RevertCompression(
				Data.Items[Name], 
				NewItems[Name], 
				Name,
				if string.sub(Name, 1, 14) == "SERIALIZEFUNC_" then false else true
			)
		end
	end
	
	-- Remove the itineration table off the memory
	NewItems = nil
	
	local FlippedTypes = Support.FlipTable(Types)

	-- Create each instance
	for Index, Type in Data.Items.Type do
		
	--	print(Types, Type, table.find(Types, Type), Types[Type])
		
		local InstanceType = FlippedTypes[Type] or TypeToProperties[Type] and Type
		
		if not InstanceType then
			continue
		end
		
		local Object = Instance.new(InstanceType)
		
		for Type, Properties in DefaultProperties do
			if Object:IsA(Type) then
				for Name, Value in Properties do
					Object[Name] = Value
				end
			end
		end
		
		-- Go through each property that need to be synced for this object
		local SerializedProperties = GetSelectedPropertiesForInstance(Object)
		
		for _, Property in SerializedProperties do
			
			local PropertyTable = Data.Items[Property]
			
			if PropertyTable and PropertyTable[Index] ~= nil then
				
				local SerializationFunctionText = Property:match("SERIALIZEFUNC_(.+)")--string.gsub(Property, "SERIALIZEFUNC_", "", 1)
				
				if SerializationFunctionText and BuildingFunctions[SerializationFunctionText] then
					local DoAfterwards = BuildingFunctions[SerializationFunctionText][2] or false				
					
					if not DoAfterwards then
						Object = BuildingFunctions[SerializationFunctionText][1](Object, PropertyTable[Index], Data, Player)
					else
						if not SerializationFunctionsOnHold[SerializationFunctionText] then
							SerializationFunctionsOnHold[SerializationFunctionText] = {}
						end
						
						SerializationFunctionsOnHold[SerializationFunctionText][Index] = PropertyTable[Index]
					end
				elseif Object:IsA("BasePart") and Property == "CFrame" then
					Object.CFrame = DecodeValue(PropertyTable[Index], "CFrame")
					if RelativePoint then
						Object.CFrame = RelativePoint * Object.CFrame
					end
				else
					local DefaultProperty = PropScan.GetDefaultValueOfType(InstanceType, Property)
					local Type = typeof(DefaultProperty)

					--			print(DecodeValue(PropertyTable[Index], Type, Type == "EnumItem" and DefaultProperty.EnumType))
					local DecodedValue = DecodeValue(PropertyTable[Index], Type, Type == "EnumItem" and DefaultProperty.EnumType or Property, InstanceType)
					
					if DefaultProperty ~= DecodedValue then
						Object[Property] = DecodedValue
					end
				end
			end
		end
		
		Instances[Index] = Object
		
		local LagBreak = 100--game:GetService("RunService"):IsClient() and 25 or 100
		
		if Index % LagBreak == 0 then
			
			task.wait(0.01)
		end
	end;
	
	-- Execute the serialization functions on hold
	for Name, Objects in SerializationFunctionsOnHold do
		for ObjectID, Value in Objects do
			Instances[ObjectID] = BuildingFunctions[Name][1](Instances[ObjectID], Value, Data, Instances, Player)
		end
	end


	-- Set object values on each instance
	if IgnoreParents then
		return Instances;
	else
		local ParentsTable = Support.Values(Data.Items.Parent, true)
		
		for Index in Data.Items.Type do

			-- Get the item's instance
			local Item = Instances[Index];
			
			local Parent = ParentsTable[Index]
			
			-- Set each item's parent and name
			if Item then
				if Parent == nil then
					table.insert(Build, Item);
				else
					Item.Parent = Instances[Parent];
				end;
			end;
			
			-- Set model primary parts
	--		if Item and Datum[1] == 15 then
	--			Item.PrimaryPart = (Datum[4] ~= 0) and Instances[Datum[4]] or nil;
	--		end;

		end;

		-- Return the model
		return Build;
	end
end;

-- Return the API
return function(CSGTreeV1, CSGTreeV2)
	if CSGTreeV1 then
		Serialization.CSGTreeV1 = CSGTreeV1
	end
	
	if CSGTreeV2 then
		Serialization.CSGTreeV2 = CSGTreeV2
	end
	
	return Serialization
end;
