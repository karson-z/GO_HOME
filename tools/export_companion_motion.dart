// Offline motion retargeting: runs the game's actual numerical skeleton.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import '../go_home_mobile/lib/game/boy_kinematics.dart';
import '../go_home_mobile/lib/game/original_boy_motion.dart';
import '../go_home_mobile/lib/game/original_boy_runtime.dart';
import '../go_home_mobile/lib/game/original_opening_pose.dart';

double smooth(double v) { final k = v.clamp(0.0, 1.0); return k*k*(3-2*k); }
void main(List<String> args) {
  final out = Directory(args.isEmpty ? 'artifacts/companion-moss' : args[0])..createSync(recursive:true);
  final spec = jsonDecode(File('go_home_mobile/assets/characters/boy.json').readAsStringSync()) as Map<String,dynamic>;
  final data = jsonDecode(File('go_home_mobile/assets/data/original_boy_motion.json').readAsStringSync()) as Map<String,dynamic>;
  final config = jsonDecode(File('go_home_mobile/assets/data/original_config.json').readAsStringSync());
  final clips = <Map<String,dynamic>>[];
  const names = {
    'idle':'呼吸待机', 'walk':'轻步行走', 'run':'向前奔跑',
    'jump':'原地跳跃', 'run-jump':'助跑跳跃', 'turn':'回身张望',
    'listen':'侧耳聆听', 'lantern':'提灯回应', 'push':'伸手推物',
    'wake':'蜷坐起身',
  };
  for (final id in names.keys) {
    final rig = BoyKinematics(spec);
    final runtime = OriginalBoyRuntime(rig,data);
    final opening = OriginalOpeningPose({'riseKeys':config['core_Wj'],'sleepPose':config['core_Uj']});
    final frames = <Map<String,dynamic>>[];
    final count = id == 'wake' ? 96 : 72;
    var x = 0.0;
    // Warm up looping gait; leave time-based gestures untouched.
    final warm = ['idle','walk','run'].contains(id) ? 240 : 30;
    for (var i = -warm; i < count*2; i++) {
      final t = math.max(0.0,i/60), absolute = (i+warm)/60;
      var vx = id == 'walk' ? 1.1 : id == 'run' ? 2.8 : 0.0;
      var vy=0.0,y=0.0,face=1.0,wind=0.0,reach=0.0;
      var grounded=true;
      if (id == 'turn') {
        face=t<.6||t>1.75 ? 1 : -1;
        vx=t<.6 ? 1.1 : t<1.75 ? -1.1 : 1.1;
      }
      if (id == 'jump'||id == 'run-jump') {
        if(id=='run-jump') vx=1.9;
        wind=t>=.40&&t<.48 ? 1 : 0;
        final a=t-.48;
        if(a>=0&&a<14/24){grounded=false;vy=7-a*24;y=7*a-12*a*a;}
      }
      if(id=='push'){reach=smooth((t-.25)/.3);vx=.5*reach;}
      x+=vx/60;
      runtime.step(1/60,BoyMotionInput(vx:vx,vy:vy,grounded:grounded,facing:face,wind:wind,reach:reach,lean:reach),x:x,y:y,groundAt:(_)=>0,jumpAir:!grounded&&vy>0);
      // Companion-specific additive gestures, authored on the inherited rig.
      final gesture = smooth(t/.4)*(1-smooth((t-1.65)/.5));
      if(id=='listen') {
        rig.joints['head']!.rot -= .13*gesture;
        rig.joints['body']!.rot -= .035*gesture;
        rig.update();
        final h=rig.at('head');
        final ids=['upperArmB','foreArmB','handB'];
        final old=[for(final name in ids)rig.joints[name]!.rot];
        rig.solve(ids[0],ids[1],ids[2],h.x+.06,h.y+.12,-1,math.pi);
        for(var j=0;j<ids.length;j++) {
          final joint=rig.joints[ids[j]]!;
          joint.rot=old[j]+(joint.rot-old[j])*gesture;
        }
      }
      if(id=='lantern') {
        rig.update();
        final h=rig.at('handF');
        final ids=['upperArmF','foreArmF','handF'];
        final old=[for(final name in ids)rig.joints[name]!.rot];
        rig.solve(ids[0],ids[1],ids[2],h.x+.015,h.y+.22,-1,math.pi/2);
        for(var j=0;j<ids.length;j++) {
          final joint=rig.joints[ids[j]]!;
          joint.rot=old[j]+(joint.rot-old[j])*gesture;
        }
        rig.joints['head']!.rot += .10*gesture;
        rig.levelBox();
      }
      if(id=='wake') {
        if(t<.4) {opening.apply(rig);}
        else {opening.apply(rig,rise:((t-.4)/2.2).clamp(0.0,1.0));}
      }
      rig.update();
      if(i<0||i.isOdd) continue;
      final turn=runtime.pose.turnX*face;
      final transforms = <String,List<double>>{};
      for(final ident in rig.joints.keys) {
        final m=rig.world(ident);
        final vals=[m.a*turn,m.b,m.c*turn,m.d,m.x*turn+runtime.dx,m.y+y+runtime.dy];
        if(vals.any((v)=>!v.isFinite)) throw StateError('Non-finite $id/$i/$ident');
        transforms[ident]=vals;
      }
      frames.add({'t':t,'bones':transforms,'glow':id=='lantern'?gesture:0,'phase':absolute,'layers':id=='listen'?{'upperArmB':76,'foreArmB':77,'handB':78}:<String,int>{}});
    }
    clips.add({'id':id,'title':names[id],'fps':30,'frames':frames,'duration':count/30,'loop':['idle','walk','run'].contains(id)});
  }
  File('${out.path}/motion.json').writeAsStringSync(jsonEncode({'source':'OriginalBoyRuntime + OriginalBoyGait + BoyKinematics','simulationHz':60,'fps':30,'clips':clips}));
  stdout.writeln('Exported ${clips.length} clips / ${clips.fold<int>(0,(v,c)=>v+(c['frames'] as List).length)} finite frames');
}
