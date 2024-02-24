import 'dart:ffi';
import 'dart:io';

import 'engine/chess_engine.dart';

void main() {
  ChessEngine.init(dynamicLibProvider());

  ChessGameData chessGameData = ChessEngine().startingGameState();
  final moves = ChessEngine().getMovesFromState(chessGameData);
  print(moves);
}

DynamicLibrary dynamicLibProvider() {
  // "Warming up" the engine
  if (!Platform.isWindows && !Platform.isLinux) {
    throw Exception("This app only supports Linux and Windows...");
  }
  // Temporary
  if (Platform.isWindows) {
    throw Exception(
        "I did not compile the engine on Windows, I apologize for that, sorry :(");
  }
  final libName =
      Platform.isWindows ? "chess_engine.dll" : "chess_engine.so.1.0.0";
  final separator = Platform.isWindows ? "\\" : "/";

  // I'm on debug mode, local linking
  final path = Directory.current.path;
  final libPath = [path, "assets", "engine", libName].join(separator);

  DynamicLibrary dynamicLibrary = DynamicLibrary.open(libPath);
  return dynamicLibrary;
}
