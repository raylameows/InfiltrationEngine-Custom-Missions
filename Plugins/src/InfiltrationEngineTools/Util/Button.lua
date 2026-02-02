local Actor = require(script.Parent.Actor)
local Create = Actor.Create
local State = Actor.State
local Derived = Actor.Derived

return function(props)
	local enabled = props.Enabled or State(false)
	
	return Create("TextButton", {
		BorderSizePixel = 0,
		Size = props.Size or UDim2.new(0, 200, 0, 40),
		Text = props.Text,
		BackgroundTransparency = Derived(function(e)
			return e and 0 or 0.5
		end, enabled),
		BackgroundColor3 = Derived(function(e)
			return e and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
		end, enabled),
		TextColor3 = Derived(function(e)
			return e and Color3.new(0, 0, 0) or Color3.new(1, 1, 1)
		end, enabled),
		
		TextSize = props.TextSize or 20,
		Font = Enum.Font.SciFi,
		
		Activated = props.Activated,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint
	})
end
