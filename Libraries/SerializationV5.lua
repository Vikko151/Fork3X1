Serialization = {};

-- Import services
local Tool = script.Parent.Parent
local Support = require(Tool.Libraries.SupportLibrary);
local GeometryService = game:GetService("GeometryService")
Support.ImportServices();

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
	PartOperation = 22
};

local DefaultNames = {
	Part = 'Part',
	WedgePart = 'Wedge',
	CornerWedgePart = 'CornerWedge',
	VehicleSeat = 'VehicleSeat',
	Seat = 'Seat',
	TrussPart = 'Truss',
	SpecialMesh = 'Mesh',
	Texture = 'Texture',
	Decal = 'Decal',
	PointLight = 'PointLight',
	SpotLight = 'SpotLight',
	SurfaceLight = 'SurfaceLight',
	Smoke = 'Smoke',
	Fire = 'Fire',
	Sparkles = 'Sparkles',
	Model = 'Model',
	ParticleEmitter = 'ParticleEmitter',
	SurfaceGui = 'SurfaceGui',
	Folder = 'Folder',
	Attachment = 'Attachment',
	SelectionBox = 'SelectionBox',
	Highlight = 'Highlight',
	PartOperation = 'PartOperation',
};

function Serialization.SerializeModel(Items, IsUnion)
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
	
	local UnionItems
	
	if IsUnion and #Items ~= 0 then
		local GUID = game:GetService("HttpService"):GenerateGUID(false)
		
		Data.Items[GUID] = {[1] = {}}
		
		UnionItems = Data.Items[GUID][1]
	end
	
	local ParticleCount = 0
	local Offset = 0
	
	-- Basically just a union priority system we'll use for Datum[35], which definies the order
	--	local UnionLayers = {}
	local UnionParts = {}

	-- Serialize each item in the model
	for Index, Item in pairs(Items) do

		if Item:IsA 'BasePart' and not Item:IsA 'PartOperation' then
			local Datum = {};
			Datum[1] = Types[Item.ClassName];
			Datum[2] = Keys[Item.Parent] or 0;
			Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name;
			Datum[4] = Item.Size.X;
			Datum[5] = Item.Size.Y;
			Datum[6] = Item.Size.Z;
			Support.ConcatTable(Datum, { Item.CFrame:components() });
			Datum[19] = Item.Color.r;
			Datum[20] = Item.Color.g;
			Datum[21] = Item.Color.b;
			Datum[22] = Item.Material.Value;
			Datum[23] = Item.MaterialVariant.Value or "";
			Datum[24] = Item.Anchored and 1 or 1;
			Datum[25] = Item.CanCollide and 1 or 0;
			Datum[26] = Item.Reflectance;
			Datum[27] = Item.Transparency;
			Datum[28] = Item.TopSurface.Value;
			Datum[29] = Item.BottomSurface.Value;
			Datum[30] = Item.FrontSurface.Value;
			Datum[31] = Item.BackSurface.Value;
			Datum[32] = Item.LeftSurface.Value;
			Datum[33] = Item.RightSurface.Value;
			
			if UnionItems then
				UnionItems[Index - Offset] = Datum;
			else
				Data.Items[Index] = Datum;
			end
			
		end;

		if Item.ClassName == 'Part' then
			local Datum = UnionItems and UnionItems[Index - Offset] or Data.Items[Index];
			Datum[34] = Item.Shape.Value;
		end;
		
		
		if Item:IsA("PartOperation") and Item:FindFirstChild("UnionData") then
			Offset += 1
			
			local UnionData = require(Item.UnionData)

			local PositivePartsData, NegativePartsData, PositionData, Intersection = UnionData:Get()

			local GUID = game:GetService("HttpService"):GenerateGUID(false)
			
			local MyData = {}
			
			MyData[1] = PositivePartsData
			MyData[2] = NegativePartsData
			MyData[3] = Intersection or false
			MyData[4] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name
			MyData[5] = Item.Size.X
			MyData[6] = Item.Size.Y
			MyData[7] = Item.Size.Z
			Support.ConcatTable(MyData, { PositionData:components() })
			MyData[20] = Item.Color.r;
			MyData[21] = Item.Color.g;
			MyData[22] = Item.Color.b;
			MyData[23] = Item.Material.Value;
			MyData[24] = Item.MaterialVariant.Value or "";
			MyData[25] = Item.Anchored and 1 or 1;
			MyData[26] = Item.CanCollide and 1 or 0;
			MyData[27] = Item.Reflectance;
			MyData[28] = Item.Transparency;
			MyData[29] = Item.UsePartColor
			
			if UnionItems then
				Data.Items[GUID] = MyData;
			else
				Data.Unions[GUID] = MyData;
			end
		end
		
	if IsUnion ~= true then
		if Item.ClassName == 'VehicleSeat' then
			local Datum = Data.Items[Index];
			Datum[33] = Item.MaxSpeed;
			Datum[34] = Item.Torque;
			Datum[35] = Item.TurnSpeed;
		end;

		if Item.ClassName == 'TrussPart' then
			local Datum = Data.Items[Index];
			Datum[33] = Item.Style.Value;
		end;
		

		if Item.ClassName == 'SpecialMesh' then
			local Datum = {};
			Datum[1] = Types[Item.ClassName];
			Datum[2] = Keys[Item.Parent] or 0;
			Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name;
			Datum[4] = Item.MeshType.Value;
			Datum[5] = Item.MeshId;
			Datum[6] = Item.TextureId;
			Datum[7] = Item.Offset.X;
			Datum[8] = Item.Offset.Y;
			Datum[9] = Item.Offset.Z;
			Datum[10] = Item.Scale.X;
			Datum[11] = Item.Scale.Y;
			Datum[12] = Item.Scale.Z;
			Datum[13] = Item.VertexColor.X;
			Datum[14] = Item.VertexColor.Y;
			Datum[15] = Item.VertexColor.Z;
			Data.Items[Index] = Datum;
		end;

		if Item:IsA 'Decal' then
			local Datum = {};
			Datum[1] = Types[Item.ClassName];
			Datum[2] = Keys[Item.Parent] or 0;
			Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name;
			Datum[4] = Item.Texture;
			Datum[5] = Item.Transparency;
			Datum[6] = Item.Face.Value;
			Datum[7] = Item.Color3.R
			Datum[8] = Item.Color3.G
			Datum[9] = Item.Color3.B
			Data.Items[Index] = Datum;
		end;

		if Item.ClassName == 'Texture' then
			local Datum = Data.Items[Index];
			Datum[10] = Item.StudsPerTileU;
			Datum[11] = Item.StudsPerTileV;
		end;

		if Item:IsA 'Light' then
			local Datum = {};
			Datum[1] = Types[Item.ClassName];
			Datum[2] = Keys[Item.Parent] or 0;
			Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name;
			Datum[4] = Item.Brightness;
			Datum[5] = Item.Color.r;
			Datum[6] = Item.Color.g;
			Datum[7] = Item.Color.b;
			Datum[8] = Item.Enabled and 1 or 0;
			Datum[9] = Item.Shadows and 1 or 0;
			Data.Items[Index] = Datum;
		end;

		if Item.ClassName == 'PointLight' then
			local Datum = Data.Items[Index];
			Datum[10] = Item.Range;
		end;

		if Item.ClassName == 'SpotLight' then
			local Datum = Data.Items[Index];
			Datum[10] = Item.Range;
			Datum[11] = Item.Angle;
			Datum[12] = Item.Face.Value;
		end;

		if Item.ClassName == 'SurfaceLight' then
			local Datum = Data.Items[Index];
			Datum[10] = Item.Range;
			Datum[11] = Item.Angle;
			Datum[12] = Item.Face.Value;
		end;

		if Item.ClassName == 'Smoke' then
			local Datum = {};
			Datum[1] = Types[Item.ClassName];
			Datum[2] = Keys[Item.Parent] or 0;
			Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name;
			Datum[4] = Item.Enabled and 1 or 0;
			Datum[5] = Item.Color.r;
			Datum[6] = Item.Color.g;
			Datum[7] = Item.Color.b;
			Datum[8] = Item.Size;
			Datum[9] = Item.RiseVelocity;
			Datum[10] = Item.Opacity;
			Data.Items[Index] = Datum;
		end;

		if Item.ClassName == 'Fire' then
			local Datum = {};
			Datum[1] = Types[Item.ClassName];
			Datum[2] = Keys[Item.Parent] or 0;
			Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name;
			Datum[4] = Item.Enabled and 1 or 0;
			Datum[5] = Item.Color.r;
			Datum[6] = Item.Color.g;
			Datum[7] = Item.Color.b;
			Datum[8] = Item.SecondaryColor.r;
			Datum[9] = Item.SecondaryColor.g;
			Datum[10] = Item.SecondaryColor.b;
			Datum[11] = Item.Heat;
			Datum[12] = Item.Size;
			Data.Items[Index] = Datum;
		end;

		if Item.ClassName == 'Sparkles' then
			local Datum = {};
			Datum[1] = Types[Item.ClassName];
			Datum[2] = Keys[Item.Parent] or 0;
			Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name;
			Datum[4] = Item.Enabled and 1 or 0;
			Datum[5] = Item.SparkleColor.r;
			Datum[6] = Item.SparkleColor.g;
			Datum[7] = Item.SparkleColor.b;
			Data.Items[Index] = Datum;
		end;
		
		if Item.ClassName == 'ParticleEmitter' then
			local Datum = {};
			ParticleCount += Item.Rate
			Datum[1] = Types[Item.ClassName];
			Datum[2] = Keys[Item.Parent] or 0;
			Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name;
			Datum[4] = Item.Enabled and 1 or 0;
			Datum[5] = Item.Color.Keypoints[2].Value.R;
			Datum[6] = Item.Color.Keypoints[2].Value.G;
			Datum[7] = Item.Color.Keypoints[2].Value.B;
			Datum[8] = Item.Orientation.Value;
			Datum[9] = Item.Size.Keypoints[2].Value;
			Datum[10] = Item.Texture;
			Datum[11] = Item.Transparency.Keypoints[2].Value;
			Datum[12] = Item.Lifetime.Max;
			Datum[13] = ParticleCount <= 400 and Item.Rate or 0;
			Datum[14] = Item.Rotation.Max;
			Datum[15] = Item.RotSpeed.Max;
			Datum[16] = Item.Speed.Max;
			Datum[17] = Item.SpreadAngle.X;
			Datum[18] = Item.Acceleration.Y * -1;
			Datum[19] = Item.LockedToPart;
			Data.Items[Index] = Datum;
		end;
		
		if Item.ClassName == 'SurfaceGui' and Item:FindFirstChildOfClass("TextLabel") then
			local Datum = {};
			local Text = Item:FindFirstChildOfClass("TextLabel")
			Datum[1] = Types[Item.ClassName];
			Datum[2] = Keys[Item.Parent] or 0;
			Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name;
			Datum[4] = Item.Enabled and 1 or 0;
			Datum[5] = Item.Face.Value;
			Datum[6] = Text.Text;
			Datum[7] = Text.TextTransparency;
			Datum[8] = Text.TextColor3.R;
			Datum[9] = Text.TextColor3.G;
			Datum[10] = Text.TextColor3.B;
			Datum[11] = Text.RichText;
			Datum[12] = Text.Font.Value;
			Data.Items[Index] = Datum;
		end;
		
		if Item.ClassName == 'Attachment' then
			local Datum = {};
			Datum[1] = Types[Item.ClassName];
			Datum[2] = Keys[Item.Parent] or 0;
			Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name;
			Datum[4] = Item.WorldCFrame.Position.X
			Datum[5] = Item.WorldCFrame.Position.Y
			Datum[6] = Item.WorldCFrame.Position.Z
			Datum[7], Datum[8], Datum[9] = Item.WorldCFrame:ToEulerAnglesXYZ()
			Data.Items[Index] = Datum;
		end;
		
		if Item.ClassName == 'SelectionBox' then
			local Datum = {};
			Datum[1] = Types[Item.ClassName];
			Datum[2] = Keys[Item.Parent] or 0;
			Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name;
			Datum[4] = Item.Color3.R
			Datum[5] = Item.Color3.G
			Datum[6] = Item.Color3.B
			Datum[7] = Item.LineThickness
			Datum[8] = Item.SurfaceColor3.R
			Datum[9] = Item.SurfaceColor3.G
			Datum[10] = Item.SurfaceColor3.B
			Datum[11] = Item.SurfaceTransparency
			Datum[12] = Item.Transparency
			Data.Items[Index] = Datum;
		end;
		
		if Item.ClassName == 'Highlight' then
			local Datum = {};
			Datum[1] = Types[Item.ClassName];
			Datum[2] = Keys[Item.Parent] or 0;
			Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name;
			Datum[4] = Item.FillColor.R
			Datum[5] = Item.FillColor.G
			Datum[6] = Item.FillColor.B
			Datum[7] = Item.FillTransparency
			Datum[8] = Item.OutlineColor.R
			Datum[9] = Item.OutlineColor.G
			Datum[10] = Item.OutlineColor.B
			Datum[11] = Item.OutlineTransparency
			Datum[12] = Item.DepthMode.Value
			Data.Items[Index] = Datum;
		end;

		if Item.ClassName == 'Model' then
			local Datum = {};
			Datum[1] = Types[Item.ClassName];
			Datum[2] = Keys[Item.Parent] or 0;
			Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name;
			Datum[4] = Item.PrimaryPart and Keys[Item.PrimaryPart] or 0;
			Data.Items[Index] = Datum;
		end;

		if Item.ClassName == 'Folder' then
			local Datum = {}
			Datum[1] = Types[Item.ClassName]
			Datum[2] = Keys[Item.Parent] or 0
			Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name
			Data.Items[Index] = Datum
		end
	end
		
		-- Spread the workload over time to avoid locking up the CPU
		if Index % 100 == 0 then
			task.wait(0.01);
		end;

	end;
	
	local IndexBeginning = #Data.Items
	
	for i, Item in UnionParts do
		Data.Items[IndexBeginning + i] = Item
	end
	
	print(Data)

	-- Return the serialized data
	return Data

