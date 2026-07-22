local SessionLogger = require 'debugtools.lib.session_logger'

local SessionLoggerService = class()

local function _safe_call(fn, ...)
   local ok, result = pcall(fn, ...)
   if ok then
      return result
   end
end

function SessionLoggerService:initialize()
   self._sv = self.__saved_variables:get_data()

   if not self._sv.initialized then
      self._sv.initialized = true
      self._sv.sessions_started = 0
      self._sv.last_session_reason = nil
      self._sv.last_session_path = nil
   end

   self._game_loaded_listener = radiant.events.listen(radiant, 'radiant:game_loaded', self, self._on_game_loaded)
   self._shut_down_listener = radiant.events.listen_once(radiant, 'radiant:shut_down', self, self.destroy)
end

function SessionLoggerService:_start_session(reason)
   self._sv.sessions_started = (self._sv.sessions_started or 0) + 1
   self._sv.last_session_reason = reason

   local payload = {
      reason = reason,
      sessions_started = self._sv.sessions_started,
      game_time = _safe_call(radiant.gamestate.now),
      game_id = stonehearth and stonehearth.game_creation and _safe_call(stonehearth.game_creation.get_game_id, stonehearth.game_creation),
   }

   local opened, path_or_error = SessionLogger.start_session(reason, payload)
   self._sv.last_session_path = opened and path_or_error or nil
   self.__saved_variables:mark_changed()
end

function SessionLoggerService:_on_game_loaded()
   self:_start_session('save loaded')
end

function SessionLoggerService:write_command(session, response, tag, message, payload)
   local written = SessionLogger.write(tag, message, payload)
   response:resolve({
      written = written,
      path = SessionLogger.get_active_path(),
   })
end

function SessionLoggerService:destroy()
   if self._game_loaded_listener then
      self._game_loaded_listener:destroy()
      self._game_loaded_listener = nil
   end

   if self._shut_down_listener then
      self._shut_down_listener:destroy()
      self._shut_down_listener = nil
   end

   SessionLogger.stop_session('service destroyed')
end

return SessionLoggerService
