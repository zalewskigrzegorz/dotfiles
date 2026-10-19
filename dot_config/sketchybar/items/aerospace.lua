function parse_string_to_table(s)
    local result = {}
    for line in s:gmatch("([^\n]+)") do
        table.insert(result, line)
    end
    return result
end

function get_current_workspace()
    local file = io.popen("aerospace list-workspaces --focused")
    if not file then
        return nil
    end
    local result = file:read("*a")
    file:close()
    if not result then
        return nil
    end
    return parse_string_to_table(result)[1]
end
