#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[2];} source_params;
uniform sampler2D tDiffuse;
#define opacity (source_params.data[1].x)
layout(location=0) in vec2 vUv;
layout(location=0) out vec4 probeColor;



		

		

		

		void sourceMain() {

			vec4 texel = texture( tDiffuse, vUv );
			probeColor = opacity * texel;


		}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0+texture(tDiffuse,vec2(0.5)).x);}
