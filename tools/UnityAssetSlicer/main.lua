local plugin = nil

function init(_plugin)
	-- if not app.isUIAvailable then
	-- 	return
	-- end
	plugin = _plugin
	print_ui("[UnitySlicer] - Starting plugin v"..tostring(plugin.version).."\n")
	registerSettings()

	plugin:newMenuGroup{
		id="whuckle_slicer",
		title="Unity Slicer",
		group="file_app"
	}

	plugin:newCommand{
		id="slice_sprite",
		title="Slice current sprite",
		group="whuckle_slicer",
		onclick=slice_sprite,
		onenabled=function ()
			if app.sprite then
				return true
			else
				return false
			end
		end
	}

	plugin:newCommand{
		id="delete_all_slices",
		title="Delete all slices",
		group="whuckle_slicer",
		onclick=delete_all_slices,
		onenabled=function ()
			if app.sprite then
				return true
			else
				return false
			end
		end
	}

	plugin:newCommand{
		id="export_slices",
		title="Export current slices",
		group="whuckle_slicer",
		onclick=export_slices,
		onenabled=function ()
			if app.sprite then
				return true
			else
				return false
			end
		end
	}
end
function print_ui(...)
	if app.isUIAvailable then
	print(...)
	end
end
function slice_sprite()
	local meta_file_path = ""
	local dlg = Dialog("Slice current sprite")
	dlg.bounds = Rectangle(app.window.width / 2.0 - 150,app.window.height / 2.0 - 100,300,200)
	dlg
		:file{
			id="meta_file",
			label="Sprite meta file",
			title="Select meta file",
			entry=true,
			open=true,
			save=false,
			filename=plugin.preferences.last_meta_file_path,
			filetypes={"meta"},
			onchange=function ()
				if app.fs.isFile(dlg.data.meta_file) then
					dlg.data.meta_file = app.fs.filePath(dlg.data.meta_file)
					meta_file_path = dlg.data.meta_file
					plugin.preferences.last_meta_file_path = dlg.data.meta_file
					dlg:modify{
						id="button_confirm",
						enabled=true
					}
				else
					dlg:modify{
						id="button_confirm",
						enabled=false
					}
				end
				dlg:repaint()
			end
		}
		:check{
			id="clear_slices",
			label="Clear current slices",
			selected=plugin.preferences.delete_slices,
			onclick=function ()
				plugin.preferences.delete_slices = dlg.data.clear_slices
				dlg:repaint()
			end
		}
		:button{
			id="button_confirm",
			text="Slice",
			enabled=false,
			onclick=function ()
				local file = io.open(meta_file_path, r)
				local text = file:read("*a")
				file:close()
				local slice_data = get_slice_data(yaml.parse(text))
				slice_sprite_from_meta(slice_data)
				dlg:close()
			
			end
		}
		:button{
			text="Cancel",
			onclick=function ()
				dlg:close()
			end
		}
		:show{
			wait=true,
			hand=true
		}
end


-- #region YAML parse

-- adaptation from https://github.com/rogvc/lua-yaml/blob/main/yaml.lua
-- MIT license

yaml = {}
local function convert_value(value)
	if value == "true" then
		return true
	elseif value == "false" then
		return false
	elseif tonumber(value) then
		return tonumber(value)
	else
		return value
	end
end
local function parse_yaml(lines, indent_level, start_index)
	local data = {}
	local i = start_index or 1
	while i <= #lines do
		local line = lines[i]
		if line:match("^#") or line:match("^%s*$") then
			i = i + 1
		else
			local indent = line:match("^(%s*)")
			local current_indent_level = #indent / 2
			if current_indent_level < indent_level then
				return data, i
			end
			if line:match("^%s*-%s*(.*)%s*$") then
				local item = line:match("^%s*-%s*(.*)%s*$")
				local sub_data = {}
				local sub_key, sub_value = item:match("^%s*([^:]+)%s*:%s*(.*)%s*$")
				if sub_key then
					sub_value = convert_value(sub_value)
					sub_data[sub_key] = sub_value
					local nested_data, next_i = parse_yaml(lines, current_indent_level + 1, i + 1)
					if next_i > i then
						for k, v in pairs(nested_data) do
							sub_data[k] = v
						end
						i = next_i
					else
						i = i + 1
					end
					table.insert(data, sub_data)
				else
					item = convert_value(item)
					local nested_data, next_i = parse_yaml(lines, current_indent_level + 1, i + 1)
					if next_i > i then
						table.insert(data, nested_data)
						i = next_i
					else
						table.insert(data, item)
						i = i + 1
					end
				end
			else
				local key, value = line:match("^%s*([^:]+)%s*:%s*(.*)%s*$")
				if key then
					value = convert_value(value)

					if value == "" then
						-- If the value is empty, it might be a nested table or sequence
						local sub_data, next_i = parse_yaml(lines, current_indent_level + 1, i + 1)
						data[key] = sub_data
						i = next_i
					else
						data[key] = value
						i = i + 1
					end
				else
					i = i + 1
				end
			end
		end
	end
	return data, i
