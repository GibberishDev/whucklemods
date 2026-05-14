local plugin = nil

local dlg = Dialog("Unity spritesheet importer    ")

function init(_plugin)
    plugin = _plugin
	if not app.isUIAvailable then
		return
	end
    registerSettings()
    print_ui("\n[UnitySlicer] - Check 'File > Unity Slicer' for options")
    dlg.bounds = Rectangle(app.window.width / 2.0 - 200,app.window.height / 2.0 - 100,400,200)
    dlg
	:button{
		id="info_button",
		text="Limitations",
		hexpand=false,
		onclick=function ()
			app.alert{
				title="Limitations",
				buttons="Damn...",
				text={
					"Due to limitations in Aseprite extension api",
					"it is impossible to have Folder selector screen.",
					"Use File/Folder entry field and paste path into it.",
					"",
					"Sorry for the inconvenience.",
					"It would be fixed as soon as feature is implemented.",
					" - GibbDev"
				}
			}
		end
	}
	:newrow{}
	:separator{
		text="Import settings"
	}
	:newrow{}
	
	:entry{
		label="Folder path",
		id="file_selector",
		text=plugin.preferences.folder_path,
		onchange=function ()
			if app.fs.isDirectory(dlg.data.file_selector) then
				dlg:modify{
					id="button_import",
					enabled=true
				}
				plugin.preferences.folder_path = dlg.data.file_selector
			else
				dlg:modify{
					id="button_import",
					enabled=false
				}
			end
			dlg:repaint()
		end
	}
	:check {
		id="check_ignore",
		text="Ignore duplicate files with '_0'",
		selected=plugin.preferences.ignore_dupes,
        onclick=function ()
            plugin.preferences.ignore_dupes=dlg.data.check_ignore
            dlg:repaint()
        end
	}
	:newrow{}
	:check {
		id="check_slice",
		text="Slice imported files",
		selected=plugin.preferences.slice,
        onclick=function ()
            plugin.preferences.slice=dlg.data.check_slice
            dlg:repaint()
        end
	}
	:newrow{}
	:check {
		id="check_no_import_slice",
		text="Ignore images without slice data",
		selected=plugin.preferences.no_slice_ignore,
        onclick=function ()
            plugin.preferences.no_slice_ignore=dlg.data.check_no_import_slice
            dlg:repaint()
        end
	}
	:entry{
		id="regex_pattern",
		label="Filename regex pattern",
		text=plugin.preferences.regex,
		onchange=function ()
			plugin.preferences.regex = dlg.data.regex_pattern
			dlg:repaint()
		end
	}

	:newrow{}
	:label{vexpand=true}
	:button{
		id="button_import",
		text="Import",
		enabled=app.fs.isDirectory(plugin.preferences.folder_path),
		onclick=function ()
			local arr = listFiles(plugin.preferences.folder_path)
			if next(arr) == nil then
				app.alert{
					title="Error!",
					text={
						"No valid files to import were found..."
					},
					buttons={"OK"}
				}
			else
				if importSprites(arr) then
					importFiles(arr)
					dlg:close()
				end
			end
			
		end
	}
	plugin:newCommand{
		id="slicer_import",
		title="Import sprites from folder",
		group="whuckle_slicer",
		onclick=function ()
            dlg:show{
                hand=true,
                wait=true
            }
        end
	}
end


function registerSettings()
	if plugin.preferences.regex == nil then
		plugin.preferences.regex = ""
		print_ui("[UnitySlicer] - registered preference: 'regex'")
	end
	if plugin.preferences.folder_path == nil then
		plugin.preferences.folder_path = ""
		print_ui("[UnitySlicer] - registered preference: 'folder_path'")
	end
	if plugin.preferences.slice == nil then
		plugin.preferences.slice = true
		print_ui("[UnitySlicer] - registered preference: 'folder_path'")
	end
	if plugin.preferences.no_slice_ignore == nil then
		plugin.preferences.no_slice_ignore = true
		print_ui("[UnitySlicer] - registered preference: 'no_slice_ignore'")
	end
	if plugin.preferences.ignore_dupes == nil then
		plugin.preferences.ignore_dupes = true
		print_ui("[UnitySlicer] - registered preference: 'ignore_dupes'")
	end
	if plugin.preferences.dont_ask_import == nil then
		plugin.preferences.dont_ask_import = false
		print_ui("[UnitySlicer] - registered preference: 'dont_ask_import'")
	end
