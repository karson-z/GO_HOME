#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[5];} source_params;
uniform sampler2D tDiffuse;
#define defaultColor (source_params.data[1].xyz)
#define defaultOpacity (source_params.data[2].x)
#define luminosityThreshold (source_params.data[3].x)
#define smoothWidth (source_params.data[4].x)
layout(location=0) in vec2 vUv;
layout(location=0) out vec4 probeColor;

float luminance(vec3 v){return dot(v,vec3(.2126,.7152,.0722));}


		
		
		
		
		

		

		void sourceMain() {

			vec4 texel = texture( tDiffuse, vUv );

			float v = luminance( texel.xyz );

			vec4 outputColor = vec4( defaultColor.rgb, defaultOpacity );

			float alpha = smoothstep( luminosityThreshold, luminosityThreshold + smoothWidth, v );

			probeColor = mix( outputColor, texel, alpha );

		}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0+texture(tDiffuse,vec2(0.5)).x);}
