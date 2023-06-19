#version 460 core

out vec4 FragOut;

in vec3 ourColor;
in vec2 texCoord;

uniform sampler2D texture1;


void main() {
	FragOut = vec4(0.0, 1.0, 0.0, 1.0);//texture(texture1, texCoord);
}
