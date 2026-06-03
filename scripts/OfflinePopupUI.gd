# =============================================================================
# OfflinePopupUI.gd
# Injected by TabNavigator._inject_offline_popup() deferred in _ready().
# Added to UILayer (same parent as TabNavigator / LevelTransitionUI).
# z_index = 90 — above normal UI, below LevelTransitionUI (100).
#
# Shows once per session when the player was away ≥ 60 seconds.
# Reads GameManager.last_offline_seconds and last_offline_earnings.
# Frees itself after the player taps "Collect!".
# =============================================================================
extends Control

const RESOURCE_ICONS: Dictionary = {
	"Wood":   "🪵",
	"Steel":  "⚙️",
	"Glass":  "💎",
	"Copper": "🔶",
}

func _ready() -> void:
	# Guard — shouldn't happen if TabNavigator checks first, but be safe
	if GameManager.last_offline_seconds < 60.0:
		queue_free()
		return

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index      = 90
	mouse_filter = Control.MOUSE_FILTER_STOP

	# ---- Dark backdrop -------------------------------------------------------
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color        = Color(0.0, 0.0, 0.0, 0.82)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# ---- Centred card --------------------------------------------------------
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(300.0, 0.0)
	card.mouse_filter        = Control.MOUSE_FILTER_STOP
	center.add_child(card)

	var card_margin := MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left",   18)
	card_margin.add_theme_constant_override("margin_right",  18)
	card_margin.add_theme_constant_override("margin_top",    18)
	card_margin.add_theme_constant_override("margin_bottom", 18)
	card.add_child(card_margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	card_margin.add_child(vbox)

	# ---- Header --------------------------------------------------------------
	var title := Label.new()
	title.text                 = "Welcome Back!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.9, 0.75, 0.2))
	vbox.add_child(title)

	# ---- Time away -----------------------------------------------------------
	var secs:  int    = int(GameManager.last_offline_seconds)
	var hours: int    = secs / 3600
	var mins:  int    = (secs % 3600) / 60
	var time_str: String
	if hours > 0:
		time_str = "%d h %d min" % [hours, mins]
	else:
		time_str = "%d min" % mins

	var away_lbl := Label.new()
	away_lbl.text                 = "You were away for %s." % time_str
	away_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	away_lbl.add_theme_font_size_override("font_size", 13)
	away_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	vbox.add_child(away_lbl)

	# ---- Earnings list -------------------------------------------------------
	var earnings: Dictionary = GameManager.last_offline_earnings
	if earnings.is_empty():
		var idle_lbl := Label.new()
		idle_lbl.text                 = "Your storage was full — nothing was produced."
		idle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		idle_lbl.add_theme_font_size_override("font_size", 12)
		idle_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		idle_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(idle_lbl)
	else:
		var earned_hdr := Label.new()
		earned_hdr.text                 = "Your factory produced:"
		earned_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		earned_hdr.add_theme_font_size_override("font_size", 12)
		earned_hdr.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		vbox.add_child(earned_hdr)

		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 16)
		grid.add_theme_constant_override("v_separation",  4)
		vbox.add_child(grid)

		# Sort by RESOURCE_TYPES order so display is consistent
		for res in GameManager.RESOURCE_TYPES:
			if not earnings.has(res):
				continue
			var amount: int = earnings[res]
			var icon: String = RESOURCE_ICONS.get(res, "•")

			var name_lbl := Label.new()
			name_lbl.text = "%s %s" % [icon, res]
			name_lbl.add_theme_font_size_override("font_size", 13)
			grid.add_child(name_lbl)

			var amt_lbl := Label.new()
			amt_lbl.text = "+%d" % amount
			amt_lbl.add_theme_font_size_override("font_size", 13)
			amt_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.55))
			amt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			grid.add_child(amt_lbl)

	# ---- Offline multiplier hint --------------------------------------------
	var pct: int = int(GameManager.offline_multiplier * 100.0)
	var hint_lbl := Label.new()
	hint_lbl.text = "Factory running at %d%% offline capacity." % pct
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.add_theme_font_size_override("font_size", 10)
	hint_lbl.add_theme_color_override("font_color", Color(0.42, 0.42, 0.42))
	vbox.add_child(hint_lbl)

	# ---- Collect button ------------------------------------------------------
	var btn_row := HBoxContainer.new()
	btn_row.alignment             = BoxContainer.ALIGNMENT_CENTER
	btn_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(btn_row)

	var collect_btn := Button.new()
	collect_btn.text               = "Collect!"
	collect_btn.custom_minimum_size = Vector2(150.0, 48.0)
	collect_btn.modulate           = Color(1.0, 0.85, 0.2)
	collect_btn.pressed.connect(func():
		# Clear so a scene reload (e.g. after reset) doesn't re-show the popup
		GameManager.last_offline_seconds  = 0.0
		GameManager.last_offline_earnings = {}
		queue_free()
	)
	btn_row.add_child(collect_btn)
