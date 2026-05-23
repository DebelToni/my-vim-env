-- Bulgarian support for macOS "Bulgarian – QWERTY" / "Bulgarian - Phonetic".
-- Physical QWERTY starts as: qwerty -> явертъ

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

  if qwerty:match "^[a-z]$" then
    qwerty_to_bulgarian[qwerty] = bulgarian
  end
end

local function to_bulgarian_keys(keys)
  return (keys:gsub(".", function(key)
    return qwerty_to_bulgarian[key] or key
  end))
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

M.langmap = build_langmap()
M.bulgarian_to_qwerty = bulgarian_to_qwerty
M.to_bulgarian_keys = to_bulgarian_keys

function M.setup(opts)
  opts = opts or {}

  if not opts.no_langmap then
    vim.o.langmap = M.langmap
    vim.o.langremap = false
  end

  if not opts.no_bulgarian_abbrev and not vim.g.no_plugin_abbrev then
    setup_command_abbrevs()
  end
end

M.setup()

return M
