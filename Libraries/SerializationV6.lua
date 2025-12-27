local Serialization = {};

-- Import services
local Tool = script.Parent.Parent
local Support = require(Tool.Libraries.SupportLibrary);
local GeometryService = game:GetService("GeometryService")
local Services = Support.ImportServices();

local Parameters = {
	CollisionFidelity = Enum.CollisionFidelity.Hull,
	RenderFidelity = Enum.RenderFidelity.Performance,
	FluidFidelity = Enum.FluidFidelity.UseCollisionGeometry,
	SplitApart = false}

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
};

-- Put each properties we want for each class/type (IsA)
-- (you can also change the ReflectionService setting if you don't need specificity)

local TypeToProperties = {
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
		"RightSurface"
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
	};
	
	Light = {
		"Brightness",
		"Color",
		"Shadows",
	};
	
	PointLight = {
		"Range"
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
		"Color",
		"Orientation",
		"Size",
		"Texture",
		"Transparency",
		"Lifetime",
		"Rate",
		"Rotation",
		"RotSpeed",
		"Speed",
		"SpreadAngle",
		"Acceleration",
		"LockedToPart"
	};
	
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
	
	Constraint = {
		"SERIALIZEFUNC_GetAttachments",
		"Visible",
		"Color",
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
	},
	
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

local SerializationFunctions = {
	GetAttachments = function(Constraint, Data, Keys)
		local Attachment0, Attachment1 = Keys[Constraint.Attachment0], Keys[Constraint.Attachment1]
		
		if Attachment0 and Attachment1 then
			return {Attachment0, Attachment1}
		else
			return nil
		end
	end,
	
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
	
	GetAdornee = function(SelectionBox, Data, Keys)
		local Adornee = Keys[SelectionBox.Adornee]
		
		return Adornee
	end,
}

-- For each function:
-- First table argument is the function.
-- Second table argument is whether the function must be called during or after inflation

local BuildingFunctions = {
	UnionData = {function(Part, SerializedProperty, Data)
		local JSONUnionData = Data.Unions[SerializedProperty]
		
		print(Data.Unions, SerializedProperty)

		local UnionData = JSONUnionData--Services.HttpService:JSONDecode(JSONUnionData)

		local Union = Serialization.CSGTree.CreateFromTree(UnionData, Parameters, Part.CFrame)

		Part:Destroy()
		
		Union:SetAttribute("BTUnionData", Services.HttpService:JSONEncode(UnionData))

		return Union
	end, false},
	
	GetAttachments = {function(Constraint, SerializedProperty, Data, Objects)
		local Attachment0, Attachment1 = Objects[SerializedProperty[1]], Objects[SerializedProperty[2]]
		
		print(Attachment0, Attachment1)
		
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
	["CFrame"] = function(Value: CFrame)
		
		local RX, RY, RZ = Value:ToEulerAnglesXYZ()
		
		local Table = {Value.Position.X, Value.Position.Y, Value.Position.Z, math.deg(RX), math.deg(RY), math.deg(RZ)}
		
		for Index, Number in Table do
			Table[Index] = Support.Round(Number, 3)
		end
	
		return Services.HttpService:JSONEncode(Table)
	end,

	["Vector3"] = function(Value: vector)
		local Table = {Value.X, Value.Y, Value.Z}
		
		for Index, Number in Table do
			Table[Index] = Support.Round(Number, 3)
		end
		
		return Services.HttpService:JSONEncode(Table)
	end,
	
	["number"] = function(Value: number)
		return Support.Round(Value, 3)
	end,

	["Color3"] = function(Value: Color3)
		return Value:ToHex()
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

		return Services.HttpService:JSONEncode({FirstKeypoint:ToHex(), LastKeypoint and LastKeypoint:ToHex() or nil})
	end,

	["NumberSequence"] = function(Value: NumberSequence)
		local Keypoints = Value.Keypoints

		local FirstKeypoint = Keypoints[1].Value
		local LastKeypoint = Keypoints[#Keypoints].Value

		if LastKeypoint == FirstKeypoint then
			LastKeypoint = nil
		end

		return Services.HttpService:JSONEncode({FirstKeypoint, LastKeypoint})
	end,

	["NumberRange"] = function(Value: NumberRange)
		local Min = Value.Min
		local Max = Value.Max

		if Max == Min then
			Max = nil
		end

		return Services.HttpService:JSONEncode({Min, Max})
	end,
}

local SerialDecodingFunctions = {
	["CFrame"] = function(Value)
		
		local PosX, PosY, PosZ, RotX, RotY, RotZ = unpack(Services.HttpService:JSONDecode(Value))
		
		print(RotX, RotY, RotZ, "|", CFrame.new(PosX, PosY, PosZ) * CFrame.fromEulerAnglesXYZ(math.rad(RotX), math.rad(RotY), math.rad(RotZ)))
		
		print(CFrame.fromEulerAnglesXYZ(math.rad(RotX), math.rad(RotY), math.rad(RotZ)))
		
		return CFrame.new(PosX, PosY, PosZ) * CFrame.fromEulerAnglesXYZ(math.rad(RotX), math.rad(RotY), math.rad(RotZ))
	end,

	["Vector3"] = function(Value)
		return vector.create(unpack(Services.HttpService:JSONDecode(Value)))
	end,

	["Color3"] = function(Value)
		return Color3.fromHex(Value)
	end,

	["boolean"] = function(Value)
		return Value == 1 and true or false
	end,

	["EnumItem"] = function(Value, EnumType)
		return EnumType:FromValue(Value)
	end,

	["ColorSequence"] = function(Value)
		return ColorSequence.new(unpack(Services.HttpService:JSONDecode(Value)))
	end,

	["NumberSequence"] = function(Value)
		return NumberSequence.new(unpack(Services.HttpService:JSONDecode(Value)))
	end,

	["NumberRange"] = function(Value)
		return NumberRange.new(unpack(Services.HttpService:JSONDecode(Value)))
	end,
}

local DefaultInstancesMemory = {}

local function GetDefaultProperty(ClassName, Property)
	local DefaultInstance = DefaultInstancesMemory[ClassName]

	if not DefaultInstance then
		DefaultInstancesMemory[ClassName] = Instance.new(ClassName)
		
		if DefaultProperties[ClassName] then
			for DefaultProperty, Value in DefaultProperties[ClassName] do
				DefaultInstancesMemory[ClassName][DefaultProperty] = Value
			end
		end
		
		DefaultInstance = DefaultInstancesMemory[ClassName]
	end
	
	return DefaultInstance[Property]
end

local function EncodeValue(Value)
	local Type = typeof(Value)
	
	return SerialEncodingFunctions[Type] and SerialEncodingFunctions[Type](Value) or Value
end

local function DecodeValue(Value, Type, EnumType)
	return SerialDecodingFunctions[Type] and SerialDecodingFunctions[Type](Value, EnumType) or Value
end

local function GetPropertyWithBlank(Object: Instance, Property)
	local ClassName = Object.ClassName

	local DefaultProperty = GetDefaultProperty(ClassName, Property)

	if DefaultProperty == Object[Property] then
		return nil
	else
		return Object[Property]
	end
end 

-- PS: If you want to get every single properties, use game:GetService("ReflectionService"):GetPropertiesOfClass()
local function GetSelectedPropertiesForInstance(Object: Instance)
	local PropertiesToReturn = {}

	for Type, Properties in TypeToProperties do
		if Object:IsA(Type) then
			Support.ConcatTable(PropertiesToReturn, Properties)
		end
	end

	return PropertiesToReturn
end 

function Serialization.SerializeModel(Items, RelativePoint)
	-- Returns a serialized version of the given model

	-- IsNegative is a number:

	-- 1 is when it simply marks the part as negative
	-- 2 means that the union will be negative

	-- Filter out non-serializable items in `Items`
	local SerializableItems = {};
	for Index, Item in ipairs(Items) do
		table.insert(SerializableItems, Types[Item.ClassName] and Item or nil);
	end;
	Items = SerializableItems;

	-- Get a snapshot of the content
	local Keys = Support.FlipTable(Items);
	
	local Data = {};
	Data.Version = 6;
	Data.Items = {};
	Data.Unions = {}
--	Data.Relative = RelativePoint and {RelativePoint:GetComponents()} or {CFrame.new(0, 0, 0):GetComponents()}
--	Data.Relative = RelativePoint and {RelativePoint:GetComponents()} or {CFrame.new(0, 0, 0):GetComponents()}
	--Data.Offset = {{CFrame.new(0, 0, 0):GetComponents()}}
	
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
		Data.Items.Type[Index] = Types[Item.ClassName]
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
			
			if Value then
				local PropertyTable = Data.Items[Property]
				
				if not PropertyTable then
					Data.Items[Property] = {}
					PropertyTable = Data.Items[Property]
				end
				
				PropertyTable[Index] = EncodeValue(Value)
			end
		end
	end;
	
	--[[
	for Property, Table in Data.Items do
		Data.Items[Property] = Support.TableToDictionary(Table)
	end]]
	
	-- Decode each union tables to allow datastores compression
	for Number, UnionData in Data.Unions do
		Data.Unions[Number] = Services.HttpService:JSONDecode(UnionData)
	end
	
	print(Data)
	
	-- Return the serialized data
	return Data
end;

--[[
function Serialization.OffsetBuild(Data, Offset)
	local OldReferential = Data.Relative and CFrame.new(table.unpack(Data.Referential))
	
	if not OldReferential then
		return
	end
	
	local Difference = Referential * OldReferential:Inverse()
	
	for Index, Datum in ipairs(Data.Items) do
		if Datum[1] == Types.Part
			or Datum[1] == Types.WedgePart
			or Datum[1] == Types.CornerWedgePart
			or Datum[1] == Types.VehicleSeat
			or Datum[1] == Types.Seat
			or Datum[1] == Types.TrussPart
			or Datum[1] == Types.UnionOperation
		then
			local ObjectCFrame = CFrame.new(unpack(Support.Slice(Datum, 7, 18)));
			local NewCFrame = {(ObjectCFrame * Difference):GetComponents()}
			
			for i = 7, 18 do
				Datum[i] = NewCFrame[i - 6]
			end
		end
	end
	
	Data.Relative = Referential
end]]

function Serialization.OffsetBuild(Data, Offset)
	for Index, Datum in ipairs(Data.Items) do
		if Datum[1] == Types.Part
			or Datum[1] == Types.WedgePart
			or Datum[1] == Types.CornerWedgePart
			or Datum[1] == Types.VehicleSeat
			or Datum[1] == Types.Seat
			or Datum[1] == Types.TrussPart
			or Datum[1] == Types.UnionOperation
		then
			local ObjectCFrame = CFrame.new(unpack(Support.Slice(Datum, 7, 18)));
			local NewCFrame = {(ObjectCFrame * Offset):GetComponents()}

			for i = 7, 18 do
				Datum[i] = NewCFrame[i - 6]
			end
		end
	end
end

function Serialization.InflateBuildData(BuildData, IgnoreParents, RelativePoint)
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
	
	-- Create each instance
	for Index, Type in Data.Items.Type do
	--	print(Types, Type, table.find(Types, Type), Types[Type])
		
		local InstanceType = Support.FindTableOccurrence(Types, Type)
		
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
			
			if PropertyTable and PropertyTable[Index] then
				
				local SerializationFunctionText = string.sub(Property, 1, 14)--string.gsub(Property, "SERIALIZEFUNC_", "", 1)
				
				if SerializationFunctionText == "SERIALIZEFUNC_" and BuildingFunctions[string.gsub(Property, "SERIALIZEFUNC_", "", 1)] then
					local NewText = string.gsub(Property, "SERIALIZEFUNC_", "", 1)
					
					local DoAfterwards = BuildingFunctions[NewText][2] or false				
					
					if not DoAfterwards then
						Object = BuildingFunctions[NewText][1](Object, PropertyTable[Index], Data)
					else
						if not SerializationFunctionsOnHold[NewText] then
							SerializationFunctionsOnHold[NewText] = {}
						end
						
						SerializationFunctionsOnHold[NewText][Object] = PropertyTable[Index]
					end
				elseif Object:IsA("BasePart") and Property == "CFrame" then
					Object.CFrame = DecodeValue(PropertyTable[Index], "CFrame")
					if RelativePoint then
						Object.CFrame = RelativePoint * Object.CFrame
					end
				else
					local DefaultProperty = GetDefaultProperty(InstanceType, Property)
					local Type = typeof(DefaultProperty)
					
		--			print(DecodeValue(PropertyTable[Index], Type, Type == "EnumItem" and DefaultProperty.EnumType))
					
					Object[Property] = DecodeValue(PropertyTable[Index], Type, Type == "EnumItem" and DefaultProperty.EnumType)
				end
			end
		end
		
		Instances[Index] = Object
		
		if Index % 100 == 0 then
			task.wait(0.01)
		end
	end;
	
	-- Execute the serialization functions on hold
	for Name, Objects in SerializationFunctionsOnHold do
		for Object, Value in Objects do
			BuildingFunctions[Name][1](Object, Value, Data, Instances)
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
return function(CSGTree)
	if CSGTree then
		Serialization.CSGTree = CSGTree
	end
	return Serialization
end;
