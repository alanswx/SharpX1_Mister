-- Original read-only MAME reference probe. Inputs are explicit experiments,
-- not verified release instructions. Never patches emulated ROM/RAM.
local machine = manager.machine
local folder = assert(os.getenv("X1_MAME_OUTPUT"), "set a private output folder")
local cpu = assert(machine.devices[":x1_cpu"])
local screen = assert(machine.screens[":screen"])
local checkpoints = {2, 8, 16, 32, 50}
local index = 1
local fields = {}
for _, port in pairs(machine.ioport.ports) do
    for name, field in pairs(port.fields) do fields[name] = field end
end
assert(fields.F and fields.Space and fields.RETURN, "missing keyboard fields")
local tap = cpu.spaces.io:install_write_tap(0x1fa0, 0x1fab, "x1-ctc-reference",
    function(offset, data, mask)
        print(string.format("CTC_WRITE time=%.9f address=%04x data=%02x", emu.time(), offset, data))
        -- No return: preserve the original write unmodified.
    end)
emu.register_frame_done(function()
    assert(tap) -- retain the observation handler for this callback's lifetime
    local time = emu.time()
    fields.F:set_value(time >= 1 and time < 1.2 and 1 or 0)
    fields.Space:set_value(((time >= 8 and time < 8.3) or (time >= 48.5 and time < 48.75)) and 1 or 0)
    fields.RETURN:set_value(time >= 48.05 and time < 48.25 and 1 or 0)
    if index <= #checkpoints and time >= checkpoints[index] then
        local name = string.format("native%d", checkpoints[index])
        local error = screen:snapshot(folder .. "/" .. name .. ".png")
        assert(not error, tostring(error))
        print(string.format("CHECKPOINT time=%.9f PC=%04x SP=%04x IFF1=%d IFF2=%d IM=%d",
            time, cpu.state.PC.value, cpu.state.SP.value,
            cpu.state.IFF1.value, cpu.state.IFF2.value, cpu.state.IM.value))
        index = index + 1
    end
end, "frame")
print("REFERENCE_PROBE_READY")
