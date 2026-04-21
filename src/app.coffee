
@song =
	clear: ->
		@notes = []
		@tuning = "eBGDAE" # backwards
		@strings = ("#{string_name}|-" for string_name in @tuning)
		@pos = 0
		return
	
	toJSON: -> @notes
	toString: -> song.strings.join("\n")
	
	addNote: (rec_note)->
		song.notes.push(rec_note)
		
		# @TODO: go through Tablature.stringify()
		
		dashes = ["","-","--","---","----"]["#{rec_note.f}".length]
		for string, s in song.strings
			song.strings[s] += if s is rec_note.s then rec_note.f else dashes
			song.strings[s] += "-" # additional dash to space notes apart
		
		$tablature_error.dismiss()
		
		tablature_editor.editor.setValue("#{song}", 1)
		
		if song.notes.length is 1
			tablature_editor.showPlaybackPosition(song.pos)
		return

song.clear()


scale_start = "C"
scale = teoria.scale scale_start, "harmonicchromatic"

scale_select = document.getElementById("scale")
scale_start_select = document.getElementById("scale-start")
tablature_presets_select = document.getElementById("tablature-presets")
# disable_outside_scale_checkbox = document.getElementById("disable-outside-scale")
multi_row_selection_mode_input = document.getElementById("multi-row-selection-mode")
overwrite_mode_input = document.getElementById("overwrite-mode")
keytar_mode_input = document.getElementById("keytar-mode")
undo_button = document.getElementById("undo")
redo_button = document.getElementById("redo")
keys_container = document.getElementById("keys")
keyboard_element = document.getElementById("keyboard")

scale_midi_values = []
@is_midi_value_in_scale = (midi_value)->
	(midi_value % 12) in scale_midi_values

do update_scale_highlighting = ->
	scale_name = scale_select.selectedOptions[0].value
	scale_start = scale_start_select.selectedOptions[0].value
	if scale_name is ""
		scale_notes = []
	else
		scale_notes = teoria.scale(scale_start, scale_name).notes()
	scale_midi_values = (scale_note.midi() % 12 for scale_note in scale_notes)
	return

# disable_outside_scale = disable_outside_scale_checkbox.checked
# disable_outside_scale_checkbox.onchange = (e)->
# 	disable_outside_scale = e.target.checked
# 	update_scale_highlighting()
# 	return

scale_select.addEventListener "change", update_scale_highlighting
scale_start_select.addEventListener "change", update_scale_highlighting

tablature_presets_select.addEventListener "change", (e)->
	path = e.target.value
	if path is ""
		tablature_editor.editor.setValue("")
		return
	# fetch isn't allowed on file: URI
	# fetch path
	# .catch (err)->
	# 	$tablature_error.message.text("Failed to load #{path}: #{err}")
	# 	tablature_editor.editor.setValue(err.stack)
	# .then (tabs_text)->
	# 	load_tablature(tabs_text)
	xhr = new XMLHttpRequest()
	xhr.addEventListener "error", (e)->
		$tablature_error.message.text("Failed to load #{path}")
		# tablature_editor.editor.setValue(err.stack)
	xhr.addEventListener "load", ->
		tabs_text = xhr.responseText
		load_tablature(tabs_text)
	xhr.open "GET", path
	xhr.send()
	return


@fretboard = new Fretboard()
$(fretboard.canvas).appendTo(".fretboard-area")

$tablature_error = $(".tablature-error")
$tablature_error.dismiss = ->
	@hide().attr("aria-hidden", "true").text("")
	return
$tablature_error.message = (message)->
	@show().attr("aria-hidden", "false").text(message)
	return

tablature_editor = new TablatureEditor($(".tablature-editor")[0])
tablature_editor.showPlaybackPosition(song.pos)

undo_button.addEventListener "click", ->
	tablature_editor.editor.undo()
	return
redo_button.addEventListener "click", ->
	tablature_editor.editor.redo()
	return

tablature_editor.editor.on "input", ->
	undo_manager = tablature_editor.editor.session.getUndoManager()
	undo_button.disabled = not undo_manager.hasUndo()
	redo_button.disabled = not undo_manager.hasRedo()
	

