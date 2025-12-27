local Tool = script.Parent;

-- Load tool completely before proceeding
local Indicator = Tool:WaitForChild 'Loaded';
while not Indicator.Value do
	Indicator.Changed:Wait();
end;

-- Initialize the core
local Core = require(Tool:WaitForChild 'Core');

-- Get core tools
local CoreTools = Tool:WaitForChild 'Tools';

-- Initialize move tool
local MoveTool = require(CoreTools:WaitForChild 'Move');
Core.AssignHotkey('Z', Core.Support.Call(Core.EquipTool, MoveTool));
Core.AddToolButton(Core.Assets.MoveIcon, 'Z', MoveTool)

-- Initialize resize tool
local ResizeTool = require(CoreTools:WaitForChild 'Resize')
Core.AssignHotkey('X', Core.Support.Call(Core.EquipTool, ResizeTool));
Core.AddToolButton(Core.Assets.ResizeIcon, 'X', ResizeTool)

-- Initialize rotate tool
local RotateTool = require(CoreTools:WaitForChild 'Rotate')
Core.AssignHotkey('C', Core.Support.Call(Core.EquipTool, RotateTool));
Core.AddToolButton(Core.Assets.RotateIcon, 'C', RotateTool)

-- Initialize paint tool
local PaintTool = require(CoreTools:WaitForChild 'Paint')
Core.AssignHotkey('V', Core.Support.Call(Core.EquipTool, PaintTool));
Core.AddToolButton(Core.Assets.PaintIcon, 'V', PaintTool)

-- Initialize surface tool
local SurfaceTool = require(CoreTools:WaitForChild 'Surface')
Core.AssignHotkey('B', Core.Support.Call(Core.EquipTool, SurfaceTool));
Core.AddToolButton(Core.Assets.SurfaceIcon, 'B', SurfaceTool)

-- Initialize material tool
local MaterialTool = require(CoreTools:WaitForChild 'Material')
Core.AssignHotkey('N', Core.Support.Call(Core.EquipTool, MaterialTool));
Core.AddToolButton(Core.Assets.MaterialIcon, 'N', MaterialTool)

-- Initialize anchor tool
local AnchorTool = require(CoreTools:WaitForChild 'Anchor')
Core.AssignHotkey('M', Core.Support.Call(Core.EquipTool, AnchorTool));
Core.AddToolButton(Core.Assets.AnchorIcon, 'M', AnchorTool)

-- Initialize collision tool
local CollisionTool = require(CoreTools:WaitForChild 'Collision')
Core.AssignHotkey('K', Core.Support.Call(Core.EquipTool, CollisionTool));
Core.AddToolButton(Core.Assets.CollisionIcon, 'K', CollisionTool)

-- Initialize new part tool
local NewPartTool = require(CoreTools:WaitForChild 'NewPart')
Core.AssignHotkey('J', Core.Support.Call(Core.EquipTool, NewPartTool));
Core.AddToolButton(Core.Assets.NewPartIcon, 'J', NewPartTool)

-- Initialize mesh tool
local MeshTool = require(CoreTools:WaitForChild 'Mesh')
Core.AssignHotkey('H', Core.Support.Call(Core.EquipTool, MeshTool));
Core.AddToolButton(Core.Assets.MeshIcon, 'H', MeshTool)

-- Initialize texture tool
local TextureTool = require(CoreTools:WaitForChild 'Texture')
Core.AssignHotkey('G', Core.Support.Call(Core.EquipTool, TextureTool));
Core.AddToolButton(Core.Assets.TextureIcon, 'G', TextureTool)

-- Initialize weld tool
local WeldTool = require(CoreTools:WaitForChild 'Weld')
Core.AssignHotkey('F', Core.Support.Call(Core.EquipTool, WeldTool));
Core.AddToolButton(Core.Assets.WeldIcon, 'F', WeldTool)

-- Initialize lighting tool
local LightingTool = require(CoreTools:WaitForChild 'Lighting')
Core.AssignHotkey('U', Core.Support.Call(Core.EquipTool, LightingTool));
Core.AddToolButton(Core.Assets.LightingIcon, 'U', LightingTool)

-- Initialize decorate tool
local DecorateTool = require(CoreTools:WaitForChild 'Decorate')
Core.AssignHotkey('P', Core.Support.Call(Core.EquipTool, DecorateTool));
Core.AddToolButton(Core.Assets.DecorateIcon, 'P', DecorateTool)

-- Initialize marketplace tool
local MarketplaceTool = require(CoreTools:WaitForChild 'Marketplace')
Core.AssignHotkey('L', Core.Support.Call(Core.EquipTool, MarketplaceTool));
Core.AddToolButton(Core.Assets.MarketplaceIcon, 'L', MarketplaceTool, UDim2.new(0.5, 0, 0.5, 0), UDim2.new(0.55, 0, 0.55, 0), Vector2.new(0.5, 0.5))

local TextTool = require(CoreTools:WaitForChild 'Text')
Core.AssignHotkey('T', Core.Support.Call(Core.EquipTool, TextTool));
Core.AddToolButton(Core.Assets.TextIcon, 'T', TextTool, UDim2.new(0.5, 0, 0.5, 0), UDim2.new(0.5, 0, 0.5, 0), Vector2.new(0.5, 0.5))

local TransformationTool = require(CoreTools:WaitForChild 'Transformation')
Core.AssignHotkey('Q', Core.Support.Call(Core.EquipTool, TransformationTool));
Core.AddToolButton(Core.Assets.TransformationIcon, 'Q', TransformationTool, UDim2.new(0.5, 0, 0.5, 0), UDim2.new(0.55, 0, 0.55, 0), Vector2.new(0.5, 0.5))

local AttachmentTool = require(CoreTools:WaitForChild 'Attachment')
Core.AssignHotkey('Y', Core.Support.Call(Core.EquipTool, AttachmentTool));
Core.AddToolButton(Core.Assets.AttachmentIcon, 'Y', AttachmentTool, UDim2.new(0.5, 0, 0.5, 0), UDim2.new(0.55, 0, 0.55, 0), Vector2.new(0.5, 0.5))

-- Once everything is initialised, parent everything in a model in PlayerScripts so equipping the tool doesn't cause lag



if not Core.Plugin and Core.Options.StoreFilesInPlayer then
	ToolContainer = Instance.new("Tool")
	ToolContainer.Name = "Fork3XComponents"
	ToolContainer.Parent = game.Players.LocalPlayer.PlayerScripts
	
	for _, Child in Tool:GetChildren() do
		if not Child:IsA("BasePart") then
			Child.Parent = ToolContainer
		end
	end
	
	coroutine.wrap(function()
		while task.wait(0.5) do
			if Tool == nil or Tool.Parent == nil then
				ToolContainer:Destroy()
			end
		end
	end)()
end

return Core
