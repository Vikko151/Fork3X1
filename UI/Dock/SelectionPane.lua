local Root = script:FindFirstAncestorWhichIsA('Tool')
local Vendor = Root:WaitForChild('Vendor')
local Libraries = Root:WaitForChild('Libraries')

-- Libraries
local Roact = require(Vendor:WaitForChild('Roact'))
local Maid = require(Libraries:WaitForChild('Maid'))
local ImageLabel = require(script.Parent.Parent:WaitForChild('ImageLabel'))

-- Roact
local new = Roact.createElement
local SelectionButton = require(script.Parent:WaitForChild('SelectionButton'))

-- Create component
local SelectionPane = Roact.PureComponent:extend(script.Name)

function SelectionPane:init()
    self.Maid = Maid.new()
    self.PaneSize, self.SetPaneSize = Roact.createBinding(UDim2.new())

    self:UpdateHistoryState()
    self.Maid.TrackHistory = self.props.Core.History.Changed:Connect(function ()
        self:UpdateHistoryState()
    end)

    self:UpdateSelectionState()
    self.Maid.TrackSelection = self.props.Core.Selection.Changed:Connect(function ()
        self:UpdateSelectionState()
    end)

	self:UpdateMultiSelectState()
	self.Maid.TrackMultiSelect = self.props.Core.Selection.MultiselectToggle:Connect(function()
		self:UpdateMultiSelectState()
	end)
	
	self:UpdateExplorerState()
	self.Maid.TrackExplorer = self.props.Core.ExplorerVisibilityChanged:Connect(function ()
		self:UpdateExplorerState()
	end)
	
	self:UpdateSaveLoadState()
	self.Maid.TrackSaveLoad = self.props.Core.SaveLoadVisibilityChanged:Connect(function ()
		self:UpdateSaveLoadState()
	end)
	
	self:UpdateRectangleSelectState()
	self.Maid.TrackRectangleSelect = self.props.Core.Targeting.MobileRectangleSelectChanged:Connect(function ()
		self:UpdateRectangleSelectState()
	end)
	
end

