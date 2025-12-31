local Root = script:FindFirstAncestorWhichIsA('Tool')
local Vendor = Root:WaitForChild('Vendor')

-- Libraries
local Roact = require(Vendor:WaitForChild('Roact'))
local Maid = require(Root:WaitForChild("Libraries"):WaitForChild('Maid'))

-- Roact
local new = Roact.createElement
local ToolList = require(script:WaitForChild('ToolList'))
local SelectionPane = require(script:WaitForChild('SelectionPane'))
local AboutPane = require(script:WaitForChild('AboutPane'))

-- Create component
local Dock = Roact.PureComponent:extend(script.Name)

function Dock:init()
	self.DockSize, self.SetDockSize = Roact.createBinding(UDim2.new())
	self.MaxSize, self.SetMaxSize = Roact.createBinding(Vector2.new())
end

function Dock:willUnmount()
	self.Maid:Destroy()
end

function Dock:render()
	return new('Frame', {
		Active = true;
		AnchorPoint = Vector2.new(1, 0.5);
		BackgroundTransparency = 1;
		Position = UDim2.new(1, -14, 0.5, 0);
		Size = UDim2.new(0, 70, 0.95, 0);--self.DockSize;--UDim2.new(0, 70, 0, 524);
		ZIndex = 0;
		RBXTAG_Dock = true;
	}, {
		Layout = new('UIListLayout', {
			Padding = UDim.new(0, 1);
			FillDirection = Enum.FillDirection.Vertical;
			HorizontalAlignment = Enum.HorizontalAlignment.Left;
			VerticalAlignment = Enum.VerticalAlignment.Top;
			SortOrder = Enum.SortOrder.LayoutOrder;
			--[[
           [Roact.Ref] = function (rbx)
               if rbx then
                    self.SetDockSize(UDim2.fromOffset(rbx.AbsoluteContentSize.X, rbx.AbsoluteContentSize.Y))
                end
            end;
            [Roact.Change.AbsoluteContentSize] = function (rbx)
                self.SetDockSize(UDim2.fromOffset(rbx.AbsoluteContentSize.X, rbx.AbsoluteContentSize.Y))
            end;]]
		});
		SizeConstraint = new('UISizeConstraint', {
			MaxSize = Vector2.new(math.huge, 559);
		});
		AboutPane = new(AboutPane, {
	--		LayoutOrder = 0;
			Core = self.props.Core;
		});
		ToolList = new(ToolList, {
	--		LayoutOrder = 1;
			Tools = self.props.Tools;
			Core = self.props.Core;
		});
		SelectionPane = new(SelectionPane, {
	--		LayoutOrder = 2;
			Core = self.props.Core;
		});
	}, script.Name, self)
end

return Dock
