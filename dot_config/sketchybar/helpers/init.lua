-- Add the sketchybar module to the package cpath
package.cpath = package.cpath .. ";/Users/" .. os.getenv("USER") .. "/.local/share/sketchybar_lua/?.so"

os.execute("(cd helpers && make)")

-- Single-quote a value for a shell command. Device names are set by whoever owns
-- the device, so `"` + `;` in one must not run anything.
function shell_quote(s)
    return "'" .. (tostring(s):gsub("'", "'\\''")) .. "'"
end
