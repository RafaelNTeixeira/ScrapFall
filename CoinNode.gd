# =============================================================================
# CoinNode.gd
# Attach via set_script() to an Area2D instantiated by Board._spawn_coin().
# Appears on the board as a golden coin.  Any ball that passes through it
# awards bonus gold.  Coins fade out and self-destruct after LIFETIME seconds.
# =============================================================================
extends Area2D

const GOLD_REWARD: float  = 8.0    # multiplied by raw_rate_multiplier
const LIFETIME:    float  = 12.0
const BLINK_AT:    float  = 3.0    # start blinking when this many seconds remain

var _timer:     float = LIFETIME
var _collected: bool  = false

func _ready() -> void:
	collision_layer = 0
	collision_mask  = 2   # detect balls (layer 2)

	# ---- Visual: golden polygon circle -------------------------------------
	var poly        := Polygon2D.new()
	var pts:           PackedVector2Array
	for i in 20:
		var a: float = i * TAU / 20.0
		pts.append(Vector2(cos(a), sin(a)) * 13.0)
	poly.polygon = pts
	poly.color   = Color(1.0, 0.82, 0.1)
	add_child(poly)

	# Inner highlight
	var inner        := Polygon2D.new()
	var inner_pts:      PackedVector2Array
	for i in 20:
		var a: float = i * TAU / 20.0
		inner_pts.append(Vector2(cos(a), sin(a)) * 7.0)
	inner.polygon = inner_pts
	inner.color   = Color(1.0, 0.95, 0.55)
	add_child(inner)

	# ---- "G" label ---------------------------------------------------------
	var lbl := Label.new()
	lbl.text = "G"
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.35, 0.0))
	lbl.size             = Vector2(14.0, 14.0)
	lbl.position         = Vector2(-7.0, -8.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(lbl)

	# ---- Collision shape ---------------------------------------------------
	var col   := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 16.0
	col.shape    = shape
	add_child(col)

	body_entered.connect(_on_ball_entered)

	# Pop-in animation
	scale = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.25, 1.25), 0.12)
	tw.tween_property(self, "scale", Vector2(1.0,  1.0),  0.09)

func _process(delta: float) -> void:
	if _collected:
		return
	_timer -= delta
	if _timer <= BLINK_AT:
		modulate.a = 0.45 + 0.55 * abs(sin(_timer * 5.5))
	if _timer <= 0.0:
		queue_free()

func _on_ball_entered(body: Node) -> void:
	if _collected:
		return
	if not body.has_method("enter_slot"):
		return
	_collected = true

	var reward: float = GOLD_REWARD * GameManager.raw_rate_multiplier
	GameManager.award_gold(reward)
	AudioManager.play(AudioManager.sfx_slot_collect)

	# Collect burst animation then free
	var tw := create_tween()
	tw.tween_property(self, "scale",      Vector2(1.6, 1.6), 0.08)
	tw.tween_property(self, "modulate:a", 0.0,               0.18)
	tw.tween_callback(queue_free)
