part of 'chess_engine.dart';

const int BOARD_SIZE = 64;

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
  knight,
  bishop,
  queen,
  rook,
  pawn;

  int get value => index; // For consistency with PieceColor

  PieceType fromInt(int value) =>
      PieceType.values[value & ChessPiece.pieceTypeBitMask];
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
      PieceColor.values[(value & ChessPiece.pieceColorBitMask) ~/ 8];
}

class ChessPiece {
  static const int pieceColorBitMask = 24; // 0b11000
  static const int pieceTypeBitMask = 7; // 0b111
  static final ChessPiece none = ChessPiece.fromInt(PieceType.none.value);

  late final int value;
  ChessPiece(PieceColor color, PieceType type) {
    value = color.value | type.value;
  }

  ChessPiece.fromInt(this.value);

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
      other is ChessPiece &&
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
    return '${ChessPiece.fromInt(state.boardArray[startSquare].value)} ($startSquare) '
        'to ${ChessPiece.fromInt(state.boardArray[endSquare].value)} ($endSquare)';
  }

  @override
  String toString() {
    return 'ChessMove(startSquare: $startSquare, endSquare: $endSquare, flag: $flag)';
  }
}

// TODO: Make this class immutable
class ChessGameState {
  final List<ChessPiece> boardArray;
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
      boardArray[i] = ChessPiece.fromInt(ChessEngine()._library.pieceAtIndex(cState.ref.board, i));
    }
    colorToGo = PieceColor.fromInt(cState.ref.colorToGo);
    castlingPerm = cState.ref.castlingPerm;
    enPassantTargetSquare = cState.ref.enPassantTargetSquare;
    turnsForFiftyRule = cState.ref.turnsForFiftyRule;
    nbMoves = cState.ref.nbMoves;

    malloc.free(cState);
  }

  String toFenString() {
    var fenString = "";
    // Add board
    var emptySpots = 0;
    for (int i = 0; i < 64; i++) {
      if (i % 8 == 0 && i > 0) {
        if (emptySpots != 0) {
          fenString += emptySpots.toString();
        }
        fenString += "/";
        emptySpots = 0;
      }
      final piece = boardArray[i];
      if (piece == ChessPiece.none) {
        emptySpots++;
      } else {
        fenString += (emptySpots != 0) ? "$emptySpots${piece.fenChar()}" : piece.fenChar();
        emptySpots = 0;
      }
    }

    // Add turn
    fenString += (colorToGo == PieceColor.black) ? " b " : " w ";
    // Add castling
    fenString += ((castlingPerm >> 3) & 1 == 1) ? "K" : "";
    fenString += ((castlingPerm >> 2) & 1 == 1) ? "Q" : "";
    fenString += ((castlingPerm >> 1) & 1 == 1) ? "k" : "";
    fenString += ((castlingPerm >> 0) & 1 == 1) ? "q" : "";
    fenString += (castlingPerm == 0) ? "-" : "";
    // Add en-passant
    fenString += " ${positionToAlgebraic(enPassantTargetSquare)}";
    // Add fifty-fifty rule
    fenString += " $turnsForFiftyRule ";
    // Add total number of moves
    fenString += nbMoves.toString();

    return fenString;
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

    final cState = malloc<GameState>();
    ChessEngine()._library.setGameStateFromFenString(cFenString, cState);
    malloc.free(cFenString);
    final boardArray = List.filled(BOARD_SIZE, ChessPiece.fromInt(0));

    for (int i = 0; i < BOARD_SIZE; i++) {
      boardArray[i] = ChessPiece.fromInt(ChessEngine()._library.pieceAtIndex(cState.ref.board, i));
    }

    final result = ChessGameState(
        boardArray,
        PieceColor.fromInt(cState.ref.colorToGo),
        cState.ref.castlingPerm,
        cState.ref.enPassantTargetSquare,
        cState.ref.turnsForFiftyRule,
        cState.ref.nbMoves);

    malloc.free(cState);

    return result;
  }

  static const startingFenString =
      "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";

  static ChessGameState startingGameState() =>
      ChessGameState.fromFenString(startingFenString);
}

