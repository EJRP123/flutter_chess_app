import 'dart:ffi';
import 'package:ffi/ffi.dart';
// import 'package:flutter/foundation.dart';
import 'chess_engine_ffi.dart';
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
  CHECMATE,
  DRAW;

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

  String boardAsString() {
    String result = "";
    for (int i = 0; i < 64; i++) {
      final fenChar = Piece.toFenChar(boardArray[i]);
      result += "|";
      result += (fenChar.isNotEmpty) ? " $fenChar " : "   ";
      if ((i + 1) % 8 == 0) {
        result += " |\n";
      }
    }
    return result;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChessGameState &&
          runtimeType == other.runtimeType &&
          boardArray == other.boardArray &&
          colorToGo == other.colorToGo &&
          castlingPerm == other.castlingPerm &&
          enPassantTargetSquare == other.enPassantTargetSquare &&
          turnsForFiftyRule == other.turnsForFiftyRule &&
          nbMoves == other.nbMoves;

  @override
  int get hashCode =>
      boardArray.hashCode ^
      colorToGo.hashCode ^
      castlingPerm.hashCode ^
      enPassantTargetSquare.hashCode ^
      turnsForFiftyRule.hashCode ^
      nbMoves.hashCode;

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

  static ChessGameState startingGameState() =>
      ChessGameState.fromFenString(startingFenString);
}

List<int> _copyList(List<int> list) {
  return List.generate(list.length, (index) => list[index], growable: false);
}

class ChessEngine {
  late NativeLibrary _library;

  ChessEngine._internal() {
    if (!Platform.isWindows && !Platform.isLinux) {
      throw Exception("This app only supports Linux and Windows...");
    }
    var libPath = "";
    final libName =
        Platform.isWindows ? "chess_engine.dll" : "chess_engine.so.1.0.0";
    final separator = Platform.isWindows ? "\\" : "/";
    if (false) { // kReleaseMode
      // I'm on release mode, absolute linking
      final String localLib = [
        'data',
        'flutter_assets',
        'assets',
        'engine',
        libName
      ].join(separator);
      libPath = [Directory(Platform.resolvedExecutable).parent.path, localLib]
          .join(separator);
    } else {
      // I'm on debug mode, local linking
      final path = Directory.current.path;
      libPath = '$path/assets/engine/$libName';
    }

    _library = NativeLibrary(DynamicLibrary.open(libPath));
  }

  static ChessEngine? _onlyInstance;
  factory ChessEngine() {
    return _onlyInstance ??= ChessEngine._internal();
  }

  List<ChessMove> getMovesFromFenString(String fenString) {
    final fenStringUTF8 = fenString.toNativeUtf8().cast<Char>();
    final state = _library.setGameStateFromFenString(fenStringUTF8, nullptr);
    malloc.free(fenStringUTF8);
    return getMovesFromPointerState(state, nullptr, 0);
  }

  List<ChessMove> getMovesFromState(
      ChessGameState gameState, List<ChessGameState> previousStates) {
    final state = dartStateToCState(gameState);
    if (previousStates.isEmpty) {
      return getMovesFromPointerState(state, nullptr, 0);
    }
    final pointerPreviousStates =
        malloc.allocate<GameState>(sizeOf<GameState>() * previousStates.length);

    for (int i = 0; i < previousStates.length; i++) {
      final pointerToState = dartStateToCState(previousStates[i]);
      pointerPreviousStates.elementAt(i).ref = pointerToState.ref;
    }

    return getMovesFromPointerState(
        state, pointerPreviousStates, previousStates.length);
  }

  List<ChessMove> getMovesFromPointerState(Pointer<gameState> state,
      Pointer<GameState> previousStates, int numberOfPreviousStates) {
    final moves =
        _library.getValidMoves(state, previousStates, numberOfPreviousStates);

    // No memory leaks Please <(^uwu^)>
    malloc.free(state.ref.boardArray);
    malloc.free(state);
    for (int i = 0; i < numberOfPreviousStates; i++) {
      malloc.free(previousStates[i].boardArray);
    }
    malloc.free(previousStates);
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
    malloc.free(moves.ref.items);
    malloc.free(moves);
    return result;
  }

  Pointer<gameState> dartStateToCState(ChessGameState state) {
    final boardPointer = malloc.allocate<Int>(sizeOf<Int>() * 64);
    for (int i = 0; i < 64; i++) {
      boardPointer.elementAt(i).value = state.boardArray[i];
    }

    return _library.createState(
        boardPointer,
        state.colorToGo,
        state.castlingPerm,
        state.enPassantTargetSquare,
        state.turnsForFiftyRule,
        state.nbMoves);
  }
}

extension Piece on PIECE {

  static String asString(int piece) {
    int color = piece & pieceColorBitMask;
    int type = piece & pieceTypeBitMask;
    String pieceColor = color == PIECE.WHITE ? "White" : "Black";

    switch (type) {
      case PIECE.KING:
        return "$pieceColor king";
      case PIECE.QUEEN:
        return "$pieceColor queen";
      case PIECE.KNIGHT:
        return "$pieceColor knight";
      case PIECE.BISHOP:
        return "$pieceColor bishop";
      case PIECE.ROOK:
        return "$pieceColor rook";
      case PIECE.PAWN:
        return "$pieceColor pawn";
      default:
        return color == 0 ? "None" : pieceColor;
    }
  }

  static String toFenChar(int piece) {
    int color = piece & pieceColorBitMask;
    int type = piece & pieceTypeBitMask;
    String caseLambda(String fenChar) {
      return color == PIECE.WHITE ? fenChar.toUpperCase() : fenChar;
    }
    switch (type) {
      case PIECE.KING:
        return caseLambda("k");
      case PIECE.QUEEN:
        return caseLambda("q");
      case PIECE.KNIGHT:
        return caseLambda("n");
      case PIECE.BISHOP:
        return caseLambda("b");
      case PIECE.ROOK:
        return caseLambda("r");
      case PIECE.PAWN:
        return caseLambda("p");
      default:
        return "";
    }
  }
}

extension FLAG on Flag {

  static String asString(int flag) {
    switch (flag) {
      case Flag.EN_PASSANT:
        return "En Passant";
      case Flag.DOUBLE_PAWN_PUSH:
        return "Double Pawn Push";
      case Flag.KING_SIDE_CASTLING:
        return "King Side Castling";
      case Flag.QUEEN_SIDE_CASTLING:
        return "Queen Side Castling";
      case Flag.PROMOTE_TO_QUEEN:
        return "Promote To Queen";
      case Flag.PROMOTE_TO_KNIGHT:
        return "Promote To Knight";
      case Flag.PROMOTE_TO_ROOK:
        return "Promote To Rook";
      case Flag.PROMOTE_TO_BISHOP:
        return "Promote To Bishop";
      case Flag.CHECKMATE:
        return "Checkmate";
      case Flag.STALEMATE:
        return "Stalemate";
      default:
        return "No Flag";
    }
  }
}
