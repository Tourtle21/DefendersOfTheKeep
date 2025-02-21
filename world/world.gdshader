shader_type canvas_item;

void fragment() {
    COLOR.rgb = texture(TEXTURE, UV).rgb; // Keep original texture color
    COLOR.a = texture(TEXTURE, UV).a;    // Keep original transparency
}