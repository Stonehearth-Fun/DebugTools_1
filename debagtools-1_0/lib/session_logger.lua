local SessionLogger = {}

local log = radiant.log.create_logger('debugtools_session')

local _active_path = nil
local _active_handle = nil
local _session_started = false
local _sequence = 0

local _candidate_directories = {
   'debugtools/logs',
   'mods/debugtools/logs',
   '../mods/debugtools/logs',
}

local function _safe_tostring(value)
   if value == nil then
      return 'nil'
   end

   if type(value) == 'boolean' then
      return value and 'true' or 'false'
   end

   return tostring(value)
end

local function _format_payload(payload)
   if type(payload) ~= 'table' then
      return _safe_tostring(payload)
   end

   local keys = {}
   for key in pairs(payload) do
      keys[#keys + 1] = key
   end
   table.sort(keys)

   local parts = {}
   for _, key in ipairs(keys) do
      parts[#parts + 1] = key .. '=' .. _safe_tostring(payload[key])
   end

   return table.concat(parts, ' ')
end

local function _get_session_stamp()
   if os and os.date then
      local ok, stamp = pcall(os.date, '%Y%m%d_%H%M%S')
      if ok and stamp then
         return stamp
      end
   end

   if radiant and radiant.gamestate and radiant.gamestate.now then
      local ok, now = pcall(radiant.gamestate.now)
      if ok and now then
         return tostring(now)
      end
   end

   _sequence = _sequence + 1
   return string.format('session_%03d', _sequence)
end

local function _build_session_file_name()
   return string.format('save_session_%s.log', _get_session_stamp())
end

local function _open_handle(file_name)
   if not io or not io.open then
      return nil, 'io.open unavailable'
   end

   for _, directory in ipairs(_candidate_directories) do
      local path = string.format('%s/%s', directory, file_name)
      local ok, handle = pcall(io.open, path, 'a')
      if ok and handle then
         return handle, path
      end
   end

   return nil, 'no writable debugtools/logs path found'
end

local function _close_handle()
   if _active_handle then
      pcall(function()
         _active_handle:flush()
         _active_handle:close()
      end)
   end

   _active_handle = nil
end

local function _emit(level, tag, message, payload)
   local formatted_payload = _format_payload(payload)
   local line = string.format('[DEBUGTOOLS:%s] %s', tag, message)
   if formatted_payload ~= '' then
      line = line .. ' ' .. formatted_payload
   end

   if level == 'warn' then
      log:warning('%s', line)
   elseif level == 'error' then
      log:error('%s', line)
   else
      log:info('%s', line)
   end

   if _active_handle then
      local ok = pcall(function()
         _active_handle:write(line .. '\n')
         _active_handle:flush()
      end)
      if not ok then
         _close_handle()
      end
   end
end

function SessionLogger.start_session(reason, payload)
   _close_handle()

   local file_name = _build_session_file_name()
   local handle, path_or_error = _open_handle(file_name)
   _active_handle = handle
   _active_path = handle and path_or_error or nil
   _session_started = true

   _emit('info', 'SESSION_START', reason or 'session logger started', payload or {})

   if _active_path then
      log:info('[DEBUGTOOLS:SESSION_FILE] %s', _active_path)
      return true, _active_path
   end

   log:warning('[DEBUGTOOLS:SESSION_FILE] fallback to shared log only: %s', tostring(path_or_error))
   return false, path_or_error
end

function SessionLogger.stop_session(reason, payload)
   if not _session_started then
      return
   end

   _emit('info', 'SESSION_END', reason or 'session logger stopped', payload or {})
   _close_handle()
   _active_path = nil
   _session_started = false
end

function SessionLogger.write(tag, message, payload)
   if not _session_started then
      return false
   end

   _emit('info', tag or 'EVENT', message or 'session event', payload or {})
   return true
end

function SessionLogger.warn(tag, message, payload)
   if not _session_started then
      return false
   end

   _emit('warn', tag or 'WARN', message or 'session warning', payload or {})
   return true
end

function SessionLogger.error(tag, message, payload)
   if not _session_started then
      return false
   end

   _emit('error', tag or 'ERROR', message or 'session error', payload or {})
   return true
end

function SessionLogger.get_active_path()
   return _active_path
end

return SessionLogger
