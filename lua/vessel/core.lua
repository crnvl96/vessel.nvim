---@module "core"

local Context = require("vessel.context")
local logger = require("vessel.logger")

---@class App
---@field buffer_name string
---@field config table
---@field context Context
---@field bufnr integer
---@field winid integer?
local App = {}
App.__index = App

--- Create new App instance
---@param config table
---@return App
function App:new(config)
	local app = {}
	setmetatable(app, App)
	app.buffer_name = "__vessel__"
	app.config = config
	app.context = Context:new()
	app.bufnr = -1
	app.winid = -1
	logger.log_level = config.verbosity
	return app
end

--- Create the window buffer
---@return integer, boolean Whether the buffer was created
function App:_create_buffer()
	local bufnr = vim.fn.bufnr(self.buffer_name)
	if bufnr == -1 then
		bufnr = vim.api.nvim_create_buf(false, false)
		vim.api.nvim_buf_set_name(bufnr, self.buffer_name)
		return bufnr, true
	end
	return bufnr, false
end

--- Close the window
function App:_close_window()
	vim.fn.win_execute(self.winid, "close")
	pcall(vim.cmd, self.context.wininfo.winnr .. "wincmd w")
end

--- Setup the buffer by setting sensible options
---@param winid integer
function App:_setup_window(winid)
	local wininfo = vim.fn.getwininfo(winid)
	local bufnr = wininfo[1].bufnr
	local winnr = wininfo[1].winnr

	vim.fn.setbufvar(bufnr, "&buftype", "nofile")
	vim.fn.setbufvar(bufnr, "&bufhidden", "delete")
	vim.fn.setbufvar(bufnr, "&buflisted", 0)
	vim.fn.setwinvar(winnr, "&cursorcolumn", 0)
	vim.fn.setwinvar(winnr, "&colorcolumn", 0)
	vim.fn.setwinvar(winnr, "&signcolumn", "no")
	vim.fn.setwinvar(winnr, "&wrap", 0)
	vim.fn.setwinvar(winnr, "&list", 0)
	vim.fn.setwinvar(winnr, "&textwidth", 0)
	vim.fn.setwinvar(winnr, "&undofile", 0)
	vim.fn.setwinvar(winnr, "&backup", 0)
	vim.fn.setwinvar(winnr, "&swapfile", 0)
	vim.fn.setwinvar(winnr, "&spell", 0)
	vim.fn.setwinvar(winnr, "&cursorline", self.config.window.cursorline)
	vim.fn.setwinvar(winnr, "&number", self.config.window.number)
	vim.fn.setwinvar(winnr, "&relativenumber", self.config.window.relativenumber)

	vim.api.nvim_create_autocmd("BufLeave", {
		desc = "Close the window when switching to another buffer",
		buffer = bufnr,
		callback = function()
			vim.api.nvim_buf_delete(self.bufnr, {})
			self:_close_window()
		end,
		once = true,
	})
end

--- Return options for the popup window
--- Compute width|height|col|row at runtime if they are defined as functions
---@param list Marklist|Jumplist|Bufferlist
---@return table
function App:_get_popup_options(list)
	local opts = {}
	for key, val in pairs(self.config.window.options) do
		opts[key] = val
	end

	local get = function(field, ...)
		if type(opts[field]) == "function" then
			return opts[field](...)
		end
		return opts[field]
	end

	opts.width = get("width", self.config)
	opts.height = get("height", list, self.config)
	opts.row = get("row", opts.width, opts.height)
	opts.col = get("col", opts.width, opts.height)

	if opts.height == 0 then
		opts.height = 1
	end

	return opts
end

--- Set the buffer-local variable with info about the buffer content
---@param map table
function App:_set_buffer_data(map)
	vim.api.nvim_buf_set_var(self.bufnr, "vessel", {
		map = map,
		get_selected = function()
			return map[vim.fn.line(".")]
		end,
		close_window = function()
			self:_close_window()
		end,
	})
end

--- Open the popup window
---@param list Marklist|Jumplist|Bufferlist
---@return integer, boolean Whether the window was actually opened
function App:open_window(list)
	local popup_opts = self:_get_popup_options(list)
	self.bufnr = self:_create_buffer()
	if vim.fn.bufwinid(self.bufnr) == -1 then
		self.winid = vim.api.nvim_open_win(self.bufnr, true, popup_opts)
		self:_setup_window(self.winid)
	else
		logger.warn("window already open")
		return self.bufnr, false
	end
	return self.bufnr, true
end

return App
