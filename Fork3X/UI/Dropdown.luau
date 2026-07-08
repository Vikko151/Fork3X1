local Root = script.Parent.Parent

local Core = require(Root.Core)
local Vendor = Root:WaitForChild('Vendor')
local Libraries = Core.Libraries

local TextService = game:GetService("TextService")

-- Libraries
local Roact = require(Vendor:WaitForChild('Roact'))
local Cryo = require(Libraries:WaitForChild('Cryo'))
local Maid = require(Libraries:WaitForChild('Maid'))
local Support = require(Libraries:WaitForChild("SupportLibrary"))
local MaterialsImages = require(Libraries:WaitForChild("MaterialsLibrary"))

local Tools = Root:WaitForChild("Tools")
local new = function(Type, props, ...)
	props["RBXTAG_Native"] = true

	return Roact.createElement(Type, props, ...)
end

-- Create component
local Dropdown = Roact.PureComponent:extend(script.Name)

function Dropdown:init()
	self.Maid = Maid.new()
	self.Size, self.SetSize = Roact.createBinding(Vector2.new())
	self.FocusedOption, self.SetFocusedOption = Roact.createBinding("")
	
	self.OptionRef = Roact.createRef()
	
	self.FocusOrder = {"", 1}
	self.IsEnterPressed = false
	
	self.Maid.OnKeyPressed = game:GetService("UserInputService").InputBegan:Connect(function(Input, GameProcessedEvent)
		if self.state.AreOptionsVisible == false then return end
		
		self:FocusOption(Input, GameProcessedEvent)
	end)
	
	self.Maid.OnKeyReleased = game:GetService("UserInputService").InputEnded:Connect(function(Input, GameProcessedEvent)
		if Input.KeyCode == Enum.KeyCode.Return then

			self.IsEnterPressed = false

		end
	end)
	
	self:setState({
		AreOptionsVisible = false;
	})
end

function Dropdown:FocusOption(Input: InputObject, IsFromTheGame: boolean)
	
	local KeyCode = Input.KeyCode.Name
	
	if self.IsEnterPressed and Input.UserInputState == Enum.UserInputState.Begin and Input.UserInputType == Enum.UserInputType.Keyboard and string.len(KeyCode) == 1 then
		if self.FocusOrder[1] ~= KeyCode then
			self.FocusOrder[1] = KeyCode
			self.FocusOrder[2] = 1
		else
			self.FocusOrder[2] += 1
		end
		
		local Options = self.props.Options
		
		local ValidOptions = {}
		
		for i = 1, #Options do
			local OptionFirstLetter = string.sub(Options[i], 1, 1)
			
			if OptionFirstLetter == self.FocusOrder[1] then
				table.insert(ValidOptions, Options[i])
			end
		end
		
		if self.FocusOrder[2] > #ValidOptions then
			self.FocusOrder[2] = 1
		end
		
		self.SetFocusedOption(ValidOptions[self.FocusOrder[2]])
		
	elseif Input.KeyCode == Enum.KeyCode.Return then
		
		self.IsEnterPressed = true
	
	end
	
end

function Dropdown:didMount()
	if self.OptionRef:getValue() and self.props.AutomaticXSize then
		local OptionsLabel = self.OptionRef:getValue()
		local Params = Instance.new("GetTextBoundsParams")

		Params.Font = OptionsLabel:GetStyled("FontFace")
		Params.Size = OptionsLabel:GetStyled("TextSize")

		local LongestOption = ""

		for _, Name in self.props.Options do
			if #Name >= #LongestOption then
				LongestOption = Name
			end
		end

		Params.Text = LongestOption
		
		self:setState({
			TextXSize = TextService:GetTextBoundsAsync(Params).X
		})
	end
end

