local M = {}

local function permission(file)
	local h = file
	if not h then
		return ""
	end

	local perm = h.cha:perm()
	if not perm then
		return ""
	end

	local spans = ""
	for i = 1, #perm do
		local c = perm:sub(i, i)
		spans = spans .. c
	end
	return spans
end

local function link_count(file)
	local h = file
	if h == nil or ya.target_family() ~= "unix" then
		return ""
	end

	return h.cha.nlink
end

local function owner_group(file)
	local h = file
	if h == nil or ya.target_family() ~= "unix" then
		return ""
	end
	return (ya.user_name(h.cha.uid) or tostring(h.cha.uid)) .. "/" .. (ya.group_name(h.cha.gid) or tostring(h.cha.gid))
end

local file_size_and_folder_childs = function(file)
	local h = file
	if not h or h.cha.is_link then
		return ""
	end

	return h.cha.len and ya.readable_size(h.cha.len) or ""
end

--- get file timestamp
---@param file any
---@param type "mtime" | "atime" | "btime"
---@return any
local function fileTimestamp(file, type)
	local h = file
	if not h or h.cha.is_link then
		return ""
	end
	local time = math.floor(h.cha[type] or 0)
	if time == 0 then
		return ""
	else
		return os.date("%Y-%m-%d %H:%M", time)
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

