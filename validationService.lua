local M = {}

--- Validates a value type
--- @example
--- ```lua
--- validationService.validateType('text', 'value', 'string')
--- ```
--- @param value any the value to validate
--- @param name string the parameter name
--- @param expectedType string the expected Lua type
--- @param optional boolean|nil whether nil is allowed
--- @return nil
function M.validateType(value, name, expectedType, optional)
  if optional and value == nil then
    return
  end

  if type(value) ~= expectedType then
    error(name .. ' must be a ' .. expectedType)
  end
end

--- Validates an integer
--- @example
--- ```lua
--- validationService.validateInt(42, 'value')
--- ```
--- @param value any the value to validate
--- @param name string the parameter name
--- @return nil
function M.validateInt(value, name)
  if type(value) ~= 'number' or value % 1 ~= 0 then
    error(name .. ' must be an integer')
  end
end

--- Validates a non-negative integer
--- @example
--- ```lua
--- validationService.validateNonNegativeInt(0, 'value')
--- ```
--- @param value any the value to validate
--- @param name string the parameter name
--- @return nil
function M.validateNonNegativeInt(value, name)
  M.validateInt(value, name)

  if value < 0 then
    error(name .. ' must be a non-negative integer')
  end
end

--- Validates a string
--- @example
--- ```lua
--- validationService.validateString('text', 'value')
--- ```
--- @param value any the value to validate
--- @param name string the parameter name
--- @param optional boolean|nil whether nil is allowed
--- @return nil
function M.validateString(value, name, optional)
  M.validateType(value, name, 'string', optional)
end

--- Validates a boolean
--- @example
--- ```lua
--- validationService.validateBoolean(true, 'value')
--- ```
--- @param value any the value to validate
--- @param name string the parameter name
--- @param optional boolean|nil whether nil is allowed
--- @return nil
function M.validateBoolean(value, name, optional)
  M.validateType(value, name, 'boolean', optional)
end

--- Validates a table
--- @example
--- ```lua
--- validationService.validateTable({}, 'value')
--- ```
--- @param value any the value to validate
--- @param name string the parameter name
--- @param optional boolean|nil whether nil is allowed
--- @return nil
function M.validateTable(value, name, optional)
  M.validateType(value, name, 'table', optional)
end

--- Validates that a value belongs to an allowed list
--- @example
--- ```lua
--- validationService.validateOneOf('small', 'size', { 'small', 'large' })
--- ```
--- @param value any the value to validate
--- @param name string the parameter name
--- @param allowedValues any[] the allowed values
--- @return nil
function M.validateOneOf(value, name, allowedValues)
  for _, allowedValue in ipairs(allowedValues) do
    if value == allowedValue then
      return
    end
  end

  error(name .. ' must be one of: ' .. table.concat(allowedValues, ', '))
end

return M
