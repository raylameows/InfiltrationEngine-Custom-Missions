local stats = {
	postTotal = 0,
	postProcessed = 0,
	postRunning = false
}
local queues = {
	Postprocessing = {},
	Background = {}
}
local states = table.freeze({
	None = `none`,
	Reading = `reading`,
	PostProcessing = `post`,
	Done = `done`
})

local stateMap = {}
for k, v in (states) do
	stateMap[v] = true
end

local function createRunner(name, limit)
	local active = 0
	local queue = queues[name]

	local function runNext()
		if active >= limit then return end

		local job = table.remove(queue, 1)
		if not job then return end

		active += 1

		task.spawn(function()
			local success, error = pcall(job)
			if not success then
				warn(`ReadProcessing : [{name}] : {error}`)
			end

			active -= 1
			if name == `Postprocessing` then
				stats.postProcessed += 1
			end
			runNext()
		end)
	end

	return runNext
end

local runPostprocessing = createRunner(`Postprocessing`, 16)
local runBackground = createRunner(`Background`, 16)

local ReadProcessing = {
	State = states.None,
	States = states,
	Data = {},
	
	-- Sets the current state of processing
	set = function(self, state)
		assert(stateMap[state], `ReadProcessing : Invalid state: {state}`)
		self.State = state
	end,
	
	-- Returns the current state of processing
	get = function(self)
		return self.State
	end,
	
	-- Yields until a certain state of processing is reached
	waitForState = function(self, state)
		repeat task.wait() until self.State == state
	end,
	
	-- Clears the data
	clear = function(self)
		self:set(states.None)
		self.Data = {}
	end,
	
	-- Saves a value under the given key to the data
	remember = function(self, key, value, nest)
		if not nest then
			self.Data[key] = value
		else
			self.Data[nest][key] = value
		end
	end,
	
	-- Returns the value of the given key from the data
	peek = function(self, key, nest)
		return nest and self.Data[nest][key] or self.Data[key]
	end,
	
	Postprocessing = {
		-- Schedules a task to run after reading
		add = function(self, job)
			stats.postTotal += 1
			table.insert(queues.Postprocessing, job)
		end,
		
		-- Runs all the tasks scheduled to run post-reading
		run = function(self)
			stats.postRunning = true
			runPostprocessing()
		end,
		
		-- Yields until all the scheduled post-reading tasks finish
		waitForFinish = function(self)
			repeat task.wait() until stats.postRunning and stats.postProcessed >= stats.postTotal
		end,
	},
	
	Background = {
		-- Performs the job instantly in a seperate thread
		add = function(self, job)
			table.insert(queues.Background, job)
			runBackground()
		end,
	},

	Live = {
		-- Performs the job instantly in the main thread
		add = function(self, job)
			job()
		end,
	}
}

return ReadProcessing