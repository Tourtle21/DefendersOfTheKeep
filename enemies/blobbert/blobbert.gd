extends CharacterBody2D

@export var speed = 10
@export var knockback_strength: float = 300.0
var detection_distance = 200
var is_taking_damage = false

func _ready():
	$AnimationPlayer.play("walking")

func _physics_process(delta):
	var target_velocity = Vector2.ZERO
	var player_position = get_parent().get_node("Player").position

	if player_position.distance_to(position) < detection_distance:
		target_velocity = (player_position - position).normalized() * speed

	# Move using the velocity while respecting collisions
	velocity = target_velocity
	move_and_collide(velocity)

	# Flip sprite based on movement direction
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
		var x_size = $ColorRect/Health.size.x
		$ColorRect/Health.size.x = x_size - 5
		if x_size <= 5:
			queue_free()
		$DamageTimer.start()
		await $DamageTimer.timeout
		modulate = Color(1, 1, 1)
		is_taking_damage = false

func apply_knockback(knockback_velocity: Vector2):
	velocity = knockback_velocity
	# Apply knockback while respecting collisions
	move_and_slide()
