-- Bulgarian support for "Bulgarian – QWERTY" / "Bulgarian - Phonetic".
-- Physical QWERTY starts as: qwerty -> явертъ

-- REMAPS ALSO YOUR CUSTOM KEYBINDS!!! <3

local M = {}

local bulgarian_to_qwerty = {
	{ "ч", "`" },
	{ "Ч", "~" },
	{ "№", "#" },

	{ "я", "q" },
	{ "в", "w" },
	{ "е", "e" },
	{ "р", "r" },
	{ "т", "t" },
	{ "ъ", "y" },
	{ "у", "u" },
	{ "и", "i" },
	{ "о", "o" },
	{ "п", "p" },
	{ "ш", "[" },
	{ "щ", "]" },
	{ "ю", "\\" },

	{ "а", "a" },
	{ "с", "s" },
	{ "д", "d" },
	{ "ф", "f" },
	{ "г", "g" },
	{ "х", "h" },
	{ "й", "j" },
	{ "к", "k" },
	{ "л", "l" },

	{ "з", "z" },
	{ "ь", "x" },
	{ "ц", "c" },
	{ "ж", "v" },
	{ "б", "b" },
	{ "н", "n" },
	{ "м", "m" },

	{ "Я", "Q" },
	{ "В", "W" },
	{ "Е", "E" },
	{ "Р", "R" },
	{ "Т", "T" },
	{ "Ъ", "Y" },
	{ "У", "U" },
	{ "И", "I" },
	{ "О", "O" },
	{ "П", "P" },
	{ "Ш", "{" },
	{ "Щ", "}" },
	{ "Ю", "|" },

	{ "А", "A" },
	{ "С", "S" },
	{ "Д", "D" },
	{ "Ф", "F" },
	{ "Г", "G" },
	{ "Х", "H" },
	{ "Й", "J" },
	{ "К", "K" },
	{ "Л", "L" },

	{ "З", "Z" },
	-- macOS emits ѝ for Shift-x in this layout; Ь/Ѝ cover Caps Lock and variants.
	{ "ѝ", "X" },
	{ "Ь", "X" },
	{ "Ѝ", "X" },
	{ "Ц", "C" },
	{ "Ж", "V" },
	{ "Б", "B" },
	{ "Н", "N" },
	{ "М", "M" },
}

local langmap_escape = {
	["\\"] = "\\\\",
	[","] = "\\,",
	[";"] = "\\;",
	['"'] = '\\"',
	["|"] = "\\|",
}

local function escape_langmap_char(char)
	return langmap_escape[char] or char
end

