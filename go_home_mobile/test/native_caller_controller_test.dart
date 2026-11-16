import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/game_controller.dart';
import 'package:go_home_mobile/game/level.dart';
import 'package:go_home_mobile/game/original_route.dart';
void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 late OriginalRoute route;late ScoreLibrary scores;
 setUpAll(()async{route=await OriginalRoute.load();scores=await ScoreLibrary.load();});
 void answer(GameController game){
   final call=game.melody!,start=game.clock;
   for(final n in call.notes){game.clock=start+n.step*.125;game.pressNote(n.degree);game.releaseNote(n.degree);}
 }
 test('native hedgehog accepts source rhythm during the demonstration',()async{
   final game=GameController(scores,route:route)..start()..enterLevel(1)..sceneReady();
   final caller=game.sourceCaller!;game.x=caller.x-1;game.y=caller.y;game.grounded=true;
   game.update(1/60);await Future<void>.value();
   expect(game.isDemo,isTrue);expect(game.canAnswer,isTrue);
   answer(game);expect(game.solved,{1});expect(game.hedgehog!.mode,'wake');expect(game.failures,0);
   expect(game.expected,isEmpty);game.dispose();
 });
 test('owl preserves both source wake rounds and accepts branch commands',()async{
   final game=GameController(scores,route:route)..start()..enterLevel(4)..sceneReady();
   final c=game.sourceCaller!;game.x=c.x-1;game.y=c.y;game.grounded=true;
   answer(game);expect(game.round,1);expect(game.owl!.stage,1);expect(game.solved,isEmpty);
   final saved=jsonDecode(jsonEncode(game.toJson())) as Map<String,dynamic>;
   final restored=GameController(scores,route:route)..restore(saved);
   expect(restored.round,1);expect(restored.owl!.stage,1);expect(restored.melody!.id,'owl-v2');
   game.clock+=1;answer(game);expect(game.solved,{4});expect(game.owl!.stage,2);
   final x=game.x,y=game.y;game.pressNote(2);expect(game.owl!.mode,'fly');expect(game.owl!.target,0);expect(game.x,x);expect(game.y,y);
   game.dispose();restored.dispose();
 });
 test('native bat checkpoint preserves pending echoes and platform timers',()async{
   final game=GameController(scores,route:route)..enterLevel(3);
   game.bat!..wake()..call(5,42);game.clock=42;
   final saved=jsonDecode(jsonEncode(game.toJson())) as Map<String,dynamic>;
   final restored=GameController(scores,route:route)..restore(saved);
   expect(restored.bat!.toJson(),game.bat!.toJson());
   game.dispose();restored.dispose();
 });
}
