part of 'chess_engine.dart';

enum MoveFlag {
  noFlag,
  enPassant,
  doublePawnPush,
  kingSideCastling,
  queenSideCastling,
  promoteToQueen,
  promoteToKnight,
  promoteToRook,
  promoteToBishop,
  stalemate,
  checkmate,
  draw;

  static MoveFlag fromInt(int flag) {
    if (flag > MoveFlag.values.length || flag < 0) return MoveFlag.noFlag;
    return MoveFlag.values[flag];
  }

  int get value => index;

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

  PieceType fromInt(int value) =>
      PieceType.values[value & Piece.pieceTypeBitMask];
}

enum PieceColor {
  none,
  white,
  black;

  int get value => index * 8;
  PieceColor get oppositeColor {
    if (this == PieceColor.black) {
      return PieceColor.white;
    } else if (this == PieceColor.white) {
      return PieceColor.black;
    } else {
      return PieceColor.none;
    }
  }

  static PieceColor fromInt(int value) =>
      PieceColor.values[(value & Piece.pieceColorBitMask) ~/ 8];
}

class Piece {
  static const int pieceColorBitMask = _pieceColorBitMask;
  static const int pieceTypeBitMask = _pieceTypeBitMask;
  static final Piece none = Piece.fromInt(PieceType.none.value);

  late final int value;
  Piece(PieceColor color, PieceType type) {
    value = color.value | type.value;
  }

  Piece.fromInt(this.value);

  PieceColor get color => PieceColor.values[(value & pieceColorBitMask) ~/ 8];
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
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Piece &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() {
    if (this == none) return "none";
    String pieceColor =
        color.name.substring(0, 1).toUpperCase() + color.name.substring(1);
    return "$pieceColor ${type.name}";
  }
}

class ChessMove {
  final int startSquare;
  final int endSquare;
  final MoveFlag flag;

  const ChessMove(this.startSquare, this.endSquare, this.flag);

  static ChessMove fromInt(int move) {
    int startSquare = move & 63;
    int endSquare = (move >> 6) & 63;
    int flag = move >> 12;
    return ChessMove(startSquare, endSquare, MoveFlag.fromInt(flag));
  }

  String toStringWithBoard(ChessGameState state) {
    return '${Piece.fromInt(state.boardArray[startSquare].value)} ($startSquare) '
        'to ${Piece.fromInt(state.boardArray[endSquare].value)} ($endSquare)';
  }

  @override
  String toString() {
    return 'ChessMove(startSquare: $startSquare, endSquare: $endSquare, flag: $flag)';
  }
}

// TODO: Make this class immutable
// TODO: Replace the int for castling perm by a Castling class
class ChessGameState {
  final List<Piece> boardArray;
  PieceColor colorToGo;
  int castlingPerm;
  int enPassantTargetSquare;
  int turnsForFiftyRule;
  int nbMoves;

  ChessGameState(this.boardArray, this.colorToGo, this.castlingPerm,
      this.enPassantTargetSquare, this.turnsForFiftyRule, this.nbMoves);

  ChessGameState copy() {
    return ChessGameState(_copyList(boardArray), colorToGo, castlingPerm,
        enPassantTargetSquare, turnsForFiftyRule, nbMoves);
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

  void makeMove(ChessMove move) {
    int from = move.startSquare;
    int to = move.endSquare << 6;
    int flag = move.flag.value << 12;
    int cMove = from + to + flag;
    final cState = ChessEngine()._dartStateToCState(this);
    ChessEngine()._library.makeMove(cMove, cState);
    // Update the dart state
    for (int i = 0; i < BOARD_SIZE; i++) {
      boardArray[i] = Piece.fromInt(cState.ref.boardArray.elementAt(i).value);
    }
    colorToGo = PieceColor.fromInt(cState.ref.colorToGo);
    castlingPerm = cState.ref.castlingPerm;
    enPassantTargetSquare = cState.ref.enPassantTargetSquare;
    turnsForFiftyRule = cState.ref.turnsForFiftyRule;
    nbMoves = cState.ref.nbMoves;

    malloc.free(cState.ref.boardArray);
    malloc.free(cState);
  }

  String boardAsString() {
    String result = "";
    for (int i = 0; i < 64; i++) {
      final fenChar = boardArray[i].fenChar();
      result += (fenChar.isNotEmpty) ? "[ $fenChar ]" : "[   ]";
      if ((i + 1) % 8 == 0) {
        result += "\n";
      }
    }
    return result.substring(0, result.length - 1); // Remove last new line
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
    final cFenString = fenString.toNativeUtf8().cast<ffi.Char>();

    final cState = ChessEngine()
        ._library
        .setGameStateFromFenString(cFenString, ffi.nullptr);
    malloc.free(cFenString);
    final boardArray = List.filled(BOARD_SIZE, Piece.fromInt(0));

    for (int i = 0; i < BOARD_SIZE; i++) {
      boardArray[i] = Piece.fromInt(cState.ref.boardArray.elementAt(i).value);
    }

    final result = ChessGameState(
        boardArray,
        PieceColor.fromInt(cState.ref.colorToGo),
        cState.ref.castlingPerm,
        cState.ref.enPassantTargetSquare,
        cState.ref.turnsForFiftyRule,
        cState.ref.nbMoves);

    malloc.free(cState.ref.boardArray);
    malloc.free(cState);

    return result;
  }

  static const startingFenString =
      "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";

  static ChessGameState startingGameState() =>
      ChessGameState.fromFenString(startingFenString);
}

List<Piece> _copyList(List<Piece> list) {
  return List.generate(list.length, (index) => list[index], growable: false);
}

class ChessEngine {
  late final _NativeLibrary _library;

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

