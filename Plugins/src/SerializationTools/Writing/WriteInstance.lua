local StringConversion = require(script.Parent.Parent.Util.StringConversion)
local InstanceProperties = require(script.Parent.Parent.Types.InstanceProperties)
local AttributeTypes = require(script.Parent.Parent.Types.AttributeTypes)
local AttributeValidation = require(script.Parent.Parent.AttributeValidation)
local plugin = require(script.Parent.Parent.Util.PluginPass)()

local WriteInstance
local DefaultFlags = { -- Some instances may use additional features, those are enabled via flags
	Attributes = false, -- Whether the attributes of the instance should be serialized
}

local function LookupMapIndex(map, value)
	if value == nil then
		return 0
	end
	if typeof(value) == "Color3" then
		value = value:ToHex()
	end
	local idx = map[value]
	if idx == nil then
		idx = (map[0] + 1) -- Size + 1
		map[value] = idx
		map[0] = idx -- Update size
	end

	return idx
end

local function CreateInstanceWriter(properties, flags)
	if not flags then flags = DefaultFlags end

	local InstanceWriter = function(object, Write, colorMap, stringMap)
		local chunks = {}
		if object.ClassName == `NegateOperation` then print(`Hola!`) end
		for i, v in (properties) do
			local property, valueType, defaultValue = unpack(v)
			
			local value
			if property == "MeshId" and object.ClassName == "UnionOperation" then
				value = object:GetAttribute("MeshId")
				if not value then
					continue
				end
			elseif valueType == "CSG" and object.ClassName == "UnionOperation" and not object:GetAttribute(`MeshId`) then
				value = plugin:Separate({object})
			else
				value = object[property]
			end
			
			if (valueType == "Color3") and (value ~= defaultValue) then
				local index = LookupMapIndex(colorMap, value)
				table.insert(chunks, StringConversion.NumberToString(i, 1))
				table.insert(chunks, Write.ShortInt(index))
				continue
			elseif (valueType == "String") and (value ~= defaultValue) then
				local index = LookupMapIndex(stringMap, value)
				table.insert(chunks, StringConversion.NumberToString(i, 1))
				table.insert(chunks, Write.ShortInt(index))
				continue
			elseif (valueType == "CSG") then
				table.insert(chunks, StringConversion.NumberToString(i, 1))
				table.insert(chunks, Write.CSG(value, colorMap, stringMap))
				continue
			elseif value ~= defaultValue then
				table.insert(chunks, StringConversion.NumberToString(i, 1))
				table.insert(chunks, Write[valueType](value))
			end
		end
		
		table.insert(chunks, StringConversion.NumberToString(0, 1)) -- Mark end of property serialization for this Instance

		if flags.Attributes then
			local attributes = object:GetAttributes()
			attributes = AttributeValidation.Validate(object.ClassName, object.Name, attributes, false)

			-- Encoding Attributes
			for k, v in (attributes) do
				if k:match("^RBX_") then
					continue
				end

				local attributeType = typeof(v) -- Changing attribute type names to match as they are in the Write file
				if attributeType == "number" then
					if v ~= math.round(v) or v < 0 then
						attributeType = "Float"
					else
						attributeType = "LongInt"
					end
				elseif attributeType == "boolean" then
					attributeType = "bool"
				end
				attributeType = (string.upper(string.sub(attributeType, 1, 1)) .. string.sub(attributeType, 2, -1))
				if AttributeTypes[attributeType] == nil then -- if the attribute is not in the table, ignore it
					continue
				end

				local index = LookupMapIndex(stringMap, k)
				table.insert(chunks, StringConversion.NumberToString(AttributeTypes[attributeType], 1))
				table.insert(chunks, Write.ShortInt(index))

				if attributeType == "Color3" then
					local index = LookupMapIndex(colorMap, v)
					table.insert(chunks, Write.ShortInt(index))
				elseif attributeType == "String" then
					local index = LookupMapIndex(stringMap, v)
					table.insert(chunks, Write.ShortInt(index))
				else
					table.insert(chunks, Write[attributeType](v))
				end
			end
			table.insert(chunks, StringConversion.NumberToString(0, 1)) -- Mark end of attribute serialization for this Instance
		end

		local str = table.concat(chunks)
		return str, colorMap, stringMap
	end

	return InstanceWriter
end

WriteInstance = {
	Model = CreateInstanceWriter(InstanceProperties.Model, {Attributes = true}),
	Folder = CreateInstanceWriter(InstanceProperties.Folder, {Attributes = true}),
	Part = CreateInstanceWriter(InstanceProperties.Part, {Attributes = true}),
	PartNoAttributes = CreateInstanceWriter(InstanceProperties.Part),
	BoolValue = CreateInstanceWriter(InstanceProperties.BoolValue, {Attributes = true}),
	WedgePart = CreateInstanceWriter(InstanceProperties.WedgePart),
	StringValue = CreateInstanceWriter(InstanceProperties.StringValue),
	MeshPart = CreateInstanceWriter(InstanceProperties.MeshPart, {Attributes = true}),
	UnionOperation = CreateInstanceWriter(InstanceProperties.UnionOperation, {Attributes = true}),
	Texture = CreateInstanceWriter(InstanceProperties.Texture),
	BlockMesh = CreateInstanceWriter(InstanceProperties.BlockMesh),
	PointLight = CreateInstanceWriter(InstanceProperties.PointLight),
	SpotLight = CreateInstanceWriter(InstanceProperties.SpotLight),
	SurfaceLight = CreateInstanceWriter(InstanceProperties.SurfaceLight),
	SpecialMesh = CreateInstanceWriter(InstanceProperties.SpecialMesh),
	Decal = CreateInstanceWriter(InstanceProperties.Decal),
	Fire = CreateInstanceWriter(InstanceProperties.Fire),
	Smoke = CreateInstanceWriter(InstanceProperties.Smoke),
	Attachment = CreateInstanceWriter(InstanceProperties.Attachment),
	ParticleEmitter = CreateInstanceWriter(InstanceProperties.ParticleEmitter),
	Sparkles = CreateInstanceWriter(InstanceProperties.Sparkles),
	SurfaceGui = CreateInstanceWriter(InstanceProperties.SurfaceGui),
	ImageLabel = CreateInstanceWriter(InstanceProperties.ImageLabel),
	BillboardGui = CreateInstanceWriter(InstanceProperties.BillboardGui),
	Frame = CreateInstanceWriter(InstanceProperties.Frame),
	Beam = CreateInstanceWriter(InstanceProperties.Beam),
	Trail = CreateInstanceWriter(InstanceProperties.Trail),
	NegateOperation = CreateInstanceWriter(InstanceProperties.NegateOperation),
}

return WriteInstance