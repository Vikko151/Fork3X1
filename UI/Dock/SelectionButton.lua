local Root = script:FindFirstAncestorWhichIsA('Tool')
local Vendor = Root:WaitForChild('Vendor')
local Sounds = Root:WaitForChild("Sounds")

-- Libraries
local Roact = require(Vendor:WaitForChild('Roact'))

-- Roact
local new = function(Type, props, ...)
	props["RBXTAG_Native"] = true

	return Roact.createElement(Type, props, ...)
end
local Tooltip = require(script.Parent:WaitForChild('Tooltip'))

-- Create component
local SelectionButton = Roact.PureComponent:extend(script.Name)

function SelectionButton:init()
    self:setState({
        IsHovering = false;
    })
end

function SelectionButton:render()
	return new('ImageButton', {
	--	BackgroundTransparency = 1;
		Image = self.props.IconAssetId;
		LayoutOrder = self.props.LayoutOrder;
		ImageTransparency = self.props.Position and self.props.Size and 1 or nil;
		RBXTAG_STATE_Active = self.props.IsActive;
		[Roact.Event.Activated] = function()
			game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Press"))
			self.props.OnActivated()
		end;
		[Roact.Event.MouseEnter] = function ()
			game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Hover"))
		end;
		[Roact.Event.InputBegan] = function (rbx, Input)
			if Input.UserInputType.Name == 'MouseMovement' then
				self:setState({
					IsHovering = true;
				})
			end
		end;
		[Roact.Event.InputEnded] = function (rbx, Input)
			if Input.UserInputType.Name == 'MouseMovement' then
				self:setState({
					IsHovering = false;
				})
			end
		end;
	}, {
		Tooltip = new(Tooltip, {
			IsVisible = self.state.IsHovering;
			Text = self.props.TooltipText or '';
		});
		ResizedImage = self.props.Position and self.props.Size and new('ImageLabel', {
			--BackgroundTransparency = 1;
			--ImageTransparency = self.props.IsActive and 0 or 0.5;
			RBXTAG_STATE_Active = self.props.IsActive;
			Image = self.props.IconAssetId;
			Position = self.props.Position;
			Size = self.props.Size;
			AnchorPoint = self.props.AnchorPoint;
		});
	}, script.Name, self);
end

return SelectionButton
