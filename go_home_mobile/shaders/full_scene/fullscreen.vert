#version 450
layout(location=0) in vec2 position;layout(location=0) out vec2 vUv;void main(){vUv=vec2(position.x*0.5+0.5,0.5-position.y*0.5);gl_Position=vec4(position,0.,1.);}