function Dropdown:BuildButtonList()
	local List = {}
	for Index, Option in ipairs(self.props.Options) do
		local PreviewFont = nil
		
		if self.props.OccurrenceOptions and self.props.TextPreview then
			PreviewFont = Support.FindTableOccurrence(self.props.OccurrenceOptions, Option) or Enum.Font.Arimo
		end
		table.insert(List, new('TextButton', {
			--[[
			BackgroundTransparency = self.FocusedOption:map(function(Focus) 
				return (self.props.CurrentOption == Option) and 0.1 or (Focus == Option) and 0.7 or 1;
			end);
			]]
			RBXTAG_STATE_Focused = self.FocusedOption:map(function(Focus) 
				return Focus == Option and true or false;
			end);
			RBXTAG_STATE_CurrentOption = self.props.CurrentOption == Option and true or false;
	--		BackgroundColor3 = Color3.fromRGB(0, 145, 255);
	--		BorderSizePixel = 0;
	--		Font = Enum.Font.GothamBold;
			Text = Option;
	--		TextColor3 = Color3.fromRGB(255, 255, 255);
	--		TextSize = 10;
	--		TextXAlignment = Enum.TextXAlignment.Left;
	--		TextYAlignment = Enum.TextYAlignment.Center;
			ZIndex = 4;
			
			[Roact.Event.MouseEnter] = function (rbx)
				Core.PlaySound("Hover")
			end,
			--[[
			[Roact.Event.InputEnded] = function (rbx)
				rbx.BackgroundTransparency = (self.props.CurrentOption == Option) and 0.1 or (self.FocusedOption:getValue() == Option) and 0.7 or 1;
			end;
			[Roact.Change.AbsoluteSize] = function (rbx)
				self.SetSize(rbx.AbsoluteSize)
			end;]]
			[Roact.Event.Activated] = function (rbx)
				Core.PlaySound("Press")
				
				self.props.OnOptionSelected(Option, Index)
				self:setState({
					AreOptionsVisible = false;
				})
			end;
		}, {
			--[[
			Padding = new('UIPadding', {
				PaddingLeft = UDim.new(0, 6);
				PaddingRight = UDim.new(0, 6);
			});
			Corners = new('UICorner', {
				CornerRadius = UDim.new(0, 4);
			});]]
			ImagePreview = self.props.ImagePreview and new('ImageLabel', {
				BackgroundTransparency = 0;
				BackgroundColor3 = Color3.fromRGB(120, 120, 120);
				BorderSizePixel = 0;
				Image = tonumber(MaterialsImages[Option]) and "rbxassetid://" .. MaterialsImages[Option] or MaterialsImages[Option] or "rbxasset://Textures/ui/dialog_purpose_help.png";
				AnchorPoint = Vector2.new(1, 0.5);
				Position = UDim2.new(1, 0, 0.5, 0);
				Size = UDim2.new(0, 20, 0, 20);
				ZIndex = 3;
				ScaleType = Enum.ScaleType.Tile;
				TileSize = MaterialsImages[Option] and UDim2.new(2, 0, 2, 0) or UDim2.new(1, 0, 1, 0);
			}) or nil;
			TextPreview = self.props.TextPreview and new('TextLabel', {
				BackgroundTransparency = 1;
				BorderSizePixel = 0;
				Text = "A";
				TextScaled = true;
				AnchorPoint = Vector2.new(1, 0.5);
				Position = UDim2.new(1, 0, 0.5, 0);
				Size = UDim2.new(0, 20, 0, 20);
				TextColor3 = Color3.fromRGB(255, 255, 255);
				ZIndex = 3;
				Font = typeof(PreviewFont) == "EnumItem" and PreviewFont or nil,
				FontFace = typeof(PreviewFont) == "Font" and PreviewFont or nil
			}) or nil;
		}))
	end
	return List
end

