debugtools_1_0 = {
}

local service_creation_order = {
   'entity_tracker',
   'session_logger',
}

local function create_service(name)
   local path = string.format('debugtools_1_0.services.server.%s.%s_service', name, name)
   local service_path = require(path)
   assert(service_path, "Could not find a debug tools service. Are you sure your debugtools_1_0 mod folder is named correctly? It should be 'debugtools_1_0' not 'debugtools_1_0_master'")
   local service = service_path()

   local saved_variables = debugtools_1_0._sv[name]
   if not saved_variables then
      saved_variables = radiant.create_datastore()
      debugtools_1_0._sv[name] = saved_variables
   end
   service.__saved_variables = saved_variables
   service._sv = saved_variables:get_data()
   saved_variables:set_controller(service)
   service:initialize()
   debugtools_1_0[name] = service
end

radiant.events.listen(debugtools_1_0, 'radiant:init', function()
      debugtools_1_0._sv = debugtools_1_0.__saved_variables:get_data()
      -- now create all the services
      for _, name in ipairs(service_creation_order) do
         create_service(name)
      end
   end)

return debugtools_1_0
