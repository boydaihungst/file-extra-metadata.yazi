local M = {}

local function permission(file)
	local h = file
	if not h then
		return ui.Line({})
	end

	local perm = h.cha:perm()
	if not perm then
		return ui.Line({})
	end

	local spans = {}
	for i = 1, #perm do
		local c = perm:sub(i, i)
		spans[i] = ui.Span(c)
	end
	return ui.Line(spans)
end

local function link_count(file)
	local h = file
	if h == nil or ya.target_family() ~= "unix" then
		return ui.Line({})
	end

	return ui.Line({
		ui.Span(tostring(h.cha.nlink)),
	})
end

local function owner_group(file)
	local h = file
	if h == nil or ya.target_family() ~= "unix" then
		return ui.Line({})
	end
	return ui.Line({
		ui.Span(ya.user_name(h.cha.uid) or tostring(h.cha.uid)),
		ui.Span("/"),
		ui.Span(ya.group_name(h.cha.gid) or tostring(h.cha.gid)),
	})
end

local file_size_and_folder_childs = function(file)
	local h = file
	if not h or h.cha.is_link then
		return ui.Line({})
	end

	return ui.Line({
		ui.Span(h.cha.len and ya.readable_size(h.cha.len) or "-"),
	})
end

--- get file timestamp
---@param file any
---@param type "mtime" | "atime" | "btime"
---@return any
local function fileTimestamp(file, type)
	local h = file
	if not h or h.cha.is_link then
		return ui.Line({})
	end
	local time = math.floor(h.cha[type] or 0)
	if time == 0 then
		return ui.Line("")
	else
		return ui.Line({
			ui.Span(os.date("%Y-%m-%d %H:%M", time)),
		})
	end
end

-- Function to split a string by spaces (considering multiple spaces as one delimiter)
local function split_by_whitespace(input)
	local result = {}
	for word in string.gmatch(input, "%S+") do
		table.insert(result, word)
	end
	return result
end

local function filesystem(file)
	local result = {
		filesystem = "",
		device = "",
		type = "",
		used_space = "",
		avail_space = "",
		total_space = "",
		used_space_percent = "",
		avail_space_percent = "",
	}
	local h = file
	local file_url = tostring(h.url)
	if not h or ya.target_family() ~= "unix" then
		return result
	end

	local output, cmd_err = Command("tail")
		:args({ "-n", "-1" })
		:stdin(Command("df"):args({ "-P", "-T", "-h", file_url }):stdout(Command.PIPED):spawn():take_stdout())
		:stdout(Command.PIPED)
		:output()

	if output then
		-- Splitting the data
		local parts = split_by_whitespace(output.stdout)

		-- Display the result
		for i, part in ipairs(parts) do
			if i == 1 then
				result.filesystem = part
			elseif i == 2 then
				result.device = part
			elseif i == 3 then
				result.total_space = part
			elseif i == 4 then
				result.used_space = part
			elseif i == 5 then
				result.avail_space = part
			elseif i == 6 then
				result.used_space_percent = part
				result.avail_space_percent = 100 - tonumber((string.match(part, "%d+") or "0"))
			elseif i == 7 then
				result.type = part
			end
		end
	else
		error("file-extra-metadata exited with error: %s. Make sure tail, df are installed", cmd_err)
	end
	return result
end

local function attributes(file)
	local h = file
	local file_url = tostring(h.url)
	if not h or ya.target_family() ~= "unix" then
		return ui.Line({})
	end

	local output, cmd_err = Command("lsattr"):args({ "-d", file_url }):stdout(Command.PIPED):output()

	if output then
		-- Splitting the data
		local parts = split_by_whitespace(output.stdout)

		-- Display the result
		for i, part in ipairs(parts) do
			if i == 1 then
				return ui.Line(ui.Span(part))
			end
		end
		return ui.Line({})
	else
		error("file-extra-metadata exited with error: %s. Make sure lsattr is installed", cmd_err)
		return ui.Line({})
	end
