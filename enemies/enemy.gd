extends CharacterBody2D
class_name Enemy

@export var speed = 20
@export var knockback_strength: float = 300.0
@export var max_health = 5.0

var health = max_health
var detection_distance = 200
var is_taking_damage = false

@onready var audio_take_damage = $TakeDamage
@onready var nav_agent = $NavigationAgent2D as NavigationAgent2D

func _ready():
	$AnimationPlayer.play("walking")
	health = max_health

func _physics_process(delta):
	var dir = to_local(nav_agent.get_next_path_position()).normalized()
	velocity = dir * speed
	move_and_slide()
	
	if velocity.x < 0 and $Sprite2D.scale.x > 0:
		$Sprite2D.scale.x = -1
	elif velocity.x > 0 and $Sprite2D.scale.x < 0:
		$Sprite2D.scale.x = 1

func take_damage(damage_origin: Vector2):
	if !is_taking_damage:
		is_taking_damage = true
		modulate = Color(1, 0, 0)
		var direction = (position - damage_origin).normalized()
		apply_knockback(direction * knockback_strength)
		audio_take_damage.play()
		health -= 1
		if health == 0:
			queue_free()
		var maxSize = $ColorRect.size.x - 2
		var ratio = health / max_health
		$ColorRect/Health.size.x = maxSize * ratio
		$DamageTimer.start()
		await $DamageTimer.timeout
		modulate = Color(1, 1, 1)
		is_taking_damage = false

func attack():
	$AnimationPlayer.play("attacking")

func apply_knockback(knockback_velocity: Vector2):
	velocity = knockback_velocity
	move_and_slide()


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if (anim_name == "attacking"):
		$AnimationPlayer.play("walking")

func make_path() -> void:
	nav_agent.set_target_position(get_parent().get_node("Player").global_position)
	
func _on_navigation_timer_timeout() -> void:
	make_path()