  List<ChessMove> getMovesFromState(
      ChessGameState gameState, List<ChessGameState> previousStates) {
    final state = _dartStateToCState(gameState);

    final gameStatesPtr = malloc<GameStates>();
    gameStatesPtr.ref.items = previousStates.isNotEmpty
        ? malloc<GameState>(ffi.sizeOf<GameState>() * previousStates.length)
        : ffi.nullptr;
    gameStatesPtr.ref.capacity = previousStates.length;
    gameStatesPtr.ref.count = previousStates.length;
    for (int i = 0; i < previousStates.length; i++) {
      final pointerToState = _dartStateToCState(previousStates[i]);
      gameStatesPtr.ref.items.elementAt(i).ref = pointerToState.ref;
    }
    return _getMovesFromPointerState(state, gameStatesPtr);
  }

  List<ChessMove> _getMovesFromPointerState(
      ffi.Pointer<GameState> state, ffi.Pointer<GameStates> previousStates) {
    final moves = _library.getValidMoves(state, previousStates);
    // No memory leaks Please <(^uwu^)>
    malloc.free(state.ref.boardArray);
    malloc.free(state);
    for (int i = 0; i < previousStates.ref.count; i++) {
      malloc.free(previousStates.ref.items[i].boardArray);
    }
    if (previousStates.ref.capacity != 0) {
      malloc.free(previousStates.ref.items);
    }
    malloc.free(previousStates);
    final result = movesDAToDartList(moves);
    malloc.free(moves.ref.items);
    malloc.free(moves);
    return result;
  }

  ffi.Pointer<GameState> _dartStateToCState(ChessGameState state) {
    final boardPointer = malloc.allocate<ffi.Int>(ffi.sizeOf<ffi.Int>() * 64);
    for (int i = 0; i < 64; i++) {
      boardPointer.elementAt(i).value = state.boardArray[i].value;
    }

    return _library.createState(
        boardPointer,
        state.colorToGo.value,
        state.castlingPerm,
        state.enPassantTargetSquare,
        state.turnsForFiftyRule,
        state.nbMoves);
  }

  List<ChessMove> getBestMovesAccordingToComputer(int depth,
      ChessGameState currentState, List<ChessGameState> previousStates) {
    final currentStateC = _dartStateToCState(currentState);
    final gameStatesPtr = malloc<GameStates>();
    gameStatesPtr.ref.capacity = previousStates.length;
    gameStatesPtr.ref.count = previousStates.length;
    gameStatesPtr.ref.items = previousStates.isNotEmpty
        ? malloc.allocate(ffi.sizeOf<GameState>() * gameStatesPtr.ref.capacity)
        : ffi.nullptr;
    for (int i = 0; i < previousStates.length; i++) {
      final c_state = _dartStateToCState(previousStates[i]);
      gameStatesPtr.ref.items[i] = c_state.ref;
      malloc.free(c_state);
    }

    final cMoves = _library.bestMovesAccordingToComputer(
        depth, currentStateC, gameStatesPtr);
    final moves = movesDAToDartList(cMoves);
    malloc.free(cMoves.ref.items);
    malloc.free(cMoves);
    if (previousStates.isNotEmpty) {
      for (int i = 0; i < gameStatesPtr.ref.count; i++) {
        malloc.free(gameStatesPtr.ref.items.elementAt(i).ref.boardArray);
      }
      malloc.free(gameStatesPtr.ref.items);
    }
    malloc.free(gameStatesPtr);
    malloc.free(currentStateC.ref.boardArray);
    malloc.free(currentStateC);
    return moves;
  }

  List<ChessMove> movesDAToDartList(ffi.Pointer<Moves> moves) {
    final result = <ChessMove>[];
    for (int i = 0; i < moves.ref.count; i++) {
      result.add(ChessMove.fromInt(moves.ref.items[i]));
    }
    return result;
  }

  @override
  String toString() {
    return "ChessEngine()";
  }
}
