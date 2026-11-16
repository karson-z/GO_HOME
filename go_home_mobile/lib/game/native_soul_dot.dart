import 'package:three_js/three_js.dart' as three;

/// Original fT additive light used when family members become spirits.
class NativeSoulDot {
  NativeSoulDot() {
    material = three.ShaderMaterial.fromMap({
      'uniforms': {
        'uCol': {'value': three.Color.fromHex32(0xeef4ff).toLinear()},
        'uA': {'value': 0.0},
      },
      'vertexShader': '''
varying vec2 vUv;
void main(){vUv=uv;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.0);}
''',
      'fragmentShader': '''
uniform vec3 uCol; uniform float uA; varying vec2 vUv;
void main(){vec2 p=vUv*2.0-1.0;float r=length(p);
float core=exp(-r*r*40.0);
float glow=exp(-r*r*9.0)*(1.0-smoothstep(0.8,1.0,r));
gl_FragColor=vec4(uCol*(core*1.6+glow*0.4)*uA,1.0);}
''',
      'transparent': true,
      'depthWrite': false,
      'blending': three.AdditiveBlending,
    });
    mesh = three.Mesh(three.PlaneGeometry(1, 1), material)
      ..name = 'fam2-soul-dot'
      ..renderOrder = 30
      ..frustumCulled = false
      ..visible = false;
  }
  late final three.ShaderMaterial material;
  late final three.Mesh mesh;
  void set(three.Vector3 position, double size, double alpha) {
    mesh.visible = alpha > .003 && size > .002;
    mesh.position.setFrom(position);
    mesh.scale.setValues(size * 3, size * 3, 1);
    material.uniforms['uA']['value'] = alpha;
  }

  void hide() => mesh.visible = false;
  void dispose() {
    mesh.removeFromParent();
    mesh.geometry!.dispose();
    material.dispose();
  }
}
