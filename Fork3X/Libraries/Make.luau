-- Callable Instance.new wrapper
-- @readme https://github.com/RoStrap/Helper#make
-- @author Validark

return function(InstanceType)
	return function(Table, ...)
		local Object = Instance.new(InstanceType)
		local Parent = Table.Parent
	
		if Parent then
			Table.Parent = nil
		end
	
		for Property, Value in Table do
			if type(Property) == "number" then
				Value.Parent = Object
			else
				if string.sub(Property, 1, 7) == "RBXTAG_" then
					Object:AddTag(string.gsub(Property, "RBXTAG_", "", 1))
				else
					Object[Property] = Value
				end
			end
		end
	
		if Parent then
			Object.Parent = Parent
		end
	
		if ... then
			local Objects = {...}
			for a = 1, #Objects do
				local Object = Object:Clone()
				for Property, Value in Objects[a] do
					if type(Property) == "number" then
						Value.Parent = Object
					else
						Object[Property] = Value
					end
				end
				Object.Parent = not Object.Parent and Parent
				Objects[a] = Object
			end
			return Object, unpack(Objects)
		else
			return Object
		end
	end
end