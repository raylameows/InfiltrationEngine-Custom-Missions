local InstanceProperties = require(script.Parent.Parent.Types.InstanceProperties)
local DefaultProperties = require(script.Parent.Parent.Types.DefaultProperties)
local AttributeTypes = require(script.Parent.Parent.Types.AttributeTypes)
local AttributeValidation = require(script.Parent.Parent.AttributeValidation)

local VersionConfig = require(script.Parent.Parent.Util.VersionConfig)

local ReadPrimitive = require(script.Parent.ReadPrimitive)

local AttributeKeys = {}
for i, v in pairs(AttributeTypes) do
	AttributeKeys[v] = i
end

local function readCFrame(str, cursor, vectorMap)
	local pIdx, cursor = ReadPrimitive.LongInt(str, cursor)
	local xIdx, cursor = ReadPrimitive.LongInt(str, cursor)
	local yIdx, cursor = ReadPrimitive.LongInt(str, cursor)
	
	local pos  = vectorMap[pIdx]
	local xVec = vectorMap[xIdx]
	local yVec = vectorMap[yIdx]
	
	return CFrame.fromMatrix(pos, xVec, yVec), cursor
end

local function readValue(str, cursor, vType, colorMap, stringMap, vectorMap)
	local value
	local expensive = false
	if vType == "Color3" then
		local colorMapIndex
		colorMapIndex, cursor = ReadPrimitive.ShortInt(str, cursor)
		value = colorMap[colorMapIndex]
	elseif vType == "String" then
		local valueMapIndex
		valueMapIndex, cursor = ReadPrimitive.ShortInt(str, cursor)
		value = stringMap[valueMapIndex]
	elseif vType == "Vector3" and VersionConfig.UseVectorMap then
		local vecMapIndex
		vecMapIndex, cursor = ReadPrimitive.LongInt(str, cursor)
		value = vectorMap[vecMapIndex]
	elseif vType == "CFrame" and VersionConfig.UseVectorMap then
		value, cursor = readCFrame(str, cursor, vectorMap)
	elseif vType == "InstanceReference" then
		value, cursor = ReadPrimitive[vType](str, cursor)
		expensive = true
	else
		value, cursor = ReadPrimitive[vType](str, cursor)
	end
	
	return value, cursor, expensive
end

local WithAttributes = function(DefaultReader)
	return function(str, cursor, colorMap, stringMap, vectorMap)
		local node
		node, cursor = DefaultReader(str, cursor, colorMap, stringMap, vectorMap)
		node.Attributes = {}
		
		local attributeId = ReadPrimitive.ShortestInt(str, cursor)
		cursor += 1
		while not (attributeId == 0) do
			local typeName = AttributeKeys[attributeId]
			local nameMapIndex
			nameMapIndex, cursor = ReadPrimitive.ShortInt(str, cursor)
			local name = stringMap[nameMapIndex]
			local value
			value, cursor = readValue(str, cursor, typeName, colorMap, stringMap, vectorMap)
			node.Attributes[name] = value
			attributeId = ReadPrimitive.ShortestInt(str, cursor)
			cursor += 1
		end
		
		local attributes = node.Attributes
		attributes = AttributeValidation.Validate(node.Class, node.Properties.Name, attributes, true)
		for k, v in (attributes) do
			node.Attributes[k] = v
		end
		
		return node, cursor
	end
end

local ReadInstance

local CreateInstanceReader = function(instanceType, properties, protected)
	local defaults = DefaultProperties[instanceType]

	local InstanceReader = function(str, cursor, colorMap, stringMap, vectorMap)
		local node = {
			Class = instanceType,
			Properties = {},
			Children = {},
			Protected = protected,
		}
		
		if defaults then
			for k, v in (defaults) do
				node.Properties[k] = v
			end
		end
		
		for i, v in (properties) do
			node.Properties[v[1]] = v[3]
		end
		
		local propertyId = ReadPrimitive.ShortestInt(str, cursor)
		cursor += 1
		while not (propertyId == 0) do
			local typeName = properties[propertyId][1]
			local valueType = properties[propertyId][2]
			local value, expensive
			value, cursor, expensive = readValue(str, cursor, valueType, colorMap, stringMap, vectorMap)
			if value ~= nil then 
				if not expensive then
					node.Properties[typeName] = value 
				elseif expensive then
					if not node.Expensives then 
						node.Expensives = {} 
					end

					node.Expensives[typeName] = value 
				end
			end
			
			propertyId = ReadPrimitive.ShortestInt(str, cursor)
			cursor += 1
		end
		
		return node, cursor
	end
	
	return InstanceReader
end

ReadInstance = {
	Model            = WithAttributes(         CreateInstanceReader("Model", InstanceProperties.Model)),
	Folder           = WithAttributes(         CreateInstanceReader("Folder", InstanceProperties.Folder)),
	Part             = WithAttributes(         CreateInstanceReader("Part", InstanceProperties.Part)),
	PartNoAttributes =                         CreateInstanceReader("Part", InstanceProperties.Part),
	BoolValue        = WithAttributes(         CreateInstanceReader("BoolValue", InstanceProperties.BoolValue)),
	WedgePart        =                         CreateInstanceReader("WedgePart", InstanceProperties.WedgePart),
	StringValue      =                         CreateInstanceReader("StringValue", InstanceProperties.StringValue),
	MeshPart         = WithAttributes(		   CreateInstanceReader("MeshPart", InstanceProperties.MeshPart, true)),
	UnionOperation   = WithAttributes(		   CreateInstanceReader("UnionOperation", InstanceProperties.UnionOperation, true)),
	Texture          =                         CreateInstanceReader("Texture", InstanceProperties.Texture),
	BlockMesh        =                         CreateInstanceReader("BlockMesh", InstanceProperties.BlockMesh),
	PointLight       =                         CreateInstanceReader("PointLight", InstanceProperties.PointLight),
	SpotLight        =                         CreateInstanceReader("SpotLight", InstanceProperties.SpotLight),
	SurfaceLight     =                         CreateInstanceReader("SurfaceLight", InstanceProperties.SurfaceLight),
	SpecialMesh      =                         CreateInstanceReader("SpecialMesh", InstanceProperties.SpecialMesh),
	Decal            =                         CreateInstanceReader("Decal", InstanceProperties.Decal),
	Fire             =                         CreateInstanceReader("Fire", InstanceProperties.Fire),
	Smoke            =                         CreateInstanceReader("Smoke", InstanceProperties.Smoke),
	Attachment       =                         CreateInstanceReader("Attachment", InstanceProperties.Attachment),
	ParticleEmitter  =                         CreateInstanceReader("ParticleEmitter", InstanceProperties.ParticleEmitter),
	Sparkles         =                         CreateInstanceReader("Sparkles", InstanceProperties.Sparkles),
	SurfaceGui       =                         CreateInstanceReader("SurfaceGui", InstanceProperties.SurfaceGui),
	ImageLabel       =                         CreateInstanceReader("ImageLabel", InstanceProperties.ImageLabel),
	BillboardGui     =                         CreateInstanceReader("BillboardGui", InstanceProperties.BillboardGui),
	Frame            =                         CreateInstanceReader("Frame", InstanceProperties.Frame),
	Beam             =                         CreateInstanceReader("Beam", InstanceProperties.Beam),
	Trail            =                         CreateInstanceReader("Trail", InstanceProperties.Trail),
}

return ReadInstance