end;

function Serialization.InflateBuildData(Data)
	-- Returns an inflated version of the given build data

	local Build = {};
	local Instances = {};
	
	local Player = game:GetService("Players"):GetPlayerFromCharacter(Tool.Parent)
	
	local PartOperationsPositive = {}
	local PartOperationsNegative = {}
	
	-- Create each instance
	for Index, Datum in pairs(Data.Items) do

		-- Inflate BaseParts
		if Datum[1] == Types.Part
			or Datum[1] == Types.WedgePart
			or Datum[1] == Types.CornerWedgePart
			or Datum[1] == Types.VehicleSeat
			or Datum[1] == Types.Seat
			or Datum[1] == Types.TrussPart
			or Datum[1] == Types.PartOperation
		then
			local Item = Instance.new(Support.FindTableOccurrence(Types, Datum[1]));
			Item.Size = Vector3.new(unpack(Support.Slice(Datum, 4, 6)));
			Item.CFrame = CFrame.new(unpack(Support.Slice(Datum, 7, 18)));
			Item.Color = Color3.new(Datum[19], Datum[20], Datum[21]);
			Item.Material = Datum[22];
			Item.Anchored = Datum[23] == 1;
			Item.CanCollide = Datum[24] == 1;
			Item.Reflectance = Datum[25];
			Item.Transparency = Datum[26];
			Item.TopSurface = Datum[27];
			Item.BottomSurface = Datum[28];
			Item.FrontSurface = Datum[29];
			Item.BackSurface = Datum[30];
			Item.LeftSurface = Datum[31];
			Item.RightSurface = Datum[32];
			
			if Datum[34] then
				Item.Shape = Datum[33];
				
				local TableToUse = Datum[35] == true and PartOperationsNegative or PartOperationsPositive
				
				if not TableToUse[Datum[34]] then
					TableToUse[Datum[34]] = {}
				end
				table.insert(TableToUse[Datum[34]], Item)
			else
				-- Register the part
				Instances[Index] = Item;
			end
			
		end;

		-- Inflate specific Part properties
		if Datum[1] == Types.Part and Instances[Index] then
			local Item = Instances[Index];
			Item.Shape = Datum[33];
		end;

		-- Inflate specific VehicleSeat properties
		if Datum[1] == Types.VehicleSeat then
			local Item = Instances[Index];
			Item.MaxSpeed = Datum[33];
			Item.Torque = Datum[34];
			Item.TurnSpeed = Datum[35];
		end;

		-- Inflate specific TrussPart properties
		if Datum[1] == Types.TrussPart then
			local Item = Instances[Index];
			Item.Style = Datum[33];
		end;

		-- Inflate SpecialMesh instances
		if Datum[1] == Types.SpecialMesh then
			local Item = Instance.new('SpecialMesh');
			Item.MeshType = Datum[4];
			Item.MeshId = Datum[5];
			Item.TextureId = Datum[6];
			Item.Offset = Vector3.new(unpack(Support.Slice(Datum, 7, 9)));
			Item.Scale = Vector3.new(unpack(Support.Slice(Datum, 10, 12)));
			Item.VertexColor = Vector3.new(unpack(Support.Slice(Datum, 13, 15)));

			-- Register the mesh
			Instances[Index] = Item;
		end;

		-- Inflate Decal instances
		if Datum[1] == Types.Decal or Datum[1] == Types.Texture then
			local Item = Instance.new(Support.FindTableOccurrence(Types, Datum[1]));
			Item.Texture = Datum[4];
			Item.Transparency = Datum[5];
			Item.Face = Datum[6];
			Item.Color3 = Color3.new(unpack(Support.Slice(Datum, 7, 9)))

			-- Register the Decal
			Instances[Index] = Item;
		end;

		-- Inflate specific Texture properties
		if Datum[1] == Types.Texture then
			local Item = Instances[Index];
			Item.StudsPerTileU = Datum[10];
			Item.StudsPerTileV = Datum[11];
		end;

		-- Inflate Light instances
		if Datum[1] == Types.PointLight
			or Datum[1] == Types.SpotLight
			or Datum[1] == Types.SurfaceLight
		then
			local Item = Instance.new(Support.FindTableOccurrence(Types, Datum[1]));
			Item.Brightness = Datum[4];
			Item.Color = Color3.new(unpack(Support.Slice(Datum, 5, 7)));
			Item.Enabled = Datum[8] == 1;
			Item.Shadows = Datum[9] == 1;

			-- Register the light
			Instances[Index] = Item;
		end;

		-- Inflate specific PointLight properties
		if Datum[1] == Types.PointLight then
			local Item = Instances[Index];
			Item.Range = Datum[10];
		end;

		-- Inflate specific SpotLight properties
		if Datum[1] == Types.SpotLight then
			local Item = Instances[Index];
			Item.Range = Datum[10];
			Item.Angle = Datum[11];
			Item.Face = Datum[12];
		end;

		-- Inflate specific SurfaceLight properties
		if Datum[1] == Types.SurfaceLight then
			local Item = Instances[Index];
			Item.Range = Datum[10];
			Item.Angle = Datum[11];
			Item.Face = Datum[12];
		end;

		-- Inflate Smoke instances
		if Datum[1] == Types.Smoke then
			local Item = Instance.new('Smoke');
			Item.Enabled = Datum[4] == 1;
			Item.Color = Color3.new(unpack(Support.Slice(Datum, 5, 7)));
			Item.Size = Datum[8];
			Item.RiseVelocity = Datum[9];
			Item.Opacity = Datum[10];

			-- Register the smoke
			Instances[Index] = Item;
		end;

		-- Inflate Fire instances
		if Datum[1] == Types.Fire then
			local Item = Instance.new('Fire');
			Item.Enabled = Datum[4] == 1;
			Item.Color = Color3.new(unpack(Support.Slice(Datum, 5, 7)));
			Item.SecondaryColor = Color3.new(unpack(Support.Slice(Datum, 8, 10)));
			Item.Heat = Datum[11];
			Item.Size = Datum[12];

			-- Register the fire
			Instances[Index] = Item;
		end;

		-- Inflate Sparkles instances
		if Datum[1] == Types.Sparkles then
			local Item = Instance.new('Sparkles');
			Item.Enabled = Datum[4] == 1;
			Item.SparkleColor = Color3.new(unpack(Support.Slice(Datum, 5, 7)));

			-- Register the instance
			Instances[Index] = Item;
		end;
		
		if Datum[1] == Types.ParticleEmitter then
			local Item = Instance.new('ParticleEmitter');
			Item.Enabled = Datum[4] == 1;
			Item.Color = ColorSequence.new {
				ColorSequenceKeypoint.new(0, Color3.new(unpack(Support.Slice(Datum, 5, 7)))),
				ColorSequenceKeypoint.new(1, Color3.new(unpack(Support.Slice(Datum, 5, 7)))),
			};
			Item.Orientation = Datum[8];
			Item.Size = NumberSequence.new(Datum[9], Datum[9]);
			Item.Texture = Datum[10];
			Item.Transparency = NumberSequence.new(Datum[11], Datum[11]);
			Item.Lifetime = NumberRange.new(Datum[12], Datum[12]);
			Item.Rate = Datum[13];
			Item.Rotation = NumberRange.new(Datum[14], Datum[14]);
			Item.RotSpeed = NumberRange.new(Datum[15], Datum[15]);
			Item.Speed = NumberRange.new(Datum[16], Datum[16]);
			Item.SpreadAngle = Vector2.new(Datum[17], -Datum[17]);
			Item.Acceleration = Vector3.new(0, Datum[18], 0);
			Item.LockedToPart = Datum[19];

			-- Register the instance
			Instances[Index] = Item;
		end;
		
		if Datum[1] == Types.SurfaceGui then
			local Item = Instance.new('SurfaceGui');
			local Text = Instance.new('TextLabel');
			Text.Parent = Item
			Item.Enabled = Datum[4] == 1;
			Item.Face = Datum[5]
			Text.Text = Datum[6];
			Text.TextTransparency = Datum[7];
			Text.TextColor3 = Color3.new(unpack(Support.Slice(Datum, 8, 10)));
			Text.RichText = Datum[11];
			Text.Font = Datum[12];

			-- Register the instance
			Instances[Index] = Item;
		end;
		
		if Datum[1] == Types.Attachment then
			local Item = Instance.new('Attachment');
			Item.WorldCFrame = CFrame.fromEulerAnglesXYZ(unpack(Support.Slice(Datum, 4, 6))) + Vector3.new(unpack(Support.Slice(Datum, 7, 9)))

			-- Register the model
			Instances[Index] = Item;
		end;
		
		if Datum[1] == Types.SelectionBox then
			local Item = Instance.new('SelectionBox');
			Item.Color3 = Color3.new(unpack(Support.Slice(Datum, 4, 6)));
			Item.LineThickness = Datum[7];
			Item.SurfaceColor3 = Color3.new(unpack(Support.Slice(Datum, 8, 10)));
			Item.SurfaceTransparency = Datum[11];
			Item.Transparency = Datum[12];

			-- Register the model
			Instances[Index] = Item;
		end;
		
		if Datum[1] == Types.Highlight then
			local Item = Instance.new('Highlight');
			Item.FillColor = Color3.new(unpack(Support.Slice(Datum, 4, 6)));
			Item.FillTransparency = Datum[7];
			Item.OutlineColor = Color3.new(unpack(Support.Slice(Datum, 8, 10)));
			Item.OutlineTransparency = Datum[11];
			Item.DepthMode = Datum[12];

			-- Register the model
			Instances[Index] = Item;
		end;

		-- Inflate Model instances
		if Datum[1] == Types.Model then
			local Item = Instance.new('Model');

			-- Register the model
			Instances[Index] = Item;
		end;

		-- Inflate Folder instances
		if Datum[1] == Types.Folder then
			local Item = Instance.new('Folder')

			-- Register the folder
			Instances[Index] = Item
		end

	end;
	
	-- Create the unions
	for ID, PartOperation in PartOperationsPositive do
		
		local NegativeParts = PartOperationsNegative[ID]
		
		local NegatedUnions = {}
		
		for _, Part in PartOperation do
			local Unions = GeometryService:SubtractAsync(Part, NegativeParts)
			
			Support.Merge(NegatedUnions, Unions)
		end
		
		local Reference = NegatedUnions[1]
		
		local FinalUnions = Reference
		
		if #NegatedUnions >= 2 then
			table.remove(NegatedUnions, 1)
		end
		
		FinalUnions = GeometryService:UnionAsync(Reference, NegatedUnions, {
			CollisionFidelity = Enum.CollisionFidelity.Hull,
			RenderFidelity = Enum.RenderFidelity.Performance,
			FluidFidelity = Enum.FluidFidelity.Automatic,
			SplitApart = false})
		
			local UnionData = script.Parent.UnionData:Clone()

			UnionData.Parent = FinalUnions[1]

			UnionData = require(UnionData)

			UnionData:Set(Serialization.SerializeModel(PartOperation, true), Serialization.SerializeModel(NegativeParts, true), FinalUnions[1].CFrame)
		
		for _, PartToDelete in ipairs(NegatedUnions) do
			if PartToDelete:IsA("PartOperation") then
				PartToDelete:Destroy()
			end
		end
		
		table.insert(Instances, FinalUnions[1])
		
	end

	-- Set object values on each instance
	for Index, Datum in pairs(Data.Items) do

		-- Get the item's instance
		local Item = Instances[Index];

		-- Set each item's parent and name
		if Item and Datum[1] <= 22 then
			Item.Name = (Datum[3] == '') and DefaultNames[Item.ClassName] or Datum[3];
			if Datum[2] == 0 then
				table.insert(Build, Item);
			else
				Item.Parent = Instances[Datum[2]];
				if Item:IsA("SelectionBox") then
					Item.Adornee = Instances[Datum[2]]
				end
			end;
		end;

		-- Set model primary parts
		if Item and Datum[1] == 15 then
			Item.PrimaryPart = (Datum[4] ~= 0) and Instances[Datum[4]] or nil;
		end;

	end;

	-- Return the model
	return Build;

end;

-- Return the API
return Serialization;