function SelectionPane:UpdateHistoryState()
    self:setState({
        CanUndo = (self.props.Core.History.Index > 0);
        CanRedo = (self.props.Core.History.Index ~= #self.props.Core.History.Stack);
    })
end

function SelectionPane:UpdateSelectionState()
    self:setState({
        IsSelectionEmpty = (#self.props.Core.Selection.Items == 0);
    })
end

function SelectionPane:UpdateMultiSelectState()
	self:setState({
		MultiSelecting = self.props.Core.Selection.Multiselecting;
	})
end

function SelectionPane:UpdateExplorerState()
    self:setState({
        IsExplorerOpen = self.props.Core.ExplorerVisible;
    })
end

function SelectionPane:UpdateSaveLoadState()
	self:setState({
		IsSaveLoadOpen = self.props.Core.SaveLoadVisible;
	})
end

function SelectionPane:UpdateRectangleSelectState()
	self:setState({
		MobileRectangleSelect = self.props.Core.Targeting.MobileRectangleSelect;
	})
end

function SelectionPane:willUnmount()
    self.Maid:Destroy()
end

function SelectionPane:render()
	local OptionsNumber = 10
	
	if self.props.Core.Options.CanUseExplorer == false then
		OptionsNumber -= 1
	end
	if self.props.Core.Options.CanUseSaveLoad == false then
		OptionsNumber -= 1
	end
	if self.props.Core.Options.CanUseExport == false then
		OptionsNumber -= 1
	end
	if game:GetService("UserInputService").TouchEnabled then
		OptionsNumber += 1
	end
	
	--local Size = 0.3358275862068966 / 5 * (5 - ReduceSize)
    return new('ScrollingFrame', {
--        BackgroundTransparency = 0.6;
--		BackgroundColor3 = Color3.new(0, 0, 0);
--        BorderSizePixel = 0;
		Size = UDim2.new(1, 0, 210 / 559, 0);
--		LayoutOrder = self.props.LayoutOrder;
		AutomaticCanvasSize = Enum.AutomaticSize.Y;
		CanvasSize = UDim2.new();
	--	ScrollBarThickness = 1;
		ScrollingDirection = Enum.ScrollingDirection.Y;
	--	ScrollBarImageColor3 = Color3.new();
		RBXTAG_SelectionPane = true;
	}, {
		--[[
        Corners = new('UICorner', {
			CornerRadius = UDim.new(0, 4);
		});]]
        Layout = new('UIGridLayout', {
            CellPadding = UDim2.new(0, 0, 0, 0);
			CellSize = UDim2.new(0, 35, 0, 35);
            FillDirection = Enum.FillDirection.Horizontal;
            FillDirectionMaxCells = 0;
            HorizontalAlignment = Enum.HorizontalAlignment.Left;
            VerticalAlignment = Enum.VerticalAlignment.Top;
            SortOrder = Enum.SortOrder.LayoutOrder;
            StartCorner = Enum.StartCorner.TopLeft;
            [Roact.Ref] = function (rbx)
                if rbx then
					self.SetPaneSize(UDim2.fromOffset(rbx.AbsoluteContentSize.X, rbx.AbsoluteContentSize.Y))
                end
            end;
            [Roact.Change.AbsoluteContentSize] = function (rbx)
                self.SetPaneSize(UDim2.fromOffset(rbx.AbsoluteContentSize.X, rbx.AbsoluteContentSize.Y))
            end;
        });
		SizeConstraint = new('UISizeConstraint', {
			MaxSize = Vector2.new(math.huge, 35 * math.ceil(OptionsNumber / 2))
		});
        UndoButton = new(SelectionButton, {
            LayoutOrder = 0;
            IconAssetId = 'rbxassetid://141741408';
            IsActive = self.state.CanUndo;
            OnActivated = self.props.Core.History.Undo;
			TooltipText = '<b>UNDO</b><br />Shift-Z';
        });
        RedoButton = new(SelectionButton, {
            LayoutOrder = 1;
            IconAssetId = 'rbxassetid://141741327';
            IsActive = self.state.CanRedo;
            OnActivated = self.props.Core.History.Redo;
			TooltipText = '<b>REDO</b><br />Shift-Y';
        });
        DeleteButton = new(SelectionButton, {
            LayoutOrder = 2;
            IconAssetId = 'rbxassetid://141896298';
            IsActive = not self.state.IsSelectionEmpty;
            OnActivated = self.props.Core.DeleteSelection;
			TooltipText = '<b>DELETE</b><br />Shift-X';
        });
		ExportButton = self.props.Core.Options.CanUseExport and new(SelectionButton, {
            LayoutOrder = 3;
            IconAssetId = 'rbxassetid://141741337';
            IsActive = not self.state.IsSelectionEmpty;
            OnActivated = self.props.Core.ExportSelection;
			TooltipText = '<b>EXPORT</b><br />Shift-P';
		});
        CloneButton = new(SelectionButton, {
            LayoutOrder = 4;
            IconAssetId = 'rbxassetid://142073926';
            IsActive = not self.state.IsSelectionEmpty;
            OnActivated = self.props.Core.CloneSelection;
			TooltipText = '<b>CLONE</b><br />Shift-C';
        });
		ExplorerButton = self.props.Core.Options.CanUseExplorer and new(SelectionButton, {
            LayoutOrder = 5;
            IconAssetId = 'rbxassetid://2326621485';
            IsActive = self.state.IsExplorerOpen;
            OnActivated = self.props.Core.ToggleExplorer;
			TooltipText = '<b>EXPLORER</b><br />Shift-H';
		}) or nil;
		GroupButton = new(SelectionButton, {
			LayoutOrder = 6;
			IconAssetId = "rbxassetid://1166534350";
			IsActive = not self.state.IsSelectionEmpty;
			OnActivated = self.props.Core.ArrangePartHotkey;
			TooltipText = '<b>GROUP/UNGROUP</b><br />Shift-M';
			Size = UDim2.new(0.55, 0, 0.55, 0);
			AnchorPoint = Vector2.new(0.5, 0.5);
			Position = UDim2.new(0.5, 0, 0.5, 0);
		});
		MultiSelectButton = new(SelectionButton, {
			LayoutOrder = 7;
			IconAssetId = 'rbxassetid://12072054746';
			IsActive = self.state.MultiSelecting;
			OnActivated = self.props.Core.ToggleMultiSelect;
			TooltipText = '<b>MULTISELECT</b><br />Hold Shift or Ctrl';
			Size = UDim2.new(0.7, 0, 0.7, 0);
			AnchorPoint = Vector2.new(0.5, 0.5);
			Position = UDim2.new(0.5, 0, 0.5, 0);
		});
		DataButton = self.props.Core.Options.CanUseSaveLoad and new(SelectionButton, {
			LayoutOrder = 8;
			IconAssetId = "rbxassetid://12392896984";
			IsActive = self.state.IsSaveLoadOpen;
			OnActivated = self.props.Core.ToggleSaveLoad;
			TooltipText = '<b>SAVE/LOAD</b><br />Shift-L';
			Size = UDim2.new(0.7, 0, 0.7, 0);
			AnchorPoint = Vector2.new(0.5, 0.5);
			Position = UDim2.new(0.5, 0, 0.5, 0);
		}) or nil;
		RectangleSelectButton = game:GetService("UserInputService").TouchEnabled and new(SelectionButton, {
			LayoutOrder = 9;
			IconAssetId = self.state.MobileRectangleSelect == 2 and "rbxassetid://99463159552749" or "rbxassetid://140571460844683";
			IsActive = self.state.MobileRectangleSelect ~= 0 and true or false;
			OnActivated = self.props.Core.Targeting.ToggleMobileRectangleSelect;
			TooltipText = '<b>RECTANGLE SELECT</b><br />FOR MOBILE';
			Size = UDim2.new(0.6, 0, 0.6, 0);
			AnchorPoint = Vector2.new(0.5, 0.5);
			Position = UDim2.new(0.5, 0, 0.5, 0);
		}) or nil;
		PrismSelectButton = new(SelectionButton, {
			LayoutOrder = 10;
			IconAssetId = "rbxassetid://74102407871192";
			IsActive = not self.state.IsSelectionEmpty;
			OnActivated = self.props.Core.Targeting.PrismSelect;
			TooltipText = '<b>BOX/PRISM SELECT</b><br />Shift-K';
			Size = UDim2.new(0.65, 0, 0.65, 0);
			AnchorPoint = Vector2.new(0.5, 0.5);
			Position = UDim2.new(0.5, 0, 0.5, 0);
		}) or nil;
	},  script.Name, self)
end

return SelectionPane
