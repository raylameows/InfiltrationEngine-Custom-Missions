local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ThreadControl = require(script.Parent.Parent.Util.ThreadControl)
local Assets = ReplicatedStorage:FindFirstChild("Assets")
local CachedUserMeshFolder
if Assets then
	CachedUserMeshFolder = Assets:FindFirstChild("LoadedMeshes")
	if not CachedUserMeshFolder then
		CachedUserMeshFolder = Instance.new("Folder")
		CachedUserMeshFolder.Name = "LoadedMeshes"
		CachedUserMeshFolder.Parent = Assets
	end
end

local ReadBuild = {}
ReadBuild.__index = ReadBuild

ReadBuild.DefaultConstructionSettings = table.freeze({
	EnableArbitraryMeshes = true, -- Allows inserting mesh parts via InsertService when not cached
	AutoBuild = true, -- Automatically builds the node tree upon construction
	YieldForProtecteds = true, -- Waits for all protected instances to finish building
	ReturnConstructed = true, -- Returns the constructed instance instead of the builder
})
ReadBuild.DefaultConstructionData = table.freeze({
	Protecteds = 0, -- Total number of protected nodes in the tree
	Expensives = 0, -- Total number of expensive properties in the tree
	Processed = 0, -- Number of protected nodes processed so far
})

-- Constructs and optionally builds a node tree based on provided settings
function ReadBuild.construct(nodeTree, data, settings)
	local self = setmetatable({}, ReadBuild)
	self.Root = nodeTree
	self.Settings = ReadBuild.applyDefaultSettings(settings or {})
	self.Data = data
	self.Constructed = nil
	self.ProtectedsThread = ThreadControl.new(16)
	self.ExpensivesThread = ThreadControl.new(16)
	
	if self:GetSetting(`AutoBuild`) == true then
		self.Constructed = self:Build(nodeTree, workspace)
	end
	
	if self:GetSetting(`YieldForProtecteds`) == true then
		repeat task.wait() until self.Data.Processed >= self.Data.Protecteds
	end
	
	if self:GetSetting(`ReturnConstructed`) == true then
		return self.Constructed
	end
	
	return self
end

-- Fills missing settings with defaults
function ReadBuild.applyDefaultSettings(settings)
	for key, value in (ReadBuild.DefaultConstructionSettings) do
		if not settings[key] then
			settings[key] = value
		end
	end
	
	return settings
end

-- Returns a copy of default construction data
function ReadBuild.getDefaultData()
	return table.clone(ReadBuild.DefaultConstructionData)
end

-- Gets a setting's value
function ReadBuild:GetSetting(setting)
	return self.Settings[setting]
end

-- Builds a node into an Instance and parents it
function ReadBuild:Build(node, parent)
	if node.Protected == true then
		return self.ProtectedsThread:Enqueue(function()
			self:ProtectedBuild(node, parent)
		end)
	end
	
	local object = Instance.new(node.Class)
	node.Instance = object
	self:ApplyExpensives(object, node.Expensives)
	self:ApplyProperties(object, node.Properties)
	self:ApplyAttributes(object, node.Attributes)
	self:BuildChildren(node, object)
	object.Parent = parent
	
	return object
end

-- Recursively builds all children of a node
function ReadBuild:BuildChildren(node)
	for index, subNode in (node.Children) do
		self:Build(subNode, node.Instance)
	end
end

-- Handles building of protected nodes (mesh loading, caching, safe property application)
function ReadBuild:ProtectedBuild(node, parent)
	local object = Instance.new(`Part`)
	local instanceInitialized = false
	local meshId = node.Properties.MeshId
	local id = meshId and node.Properties.MeshId:match("%d+")
	if id and #id > 3 then
		meshId = id
	end
	node.Properties.MeshId = nil

	local cachedMeshPart = meshId
		and (
			(
				game.ReplicatedStorage:FindFirstChild("Assets")
				and game.ReplicatedStorage.Assets:FindFirstChild("ImportParts")
				and game.ReplicatedStorage.Assets.ImportParts:FindFirstChild(meshId)
			) or (CachedUserMeshFolder and CachedUserMeshFolder:FindFirstChild(meshId))
		)
	if cachedMeshPart then
		object = cachedMeshPart:Clone()
		node.Properties.CollisionFidelity = nil
		node.Properties.RenderFidelity = nil
		instanceInitialized = true
	elseif meshId and self:GetSetting(`EnableArbitraryMeshes`) == true then
		local success, instOrReason = pcall(function()
			local part = InsertService:CreateMeshPartAsync(
				`rbxassetid://{meshId}`,
				node.Properties["CollisionFidelity"] or Enum.CollisionFidelity.Default,
				node.Properties["RenderFidelity"] or Enum.RenderFidelity.Automatic
			)
			if CachedUserMeshFolder then
				local copy = part:Clone()
				copy.Name = meshId
				copy.Parent = CachedUserMeshFolder
			end

			node.Instance = part
			self:ApplyExpensives(object, node.Expensives)
			self:ApplyProtectedProperties(part, node.Properties)
			self:ApplyAttributes(part, node.Attributes)
			self:IncrementData(`Processed`, 1)
			self:BuildChildren(node)
			part.Parent = parent

			return part
		end)

		node.Properties.CollisionFidelity = nil
		node.Properties.RenderFidelity = nil
		if success then
			object = instOrReason
			instanceInitialized = true
		end
	end

	node.Instance = object
	self:ApplyExpensives(object, node.Expensives)
	self:ApplyProtectedProperties(object, node.Properties)
	self:ApplyAttributes(object, node.Attributes)
	self:IncrementData(`Processed`, 1)
	self:BuildChildren(node)
	object.Parent = parent

	return object
end

-- Applies expensive properties asynchronously via thread queue
function ReadBuild:ApplyExpensives(object, expensives)
	if not expensives then return end
	for expensive, value in (expensives) do
		self.ExpensivesThread:Enqueue(function()
			object[expensive] = self:ResolvePath(value)
		end)
	end
end

-- Applies properties directly to an instance
function ReadBuild:ApplyProperties(object, properties)
	for property, value in (properties) do
		object[property] = value
	end
end

-- Applies properties safely using pcall
function ReadBuild:ApplyProtectedProperties(object, properties)
	for property, value in (properties) do
		pcall(function()
			object[property] = value
		end)
	end
end

-- Applies attributes to an instance
function ReadBuild:ApplyAttributes(object, attributes)
	if not attributes then return end
	for attribute, value in (attributes) do
		object:SetAttribute(attribute, value)
	end
end

-- Resolves a path string to an instance, yielding if necessary
function ReadBuild:ResolvePath(pathString)
	local path = string.split(pathString, `.`)
	local current = self.Root
	for _, v in (path) do
		local index = tonumber(v)
		current = current.Children[index]
	end

	if not current.Instance then repeat task.wait() until current.Instance end -- Ensure that the instance the path references exists
	return current.Instance
end

-- Increments a value in the construction data
function ReadBuild:IncrementData(key, value)
	self.Data[key] += value
end

return ReadBuild