-- SPDX-License-Identifier: GPL-2.0-only
-- Original observational native X1 cassette reference. No keyboard input,
-- deck-control calls, bus substitution, ROM/RAM writes or gameplay claim.
-- Taps return nothing, leaving every original access/value unchanged.
local machine = manager.machine
local folder = assert(os.getenv("X1_MAME_OUTPUT"), "private output folder required")
local cpu = assert(machine.devices[":x1_cpu"], "X1 CPU missing")
local screen = assert(machine.screens[":screen"], "screen missing")
local cassette = assert(machine.cassettes[":cassette"], "cassette missing")
local log = assert(io.open(folder .. "/observer.csv", "w"))
log:write("time_s,event,pc,address,data,position_s,playing,motor\n")
local function event(name, address, data)
    log:write(string.format("%.12f,%s,%04x,%04x,%02x,%.12f,%d,%d\n",
        emu.time(), name, cpu.state.PC.value, address or 0, data or 0,
        cassette.position, cassette.is_playing and 1 or 0, cassette.motor_state and 1 or 0))
end
local pending_e9 = false
local mailbox_reads, mailbox_writes, ppi_reads, wave_edges = 0, 0, 0, 0
local old_pb = nil
local taps = {}
taps[1] = cpu.spaces.io:install_write_tap(0x1900, 0x19ff, "rallyx-mailbox-observer",
    function(offset, data, mask)
        mailbox_writes = mailbox_writes + 1
        event("mailbox-write", offset, data)
        if pending_e9 then
            event("e9-argument", offset, data)
            pending_e9 = false
        else pending_e9 = data == 0xe9 end
    end)
taps[2] = cpu.spaces.io:install_read_tap(0x1900, 0x19ff, "rallyx-mailbox-read-observer",
    function(offset, data, mask)
        mailbox_reads = mailbox_reads + 1
        event("mailbox-read", offset, data)
    end)
taps[3] = cpu.spaces.io:install_read_tap(0x1a00, 0x1aff, "rallyx-ppi-observer",
    function(offset, data, mask)
        if offset % 4 == 1 then
            ppi_reads = ppi_reads + 1
            if old_pb ~= nil then
                if (old_pb & 2) ~= (data & 2) then wave_edges = wave_edges + 1 end
                if (old_pb & 1) ~= (data & 1) then event("pb0-transition", offset, data) end
            end
            old_pb = data
        end
    end)
taps[4] = cpu.spaces.io:install_write_tap(0x1800, 0x18ff, "rallyx-crtc-observer",
    function(offset, data, mask) event("crtc-write", offset, data) end)
local checkpoints = {2, 8, 72, 83, 130}
local index, old_playing, old_motor = 1, nil, nil
-- Direct saved storage reads are memcpy, not CPU I/O transactions. Enumerate
-- exact names and sizes rather than guessing indexed-item identities.
local inventory = assert(io.open(folder .. "/storage-inventory.tsv", "w"))
local storage = {}
for tag, device in pairs(machine.devices) do
    for name, id in pairs(device.items) do
        local item = emu.item(id)
        inventory:write(string.format("%s\t%s\t%d\t%d\t%d\n", tag, name, id, item.size, item.count))
        for _, field in ipairs({"m_pcg_ram", "m_work_ram", "m_gfx_bitmap_ram", "m_crtc_vreg", "m_ram_bank"}) do
            if name == field or name:match("/" .. field .. "$") then
                assert(not storage[field], "ambiguous saved storage: " .. field)
                storage[field] = item
            end
        end
    end
end
inventory:close()
local function binary(name, bytes)
    local file = assert(io.open(folder .. "/" .. name, "wb"))
    assert(file:write(bytes)); assert(file:close())
end
local function dump_storage(prefix)
    local bytes = {}
    -- x1_state::mem_r only selects IPL overlay or RAM; no debugger I/O read.
    for address = 0, 0xffff do
        bytes[#bytes + 1] = string.char(cpu.spaces.program:read_u8(address))
    end
    binary(prefix .. "-program.bin", table.concat(bytes))
    assert(storage.m_pcg_ram and storage.m_work_ram, "required saved RAM unavailable")
    for field, item in pairs(storage) do
        binary(prefix .. "-" .. field .. ".bin", item:read_block(0, item.size * item.count))
    end
    for _, field in ipairs({"tvram", "avram"}) do
        local share = assert(machine.memory.shares[":" .. field], "missing memory share " .. field)
        local data = {}
        for address = 0, share.size - 1 do data[#data + 1] = string.char(share:read_u8(address)) end
        binary(prefix .. "-" .. field .. ".bin", table.concat(data))
    end
    -- Local direct_mem_read uses get_read_ptr, not handlers or taps. Read
    -- only the currently mapped bitmap bank; never select another entry.
    local bank = assert(machine.memory.banks[":bitmapbank"], "missing bitmap bank")
    local entry = bank.entry
    assert(entry == 0, "base-X1 reference expected bitmap bank zero")
    local space = assert(machine.devices[":iobank"].spaces.program, "missing bitmap address space")
    local gram = {}
    for offset = 0, 0xbfff do
        gram[#gram + 1] = string.char(space:read_direct_u8(0x4000 + offset))
    end
    assert(bank.entry == entry, "bitmap bank changed during passive capture")
    binary(prefix .. "-gram-bank" .. entry .. ".bin", table.concat(gram))
    print(string.format("READONLY_GRAM_CAPTURE target=%s entry=%d bytes=49152 direct_pointer_only=1", prefix, entry))
    print(string.format("READONLY_STORAGE_CAPTURE target=%s program_bytes=65536 no_debug_io_reads=1", prefix))
end
local function checkpoint(time)
    local name = string.format("native%d", checkpoints[index])
    if checkpoints[index] == 83 or checkpoints[index] == 130 then dump_storage(name) end
    local error = screen:snapshot(folder .. "/" .. name .. ".png")
    assert(not error, tostring(error))
    event(name)
    print(string.format("CHECKPOINT target=%d time=%.12f PC=%04x SP=%04x IFF1=%d IFF2=%d IM=%d position=%.12f length=%.12f playing=%d motor=%d mailbox_r=%d mailbox_w=%d ppi_r=%d pb1_edges=%d",
        checkpoints[index], time, cpu.state.PC.value, cpu.state.SP.value,
        cpu.state.IFF1.value, cpu.state.IFF2.value, cpu.state.IM.value,
        cassette.position, cassette.length, cassette.is_playing and 1 or 0,
        cassette.motor_state and 1 or 0, mailbox_reads, mailbox_writes, ppi_reads, wave_edges))
    log:flush()
    index = index + 1
end
emu.register_frame_done(function()
    assert(taps[1] and taps[2] and taps[3] and taps[4])
    local time = emu.time()
    if cassette.is_playing ~= old_playing or cassette.motor_state ~= old_motor then
        event("deck-state-frame-observed")
        old_playing, old_motor = cassette.is_playing, cassette.motor_state
        log:flush()
    end
    if index <= #checkpoints and time >= checkpoints[index] then checkpoint(time) end
end, "frame")
emu.register_stop(function()
    event("terminal")
    log:flush(); log:close()
    print(string.format("REFERENCE_TERMINAL checkpoints=%d expected=%d default_no_input=1 mailbox_r=%d mailbox_w=%d ppi_r=%d pb1_edges=%d",
        index - 1, #checkpoints, mailbox_reads, mailbox_writes, ppi_reads, wave_edges))
end)
print("RALLYX_REFERENCE_READY default_no_input=1 readonly_taps=4")