local function build_langmap()
	local parts = {}

	for _, pair in ipairs(bulgarian_to_qwerty) do
		parts[#parts + 1] = escape_langmap_char(pair[1]) .. escape_langmap_char(pair[2])
	end

	return table.concat(parts, ",")
end

local qwerty_to_bulgarian = {}

for _, pair in ipairs(bulgarian_to_qwerty) do
	local bulgarian, qwerty = pair[1], pair[2]

	if #qwerty == 1 and not qwerty_to_bulgarian[qwerty] then
		qwerty_to_bulgarian[qwerty] = bulgarian
	end
end

local function to_bulgarian_keys(keys)
	return (keys:gsub(".", function(key)
		return qwerty_to_bulgarian[key] or key
	end))
end

local function to_bulgarian_lhs(lhs)
	if type(lhs) ~= "string" or lhs:lower():sub(1, 6) == "<plug>" then
		return nil
	end

	local parts = {}
	local changed = false
	local i = 1

	while i <= #lhs do
		local char = lhs:sub(i, i)

		if char == "<" then
			local token_end = lhs:find(">", i + 1, true)

			if token_end then
				parts[#parts + 1] = lhs:sub(i, token_end)
				i = token_end + 1
			else
				parts[#parts + 1] = qwerty_to_bulgarian[char] or char
				changed = changed or parts[#parts] ~= char
				i = i + 1
			end
		else
			parts[#parts + 1] = qwerty_to_bulgarian[char] or char
			changed = changed or parts[#parts] ~= char
			i = i + 1
		end
	end

	if not changed then
		return nil
	end

	return table.concat(parts)
end

local function command_abbrev(lhs, rhs)
	local lhs_expr = vim.fn.string(lhs)
	local rhs_expr = vim.fn.string(rhs)

	vim.cmd(
		("cabbrev <expr> %s getcmdtype() ==# ':' && getcmdline() ==# %s ? %s : %s"):format(
			lhs,
			lhs_expr,
			rhs_expr,
			lhs_expr
		)
	)
end

local function setup_command_abbrevs()
	for _, command in ipairs { "bd", "bn", "q", "qa", "w", "wq" } do
		command_abbrev(to_bulgarian_keys(command), command)
	end
end

local aliasable_modes = {
	[""] = true,
	n = true,
	o = true,
	s = true,
	v = true,
	x = true,
}

local function keymap_alias_modes(mode)
	if type(mode) == "table" then
		local modes = {}

		for _, item in ipairs(mode) do
			if aliasable_modes[item] then
				modes[#modes + 1] = item
			end
		end

		if #modes == 0 then
			return nil
		end

		return modes
	end

	return aliasable_modes[mode] and mode or nil
end

local function keymap_alias_opts(opts)
	local alias_opts = type(opts) == "table" and vim.deepcopy(opts) or {}
	alias_opts.desc = "which_key_ignore"
	alias_opts.unique = nil
	return alias_opts
end

local function set_keymap_alias(mode, lhs, rhs, opts, setter)
	local modes = keymap_alias_modes(mode)

	if not modes then
		return
	end

	local alias = to_bulgarian_lhs(lhs)

	if not alias or alias == lhs then
		return
	end

	pcall(setter, modes, alias, keymap_alias_opts(opts))
end

local keymaps_patched = false

local function copy_existing_keymap_opts(map)
	return {
		desc = "which_key_ignore",
		expr = map.expr == 1,
		nowait = map.nowait == 1,
		remap = map.noremap == 0,
		script = map.script == 1,
		silent = map.silent == 1,
	}
end

local function alias_existing_keymaps(original_keymap_set)
	for mode in pairs(aliasable_modes) do
		if mode ~= "" then
			for _, map in ipairs(vim.api.nvim_get_keymap(mode)) do
				local alias = to_bulgarian_lhs(map.lhs)
				local rhs = map.callback or map.rhs

				if alias and rhs then
					pcall(original_keymap_set, mode, alias, rhs, copy_existing_keymap_opts(map))
				end
			end
		end
	end
end

local function patch_keymaps()
	if keymaps_patched then
		return
	end

	keymaps_patched = true

	local original_keymap_set = vim.keymap.set
	local original_set_keymap = vim.api.nvim_set_keymap
	local original_buf_set_keymap = vim.api.nvim_buf_set_keymap

	vim.keymap.set = function(mode, lhs, rhs, opts)
		local result = original_keymap_set(mode, lhs, rhs, opts)

		set_keymap_alias(mode, lhs, rhs, opts, function(alias_modes, alias, alias_opts)
			original_keymap_set(alias_modes, alias, rhs, alias_opts)
		end)

		return result
	end

	vim.api.nvim_set_keymap = function(mode, lhs, rhs, opts)
		local result = original_set_keymap(mode, lhs, rhs, opts)

		set_keymap_alias(mode, lhs, rhs, opts, function(alias_mode, alias, alias_opts)
			original_set_keymap(alias_mode, alias, rhs, alias_opts)
		end)

		return result
	end

	vim.api.nvim_buf_set_keymap = function(buffer, mode, lhs, rhs, opts)
		local result = original_buf_set_keymap(buffer, mode, lhs, rhs, opts)

		set_keymap_alias(mode, lhs, rhs, opts, function(alias_mode, alias, alias_opts)
			original_buf_set_keymap(buffer, alias_mode, alias, rhs, alias_opts)
		end)

		return result
	end

	alias_existing_keymaps(original_keymap_set)
end

M.langmap = build_langmap()
M.bulgarian_to_qwerty = bulgarian_to_qwerty
M.to_bulgarian_keys = to_bulgarian_keys
M.to_bulgarian_lhs = to_bulgarian_lhs

function M.setup(opts)
	opts = opts or {}

	if not opts.no_langmap then
		vim.o.langmap = M.langmap
		vim.o.langremap = false
	end

	if not opts.no_bulgarian_abbrev and not vim.g.no_plugin_abbrev then
		setup_command_abbrevs()
	end

	if not opts.no_keymap_aliases then
		patch_keymaps()
	end
end

M.setup()

return M
