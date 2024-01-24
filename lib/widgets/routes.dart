import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../engine/chess_engine.dart';
import 'board.dart';
import 'debug_board.dart';

class MainMenu extends StatelessWidget {
  const MainMenu({super.key});

  @override
  Widget build(BuildContext context) {
    String whiteAsset =
        "assets/images/${ChessPiece(PieceColor.white, PieceType.king).toString().toLowerCase().replaceAll(" ", "_")}.svg";
    String blackAsset =
        "assets/images/${ChessPiece(PieceColor.black, PieceType.king).toString().toLowerCase().replaceAll(" ", "_")}.svg";
    return Material(
      color: Colors.grey,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: InkWell(
                onTap: () {
                  Navigator.push(context, getRouteBuilder(PieceColor.white));
                },
                child: SvgPicture.asset(whiteAsset,
                    semanticsLabel:
                    ChessPiece(PieceColor.white, PieceType.king)
                            .toString())),
          ),
          Expanded(
              child: InkWell(
            onTap: () {
              Navigator.push(context, getRouteBuilder(PieceColor.black));
            },
            child: SvgPicture.asset(blackAsset,
                semanticsLabel: ChessPiece(PieceColor.black, PieceType.king)
                    .toString()),
          )),
          Expanded(
              child: InkWell(
                onTap: () {
                  Navigator.push(context, PageRouteBuilder(pageBuilder: (c,a, s) => const DebugPage()));
                },
                child: const Center(
                  child: Text("Debug Mode",
                    style: TextStyle(
                      fontSize: 64.0,
                      fontWeight: FontWeight.bold
                  ),),
                ),
              ))
        ],
      ),
    );
  }

  PageRouteBuilder getRouteBuilder(PieceColor pieceColor) {
    // This animation for the route builder is ripped directly from the flutter docs
    return PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            GamePage(pieceColor: pieceColor),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.ease;

          final tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        });
  }
}

class GamePage extends StatelessWidget {
  final PieceColor pieceColor;
  const GamePage({super.key, required this.pieceColor});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueGrey,
        title: Text("Playing ${pieceColor.name} against AI"),
      ),
      body: Center(child: ChessBoard(pieceColor)),
      backgroundColor: Colors.blueGrey,
    );
  }
}

class DebugPage extends StatelessWidget {

  const DebugPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueGrey,
        title: const Text("Debugging chess positions"),
      ),
      body: DebugBoard(),
      backgroundColor: Colors.blueGrey,
    );
  }

}

// I need to do this to use the Flutter compute function
List<ChessMove> getMoveFromAiIsolate(AiMoveParam param) {
  ChessEngine.init(
      dynamicLibProvider()); // Since this will be called in another isolate
  final result = ChessEngine().getBestMovesAccordingToComputer(param.state, param.previousStates);
  return result;
}

// I need to do this to use the Flutter compute function with multiple param
class AiMoveParam {
  final ChessGameState state;
  final List<ChessGameState> previousStates;

  AiMoveParam(this.state, this.previousStates);
}

DynamicLibrary dynamicLibProvider() {
  // "Warming up" the engine
  if (!Platform.isWindows && !Platform.isLinux) {
    throw Exception("This app only supports Linux and Windows...");
  }
  // Temporary
  if (Platform.isWindows) {
    throw Exception("I did not compile the engine on Windows, I apologize for that, sorry :(");
  }
  var libPath = "";
  final libName =
      Platform.isWindows ? "chess_engine.dll" : "chess_engine.so.1.0.0";
  final separator = Platform.isWindows ? "\\" : "/";
  if (kReleaseMode) {
  // I'm on release mode, absolute linking
    final String localLib =
        ['data', 'flutter_assets', 'assets', 'engine', libName].join(separator);
    libPath = [Directory(Platform.resolvedExecutable).parent.path, localLib]
        .join(separator);
  } else {
    // I'm on debug mode, local linking
    final path = Directory.current.path;
    libPath = '$path/assets/engine/$libName';
  }

  DynamicLibrary dynamicLibrary = DynamicLibrary.open(libPath);
  return dynamicLibrary;
}