List<ChessPiece> _copyList(List<ChessPiece> list) {
  return List.generate(list.length, (index) => list[index], growable: false);
}

class ChessEngine {
  late final _NativeLibrary _library;

  ChessEngine.init(ffi.DynamicLibrary dynamicLibrary) {
    if (_onlyInstance == null) {
      _library = _NativeLibrary(dynamicLibrary);
      _library.magicBitBoardInitialize();
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

  List<ChessMove> getMovesFromState(ChessGameState gameState, List<ChessGameState> previousStates) {

    final cCurrentState = _dartStateToCState(gameState);

    int previousStatesSize = previousStates.length + 1;
    final cPreviousStates = calloc.allocate<GameState>(ffi.sizeOf<GameState>() * previousStatesSize);
    for (int i = 0; i < previousStates.length; i++) {
      final pointerToState = _dartStateToCState(previousStates[i]);
      cPreviousStates.elementAt(i).ref = pointerToState.ref;
    }

    // Here I put 256 because it is the power of 2 closest to the MAX_LEGAL_MOVES (218)
    final cResult = calloc.allocate<Move>(ffi.sizeOf<Move>() * 256);

    _library.getValidMoves(cResult, cCurrentState.ref, cPreviousStates);

    final nbMoves = _library.nbMovesInArray(cResult);
    final result = <ChessMove>[];

    for (int i = 0; i < nbMoves; i++) {
      final move = cResult.elementAt(i);
      final chessMove = ChessMove.fromInt(move.value);
      result.add(chessMove);
    }

    malloc.free(cCurrentState);
    calloc.free(cPreviousStates);
    calloc.free(cResult);
    return result;
  }


  List<ChessMove> getBestMovesAccordingToComputer(ChessGameState currentState, List<ChessGameState> previousStates) {
    final cCurrentState = _dartStateToCState(currentState);

    int previousStatesSize = previousStates.length + 1;
    final cPreviousStates = calloc.allocate<GameState>(ffi.sizeOf<GameState>() * previousStatesSize);
    for (int i = 0; i < previousStates.length; i++) {
      final pointerToState = _dartStateToCState(previousStates[i]);
      cPreviousStates.elementAt(i).ref = pointerToState.ref;
    }

    final cMoves = _library.think(cCurrentState.ref, cPreviousStates);

    malloc.free(cCurrentState);
    calloc.free(cPreviousStates);
    return <ChessMove>[ChessMove.fromInt(cMoves)];
  }

  ffi.Pointer<GameState> _dartStateToCState(ChessGameState state) {
    final array = calloc.allocate<Piece>(ffi.sizeOf<Piece>() * BOARD_SIZE);
    for (int i = 0; i < state.boardArray.length; i++) {
      final piece = state.boardArray[i].value;
      array.elementAt(i).value = piece;
    }
    final board = calloc<Board>();
    _library.fromArray(board, array);
    calloc.free(array);

    final result = malloc<GameState>();
    result.ref.board = board.ref;
    calloc.free(board);
    result.ref.colorToGo = state.colorToGo.value;
    result.ref.castlingPerm = state.castlingPerm;
    result.ref.enPassantTargetSquare = state.enPassantTargetSquare;
    result.ref.turnsForFiftyRule = state.turnsForFiftyRule;
    result.ref.nbMoves = state.nbMoves;

    return result;
  }

  void terminate() {
    // We are good programmers and we clean up after ourselves
    _library.magicBitBoardTerminate();
  }

  @override
  String toString() {
    return "ChessEngine()";
  }
}

String positionToAlgebraic(int position) {
  String result;
  if (position < 0 || position > 63) {
    return "-";
  }
  switch (position % 8) {
    case 0: result = "a${8 - position ~/ 8}"; break;
    case 1: result = "b${8 - position ~/ 8}"; break;
    case 2: result = "c${8 - position ~/ 8}"; break;
    case 3: result = "d${8 - position ~/ 8}"; break;
    case 4: result = "e${8 - position ~/ 8}"; break;
    case 5: result = "f${8 - position ~/ 8}"; break;
    case 6: result = "g${8 - position ~/ 8}"; break;
    case 7: result = "h${8 - position ~/ 8}"; break;
    default: result =  "-";
  }
  return result;
}