extends Node2D

# =====================================================
# LITTLE TRICK OR TREATER
# Godot 4 | Main game script
# =====================================================

const WORLD_LENGTH := 2400.0
const SCREEN_HEIGHT := 540.0
const GROUND_Y := 420.0

const SPEED := 260.0
const GRAVITY := 1100.0
const JUMP_FORCE := -430.0

const ASSET_DIR := "res://assets/Background and main character/"
const SOUND_DIR := "res://assets/Sounds/"

const IDLE_PATH := ASSET_DIR + "Idle.png"
const WALK_PATH := ASSET_DIR + "Walk.png"
const JUMP_PATH := ASSET_DIR + "Jump.png"

const MUSIC_PATH := SOUND_DIR + "BackgroundMusic.mp3"
const COLLECT_SOUND_PATH := SOUND_DIR + "sound_when_getting_candy.mp3"

var player: CharacterBody2D
var animated_player: AnimatedSprite2D
var camera: Camera2D

var health := 3
var chocolates := 0
var obstacle_index := 0

var game_started := false
var game_over := false
var game_won := false
var paused_for_choice := false
var bounce_used := false

var chest_positions := [760.0, 1390.0, 2150.0]
var collected_chests: Array[int] = []

var obstacles := [
	{
		"position": 520.0,
		"title": "A HUGE PIT!",
		"description": "Haven cannot cross this pit. What should she use?",
		"correct": "Ladder",
		"choices": ["Pretty Ribbon", "Ladder", "Tiny Comb"]
	},
	{
		"position": 1120.0,
		"title": "A SPOOKY GHOST!",
		"description": "A ghost is blocking the path! What might help?",
		"correct": "Pumpkin Lantern",
		"choices": ["Flower", "Pumpkin Lantern", "Pretty Ribbon"]
	},
	{
		"position": 1720.0,
		"title": "A DEAD TREE!",
		"description": "Branches are blocking the way. What should Haven use?",
		"correct": "Garden Shears",
		"choices": ["Tiny Comb", "Health Potion", "Garden Shears"]
	}
]

var ui_layer: CanvasLayer
var dialogue_panel: Panel
var dialogue_label: Label
var button_container: VBoxContainer
var health_label: Label
var chocolate_label: Label
var toast_label: Label

var music_player: AudioStreamPlayer
var collect_player: AudioStreamPlayer


# =====================================================
# START
# =====================================================

func _ready():
	_create_input_controls()
	_create_ground()
	_build_player()
	_build_audio()
	_build_ui()
	queue_redraw()


func _create_input_controls():
	if not InputMap.has_action("ui_left"):
		InputMap.add_action("ui_left")

	if not InputMap.has_action("ui_right"):
		InputMap.add_action("ui_right")

	var key_a := InputEventKey.new()
	key_a.physical_keycode = KEY_A

	if not InputMap.action_has_event("ui_left", key_a):
		InputMap.action_add_event("ui_left", key_a)

	var key_d := InputEventKey.new()
	key_d.physical_keycode = KEY_D

	if not InputMap.action_has_event("ui_right", key_d):
		InputMap.action_add_event("ui_right", key_d)


# =====================================================
# GROUND
# =====================================================

func _create_ground():
	var ground := StaticBody2D.new()
	ground.position = Vector2(WORLD_LENGTH / 2.0, GROUND_Y + 40.0)

	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(WORLD_LENGTH, 80.0)

	collision.shape = shape
	ground.add_child(collision)
	add_child(ground)


# =====================================================
# CHARACTER ANIMATIONS
# =====================================================

func _make_animation(
	frames: SpriteFrames,
	animation_name: String,
	texture_path: String,
	frame_count: int,
	fps: float,
	loop_animation: bool
):
	if not ResourceLoader.exists(texture_path):
		push_warning("Missing character asset: " + texture_path)
		return

	var texture := load(texture_path) as Texture2D

	if texture == null:
		push_warning("Could not load: " + texture_path)
		return

	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, fps)
	frames.set_animation_loop(animation_name, loop_animation)

	var frame_width := float(texture.get_width()) / float(frame_count)
	var frame_height := float(texture.get_height())

	for i in range(frame_count):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(
			i * frame_width,
			0,
			frame_width,
			frame_height
		)

		frames.add_frame(animation_name, atlas)


