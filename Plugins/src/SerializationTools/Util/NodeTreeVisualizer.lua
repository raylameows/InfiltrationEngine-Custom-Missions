local Visualize

local PriorityOrder = {
	Root = 1,
	Type = 2,
	Properties = 3,
	Attributes = 4,
	CSG = 5,
	Children = 6,
	Expensives = 7,
	Processed = 8,
	Protecteds = 9,
	-- Everything after is sorted alphabetically
}
local ValueHandlers = {
	[`table`] = function(value, indent, indentStr, nextIndentStr)
		if next(value) == nil then
			return "{}"
		end

		local result = "{\n"
		local keys = {}
		for k in (value) do
			table.insert(keys, k)
		end

		table.sort(keys, function(a, b)
			local aPriority = PriorityOrder[a]
			local bPriority = PriorityOrder[b]
			if aPriority and bPriority then
				return aPriority < bPriority
			end
			if aPriority then return true end
			if bPriority then return false end
			return tostring(a) < tostring(b)
		end)

		for _, k in ipairs(keys) do
			local v = value[k]

			local key
			if typeof(k) == "string" and k:match("^%a[%w_]*$") then
				key = k
			else
				key = "[" .. Visualize(k, indent + 1) .. "]"
			end

			result ..= nextIndentStr .. key .. " = " .. Visualize(v, indent + 1) .. ",\n"
		end

		result ..= indentStr .. "}"
		return result
	end,
	[`string`] = function(value)
		if value:find("\n") then
			return "[[\n" .. value .. "]]"
		elseif value:find(`"`) then
			return "[[" .. value .. "]]"
		else
			return string.format("%q", value)
		end
	end,
	[`number`] = tostring,
	[`boolean`] = tostring,
	[`Vector3`] = function(value)
		return `Vector3.new({value.X}, {value.Y}, {value.Z})`
	end,
	[`Color3`] = function(value)
		return `Color3.new({value.R}, {value.G}, {value.B})`
	end,
	[`CFrame`] = function(value)
		return `CFrame.new({tostring(value)})`
	end,
	[`EnumItem`] = function(value)
		return tostring(value)
	end,
	[`nil`] = function()
		return "nil"
	end,
	[`unknown`] = function(value, _, _, _, valueType)
		return `nil --[[({valueType}) | ({tostring(value)})]]`
	end,
}

Visualize = function(value, indent)
	indent = indent or 0

	local indentStr = string.rep("\t", indent)
	local nextIndentStr = string.rep("\t", indent + 1)

	local valueType = typeof(value)
	local handler = ValueHandlers[valueType]
	local pass = {value, indent, indentStr, nextIndentStr, valueType}

	if handler then
		return handler(unpack(pass))
	else
		return ValueHandlers.unknown(unpack(pass))
	end
end

return Visualize