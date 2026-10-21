import 'package:tictactoe/src/cli.dart';

Future<void> main(List<String> arguments) async {
  await TicTacToeCli().run();
}
