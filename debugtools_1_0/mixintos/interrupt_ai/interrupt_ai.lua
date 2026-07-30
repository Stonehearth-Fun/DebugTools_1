local InterruptAi = class()

InterruptAi.name = 'interrupt the currently running action'
InterruptAi.does = 'stonehearth:top'
InterruptAi.args = {}
InterruptAi.priority = 1

function InterruptAi:run(ai, entity)
   ai:get_log():info('interrupting ai on debugtool request')
   radiant.events.trigger_async(entity, 'debugtools_1_0:ai_interrupted')
   ai:suspend()
end

return InterruptAi
