#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[13];} source_params;
uniform sampler2D blurTexture1;
uniform sampler2D blurTexture2;
uniform sampler2D blurTexture3;
uniform sampler2D blurTexture4;
uniform sampler2D blurTexture5;
#define bloomStrength (source_params.data[1].x)
#define bloomRadius (source_params.data[2].x)
#define bloomFactors (float[5](source_params.data[3].x,source_params.data[4].x,source_params.data[5].x,source_params.data[6].x,source_params.data[7].x))
#define bloomTintColors (vec3[5](source_params.data[8].xyz,source_params.data[9].xyz,source_params.data[10].xyz,source_params.data[11].xyz,source_params.data[12].xyz))
layout(location=0) in vec2 vUv;
layout(location=0) out vec4 probeColor;
#define NUM_MIPS 5


				

				
				
				
				
				
				
				
				
				

				float lerpBloomFactor( const in float factor ) {

					float mirrorFactor = 1.2 - factor;
					return mix( factor, mirrorFactor, bloomRadius );

				}

				void sourceMain() {

					
					vec3 bloom = 3.0 * bloomStrength * (
						lerpBloomFactor( bloomFactors[ 0 ] ) * bloomTintColors[ 0 ] * texture( blurTexture1, vUv ).rgb +
						lerpBloomFactor( bloomFactors[ 1 ] ) * bloomTintColors[ 1 ] * texture( blurTexture2, vUv ).rgb +
						lerpBloomFactor( bloomFactors[ 2 ] ) * bloomTintColors[ 2 ] * texture( blurTexture3, vUv ).rgb +
						lerpBloomFactor( bloomFactors[ 3 ] ) * bloomTintColors[ 3 ] * texture( blurTexture4, vUv ).rgb +
						lerpBloomFactor( bloomFactors[ 4 ] ) * bloomTintColors[ 4 ] * texture( blurTexture5, vUv ).rgb
					);

					float bloomAlpha = max( bloom.r, max( bloom.g, bloom.b ) );
					probeColor = vec4( bloom, bloomAlpha );

				}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0+texture(blurTexture1,vec2(0.5)).x+texture(blurTexture2,vec2(0.5)).x+texture(blurTexture3,vec2(0.5)).x+texture(blurTexture4,vec2(0.5)).x+texture(blurTexture5,vec2(0.5)).x);}
