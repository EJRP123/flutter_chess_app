import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'c_chess_engine_library.dart';
import 'dart:io';

enum MoveFlag {
  NOFlAG,
  EN_PASSANT,
  DOUBLE_PAWN_PUSH,
  KING_SIDE_CASTLING,
  QUEEN_SIDE_CASTLING,
  PROMOTE_TO_QUEEN,
  PROMOTE_TO_KNIGHT,
  PROMOTE_TO_ROOK,
  PROMOTE_TO_BISHOP,
  STALEMATE,
  CHECMATE;

  static MoveFlag fromInt(int flag) {
    if (flag > MoveFlag.values.length || flag < 0) return MoveFlag.NOFlAG;
    return MoveFlag.values[flag];
  }
}

class ChessMove {
  final int startSquare;
  final int endSquare;
  final MoveFlag flag;

  const ChessMove(this.startSquare, this.endSquare, this.flag);

  @override
  String toString() {
    return 'ChessMove(startSquare: $startSquare, endSquare: $endSquare, flag: $flag)';
  }
}

class ChessGameState {
  final List<int> boardArray;
  int colorToGo;
  int castlingPerm;
  int enPassantTargetSquare;
  int turnsForFiftyRule;
  int nbMoves;

  ChessGameState(this.boardArray, this.colorToGo, this.castlingPerm,
      this.enPassantTargetSquare, this.nbMoves, this.turnsForFiftyRule);

  ChessGameState copy() {
    return ChessGameState(_copyList(boardArray), colorToGo, castlingPerm,
        enPassantTargetSquare, nbMoves, turnsForFiftyRule);
  }

  void copyFrom(ChessGameState src) {
    for (int i = 0; i < BOARD_SIZE; i++) {
      boardArray[i] = src.boardArray[i];
    }
    colorToGo = src.colorToGo;
    castlingPerm = src.castlingPerm;
    enPassantTargetSquare = src.enPassantTargetSquare;
    nbMoves = src.nbMoves;
    turnsForFiftyRule = src.turnsForFiftyRule;
  }

  static ChessGameState fromFenString(String fenString) {
    final reg = RegExp(
        "((([prnbqkPRNBQK12345678]*/){7})([prnbqkPRNBQK12345678]*)) (w|b) ((K?Q?k?q?)|-) (([abcdefgh][36])|-) (\\d*) (\\d*)");
    if (!reg.hasMatch(fenString)) {
      throw ArgumentError(
          "The fen string $fenString is not formatted properly!");
    }
    if (fenString.length > 100) {
      // This condition is to remove buffer overflow in the c code
      throw ArgumentError(
          "This program cannot parse fen string with a bigger length than 100");
    }
    final c_fenString = fenString.toNativeUtf8().cast<Char>();

    final c_state =
        ChessEngine()._library.setGameStateFromFenString(c_fenString, nullptr);
    malloc.free(c_fenString);
    final boardArray = List.filled(BOARD_SIZE, 0);

    for (int i = 0; i < BOARD_SIZE; i++) {
      boardArray[i] = c_state.ref.boardArray.elementAt(i).value;
    }

    final result = ChessGameState(
        boardArray,
        c_state.ref.colorToGo,
        c_state.ref.castlinPerm,
        c_state.ref.enPassantTargetSquare,
        c_state.ref.turnsForFiftyRule,
        c_state.ref.nbMoves);

    malloc.free(c_state.ref.boardArray);
    malloc.free(c_state);

    return result;
  }

  static const startingFenString =
      "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";

  static ChessGameState startingGameState =
      ChessGameState.fromFenString(startingFenString);
}

List<int> _copyList(List<int> list) {
  return List.generate(list.length, (index) => list[index], growable: false);
}

class ChessEngine {
  late ChessEngineLibrary _library;

  ChessEngine._internal() {
    if (!Platform.isWindows && !Platform.isLinux) {
      throw Exception("This app only supports Linux and Windows...");
    }
    var libPath = "";
    final libName =
        Platform.isWindows ? "chess_engine.dll" : "libchess_engine.so.1.0.0";
    final seperator = Platform.isWindows ? "\\" : "/";
    if (kReleaseMode) {
      // I'm on release mode, absolute linking
      final String localLib = [
        'data',
        'flutter_assets',
        'assets',
        'engine',
        libName
      ].join(seperator);
      libPath = [Directory(Platform.resolvedExecutable).parent.path, localLib]
          .join(seperator);
    } else {
      // I'm on debug mode, local linking
      var path = Directory.current.path;
      libPath = '$path/assets/engine/$libName';
    }

    _library = ChessEngineLibrary(DynamicLibrary.open(libPath));
  }

  static ChessEngine? _onlyInstance;
  factory ChessEngine() {
    return _onlyInstance ??= ChessEngine._internal();
  }

  List<ChessMove> getMovesFromFenString(String fenString) {
    final fenStringUTF8 = fenString.toNativeUtf8().cast<Char>();
    final state = _library.setGameStateFromFenString(fenStringUTF8, nullptr);
    calloc.free(fenStringUTF8);
    return getMovesFromPointerState(state);
  }

  List<ChessMove> getMovesFromState(ChessGameState gameState) {
    final boardPointer = malloc.allocate<Int>(sizeOf<Int>() * 64);
    for (int i = 0; i < 64; i++) {
      boardPointer.elementAt(i).value = gameState.boardArray[i];
    }

    final state = _library.createState(
        boardPointer,
        gameState.colorToGo,
        gameState.castlingPerm,
        gameState.enPassantTargetSquare,
        gameState.turnsForFiftyRule,
        gameState.nbMoves);
    return getMovesFromPointerState(state);
  }

  List<ChessMove> getMovesFromPointerState(Pointer<gameState> state) {
    final moves = _library.getValidMoves(state);

    final result = <ChessMove>[];
    Moves totalMoves = moves.ref;
    for (int i = 0; i < totalMoves.count; i++) {
      int move = totalMoves.items.elementAt(i).value;

      int startSquare = move & 63;
      int endSquare = (move >> 6) & 63;
      int flag = move >> 12;

      final moveObj = ChessMove(startSquare, endSquare, MoveFlag.fromInt(flag));

      result.add(moveObj);
    }
    calloc.free(moves);
    return result;
  }
}
