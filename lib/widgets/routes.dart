import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../engine/chess_engine.dart';
import 'board.dart';
import 'debug_board.dart';

// This main meny manages the heap state of the chess engine
// This heap state is the magic bitboards and zobrist keys
class MainMenu extends StatefulWidget {
  const MainMenu({super.key});

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {

  @override
  void initState() {
    super.initState();
    // Initialization the C library once
    ChessEngine.init(dynamicLibProvider());
    ChessEngine().libraryInit();
  }

  @override
  void dispose() {
    super.dispose();
    ChessEngine().terminate();
  }

  @override
  Widget build(BuildContext context) {
    String whiteAsset = "assets/images/white_king.svg";
    String blackAsset = "assets/images/black_king.svg";
    return Material(
      color: Colors.grey,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: InkWell(
                onTap: () {
                  Navigator.push(
                      context, getRouteBuilder(PieceCharacteristics.WHITE));
                },
                child: SvgPicture.asset(whiteAsset,
                    semanticsLabel: PieceUtility.fromColorAndType(
                        PieceCharacteristics.WHITE,
                        PieceCharacteristics.KING)
                        .toString())),
          ),
          Expanded(
              child: InkWell(
                onTap: () {
                  Navigator.push(
                      context, getRouteBuilder(PieceCharacteristics.BLACK));
                },
                child: SvgPicture.asset(blackAsset,
                    semanticsLabel: PieceUtility.fromColorAndType(
                        PieceCharacteristics.BLACK, PieceCharacteristics.KING)
                        .toString()),
              )),
          Expanded(
              child: InkWell(
                onTap: () {
                  Navigator.push(
                      context,
                      PageRouteBuilder(
                          pageBuilder: (c, a, s) => const DebugPage()));
                },
                child: const Center(
                  child: Text(
                    "Debug Mode",
                    style: TextStyle(fontSize: 64.0, fontWeight: FontWeight.bold),
                  ),
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
        title: Text(
            "Playing ${pieceColor == PieceCharacteristics.WHITE ? "white" : "black"} against AI"),
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
  // Since this function will be called in another isolate, the dynamic library needs to be provided again
  // However, the magic bitboard and Zobrist keys are already initialized, so we do not need to initialized them aging
  // If we did, we would leak memory, as C would allocate new memory without freeing the old one
  ChessEngine.init(dynamicLibProvider());

  final state = ChessEngine().setupGameFromFenString(nullptr, param.fenString);

  if (state.ref.previousStatesCapacity < param.keys.length) {
    state.ref.previousStatesCapacity = param.keys.length;
    // The previousStates array is always empty
    malloc.free(state.ref.previousStates);

    final biggerPrevStates = malloc.allocate<ZobristKey>(
        sizeOf<ZobristKey>() * state.ref.previousStatesCapacity);
    state.ref.previousStates = biggerPrevStates;
  }

  for (int i = 0; i < param.keys.length; i++) {
    state.ref.previousStates.elementAt(i).value = param.keys[i];
  }

  final result = ChessEngine().getBestMovesAccordingToComputer(state);

  ChessEngine().freeChessGame(state);
  return result;
}

// I do this so that if more parameters are needed it will be easy to add them
class AiMoveParam {
  final List<int> keys;

  final String fenString;

  AiMoveParam(this.keys, this.fenString);
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