do update_multi_row_selection_mode = ->
	tablature_editor.multi_row_selection_mode = multi_row_selection_mode_input.checked
	return
multi_row_selection_mode_input.addEventListener "change", update_multi_row_selection_mode

do update_overwrite_mode = ->
	tablature_editor.editor.session.setOverwrite(overwrite_mode_input.checked)
	return
overwrite_mode_input.addEventListener "change", update_overwrite_mode
tablature_editor.editor.session.on "changeOverwrite", ->
	overwrite_mode_input.checked = tablature_editor.editor.session.getOverwrite()
	return

keytar_mode = no
keytar_frets = [0, 0, 0, 0]
keytar_fret_keys_by_string = [null, null, null, null]
keytar_plucking_notes = {}
fretboard.keytar_frets = keytar_frets

keytar_fret_key_rows = [
	[49, 50, 51, 52, 53, 54, 55, 56, 57, 48, 189, 187] # 1234567890-=
	[81, 87, 69, 82, 84, 89, 85, 73, 79, 80, 219, 221] # qwertyuiop[]
	[65, 83, 68, 70, 71, 72, 74, 75, 76, 186, 222] # asdfghjkl;'
	[90, 88, 67, 86, 66, 78, 77, 188, 190, 191] # zxcvbnm,./
]
keytar_fret_key_map = {}
for row, string_index in keytar_fret_key_rows
	for key_code, key_index in row
		keytar_fret_key_map[key_code] =
			string: string_index
			fret: key_index + 1

keytar_pluck_key_map =
	8: 0 # Backspace
	220: 1 # Backslash
	13: 2 # Enter
	16: 3 # Shift

is_text_input_target = (target)->
	target?.tagName?.match /textarea|input|select/i

handle_keytar_keydown = (e)->
	key = e.keyCode
	fret_spec = keytar_fret_key_map[key]
	if fret_spec?
		e.preventDefault()
		keytar_fret_keys_by_string[fret_spec.string] = key
		keytar_frets[fret_spec.string] = fret_spec.fret
		return on

	pluck_string_index = keytar_pluck_key_map[key]
	if pluck_string_index?
		return on if keytar_plucking_notes[key] # prevent repeat
		e.preventDefault()
		str = fretboard.strings[pluck_string_index]
		PLAYING_ID = Math.random()
		str.PLAYING_ID = PLAYING_ID
		str.play(keytar_frets[pluck_string_index] ? 0)
		keytar_plucking_notes[key] =
			string_index: pluck_string_index
			PLAYING_ID: PLAYING_ID
		return on

	off

handle_keytar_keyup = (e)->
	key = e.keyCode
	fret_spec = keytar_fret_key_map[key]
	if fret_spec?
		e.preventDefault()
		if keytar_fret_keys_by_string[fret_spec.string] is key
			keytar_fret_keys_by_string[fret_spec.string] = null
			keytar_frets[fret_spec.string] = 0
		return on

	pluck_note = keytar_plucking_notes[key]
	if pluck_note?
		e.preventDefault()
		str = fretboard.strings[pluck_note.string_index]
		str.release() if str.PLAYING_ID is pluck_note.PLAYING_ID
		delete keytar_plucking_notes[key]
		return on

	off

do update_keytar_mode = ->
	keytar_mode = keytar_mode_input?.checked
	unless keytar_mode
		for pluck_key, pluck_note of keytar_plucking_notes
			str = fretboard.strings[pluck_note.string_index]
			str.release() if str.PLAYING_ID is pluck_note.PLAYING_ID
		keytar_plucking_notes = {}
		for i in [0...keytar_frets.length]
			keytar_frets[i] = 0
			keytar_fret_keys_by_string[i] = null
	try localStorage.guitar_keytar_mode = "#{keytar_mode}" if keytar_mode_input?
	return
if keytar_mode_input?
	try keytar_mode_input.checked = localStorage.guitar_keytar_mode is "true"
	keytar_mode_input.addEventListener "change", update_keytar_mode
	update_keytar_mode()

