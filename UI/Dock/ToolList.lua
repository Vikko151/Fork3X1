local Root = script:FindFirstAncestorWhichIsA('Tool')
local Vendor = Root:WaitForChild('Vendor')
local Libraries = Root:WaitForChild('Libraries')

-- Libraries
local Roact = require(Vendor:WaitForChild('Roact'))
local Maid = require(Libraries:WaitForChild('Maid'))

-- Roact
local new = function(Type, props, ...)
	props["RBXTAG_Native"] = true

	return Roact.createElement(Type, props, ...)
end
local ToolButton = require(script.Parent:WaitForChild('ToolButton'))

-- Create component
local ToolList = Roact.PureComponent:extend(script.Name)

function ToolList:init()
	self.Maid = Maid.new()
	self.CanvasSize, self.SetCanvasSize = Roact.createBinding(UDim2.new())

	-- Track current tool
	--self:setState({
	--	CurrentTool = self.props.Core.CurrentTool;
	--	})

	--[[
	self.Maid.CurrentTool = self.props.Core.ToolChanged:Connect(function (Tool)
		self:setState({
			CurrentTool = Tool;
		})
	end)]]
end

function ToolList:render()
	local ListChildren = {
		Layout = new('UIGridLayout', {
			CellPadding = UDim2.new(0, 0, 0, 0);
			CellSize = UDim2.new(0, 35, 0, 35);
			FillDirection = Enum.FillDirection.Horizontal;
			FillDirectionMaxCells = 2;
			HorizontalAlignment = Enum.HorizontalAlignment.Left;
			VerticalAlignment = Enum.VerticalAlignment.Top;
			SortOrder = Enum.SortOrder.LayoutOrder;
			StartCorner = Enum.StartCorner.TopLeft;
			--        [Roact.Ref] = function (rbx)
			--            if rbx then
			--                self.SetCanvasSize(UDim2.fromOffset(rbx.AbsoluteContentSize.X, rbx.AbsoluteContentSize.Y))
			--            end
			--        end;
			--        [Roact.Change.AbsoluteContentSize] = function (rbx)
			--            self.SetCanvasSize(UDim2.fromOffset(rbx.AbsoluteContentSize.X, rbx.AbsoluteContentSize.Y))
			--        end;
		});
	}
	

	-- Build buttons for each tool
	for ToolIndex, ToolInfo in ipairs(self.props.Tools) do
		ListChildren[tostring(ToolIndex)] = new(ToolButton, {
			--		CurrentTool = self.state.CurrentTool;
			IconAssetId = ToolInfo.IconAssetId;
			HotkeyLabel = ToolInfo.HotkeyLabel;
			LayoutOrder = ToolIndex;
			Tool = ToolInfo.Tool;
			Position = ToolInfo.Position;
			Size = ToolInfo.Size;
			AnchorPoint = ToolInfo.AnchorPoint;
			Core = self.props.Core;
		})
	end
	
--	local Children = 
	
	--[[
	if self.props.Core.RoactComponents and self.props.Core.RoactComponents[script.Name] then
		for _, Function in self.props.Core.RoactComponents[script.Name] do
			table.insert(Children, Function(self))
		end
	end]]

	return new('Frame', {
	--	BackgroundTransparency = 1;
	--	BackgroundColor3 = Color3.fromRGB(0, 0, 0);
	--	BorderSizePixel = 0;
		--		LayoutOrder = self.props.LayoutOrder;
		Size = UDim2.new(1, 0, math.ceil(#self.props.Tools / 2) * 35 / 559, 0);
		RBXTAG_ToolList = true;
	}, { 
		List = new('ScrollingFrame', {
			--		BackgroundTransparency = 1;
			--		BorderSizePixel = 0;
			Size = UDim2.new(1, 0, 1, 0);
			CanvasSize = UDim2.new();
			--	ScrollBarThickness = 1;
			ScrollingDirection = Enum.ScrollingDirection.Y;
			--	ScrollBarImageColor3 = Color3.fromRGB(0, 0, 0);
			AutomaticCanvasSize = Enum.AutomaticSize.Y;
			[Roact.Children] = ListChildren;
		});
		SizeConstraint = new('UISizeConstraint', {
			MaxSize = Vector2.new(math.huge, 35 * math.ceil(#self.props.Tools / 2))
		});
		--[[
		Background = new('Frame', {
			BackgroundTransparency = 0.6;
			BackgroundColor3 = Color3.fromRGB(0, 0, 0);
			BorderSizePixel = 0;
			--	LayoutOrder = self.props.LayoutOrder;
			Size = self.CanvasSize:map(function (CanvasSize)
				return UDim2.new(1, 0, 1, 3)
			end);
			Position = UDim2.new(0, 0, 0, -3);
		}, {
			Corners = new('UICorner', {
				CornerRadius = UDim.new(0, 4);
			});
		})]]
	}, script.Name, self)
end

return ToolList
