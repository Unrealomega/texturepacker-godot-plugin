# The MIT License (MIT)
#
# Copyright (c) 2018 Andreas Loew / CodeAndWeb GmbH www.codeandweb.com
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

tool
extends EditorImportPlugin

var imageLoader = preload("image_loader.gd").new()

enum Preset { PRESET_DEFAULT, PRESET_PIXEL_ART }

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		imageLoader.free()

func get_importer_name():
	return "codeandweb.texturepacker_import"


func get_visible_name():
	return "TexturePacker Sheet"


func get_recognized_extensions():
	return ["tpsheet", "tpset"]


func get_save_extension():
	return "res"


func get_resource_type():
	return "Resource"


func get_preset_count():
	return Preset.size()


func get_preset_name(preset):
	match preset:
		Preset.PRESET_DEFAULT: return "Default"
		Preset.PRESET_PIXEL_ART: return "Pixel Art"


func get_import_options(preset):
	return [{
			"name": "image_flags",
			"default_value": 0 if preset == Preset.PRESET_PIXEL_ART else Texture.FLAGS_DEFAULT,
			"property_hint": PROPERTY_HINT_FLAGS,
			"hint_string": "Mipmaps,Repeat,Filter,Anisotropic,sRGB,Mirrored Repeat"
		}]


func get_option_visibility(option, options):
	return true


func get_import_order():
	return 200


func import(source_file, save_path, options, r_platform_variants, r_gen_files):
	# Dict containing all sprite information
	var sheets = read_sprite_sheet(source_file)

	match (source_file.get_extension()):
		"tpsheet":
			# Spritesheet
			print("Importing sprite sheet from "+source_file);

			var sheetFolder = source_file.get_basename()+".sprites"

			if create_folder(sheetFolder) == OK:
				var status

				for sheet in sheets.textures:
					var sheetFile = source_file.get_base_dir()+"/"+sheet.image
					var image = imageLoader.load_image(sheetFile, "ImageTexture", options)

					status = create_atlas_textures(sheetFolder, sheet, image, r_gen_files)

					if status != OK:
						break

				return status # Return if we were successful or not

			return # totally exit out of this
		"tpset":
			# Tileset
			print("Importing tileset from "+source_file);

			var fileName = "%s.%s" % [source_file.get_basename(), "res"]

			var tileSet

			if File.new().file_exists(fileName):
				tileSet = ResourceLoader.load(fileName, "TileSet")
			else:
				tileSet = TileSet.new()

			var tiles = []

			for sheet in sheets.textures:
				var sheetFile = source_file.get_base_dir()+"/"+sheet.image
				var image = imageLoader.load_image(sheetFile, "ImageTexture", options)
				r_gen_files.push_back(sheet.image)
				create_tiles(tileSet, sheet, image, tiles)

			prune_tileset(tileSet, tiles)

			r_gen_files.push_back(fileName)

			return ResourceSaver.save(fileName, tileSet)

#### Spritesheet code start ####
func create_folder(folder):
	var dir = Directory.new()

	if !dir.dir_exists(folder):
		var status = dir.make_dir_recursive(folder)

		if status != OK:
			printerr("Failed to create folder: " + folder)

		return status

	return OK # No need to create a new folder


func create_atlas_textures(sheetFolder, sheet, image, r_gen_files):
	var status

	for sprite in sheet.sprites:
		status = create_atlas_texture(sheetFolder, sprite, image, r_gen_files)

		if status != OK:
			break

	return status


func create_atlas_texture(sheetFolder, sprite, image, r_gen_files):
	var texture = AtlasTexture.new()
	texture.atlas = image

	var name = sheetFolder+"/"+sprite.filename.get_basename()+".tres"
	texture.region = Rect2(sprite.region.x,sprite.region.y,sprite.region.w,sprite.region.h)
	texture.margin = Rect2(sprite.margin.x, sprite.margin.y, sprite.margin.w, sprite.margin.h)
	r_gen_files.push_back(name)

	return save_resource(name, texture)
#### Spritesheet code end ####

#### Tileset code start ####
func create_tiles(tileSet, sheet, image, tiles):
	for sprite in sheet.sprites:
		tiles.push_back(create_tile(tileSet, sprite, image))


func create_tile(tileSet, sprite, image):
	var tileName = sprite.filename.get_basename()

	var id = tileSet.find_tile_by_name(tileName)
	if id==-1:
		id = tileSet.get_last_unused_tile_id()
		tileSet.create_tile(id)
		tileSet.tile_set_name(id, tileName)

	tileSet.tile_set_texture(id, image)
	tileSet.tile_set_region(id, Rect2(sprite.region.x,sprite.region.y,sprite.region.w,sprite.region.h))
	tileSet.tile_set_texture_offset(id, Vector2(sprite.margin.x, sprite.margin.y))
	return id


func prune_tileset(tileSet, tiles):
	tiles.sort()

	for id in tileSet.get_tiles_ids():
		if !tiles.has(id):
			tileSet.remove_tile(id)
#### Tileset code end ####

func read_sprite_sheet(fileName):
	var file = File.new()

	if file.open(fileName, file.READ) != OK:
		printerr("Failed to load "+fileName)

	var text = file.get_as_text()
	var dict = JSON.parse(text).result

	if !dict:
		printerr("Invalid json data in "+fileName)

	file.close()

	return dict


func save_resource(name, texture):
	var status = create_folder(name.get_base_dir())

	if status == OK:
		status = ResourceSaver.save(name, texture)

		if status != OK:
			printerr("Failed to save resource "+name)

	return status

