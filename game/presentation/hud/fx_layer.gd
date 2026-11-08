class_name FxLayer
extends Control
## Screen-space effects that cross between the train scene and the board: parcels flying
## from a collected wagon to its shelf slot, floating texts ("Combo x3!", "+30"), coin
## bursts and the red danger vignette. Drawn above both 3D views and below the HUD.

const PARCEL_SECONDS := 0.38
const TEXT_SECONDS := 0.9

var _vignette: ColorRect
var _danger := 0.0
var _pulse := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette = ColorRect.new()
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float strength = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 0.15, 0.1, 1.0);
void fragment() {
	vec2 d = UV - vec2(0.5);
	float edge = smoothstep(0.32, 0.75, length(d * vec2(1.0, 0.75)));
	COLOR = vec4(tint.rgb, edge * strength);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	_vignette.material = material
	add_child(_vignette)


## 0..1 danger; above the threshold the screen edges pulse red.
func set_danger(value: float) -> void:
	_danger = value


func _process(delta: float) -> void:
	_pulse += delta * (4.0 + _danger * 6.0)
	var strength := 0.0
	if _danger > 0.8:
		strength = (_danger - 0.8) / 0.2 * (0.35 + 0.2 * sin(_pulse))
	(_vignette.material as ShaderMaterial).set_shader_parameter("strength", strength)


## A rounded parcel of `color` arcs from `from` to `to` (screen points), then `arrived`.
func fly_parcel(from: Vector2, to: Vector2, color: Color, arrived: Callable) -> void:
	var parcel := Panel.new()
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = color.darkened(0.3)
	box.set_border_width_all(4)
	box.set_corner_radius_all(14)
	parcel.add_theme_stylebox_override("panel", box)
	parcel.size = Vector2(56, 56)
	parcel.pivot_offset = parcel.size * 0.5
	parcel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(parcel)
	var lift := minf(220.0, from.distance_to(to) * 0.35)
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		var point := from.lerp(to, t) + Vector2(0.0, -sin(t * PI) * lift)
		parcel.position = point - parcel.size * 0.5
		parcel.rotation = t * TAU
		parcel.scale = Vector2.ONE * lerpf(1.0, 0.6, t), 0.0, 1.0, PARCEL_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(parcel.queue_free)
	tween.tween_callback(arrived)


## Text that pops in, rises and fades (combo, near miss, coin rewards).
func float_text(text: String, at: Vector2, color: Color, size: int = 72) -> void:
	var label := UiStyle.heading(text, size, color, Palette.INK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size = Vector2(900, size * 1.6)
	label.position = at - label.size * 0.5
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2.ONE * 0.4
	add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "scale", Vector2.ONE * 1.1, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, 0.08)
	tween.parallel().tween_property(label, "position:y", label.position.y - 120.0, TEXT_SECONDS).set_delay(0.1)
	tween.parallel().tween_property(label, "modulate:a", 0.0, TEXT_SECONDS * 0.6).set_delay(TEXT_SECONDS * 0.5)
	tween.tween_callback(label.queue_free)


## A burst of small coins flying from `from` to `to` (e.g. win reward to coin counter).
func coin_burst(from: Vector2, to: Vector2, count: int = 10) -> void:
	for i in count:
		var coin := Panel.new()
		var box := StyleBoxFlat.new()
		box.bg_color = Palette.GOLD
		box.border_color = Palette.GOLD_DARK
		box.set_border_width_all(4)
		box.set_corner_radius_all(99)
		coin.add_theme_stylebox_override("panel", box)
		coin.size = Vector2(44, 44)
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var start := from + Vector2(randf_range(-90, 90), randf_range(-60, 60))
		coin.position = start
		add_child(coin)
		var tween := create_tween()
		tween.tween_interval(i * 0.04)
		tween.tween_property(coin, "position", to, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(coin.queue_free)