end

function importSprites(arr)
    if plugin.preferences.dont_ask_import then
        return true
    end
	local confirm = false
	local confirmDialog = Dialog("Import confirmation")
	confirmDialog
		:label{
			text="The following sprites will be imported:"
		}
		:button{
			id="sprites_list",
			text="Sprites list: "..#arr,
			onclick=function ()
				showSpriteNames(arr)
			end,
			hexpand=true
		}
		:newrow{}
		:button{
			id="yes",
			text="Yes",
			hexpand=true
		}
		:button{
			id="no",
			text="No",
			hexpand=true
		}
		:check{
			id="dont_ask_import",
			text="Dont ask me again",
			selected=plugin.preferences.dont_ask_import,
            onclick=function ()
                plugin.preferences.dont_ask_import=confirmDialog.data.dont_ask_import
                confirmDialog:repaint()
            end
		}
		-- :label{
		-- 	text=getSpriteNames(arr),
		-- 	vexpand=true
		-- }
		:show{
			autoscrollbars=true,
			wait=true,
			hand=true
		}
	if confirmDialog.data.yes then
		confirm = true
	end
	return confirm
end

function importFiles(arr)
	for i,v in ipairs(arr) do
        app.command.OpenFile{
            ui=false,
            filename=app.fs.joinPath(plugin.preferences.folder_path,v),
            sequence="no"
        }
        if plugin.preferences.slice then
            local file = io.open(app.fs.joinPath(plugin.preferences.folder_path,v)..".meta", r)
            local text = file:read("*a")
            file:close()
            local slice_data = get_slice_data(yaml.parse(text))
            slice_sprite_from_meta(slice_data)
        end
	end
end

function showSpriteNames(table)
	local str = ""
	for i,v in ipairs(table) do
		str = str..tostring(i)..": "..v.."\n"
	end
	print(str)
end

function slice_sprite_from_meta(slice_data)
	for k,v in pairs(slice_data) do
		local slice = app.sprite:newSlice(Rectangle(v["x"],app.sprite.height - v["y"] - v["height"],v["width"],v["height"]))
		slice.name = tostring(k)
		slice.color = Color{r=176,g=11,b=105,a=255}
	end
	app.refresh()
end

function listFiles(path)
	local directoryTable = app.fs.listFiles(path)
	local importTable = {}
	if app.fs.isFile(path) then
		path = app.fs.filePath(path)
	end
	for k,v in pairs(directoryTable) do
		if filetype(app.fs.joinPath(path,tostring(v))) then
			if regexMatch(v) then
				table.insert(importTable,v)
			end
		end
	end
	table.sort(importTable)
	return importTable
end

function filetype(path)
	if app.fs.isFile(path) then
		if (app.fs.fileExtension(path)=="png" or app.fs.fileExtension(path)=="jpg" or app.fs.fileExtension(path)=="jpeg") and app.fs.isFile(path..".meta") then
			if plugin.preferences.ignore_dupes and string.find(app.fs.fileTitle(path),"(_0)$")~=nil then
				if app.fs.isFile(app.fs.joinPath(app.fs.filePath(path),string.sub(app.fs.fileTitle(path),1,-3).."."..app.fs.fileExtension(path))) then
					return false
				else
					return true
				end
			else
				if plugin.preferences.no_slice_ignore then
					local file = io.open(path..".meta", r)
					local text = file:read("*a")
					file:close()
					if next(get_slice_data(yaml.parse(text)))==nil then
						return false
					end
				end
				return true
			end
		end
	end
	return false
end

function regexMatch(filename)
	if string.find(filename, plugin.preferences.regex) ~= nil then
		return true
	end
	return false
end

function dump(o)
	if type(o) == 'table' then
		local s = '{ '
		for k,v in pairs(o) do
			if type(k) ~= 'number' then k = '"'..k..'"' end
			s = s .. '['..k..'] = ' .. dump(v) .. ','.."\n"
		end
		return s .. '} '
	else
		return tostring(o)
	end
end

-- #region yaml parse
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
-- #endregion
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