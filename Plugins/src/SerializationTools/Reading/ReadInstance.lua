local ENABLE_ARBITRARY_MESHES = true

local StringConversion = require(script.Parent.Parent.Util.StringConversion)
local InstanceProperties = require(script.Parent.Parent.Types.InstanceProperties)
local DefaultProperties = require(script.Parent.Parent.Types.DefaultProperties)
local AttributeTypes = require(script.Parent.Parent.Types.AttributeTypes)
local AttributeValidation = require(script.Parent.Parent.AttributeValidation)
local ReadBuild = require(script.Parent.ReadBuild)

local AttributeKeys = {}
for i, v in (AttributeTypes) do
	AttributeKeys[v] = i
end

local ReadInstance
local DefaultFlags = { -- Some instances may use additional features, those are enabled via flags
	Protected = false, -- The instance will be handled in a protected call during instance creation
	Attributes = false, -- The string code will be checked for potential attributes. If said attributes are valid they will be applied to the instance
}
local rootNode

local CreateInstanceReader = function(instanceType, properties, flags)
	if not flags then flags = DefaultFlags end
	local defaults = DefaultProperties[instanceType]

	local InstanceReader = function(str, cursor, Read, colorMap, stringMap)
		local node = {
			Type = instanceType, -- The type of the Instance
			Children = {}, -- Children of the Instance
			Attributes = {}, -- Attributes of the Instance
			Properties = {}, -- Properties of the Instance
		}
		if flags.Protected then -- Whether the Instance is protected
			node.Protected = true
			ReadBuild.rootNode.Protecteds += 1
		end

		if defaults then
			for k, v in (defaults) do
				node.Properties[k] = v
			end
		end
		for i, v in (properties) do -- Set the properties of the instance to the defaults, as defined in InstanceProperties.lua
			node.Properties[v[1]] = v[3]
		end

		local propertyId = StringConversion.StringToNumber(str, cursor, 1)
		cursor += 1
		while not (propertyId == 0) do
			local typeName = properties[propertyId][1]
			local valueType = properties[propertyId][2]
			if valueType == "Color3" then
				local colorMapIndex
				colorMapIndex, cursor = Read.ShortInt(str, cursor)
				node.Properties[typeName] = colorMap[colorMapIndex]
			elseif valueType == "String" then
				local stringMapIndex
				stringMapIndex, cursor = Read.ShortInt(str, cursor)
				node.Properties[typeName] = stringMap[stringMapIndex]
			elseif valueType == "InstanceReference" then
				local pathString, newCursor = Read.String(str, cursor)
				cursor = newCursor
				if not node.Expensive then node.Expensive = {} end -- Create a dictionary of expensive properties in the node if it's missing
				node.Expensive[typeName] = pathString -- Set the property as an expensive property. Expensive properties get special treatment during instance creation
				ReadBuild.rootNode.Expensives += 1 -- Inform the code of how many expensive properties exist
			else
				node.Properties[typeName], cursor = Read[valueType](str, cursor)
			end
			propertyId = StringConversion.StringToNumber(str, cursor, 1)
			cursor += 1
		end

		if flags.Attributes then -- Check for potential attributes if the flag is enabled
			local attributeId = StringConversion.StringToNumber(str, cursor, 1)
			cursor += 1
			while not (attributeId == 0) do
				local typeName = AttributeKeys[attributeId]
				local nameMapIndex
				nameMapIndex, cursor = Read.ShortInt(str, cursor)
				local name = stringMap[nameMapIndex]
				local value
				if typeName == "Color3" then
					local colorMapIndex
					colorMapIndex, cursor = Read.ShortInt(str, cursor)
					value = colorMap[colorMapIndex]
				elseif typeName == "String" then
					local valueMapIndex
					valueMapIndex, cursor = Read.ShortInt(str, cursor)
					value = stringMap[valueMapIndex]
				else
					value, cursor = Read[typeName](str, cursor)
				end
				node.Attributes[name] = value
				attributeId = StringConversion.StringToNumber(str, cursor, 1)
				cursor += 1
			end
			node.Attributes = AttributeValidation.Validate(node.Properties.ClassName, node.Properties.Name, node.Attributes, true) -- Validate the attributes
		end

		return node, cursor
	end

	return InstanceReader
end

ReadInstance = {
	Model = CreateInstanceReader(`Model`, InstanceProperties.Model, {Attributes = true}),
	Folder = CreateInstanceReader(`Folder`, InstanceProperties.Folder, {Attributes = true}),
	Part = CreateInstanceReader(`Part`, InstanceProperties.Part, {Attributes = true}),
	PartNoAttributes = CreateInstanceReader("Part", InstanceProperties.Part),
	BoolValue = CreateInstanceReader(`BoolValue`, InstanceProperties.BoolValue, {Attributes = true}),
	WedgePart = CreateInstanceReader("WedgePart", InstanceProperties.WedgePart),
	StringValue = CreateInstanceReader("StringValue", InstanceProperties.StringValue),
	MeshPart = CreateInstanceReader(`MeshPart`, InstanceProperties.MeshPart, {Attributes = true, Protected = true}),
	UnionOperation = CreateInstanceReader(`UnionOperation`, InstanceProperties.UnionOperation, {Attributes = true, Protected = true}),
	Texture = CreateInstanceReader("Texture", InstanceProperties.Texture),
	BlockMesh = CreateInstanceReader("BlockMesh", InstanceProperties.BlockMesh),
	PointLight = CreateInstanceReader("PointLight", InstanceProperties.PointLight),
	SpotLight = CreateInstanceReader("SpotLight", InstanceProperties.SpotLight),
	SurfaceLight = CreateInstanceReader("SurfaceLight", InstanceProperties.SurfaceLight),
	SpecialMesh = CreateInstanceReader("SpecialMesh", InstanceProperties.SpecialMesh),
	Decal = CreateInstanceReader("Decal", InstanceProperties.Decal),
	Fire = CreateInstanceReader("Fire", InstanceProperties.Fire),
	Smoke = CreateInstanceReader("Smoke", InstanceProperties.Smoke),
	Attachment = CreateInstanceReader("Attachment", InstanceProperties.Attachment),
	ParticleEmitter = CreateInstanceReader("ParticleEmitter", InstanceProperties.ParticleEmitter),
	Sparkles = CreateInstanceReader("Sparkles", InstanceProperties.Sparkles),
	SurfaceGui = CreateInstanceReader("SurfaceGui", InstanceProperties.SurfaceGui),
	ImageLabel = CreateInstanceReader("ImageLabel", InstanceProperties.ImageLabel),
	BillboardGui = CreateInstanceReader("BillboardGui", InstanceProperties.BillboardGui),
	Frame = CreateInstanceReader("Frame", InstanceProperties.Frame),
	Beam = CreateInstanceReader("Beam", InstanceProperties.Beam),
	Trail = CreateInstanceReader("Trail", InstanceProperties.Trail),
}

return ReadInstance