function Dropdown:render()
	return new('ImageButton', {
	--	BackgroundColor3 = Color3.new(1, 1, 1);
	--	BackgroundTransparency = 0.9;
		--	BorderSizePixel = 0;
		AnchorPoint = self.props.AnchorPoint or Vector2.new();
		Position = self.props.Position;
		Size = self.state.TextXSize and self.props.Size + UDim2.fromOffset(self.state.TextXSize + 32, 0) or self.props.Size;
		RBXTAG_Dropdown = true;
	--	Image = '';
		[Roact.Change.AbsoluteSize] = function (rbx)
			self.SetSize(rbx.AbsoluteSize)
			--self.SetSize(self.state.TextXSize and rbx.AbsoluteSize + Vector2.new(self.state.TextXSize + 32, 0) or rbx.AbsoluteSize)
		end;
		[Roact.Event.MouseEnter] = function (rbx)
			Core.PlaySound("Hover")
		end;
		[Roact.Event.Activated] = function (rbx)
			Core.PlaySound("Press")
			self:setState({
				AreOptionsVisible = not self.state.AreOptionsVisible;
			})
		end;
	}, {
		--[[
		Corners = new('UICorner', {
			CornerRadius = UDim.new(0, 4);
		});
		Stroke = new('UIStroke', {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border;
			Transparency = 0.9;
			Thickness = 2;
			Color = Color3.new(0, 0, 0);
		});]]
		CurrentOption = new('TextLabel', {
		--	BackgroundTransparency = 1;
		--	Font = Enum.Font.GothamBold;
			Text = self.props.CurrentOption or '*';
		--	TextColor3 = Color3.fromRGB(255, 255, 255);
		--	TextSize = 10;
		--	TextXAlignment = Enum.TextXAlignment.Left;
		--	TextYAlignment = Enum.TextYAlignment.Center;
			Position = UDim2.new(0, 6, 0, 0);
			Size = UDim2.new(1, -32, 1, 0);
			[Roact.Ref] = self.OptionRef;
		});
		Arrow = new('ImageLabel', {
			--BackgroundTransparency = 1;
			--AnchorPoint = Vector2.new(1, 0.5);
			--Position = UDim2.new(1, -3, 0.5, 0);
			--Size = UDim2.new(0, 20, 0, 20);
			--Image = 'rbxassetid://11552476728';
		});
		ScrollFrame = new('ScrollingFrame', {
			Visible = self.state.AreOptionsVisible;
			--BackgroundColor3 = Color3.fromRGB(255, 255, 255);
			--BackgroundTransparency = 1;
			--BorderSizePixel = 0;
			--Position = UDim2.new(0, 0, 1, 5);
			RBXTAG_STATE_NoClipping = self.props.NoClipping or false;
			Position = self.props.OptionsPosition or nil;
			Size = UDim2.new(
				math.clamp(math.ceil(#self.props.Options / self.props.MaxRows), 0, 3), 0,
				(#self.props.Options > self.props.MaxRows) and self.props.MaxRows or #self.props.Options, math.ceil(#self.props.Options / self.props.MaxRows) >= 3 and 12 or 0
			);
			ZIndex = 4;
			AutomaticCanvasSize = Enum.AutomaticSize.None;
			CanvasSize = UDim2.new(
				math.ceil(#self.props.Options / self.props.MaxRows), 0,
				(#self.props.Options > self.props.MaxRows) and self.props.MaxRows or #self.props.Options, 0
			);
			ScrollingDirection = Enum.ScrollingDirection.X;
			--ScrollBarImageColor3 = Core.Selection.Color.Color ~= Color3.fromRGB(255, 255, 255) and Core.Selection.Color.Color or Color3.new(17 / 255, 17 / 255, 17 / 255);
			--TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png";
			--BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png";
			CanvasPosition = self.FocusedOption:map(function(Option)
				return Vector2.new(table.find(self.props.Options, Option) and
					math.ceil(table.find(self.props.Options, Option) / self.props.MaxRows - 1) * self.props.Size.X.Offset
					or 0, 0) or Vector2.new(0, 0)
			end);
		}, Cryo.Dictionary.join(self:BuildButtonList(), {
			Layout = new('UIGridLayout', {
				CellPadding = UDim2.new();
				CellSize = self.Size:map(function (Size)
					
					return UDim2.fromOffset(Size.X, Size.Y)
				end);
				FillDirection = Enum.FillDirection.Vertical;
				FillDirectionMaxCells = self.props.MaxRows;
				HorizontalAlignment = Enum.HorizontalAlignment.Left;
				VerticalAlignment = Enum.VerticalAlignment.Top;
				SortOrder = Enum.SortOrder.LayoutOrder;
				StartCorner = Enum.StartCorner.TopLeft;
			});
		}));
		Options = new('Frame', {
			Visible = self.state.AreOptionsVisible;
		--	BackgroundColor3 = Color3.fromRGB(255, 255, 255);
		--	BackgroundTransparency = 0.6;
		--	BorderSizePixel = 0;
			--	Position = UDim2.new(0, 0, 1, 5);
			RBXTAG_STATE_NoClipping = self.props.NoClipping or false;
			Position = self.props.OptionsPosition or nil;
			Size = UDim2.new(
				math.clamp(math.ceil(#self.props.Options / self.props.MaxRows), 0, 3), 0,
				(#self.props.Options > self.props.MaxRows) and self.props.MaxRows or #self.props.Options, math.ceil(#self.props.Options / self.props.MaxRows) >= 3 and 12 or 0
			);
			ZIndex = 3;
		}, {
			--[[
			Corners = new('UICorner', {
				CornerRadius = UDim.new(0, 4);
			});
			Stroke = new('UIStroke', {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border;
				Transparency = 0.9;
				Thickness = 2;
				Color = Color3.new(0, 0, 0);
			});]]
		});
	},  script.Name, self)
end

return Dropdown

				--[[self.Size:map(function (Size)
					print(Size)
					print(UDim2.fromOffset(Size.X, Size.Y))
                    return UDim2.fromOffset(Size.X, Size.Y)
                end);]]