end
function yaml.parse(yaml_str)
	local lines = {}
	for line in yaml_str:gmatch("[^\r\n]+") do
	table.insert(lines, line)
	end
	local data, _ = parse_yaml(lines, 0, 1)
	return data
end

function dump(o)
	if type(o) == 'table' then
		local s = '{ '
		for k,v in pairs(o) do
			if type(k) ~= 'number' then k = '"'..k..'"' end
			s = s .. '['..k..'] = ' .. dump(v) .. ','
		end
		return s .. '} '
	else
		return tostring(o)
	end
end

-- #endregion

-- #region slices
function round(num)
	return num >= 0 and math.floor(num + 0.5) or math.ceil(num - 0.5)
end

function get_slice_data(data)
	local slices = {}
	if type(data) == "table" and data["TextureImporter"]["spriteSheet"] then
    for k,v in pairs(data["TextureImporter"]["spriteSheet"]) do 
			if type(v)=="table" and v["name"] then
				slices[v["name"]] = {
					x=round(v["rect"]["x"]),
					y=round(v["rect"]["y"]),
					width=round(v["rect"]["width"]),
					height=round(v["rect"]["height"])
				}
			end
    end
	end
	return slices
end

function slice_sprite_from_meta(slice_data)
	if plugin.preferences.delete_slices then
		delete_all_slices()
	end
	for k,v in pairs(slice_data) do
		local slice = app.sprite:newSlice(Rectangle(v["x"],app.sprite.height - v["y"] - v["height"],v["width"],v["height"]))
		slice.name = tostring(k)
		slice.color = Color{r=176,g=11,b=105,a=255}
	end
	app.refresh()
end

function delete_all_slices()
	local slice_list = {}
	for i,slice in ipairs(app.sprite.slices) do
		table.insert(slice_list, slice)
	end
	for k,v in pairs(slice_list) do
		app.sprite:deleteSlice(v)
	end
	app.refresh()
end

function export_slices()
	local dlg = Dialog("Export slices")
	dlg.bounds = Rectangle(app.window.width / 2.0 - 150,app.window.height / 2.0 - 50,300,100)
	dlg
		:entry{
			id="output_directory",
			label="Select Output Directory",
			text=app.fs.filePath(app.sprite.filename),
			onchange=function ()
				if app.fs.isDirectory(dlg.data.output_directory) then
					plugin.preferences.last_export_path = dlg.data.output_directory
					dlg:modify{
						id="button_confirm",
						enabled=true
					}
				else
					dlg:modify{
						id="button_confirm",
						enabled=false
					}
				end
				dlg:repaint()
			end
		}
		:button{
			id="button_confirm",
			text="Export",
			enabled=false,
			onclick=function ()
				local slice_list = {}
				for i,slice in ipairs(app.sprite.slices) do
					table.insert(slice_list, slice)
				end
				for k,v in pairs(slice_list) do
					app.command.SaveFileCopyAs{
						ui=false,
						recent=false,
						filename=plugin.preferences.last_export_path..app.fs.pathSeparator..v["name"]..".png",
						bounds=v.bounds
					}
					print_ui("saved "..plugin.preferences.last_export_path..app.fs.pathSeparator..v["name"]..".png")
				end
				dlg:close()
			end
		}
		:button{
			text="Cancel",
			onclick=function ()
				dlg:close()
			end
		}
		:show{
			wait=true,
			hand=true
		}
end
-- #endregion

-- #region init
function registerSettings()
	if plugin.preferences.last_meta_file_path == nil then
		plugin.preferences.last_meta_file_path = ""
		print_ui("[UnitySlicer] - registered preference: 'last_meta_file_path'")
	end
	if plugin.preferences.last_export_path == nil then
		plugin.preferences.last_export_path = ""
		print_ui("[UnitySlicer] - registered preference: 'last_export_path'")
	end
	if plugin.preferences.delete_slices == nil then
		plugin.preferences.delete_slices = true
		print_ui("[UnitySlicer] - registered preference: 'delete_slices'")
	end
end

-- #endregion