func _build_player():
	player = CharacterBody2D.new()
	player.position = Vector2(100, GROUND_Y - 30)

	var collision := CollisionShape2D.new()
	var shape := CapsuleShape2D.new()
	shape.radius = 14
	shape.height = 54
	collision.shape = shape
	player.add_child(collision)

	var frames := SpriteFrames.new()

	_make_animation(
		frames, "idle", IDLE_PATH, 2, 3.0, true
	)

	_make_animation(
		frames, "walk", WALK_PATH, 4, 9.0, true
	)

	_make_animation(
		frames, "jump", JUMP_PATH, 11, 12.0, false
	)

	animated_player = AnimatedSprite2D.new()
	animated_player.sprite_frames = frames
	animated_player.position = Vector2(0, -5)
	animated_player.scale = Vector2(1.0, 1.0)

	player.add_child(animated_player)

	if frames.has_animation("idle"):
		animated_player.play("idle")

	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	camera.limit_left = 0
	camera.limit_right = int(WORLD_LENGTH)
	camera.limit_top = 0
	camera.limit_bottom = int(SCREEN_HEIGHT)

	player.add_child(camera)
	camera.make_current()

	add_child(player)


# =====================================================
# SOUND
# =====================================================

func _build_audio():
	music_player = AudioStreamPlayer.new()
	add_child(music_player)

	collect_player = AudioStreamPlayer.new()
	add_child(collect_player)

	if ResourceLoader.exists(MUSIC_PATH):
		music_player.stream = load(MUSIC_PATH)
		music_player.volume_db = -12
		music_player.finished.connect(
			func():
				music_player.play()
		)

	if ResourceLoader.exists(COLLECT_SOUND_PATH):
		collect_player.stream = load(COLLECT_SOUND_PATH)


func _play_collect_sound():
	if collect_player.stream != null:
		collect_player.play()


# =====================================================
# USER INTERFACE
# =====================================================

func _build_ui():
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	health_label = Label.new()
	health_label.position = Vector2(25, 20)
	health_label.add_theme_font_size_override("font_size", 25)
	ui_layer.add_child(health_label)

	chocolate_label = Label.new()
	chocolate_label.position = Vector2(760, 20)
	chocolate_label.add_theme_font_size_override("font_size", 22)
	ui_layer.add_child(chocolate_label)

	toast_label = Label.new()
	toast_label.position = Vector2(280, 75)
	toast_label.size = Vector2(500, 50)
	toast_label.add_theme_font_size_override("font_size", 24)
	toast_label.add_theme_color_override("font_color", Color.YELLOW)
	ui_layer.add_child(toast_label)

	dialogue_panel = Panel.new()
	dialogue_panel.position = Vector2(180, 120)
	dialogue_panel.size = Vector2(600, 310)
	dialogue_panel.visible = false
	ui_layer.add_child(dialogue_panel)

	dialogue_label = Label.new()
	dialogue_label.position = Vector2(25, 20)
	dialogue_label.size = Vector2(550, 110)
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	dialogue_label.add_theme_font_size_override("font_size", 22)
	dialogue_panel.add_child(dialogue_label)

	button_container = VBoxContainer.new()
	button_container.position = Vector2(80, 145)
	button_container.size = Vector2(440, 145)
	button_container.add_theme_constant_override("separation", 10)
	dialogue_panel.add_child(button_container)

	_update_hud()
	_show_intro()


func _update_hud():
	health_label.text = "❤️ ".repeat(health)
	chocolate_label.text = "🍫 %d / 3" % chocolates


# =====================================================
# INTRO
# =====================================================

func _show_intro():
	_show_dialogue(
		"LITTLE TRICK OR TREATER 🎃\n\n" +
		"Meet Haven! She is going trick-or-treating " +
		"on a spooky Halloween night.\n\n" +
		"Her mission is to collect three chocolates " +
		"and bring them to her sick friend.",
		["START PLAYING"],
		_start_game
	)


func _start_game(_option = ""):
	game_started = true
	dialogue_panel.visible = false

	if music_player.stream != null:
		music_player.play()

	_show_toast("Find all three chocolates, Haven!")


# =====================================================
# MOVEMENT
# =====================================================

