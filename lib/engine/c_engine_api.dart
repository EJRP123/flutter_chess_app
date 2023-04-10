library c_engine_api;

import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';

export 'c_engine_api.dart'
    show
        ChessEngine,
        ChessGameState,
        Piece,
        ChessMove,
        MoveFlag,
        PieceColor,
        PieceType;

part 'c_engine_ffi.dart';
// part of 'package:chess_app/engine/c_engine_api.dart'; // Line added by EJRP
part 'game_emulator.dart';

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

  @override
  String toString() {
    return name
        .toLowerCase()
        .replaceAll("_", " ")
        .split(" ")
        .map((e) => e.substring(0, 1).toUpperCase() + e.substring(1))
        .join(" ");
  }
}

enum PieceType {
  none,
  king,
  queen,
  knight,
  bishop,
  rook,
  pawn;

  int get value => index; // For consistency with PieceColor
}

enum PieceColor {
  white,
  black,
  none;

  int get value => this != none ? (index + 1) * 8 : 0;
}

// TODO: Make pieces instances not static to have methods like piece color not static
class Piece {
  static const int pieceColorBitMask = _pieceColorBitMask;
  static const int pieceTypeBitMask = _pieceTypeBitMask;

  late final int value;
  Piece(this.value);

  Piece.fromEnum(PieceColor color, PieceType type) {
    value = color.value | type.value;
  }

  PieceColor get color {
    if (value != 0) {
      return PieceColor.values[(value & pieceColorBitMask) ~/ 8 - 1];
    } else {
      return PieceColor.none;
    }
  }
  PieceType get type => PieceType.values[value & pieceTypeBitMask];

  String fenChar() {
    String caseLambda(String fenChar) {
      return color == PieceColor.white ? fenChar.toUpperCase() : fenChar;
    }

    switch (type) {
      case PieceType.king:
        return caseLambda("k");
      case PieceType.queen:
        return caseLambda("q");
      case PieceType.knight:
        return caseLambda("n");
      case PieceType.bishop:
        return caseLambda("b");
      case PieceType.rook:
        return caseLambda("r");
      case PieceType.pawn:
        return caseLambda("p");
      default:
        return "";
    }
  }

  @override
  String toString() {
    String pieceColor = color == PieceColor.white ? "White" : "Black";

    switch (type) {
      case PieceType.king:
        return "$pieceColor king";
      case PieceType.queen:
        return "$pieceColor queen";
      case PieceType.knight:
        return "$pieceColor knight";
      case PieceType.bishop:
        return "$pieceColor bishop";
      case PieceType.rook:
        return "$pieceColor rook";
      case PieceType.pawn:
        return "$pieceColor pawn";
      default:
        return "None";
    }
  }
}

class ChessMove {
  final int startSquare;
  final int endSquare;
  final MoveFlag flag;

  const ChessMove(this.startSquare, this.endSquare, this.flag);

  String toStringWithBoard(ChessGameState state) {
    return '${Piece(state.boardArray[startSquare])} ($startSquare) '
        'to ${Piece(state.boardArray[endSquare])} ($endSquare)';
  }

  @override
  String toString() {
    return 'ChessMove(startSquare: $startSquare, endSquare: $endSquare, flag: $flag)';
  }
}

// TODO: Replace the List<int> with List<Piece>
// TODO: Replace colorToGo with PieceColor
// This will impact performance but like if you want to go fast use C
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
    for (int i = 0; i < _BOARD_SIZE; i++) {
      boardArray[i] = src.boardArray[i];
    }
    colorToGo = src.colorToGo;
    castlingPerm = src.castlingPerm;
    enPassantTargetSquare = src.enPassantTargetSquare;
    nbMoves = src.nbMoves;
    turnsForFiftyRule = src.turnsForFiftyRule;
  }

  void makeMove(ChessMove move) {
    _makeMove(move, this);
  }

  String boardAsString() {
    String result = "";
    for (int i = 0; i < 64; i++) {
      final fenChar = Piece(boardArray[i]).fenChar();
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
    final c_fenString = fenString.toNativeUtf8().cast<ffi.Char>();

    final c_state = ChessEngine()
        ._library
        .setGameStateFromFenString(c_fenString, ffi.nullptr);
    malloc.free(c_fenString);
    final boardArray = List.filled(_BOARD_SIZE, 0);

    for (int i = 0; i < _BOARD_SIZE; i++) {
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
  late _NativeLibrary _library;

  ChessEngine.init(ffi.DynamicLibrary dynamicLibrary) {
    if (_onlyInstance == null) {
      _library = _NativeLibrary(dynamicLibrary);
      _onlyInstance = this;
    }
  }

  static ChessEngine? _onlyInstance;
  factory ChessEngine() {
    if (_onlyInstance == null) {
      throw StateError(
          "You need to call ChessEngine.init() and provide a dynamic library before you can use the engine!");
    }
    return _onlyInstance!;
  }

  List<ChessMove> getMovesFromFenString(String fenString) {
    final fenStringUTF8 = fenString.toNativeUtf8().cast<ffi.Char>();
    final state =
        _library.setGameStateFromFenString(fenStringUTF8, ffi.nullptr);
    malloc.free(fenStringUTF8);
    return getMovesFromPointerState(state, ffi.nullptr, 0);
  }

  List<ChessMove> getMovesFromState(
      ChessGameState gameState, List<ChessGameState> previousStates) {
    final state = dartStateToCState(gameState);
    if (previousStates.isEmpty) {
      return getMovesFromPointerState(state, ffi.nullptr, 0);
    }
    final pointerPreviousStates = malloc
        .allocate<_GameState>(ffi.sizeOf<_GameState>() * previousStates.length);

    for (int i = 0; i < previousStates.length; i++) {
      final pointerToState = dartStateToCState(previousStates[i]);
      pointerPreviousStates.elementAt(i).ref = pointerToState.ref;
    }

    return getMovesFromPointerState(
        state, pointerPreviousStates, previousStates.length);
  }

  List<ChessMove> getMovesFromPointerState(ffi.Pointer<_gameState> state,
      ffi.Pointer<_GameState> previousStates, int numberOfPreviousStates) {
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
    _Moves totalMoves = moves.ref;
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

  ffi.Pointer<_gameState> dartStateToCState(ChessGameState state) {
    final boardPointer = malloc.allocate<ffi.Int>(ffi.sizeOf<ffi.Int>() * 64);
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

  @override
  String toString() {
    return "ChessEngine()";
  }
}
