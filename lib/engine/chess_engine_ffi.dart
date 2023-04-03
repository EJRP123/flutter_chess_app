// AUTO GENERATED FILE, DO NOT EDIT.
//
// Generated by `package:ffigen`.
import 'dart:ffi' as ffi;

class NativeLibrary {
  /// Holds the symbol lookup function.
  final ffi.Pointer<T> Function<T extends ffi.NativeType>(String symbolName)
      _lookup;

  /// The symbols are looked up in [dynamicLibrary].
  NativeLibrary(ffi.DynamicLibrary dynamicLibrary)
      : _lookup = dynamicLibrary.lookup;

  /// The symbols are looked up with [lookup].
  NativeLibrary.fromLookup(
      ffi.Pointer<T> Function<T extends ffi.NativeType>(String symbolName)
          lookup)
      : _lookup = lookup;

  ffi.Pointer<Moves> getValidMoves(
    ffi.Pointer<GameState> gameState,
    ffi.Pointer<GameState> previousStates,
    int nbStatesReached,
  ) {
    return _getValidMoves(
      gameState,
      previousStates,
      nbStatesReached,
    );
  }

  late final _getValidMovesPtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<Moves> Function(ffi.Pointer<GameState>,
              ffi.Pointer<GameState>, ffi.Int)>>('getValidMoves');
  late final _getValidMoves = _getValidMovesPtr.asFunction<
      ffi.Pointer<Moves> Function(
          ffi.Pointer<GameState>, ffi.Pointer<GameState>, int)>();

  ffi.Pointer<GameState> createState(
    ffi.Pointer<ffi.Int> boardArray,
    int colorToGo,
    int castlinPerm,
    int enPassantTargetSquare,
    int turnsForFiftyRule,
    int nbMoves,
  ) {
    return _createState(
      boardArray,
      colorToGo,
      castlinPerm,
      enPassantTargetSquare,
      turnsForFiftyRule,
      nbMoves,
    );
  }

  late final _createStatePtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<GameState> Function(ffi.Pointer<ffi.Int>, ffi.Int,
              ffi.Int, ffi.Int, ffi.Int, ffi.Int)>>('createState');
  late final _createState = _createStatePtr.asFunction<
      ffi.Pointer<GameState> Function(
          ffi.Pointer<ffi.Int>, int, int, int, int, int)>();

  ffi.Pointer<GameState> setGameStateFromFenString(
    ffi.Pointer<ffi.Char> fenString,
    ffi.Pointer<GameState> result,
  ) {
    return _setGameStateFromFenString(
      fenString,
      result,
    );
  }

  late final _setGameStateFromFenStringPtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<GameState> Function(ffi.Pointer<ffi.Char>,
              ffi.Pointer<GameState>)>>('setGameStateFromFenString');
  late final _setGameStateFromFenString =
      _setGameStateFromFenStringPtr.asFunction<
          ffi.Pointer<GameState> Function(
              ffi.Pointer<ffi.Char>, ffi.Pointer<GameState>)>();
}

/// This is a dynamic array of integers. You can use the
/// da_append macro to append integer to this list
class intList extends ffi.Struct {
  external ffi.Pointer<ffi.Int> items;

  @ffi.Int()
  external int count;

  @ffi.Int()
  external int capacity;
}

/// Dynamic array of moves
/// The structure is copied from Sebastian Lague chess program
/// A move is a 16 bit number
/// bit 0-5: from square (0 to 63)
/// bit 6-11: to square (0 to 63)
/// bit 12-15: flag
class moves extends ffi.Struct {
  external ffi.Pointer<ffi.UnsignedShort> items;

  @ffi.Int()
  external int count;

  @ffi.Int()
  external int capacity;
}

class gameState extends ffi.Struct {
  external ffi.Pointer<ffi.Int> boardArray;

  @ffi.Int()
  external int colorToGo;

  @ffi.Int()
  external int castlinPerm;

  @ffi.Int()
  external int enPassantTargetSquare;

  @ffi.Int()
  external int turnsForFiftyRule;

  @ffi.Int()
  external int nbMoves;
}

abstract class Flag {
  static const int NOFlAG = 0;
  static const int EN_PASSANT = 1;
  static const int DOUBLE_PAWN_PUSH = 2;
  static const int KING_SIDE_CASTLING = 3;
  static const int QUEEN_SIDE_CASTLING = 4;
  static const int PROMOTE_TO_QUEEN = 5;
  static const int PROMOTE_TO_KNIGHT = 6;
  static const int PROMOTE_TO_ROOK = 7;
  static const int PROMOTE_TO_BISHOP = 8;
  static const int STALEMATE = 9;
  static const int CHECKMATE = 10;
  static const int DRAW = 11;
}

abstract class PIECE {
  static const int NONE = 0;
  static const int KING = 1;
  static const int QUEEN = 2;
  static const int KNIGHT = 3;
  static const int BISHOP = 4;
  static const int ROOK = 5;
  static const int PAWN = 6;
  static const int WHITE = 8;
  static const int BLACK = 16;
}

/// Dynamic array of moves
/// The structure is copied from Sebastian Lague chess program
/// A move is a 16 bit number
/// bit 0-5: from square (0 to 63)
/// bit 6-11: to square (0 to 63)
/// bit 12-15: flag
typedef Moves = moves;
typedef GameState = gameState;

const int BOARD_SIZE = 64;

const int pieceColorBitMask = 24;

const int pieceTypeBitMask = 7;

const int DA_INIT_CAP = 256;