func _physics_process(delta):
	if not game_started or game_over or game_won:
		return

	if paused_for_choice:
		player.velocity.x = 0
		return

	var direction := 0.0

	if Input.is_action_pressed("ui_right"):
		direction += 1.0

	if Input.is_action_pressed("ui_left"):
		direction -= 1.0

	player.velocity.x = direction * SPEED

	if not player.is_on_floor():
		player.velocity.y += GRAVITY * delta

		if animated_player.sprite_frames.has_animation("jump"):
			if animated_player.animation != "jump":
				animated_player.play("jump")

	else:
		if Input.is_action_just_pressed("ui_accept"):
			player.velocity.y = JUMP_FORCE

			if animated_player.sprite_frames.has_animation("jump"):
				animated_player.play("jump")

		elif direction != 0:
			if animated_player.sprite_frames.has_animation("walk"):
				if animated_player.animation != "walk":
					animated_player.play("walk")

		else:
			if animated_player.sprite_frames.has_animation("idle"):
				if animated_player.animation != "idle":
					animated_player.play("idle")

	if direction != 0:
		animated_player.flip_h = direction < 0

	player.move_and_slide()

	player.position.x = clamp(
		player.position.x,
		40.0,
		WORLD_LENGTH - 40.0
	)

	if player.position.y > SCREEN_HEIGHT + 100:
		player.position.y = GROUND_Y - 40
		player.velocity = Vector2.ZERO
		_lose_heart("Haven fell down!")


# =====================================================
# GAME LOOP
# =====================================================

func _process(_delta):
	if not game_started or game_over or game_won:
		return

	if paused_for_choice:
		return

	_check_obstacles()
	_check_chests()
	_check_bounce_pad()

	if chocolates >= 3:
		_win_game()

	_update_hud()


# =====================================================
# OBSTACLES AND ITEM CHOICES
# =====================================================

func _check_obstacles():
	if obstacle_index >= obstacles.size():
		return

	var obstacle = obstacles[obstacle_index]

	if abs(player.position.x - obstacle["position"]) < 35:
		player.position.x = obstacle["position"] - 35
		_open_item_selection(obstacle)


func _open_item_selection(obstacle):
	paused_for_choice = true

	_show_dialogue(
		obstacle["title"] + "\n\n" + obstacle["description"],
		obstacle["choices"],
		_select_item
	)


func _select_item(selected_item):
	dialogue_panel.visible = false
	paused_for_choice = false

	var obstacle = obstacles[obstacle_index]

	if selected_item == obstacle["correct"]:
		_show_toast("Great choice! Haven can continue!")

	else:
		if selected_item == "Health Potion":
			_restore_heart()

		_lose_heart("That wasn't the right choice!")

	obstacle_index += 1
	player.position.x += 20


# =====================================================
# HEALTH
# =====================================================

func _lose_heart(message):
	if game_over:
		return

	health = max(health - 1, 0)
	_update_hud()
	_show_toast(message)

	if health <= 0:
		_game_over()


func _restore_heart():
	if health < 3:
		health += 1
		_update_hud()
		_show_toast("Haven gained one heart! ❤️")
	else:
		_show_toast("Haven already has full health!")


# =====================================================
# TREASURE CHESTS
# =====================================================

func _check_chests():
	for i in range(chest_positions.size()):
		if collected_chests.has(i):
			continue

		if abs(player.position.x - chest_positions[i]) < 35:
			_collect_chocolate(i)


func _collect_chocolate(index):
	collected_chests.append(index)
	chocolates += 1

	_play_collect_sound()
	queue_redraw()

	_update_hud()

	_show_toast(
		"Chocolate collected! 🍫 %d / 3" % chocolates
	)

	if chocolates >= 3:
		_win_game()


# =====================================================
# BOUNCE BACK
# =====================================================

func _check_bounce_pad():
	if bounce_used:
		return

	if abs(player.position.x - 1930.0) < 30:
		bounce_used = true
		player.velocity.y = JUMP_FORCE * 1.3

		_restore_heart()

		_show_toast("BOUNCE BACK!!! Haven bounced back!")


# =====================================================
# WIN SCREEN
# =====================================================

func _win_game():
	if game_won:
		return

	game_won = true
	game_started = false

	_show_dialogue(
		"YOU DID IT! 🎃\n\n" +
		"Haven collected all three chocolates!\n\n" +
		"She takes them to her sick friend " +
		"to make her feel better.\n\n" +
		"Sometimes a little kindness can make someone's day!",
		["PLAY AGAIN"],
		_restart_game
	)