local function get_filesystem_extra(file)
	local result = {
		filesystem = "",
		device = "",
		type = "",
		used_space = "",
		avail_space = "",
		total_space = "",
		used_space_percent = "",
		avail_space_percent = "",
		error = nil,
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
		result.error = "ERROR_CODE: " .. cmd_err .. '. "tail, df" are installed?'
	end
	return result
end

local function attributes(file)
	local h = file
	local file_url = tostring(h.url)
	if not h or ya.target_family() ~= "unix" then
		return ""
	end

	local output, cmd_err = Command("lsattr"):args({ "-d", file_url }):stdout(Command.PIPED):output()

	if output then
		-- Splitting the data
		local parts = split_by_whitespace(output.stdout)

		-- Display the result
		for i, part in ipairs(parts) do
			if i == 1 then
				return part
			end
		end
		return ""
	else
		return "ERROR_CODE: " .. cmd_err .. '. "lsattr" is installed?'
	end
end

---shorten string
---@param _s string string
---@param _t string tail
---@param _w number max characters
---@return string
local shorten = function(_s, _t, _w)
	local s = _s or utf8.len(_s)
	local t = _t or ""
	local ellipsis = "…" .. t
	local w = _w < utf8.len(ellipsis) and utf8.len(ellipsis) or _w
	local n_ellipsis = utf8.len(ellipsis) or 0
	if utf8.len(s) > w then
		return s:sub(1, (utf8.offset(s, w - n_ellipsis + 1) or 2) - 1) .. ellipsis
	end
	return s
end

local is_supported_table = type(ui.Table) ~= "nil" and type(ui.Row) ~= "nil"

local styles = {
	header = ui.Style():fg("green"),
	row_label = ui.Style():fg("reset"),
	row_value = ui.Style():fg("blue"),
	row_value_spot_hovered = ui.Style():fg("blue"):reverse(),
}

local function render_table(_self, opts)
	local filesystem_extra = get_filesystem_extra(_self.file)
	local prefix = "  "
	local label_lines, value_lines, rows = {}, {}, {}
	local label_max_length = 15
	local file_name_extension = _self.file.cha.is_dir and "…" or ("." .. (_self.file.url.ext(_self.file.url) or ""))

	local row = function(key, value)
		local h = type(value) == "table" and utf8.len(value) or 1
		rows[#rows + 1] = ui.Row({ ui.Span(key):style(styles.row_label), ui.Span(value):style(styles.row_value) })
			:height(h)
	end

	local file_name = shorten(
		_self.file.name,
		file_name_extension,
		math.floor(_self.area.w - label_max_length - utf8.len(file_name_extension))
	)
	local location =
		shorten(tostring(_self.file.url:parent()), "", math.floor(_self.area.w - label_max_length - utf8.len(prefix)))
	local filesystem_error = filesystem_extra.error
			and shorten(filesystem_extra.error, "", math.floor(_self.area.w - label_max_length - utf8.len(prefix)))
		or nil
	local filesystem =
		shorten(filesystem_extra.filesystem, "", math.floor(_self.area.w - label_max_length - utf8.len(prefix)))

	if not is_supported_table then
		table.insert(
			label_lines,
			ui.Line({
				ui.Span("Metadata:"),
			}):style(styles.header)
		)
		table.insert(
			value_lines,
			ui.Line({
				ui.Span(""),
			})
		)

		table.insert(
			label_lines,
			ui.Line({
				ui.Span(prefix),
				ui.Span("File:"),
			}):style(styles.row_label)
		)
		table.insert(
			value_lines,
			ui.Line({
				ui.Span(file_name),
			}):style(styles.row_value)
		)

		table.insert(
			label_lines,
			ui.Line({
				ui.Span(prefix),
				ui.Span("Mimetype: "),
			}):style(styles.row_label)
		)
		table.insert(value_lines, ui.Line(ui.Span(_self._mime or _self.mime)):style(styles.row_value))

		table.insert(
			label_lines,
			ui.Line({
				ui.Span(prefix),
				ui.Span("Location: "),
			}):style(styles.row_label)
		)
		table.insert(
			value_lines,
			ui.Line({
				ui.Span(location),
			}):style(styles.row_value)
		)

		table.insert(
			label_lines,
			ui.Line({
				ui.Span(prefix),
				ui.Span("Mode: "),
			}):style(styles.row_label)
		)
		table.insert(value_lines, ui.Line(permission(_self.file)):style(styles.row_value))

		table.insert(
			label_lines,
			ui.Line({
				ui.Span(prefix),
				ui.Span("Attributes: "),
			}):style(styles.row_label)
		)
		table.insert(value_lines, ui.Line(ui.Span(attributes(_self.file))):style(styles.row_value))

		table.insert(
			label_lines,
			ui.Line({
				ui.Span(prefix),
				ui.Span("Links: "),
			}):style(styles.row_label)
		)
		table.insert(
			value_lines,
			ui.Line({
				ui.Span(tostring(link_count(_self.file))),
			}):style(styles.row_value)
		)

		table.insert(
			label_lines,
			ui.Line({
				ui.Span(prefix),
				ui.Span("Owner: "),
			}):style(styles.row_label)
		)
		table.insert(value_lines, ui.Line(ui.Span(owner_group(_self.file))):style(styles.row_value))

		table.insert(
			label_lines,
			ui.Line({
				ui.Span(prefix),
				ui.Span("Size: "),
			}):style(styles.row_label)
		)
		table.insert(value_lines, ui.Line(ui.Span(file_size_and_folder_childs(_self.file))):style(styles.row_value))

		table.insert(
			label_lines,
			ui.Line({
				ui.Span(prefix),
				ui.Span("Changed: "),
			}):style(styles.row_label)
		)
		table.insert(value_lines, ui.Line(ui.Span(fileTimestamp(_self.file, "btime"))):style(styles.row_value))

		table.insert(
			label_lines,
			ui.Line({
				ui.Span(prefix),
				ui.Span("Modified: "),
			}):style(styles.row_label)
		)
		table.insert(value_lines, ui.Line(ui.Span(fileTimestamp(_self.file, "mtime"))):style(styles.row_value))

		table.insert(
			label_lines,
			ui.Line({
				ui.Span(prefix),
				ui.Span("Accessed: "),
			}):style(styles.row_label)
		)
		table.insert(value_lines, ui.Line(ui.Span(fileTimestamp(_self.file, "atime"))):style(styles.row_value))

		table.insert(
			label_lines,
			ui.Line({
				ui.Span(prefix),
				ui.Span("Filesystem: "),
			}):style(styles.row_label)
		)
		table.insert(value_lines, ui.Line(ui.Span(filesystem_error or filesystem)):style(styles.row_value))

		table.insert(
			label_lines,
			ui.Line({
				ui.Span(prefix),
				ui.Span("Device: "),
			}):style(styles.row_label)
		)
		table.insert(value_lines, ui.Line(ui.Span(filesystem_error or filesystem_extra.device)):style(styles.row_value))

		table.insert(
			label_lines,
			ui.Line({
				ui.Span(prefix),
				ui.Span("Type: "),
			}):style(styles.row_label)
		)
		table.insert(value_lines, ui.Line(ui.Span(filesystem_error or filesystem_extra.type)):style(styles.row_value))

		table.insert(
			label_lines,
			ui.Line({
				ui.Span(prefix),
				ui.Span("Free space: "),
			}):style(styles.row_label)
		)
		table.insert(
			value_lines,
			ui.Line(
				ui.Span(
					filesystem_extra.error
						or (
							filesystem_extra.avail_space
							.. " / "
							.. filesystem_extra.total_space
							.. " ("
							.. filesystem_extra.avail_space_percent
							.. "%)"
						)
				)
			):style(styles.row_value)
		)
	else
		rows[#rows + 1] = ui.Row({ "Metadata", "" }):style(styles.header)
		row(prefix .. "File:", file_name)
		row(prefix .. "Mimetype:", _self.mime)
		row(prefix .. "Location:", location)
		row(prefix .. "Mode:", permission(_self.file))
		row(prefix .. "Attributes:", attributes(_self.file))
		row(prefix .. "Links:", tostring(link_count(_self.file)))
		row(prefix .. "Owner:", owner_group(_self.file))
		row(prefix .. "Size:", file_size_and_folder_childs(_self.file))
		row(prefix .. "Changed:", fileTimestamp(_self.file, "btime"))
		row(prefix .. "Modified:", fileTimestamp(_self.file, "mtime"))
		row(prefix .. "Accessed:", fileTimestamp(_self.file, "atime"))
		row(prefix .. "Filesystem:", filesystem_error or filesystem)
		row(prefix .. "Device:", filesystem_error or filesystem_extra.device)
		row(prefix .. "Type:", filesystem_error or filesystem_extra.type)
		row(
			prefix .. "Free space:",
			filesystem_error
				or (
					(
							filesystem_extra.avail_space
							and filesystem_extra.total_space
							and filesystem_extra.avail_space_percent
						)
						and (filesystem_extra.avail_space .. " / " .. filesystem_extra.total_space .. " (" .. filesystem_extra.avail_space_percent .. "%)")
					or ""
				)
		)
		if opts and opts.show_plugins_section and PLUGIN then
			local spotter = PLUGIN.spotter(_self.file.url, _self.mime)
			local previewer = PLUGIN.previewer(_self.file.url, _self.mime)
			local fetchers = PLUGIN.fetchers(_self.file.url, _self.mime)
			local preloaders = PLUGIN.preloaders(_self.file.url, _self.mime)

			for i, v in ipairs(fetchers) do
				fetchers[i] = v.cmd
			end
			for i, v in ipairs(preloaders) do
				preloaders[i] = v.cmd
			end

			rows[#rows + 1] = ui.Row({ { "", "Plugins" }, "" }):height(2):style(styles.header)
			row(prefix .. "Spotter:", spotter and spotter.cmd or "")
			row(prefix .. "Previewer:", previewer and previewer.cmd or "")
			row(prefix .. "Fetchers:", #fetchers ~= 0 and fetchers or "")
			row(prefix .. "Preloaders:", #preloaders ~= 0 and preloaders or "")
		end
	end

	if not is_supported_table then
		local areas = ui.Layout()
			:direction(ui.Layout.HORIZONTAL)
			:constraints({ ui.Constraint.Length(label_max_length), ui.Constraint.Fill(1) })
			:split(_self.area)
		local label_area = areas[1]
		local value_area = areas[2]
		return {
			ui.Text(label_lines):area(label_area):align(ui.Text.LEFT):wrap(ui.Text.WRAP_NO),
			ui.Text(value_lines):area(value_area):align(ui.Text.LEFT):wrap(ui.Text.WRAP_NO),
		}
	else
		return {
			ui.Table(rows):area(_self.area):row(1):col(1):col_style(styles.row_value):widths({
				ui.Constraint.Length(label_max_length),
				ui.Constraint.Fill(1),
			}),
		}
	end
end

function M:peek()
	local start, cache = os.clock(), ya.file_cache(self)
	if not cache or self:preload() ~= 1 then
		return 1
	end
	ya.sleep(math.max(0, PREVIEW.image_delay / 1000 + start - os.clock()))
	ya.preview_widgets(self, render_table(self))
end

function M:seek() end

function M:preload()
	local cache = ya.file_cache(self)
	if not cache or fs.cha(cache) then
		return 1
	end
	return 1
end

function M:spot(args)
	args.area = ui.Pos({ "center", w = 80, h = 25 })
	ya.spot_table(
		args,
		render_table(args, { show_plugins_section = true })[1]:cell_style(styles.row_value_spot_hovered)
	)
end

return M
