local Root = script.Parent.Parent.Parent
local Vendor = Root:WaitForChild('Vendor')
local TextService = game:GetService('TextService')
local Sounds = Root:WaitForChild("Sounds")

-- Libraries
local Roact = require(Vendor:WaitForChild('Roact'))
local Maid = require(Root.Libraries:WaitForChild('Maid'))
local new = function(Type, props, ...)
	props["RBXTAG_Native"] = true

	return Roact.createElement(Type, props, ...)
end

-- Create component
local ToolButton = Roact.PureComponent:extend(script.Name)

function ToolButton:init()
	self.Maid = Maid.new()
	
	self:UpdateHotkeyTextSize(self.props.HotkeyLabel)
	
	self:UpdateCurrentTool()
	self.Maid.TrackCurrentTool = self.props.Core.ToolChanged:Connect(function (Tool)
		self:UpdateCurrentTool(Tool)
	end)
end

function ToolButton:willUpdate(nextProps)
    if self.props.HotkeyLabel ~= nextProps.HotkeyLabel then
        self:UpdateHotkeyTextSize(nextProps.HotkeyLabel)
	end
end

function ToolButton:UpdateHotkeyTextSize(Text)
    self.HotkeyTextSize = TextService:GetTextSize(
        Text,
        9,
        Enum.Font.Gotham,
        Vector2.new(math.huge, math.huge)
    )
end

function ToolButton:UpdateCurrentTool(Tool)
	self:setState({
		-- DEPRECATED: Use Active as a state to support UI styling
		-- Transparency = Tool == self.props.Tool and 0 or 1;
		Active = Tool == self.props.Tool and true or false;
	})
end

function ToolButton:render()
    return new('ImageButton', {
--        BackgroundColor3 = self.props.Tool.Color.Color;
--        BackgroundTransparency = self.state.Transparency;
--        BorderSizePixel = 0;
		Image = self.props.IconAssetId;
		ImageTransparency = self.props.Position and self.props.Size and 1 or nil;
		LayoutOrder = self.props.LayoutOrder;
		RBXTAG_STATE_Active = self.state.Active;
  --      AutoButtonColor = false;
		[Roact.Event.Activated] = function ()
			game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Press"))
            self.props.Core.EquipTool(self.props.Tool)
		end;
		[Roact.Event.MouseEnter] = function ()
			game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Hover"))
		end;
	}, {
		--[[
        Corners = new('UICorner', {
            CornerRadius = UDim.new(0, 3);
        });]]
        Hotkey = new('TextLabel', {
        --    BackgroundTransparency = 1;
        --    Position = UDim2.new(0, 3, 0, 3);
        --    Size = UDim2.fromOffset(self.HotkeyTextSize.X, self.HotkeyTextSize.Y);
        --    Font = Enum.Font.Gotham;
			Text = self.props.HotkeyLabel;
		--	RichText = true;
        --    TextColor3 = Color3.fromRGB(255, 255, 255);
        --    TextSize = 9;
        --    TextXAlignment = Enum.TextXAlignment.Left;
        --    TextYAlignment = Enum.TextYAlignment.Top;
		});
		ResizedImage = self.props.Position and self.props.Size and new('ImageLabel', {
		--	BackgroundTransparency = 1;
		--	ImageTransparency = 0;
			Image = self.props.IconAssetId;
			Position = self.props.Position;
			Size = self.props.Size;
			AnchorPoint = self.props.AnchorPoint or Vector2.new(0, 0);
		});
	},  script.Name, self)
end

return ToolButton
