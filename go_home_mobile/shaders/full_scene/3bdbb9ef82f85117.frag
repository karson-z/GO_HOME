#version 450
layout(set=0,binding=3) uniform SourceFragmentParams {vec4 data[22];} source_params;
uniform sampler2D colorTexture;
#define invSize (source_params.data[1].xy)
#define direction (source_params.data[2].xy)
#define centerWeight (source_params.data[3].x)
#define gaussianOffsets (float[9](source_params.data[4].x,source_params.data[5].x,source_params.data[6].x,source_params.data[7].x,source_params.data[8].x,source_params.data[9].x,source_params.data[10].x,source_params.data[11].x,source_params.data[12].x))
#define gaussianWeights (float[9](source_params.data[13].x,source_params.data[14].x,source_params.data[15].x,source_params.data[16].x,source_params.data[17].x,source_params.data[18].x,source_params.data[19].x,source_params.data[20].x,source_params.data[21].x))
layout(location=0) in vec2 vUv;
layout(location=0) out vec4 probeColor;
#define KERNEL_PAIRS 9


				float luminance(vec3 v){return dot(v,vec3(.2126,.7152,.0722));}

				

				
				
				
				
				
				

				void sourceMain() {

					vec3 diffuseSum = texture( colorTexture, vUv ).rgb * centerWeight;

					for ( int i = 0; i < KERNEL_PAIRS; i ++ ) {

						vec2 uvOffset = direction * invSize * gaussianOffsets[ i ];
						vec3 sample1 = texture( colorTexture, vUv + uvOffset ).rgb;
						vec3 sample2 = texture( colorTexture, vUv - uvOffset ).rgb;
						diffuseSum += ( sample1 + sample2 ) * gaussianWeights[ i ];

					}

					probeColor = vec4( diffuseSum, 1.0 );

				}
void main(){sourceMain();probeColor.r+=source_params.data[0].x*(1.0+texture(colorTexture,vec2(0.5)).x);}