$theme = $(".theme")

try
	theme = Fretboard.themes[localStorage.guitar_theme]
	fretboard.theme = theme if theme

for theme_name, theme of Fretboard.themes
	$("<option>")
		.text(theme_name)
		.attr(value: theme_name, selected: Fretboard.themes[theme_name] is fretboard.theme)
		.appendTo($theme)

$theme.on "change", ->
	fretboard.theme = Fretboard.themes[$theme.val()]
	try localStorage.guitar_theme = $theme.val()
	return


do animate = =>
	fretboard.draw()
	requestAnimationFrame(animate)
	return


$$ = $(window)

$$.on "keyup", (e)->
	if keytar_mode and not is_text_input_target(e.target)
		handle_keytar_keyup(e)
		e.preventDefault()
		return

	if e.keyCode is 32 # Spacebar
		sustain = off
		for string in fretboard.strings
			string.release()
	return

$$.on "keydown", (e)->
	key = e.keyCode
	console?.log? key if e.altKey
	
	if e.ctrlKey and key is 65 # Ctrl+A
		tablature_editor.editor.focus()
		tablature_editor.editor.selection.selectAll()

	if keytar_mode and not is_text_input_target(e.target)
		handle_keytar_keydown(e)
		e.preventDefault()
		return
	
	return if e.ctrlKey or e.shiftKey or e.altKey or key is 9 or key > ~~100
	
	if key is 36 # Home
		song.pos = 0
		tablature_editor.showPlaybackPosition(song.pos)
	else if key is 32 # Spacebar
		sustain = on
	else
		unless is_text_input_target(e.target)
			
			return if fretboard.playing_notes[key] # prevent repeat
			play = song.notes[song.pos]
			return unless play
			
			chord = if play.length then play else [play]
			
			fretboard.playing_notes[key] = chord
			chord_pos = song.pos
			song.pos = (song.pos+1) % song.notes.length
			
			PLAYING_ID = Math.random()
			for chord_note in chord
				str = fretboard.strings[chord_note.s]
				str.PLAYING_ID = PLAYING_ID
				str.play(chord_note.f)
				tablature_editor.showPlayingNote(chord_pos, chord_note)
			
			$$.on "keyup", onkeyup = (e)->
				if e.keyCode is key
					for chord_note in chord
						str = fretboard.strings[chord_note.s]
						str.release() if str.PLAYING_ID is PLAYING_ID
						tablature_editor.removePlayingNote(chord_pos, chord_note)
					
					delete fretboard.playing_notes[key]
					$$.off "keyup", onkeyup
					
					tablature_editor.showPlaybackPosition(song.pos)
				return
	return

$$.on "blur", ->
	keytar_plucking_notes = {}
	for i in [0...keytar_frets.length]
		keytar_frets[i] = 0
		keytar_fret_keys_by_string[i] = null
	string.stop() for string in fretboard.strings

# @TODO: maybe listen for change and indicate that you need to unfocus it to update
# or better yet just conditionally show a button

tablature_editor.editor.on "blur", ->
	text = tablature_editor.editor.getValue()
	load_tablature(text)
	return

load_tablature = (text)->
	if text isnt "#{song}" and text
		try
			res = Tablature.parse(text.replace(/\ <</g, ""))
		catch error
			if error.blocks
				$tablature_error.message(error.message_only)
				tablature_editor.editor.setValue(error.blocks, -1)
				index = error.blocks.indexOf(error.misaligned_block)
				unless index is -1
					position = tablature_editor.editor.getSession().getDocument().indexToPosition(index)
					tablature_editor.editor.scrollToRow(position.row)
			else
				$tablature_error.message(error.message)
		
		if res
			song.clear()
			song.notes = res
			song.strings = Tablature.stringify(res).split("\n")
			
			$tablature_error.dismiss()
			tablature_editor.editor.setValue("#{song}", -1)
			tablature_editor.showPlaybackPosition(song.pos)
	else
		$tablature_error.dismiss()
	return
