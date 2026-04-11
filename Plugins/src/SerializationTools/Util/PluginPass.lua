local Plugin = nil

return function(pluginSource: Plugin?): Plugin?
	if pluginSource then
		Plugin = pluginSource
	end
	
	return Plugin
end