end
function M:peek()
	local start, cache = os.clock(), ya.file_cache(self)
	if not cache or self:preload() ~= 1 then
		return 1
	end

	ya.sleep(math.max(0, PREVIEW.image_delay / 1000 + start - os.clock()))

	local file_cha, _ = self.file.cha
	local filesystem_extra = filesystem(self.file)
	local label_lines = {}
	local value_lines = {}

	if file_cha and filesystem_extra then
		local prefix = "  "
		table.insert(
			label_lines,
			ui.Line({
				ui.Span("File:"),
			})
		)
		table.insert(
			value_lines,
			ui.Line({
				ui.Span(self.file.name),
			})
		)
		table.insert(
			label_lines,
			ui.Line({
				ui.Span(prefix),
				ui.Span("Location: "),
			})
		)
		table.insert(
			value_lines,
			ui.Line({
				ui.Span(tostring(self.file.url:parent())),
			})
		)

		table.insert(
			label_lines,
			ui.Line({
				ui.Span(prefix),
				ui.Span("Mode: "),
			})
		)
		table.insert(value_lines, permission(self.file))
		table.insert(
			label_lines,
			ui.Line({
				ui.Span(prefix),
				ui.Span("Attributes: "),
			})
		)
		table.insert(value_lines, attributes(self.file))

		table.insert(
			label_lines,
			ui.Line({
				ui.Span(prefix),
				ui.Span("Links: "),
			})
		)
		table.insert(value_lines, link_count(self.file))

		table.insert(
			label_lines,
			ui.Line({
				ui.Span(prefix),
				ui.Span("Owner: "),
			})
		)
		table.insert(value_lines, owner_group(self.file))

		table.insert(
			label_lines,
			ui.Line({
				ui.Span(prefix),
				ui.Span("Size: "),
			})
		)
		table.insert(value_lines, file_size_and_folder_childs(self.file))

		table.insert(
			label_lines,
			ui.Line({
				ui.Span(prefix),
				ui.Span("Changed: "),
			})
		)
		table.insert(value_lines, fileTimestamp(self.file, "btime"))

		table.insert(
			label_lines,
			ui.Line({
				ui.Span(prefix),
				ui.Span("Modified: "),
			})
		)
		table.insert(value_lines, fileTimestamp(self.file, "mtime"))
		table.insert(
			label_lines,
			ui.Line({
				ui.Span(prefix),
				ui.Span("Accessed: "),
			})
		)
		table.insert(value_lines, fileTimestamp(self.file, "atime"))
		table.insert(
			label_lines,
			ui.Line({
				ui.Span(prefix),
				ui.Span("Filesystem: "),
			})
		)
		table.insert(value_lines, ui.Line(ui.Span(filesystem_extra.filesystem)))
		table.insert(
			label_lines,
			ui.Line({
				ui.Span(prefix),
				ui.Span("Device: "),
			})
		)
		table.insert(value_lines, ui.Line(ui.Span(filesystem_extra.device)))
		table.insert(
			label_lines,
			ui.Line({
				ui.Span(prefix),
				ui.Span("Type: "),
			})
		)
		table.insert(value_lines, ui.Line(ui.Span(filesystem_extra.type)))
		table.insert(
			label_lines,
			ui.Line({
				ui.Span(prefix),
				ui.Span("Free space: "),
			})
		)
		table.insert(
			value_lines,
			ui.Line(
				ui.Span(
					filesystem_extra.avail_space
						.. " / "
						.. filesystem_extra.total_space
						.. " ("
						.. filesystem_extra.avail_space_percent
						.. "%)"
				)
			)
		)
	else
		local error = string.format("Failed to read metadata")
		table.insert(value_lines, ui.Line(error))
	end

	local areas = ui.Layout()
		:direction(ui.Layout.HORIZONTAL)
		:constraints({ ui.Constraint.Length(15), ui.Constraint.Fill(1) })
		:split(self.area)
	local label_area = areas[1]
	local value_area = areas[2]

	ya.preview_widgets(self, {
		ui.Text(label_lines):area(label_area):align(ui.Text.LEFT):wrap(ui.Text.WRAP_NO),
		ui.Text(value_lines):area(value_area):align(ui.Text.LEFT):wrap(ui.Text.WRAP_NO),
	})
end

function M:seek(units)
	local h = cx.active.current.hovered
	if h and h.url == self.file.url then
		local step = math.floor(units * self.area.h / 10)
		ya.manager_emit("peek", {
			math.max(0, cx.active.preview.skip + step),
			only_if = self.file.url,
		})
	end
end

function M:preload()
	local cache = ya.file_cache(self)
	if not cache or fs.cha(cache) then
		return 1
	end
	return 1
end

return M