# =====================================================
# GAME OVER
# =====================================================

func _game_over():
	if game_over:
		return

	game_over = true
	game_started = false

	_show_dialogue(
		"OH NO! 💔\n\n" +
		"Haven ran out of hearts.\n\n" +
		"Don't give up! Every adventure is another chance.\n\n" +
		"Try again, we believe in you!",
		["TRY AGAIN"],
		_restart_game
	)


func _restart_game(_option = ""):
	get_tree().reload_current_scene()


# =====================================================
# DIALOGUE
# =====================================================

func _show_dialogue(message, options, callback):
	dialogue_panel.visible = true
	dialogue_label.text = message

	for child in button_container.get_children():
		child.queue_free()

	for option in options:
		var selected_option := str(option)

		var button := Button.new()
		button.text = selected_option
		button.custom_minimum_size = Vector2(420, 42)
		button.add_theme_font_size_override("font_size", 19)

		button_container.add_child(button)

		button.pressed.connect(
			func():
				callback.call(selected_option)
		)


# =====================================================
# TOAST
# =====================================================

func _show_toast(message):
	toast_label.text = message

	var timer := get_tree().create_timer(2.0)

	timer.timeout.connect(
		func():
			if is_instance_valid(toast_label):
				toast_label.text = ""
	)


# =====================================================
# WORLD DRAWING
# =====================================================

func _draw():
	# Night sky
	draw_rect(
		Rect2(0, 0, WORLD_LENGTH, GROUND_Y),
		Color(0.08, 0.07, 0.20)
	)

	# Moon
	draw_circle(
		Vector2(400, 95),
		42,
		Color(1.0, 0.93, 0.65)
	)

	# Stars
	for i in range(55):
		var x := float((i * 173) % int(WORLD_LENGTH))
		var y := float((i * 47) % 300 + 20)

		draw_circle(Vector2(x, y), 2, Color.WHITE)

	# Ground
	draw_rect(
		Rect2(0, GROUND_Y, WORLD_LENGTH, 120),
		Color(0.20, 0.12, 0.10)
	)

	draw_rect(
		Rect2(0, GROUND_Y, WORLD_LENGTH, 12),
		Color(0.20, 0.42, 0.20)
	)

	# Trees
	for x in range(250, int(WORLD_LENGTH), 350):
		draw_rect(
			Rect2(x, 290, 22, 130),
			Color(0.22, 0.12, 0.08)
		)

		draw_circle(
			Vector2(x + 10, 280),
			55,
			Color(0.12, 0.25, 0.15)
		)

	# Pit marker
	draw_rect(
		Rect2(490, GROUND_Y - 5, 70, 25),
		Color(0.02, 0.02, 0.04)
	)

	# Ghost marker
	draw_circle(
		Vector2(1120, GROUND_Y - 55),
		25,
		Color(0.65, 0.65, 0.85)
	)

	# Dead tree marker
	draw_rect(
		Rect2(1700, GROUND_Y - 55, 90, 55),
		Color(0.20, 0.12, 0.08)
	)

	# Treasure chests
	for i in range(chest_positions.size()):
		if collected_chests.has(i):
			continue

		var chest_x: float = chest_positions[i]

		draw_rect(
			Rect2(chest_x - 18, GROUND_Y - 38, 36, 28),
			Color(0.55, 0.25, 0.08)
		)

		draw_rect(
			Rect2(chest_x - 18, GROUND_Y - 42, 36, 9),
			Color(0.85, 0.55, 0.12)
		)

		draw_circle(
			Vector2(chest_x, GROUND_Y - 25),
			4,
			Color.YELLOW
		)

	# Bounce pad
	draw_rect(
		Rect2(1910, GROUND_Y - 12, 45, 12),
		Color(0.1, 0.9, 0.4)
	)

	# Pumpkins
	for x in range(300, int(WORLD_LENGTH), 600):
		draw_circle(
			Vector2(x, GROUND_Y - 15),
			13,
			Color(1.0, 0.42, 0.05)
		)

		draw_rect(
			Rect2(x - 2, GROUND_Y - 30, 4, 8),
			Color(0.15, 0.45, 0.10)
		)
