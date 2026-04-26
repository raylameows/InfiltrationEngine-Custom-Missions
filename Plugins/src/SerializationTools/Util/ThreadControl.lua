local ThreadControl = {}
ThreadControl.__index = ThreadControl

function ThreadControl.new(limit)
	local self = setmetatable({}, ThreadControl)
	self.Limit = limit or 16
	self.Active = 0
	self.Queue = {}

	return self
end

function ThreadControl:RunNextThread()
	if self.Active >= self.Limit then return end

	local job = table.remove(self.Queue, 1)
	if not job then return end

	self.Active += 1
	task.spawn(function()
		job()
		self.Active -= 1
		self:RunNextThread()
	end)
end

function ThreadControl:Enqueue(job)
	table.insert(self.Queue, job)
	self:RunNextThread()
end

return ThreadControl