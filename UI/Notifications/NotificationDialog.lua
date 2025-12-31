local Root = script:FindFirstAncestorWhichIsA('Tool')
local Vendor = Root:WaitForChild('Vendor')

-- Libraries
local Roact = require(Vendor:WaitForChild('Roact'))
local new = function(Type, props, ...)
	props["RBXTAG_Native"] = true

	return Roact.createElement(Type, props, ...)
end

-- Create component
local NotificationDialog = Roact.PureComponent:extend(script.Name)

function NotificationDialog:init()
    self:setState({
        ShouldDisplayDetails = false;
    })
end

function NotificationDialog:render()
    return new('Frame', {
    --    BackgroundColor3 = Color3.fromRGB(0, 0, 0);
    --    BackgroundTransparency = 0.6;
    --    BorderSizePixel = 0;
        Size = UDim2.new(1, 0, 0, 22 + 2);
		LayoutOrder = self.props.LayoutOrder;
		RBXTAG_Notification = true
	}, {
		--[[
        ColorBar = new('Frame', {
            BorderSizePixel = 0;
            BackgroundColor3 = self.props.ThemeColor;
            Size = UDim2.new(1, 0, 0, 2);
        });]]
        OKButton = new('TextButton', {
        --    BackgroundColor3 = Color3.fromRGB(0, 0, 0);
        --    BackgroundTransparency = 0.8;
       --     BorderSizePixel = 0;
			--    AnchorPoint = Vector2.new(0.5, 1);
			AnchorPoint = Vector2.new(0.5, 1);
			Position = not self.state.ShouldDisplayDetails and UDim2.new(0.25, 0, 1, 0) or UDim2.new();
			RBXTAG_STATE_DetailsDisplayed = self.state.ShouldDisplayDetails;
        ---    Size = UDim2.new(self.state.ShouldDisplayDetails and 1 or 0.5, 0, 0, 22);
            Text = 'GOT IT';
		--	FontFace = Font.new("rbxassetid://12187365977", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
         --   TextSize = 10;
        --    TextColor3 = Color3.fromRGB(255, 255, 255);
            [Roact.Event.Activated] = function (rbx)
                self.props.OnDismiss(rbx.Parent)
            end;
        });
        DetailsButton = (not self.state.ShouldDisplayDetails or nil) and new('TextButton', {
        --    BackgroundColor3 = Color3.fromRGB(0, 0, 0);
--            BackgroundTransparency = 0.8;
--            BorderSizePixel = 0;
            AnchorPoint = Vector2.new(0.5, 1);
            Position = UDim2.new(0.75, 0, 1, 0);
 --           Size = UDim2.new(0.5, 0, 0, 22);
            Text = 'WHAT CAN I DO?';
--			FontFace = Font.new("rbxassetid://12187365977", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
--            TextSize = 10;
 --           TextColor3 = Color3.fromRGB(255, 255, 255);
            [Roact.Event.Activated] = function (rbx)
                self:setState({
                    ShouldDisplayDetails = true;
                })
            end;
		});
		--[[
        ButtonDivider = (not self.state.ShouldDisplayDetails or nil) and new('Frame', {
            BackgroundColor3 = Color3.fromRGB(0, 0, 0);
            BackgroundTransparency = 0.75;
            BorderSizePixel = 0;
            Position = UDim2.new(0.5, 0, 1, 0);
            AnchorPoint = Vector2.new(0.5, 1);
            Size = UDim2.new(0, 1, 0, 22);
        });]]
        Text = new('TextLabel', {
--            BackgroundTransparency = 1;
--            Position = UDim2.new(0, 0, 0, 2);
--           Size = UDim2.new(1, 0, 1, -22 - 2);
--            TextWrapped = true;
            RichText = true;
--			FontFace = Font.new("rbxassetid://12187365977", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal),
--            TextColor3 = Color3.fromRGB(255, 255, 255);
--            TextSize = 11;
--            TextStrokeTransparency = 0.9;
 --           LineHeight = 1;
            Text = (not self.state.ShouldDisplayDetails) and
                self.props.NoticeText or
                self.props.DetailText;
            [Roact.Change.TextBounds] = function (rbx)
                rbx.Parent.Size = UDim2.new(1, 0, 0, rbx.TextBounds.Y + 29 + 22 + 2)
            end;
        });
	},  script.Name, self)
end

return NotificationDialog
