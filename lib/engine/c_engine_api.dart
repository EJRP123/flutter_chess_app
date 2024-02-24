part of 'chess_engine.dart';

const int BOARD_SIZE = 64;
const startingFenString = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";

typedef ChessPiece = int;
typedef PieceColor = int;

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

extension PieceUtility on ChessPiece {
  static const int pieceColorBitMask = 24; // 0b11000
  static const int pieceTypeBitMask = 7; // 0b111
  static const ChessPiece none = 0;

  static ChessPiece fromColorAndType(int color, int type) => color | type;

  int get color => this & pieceColorBitMask;
  int get type => this & pieceTypeBitMask;

  String fenChar() {
    String caseLambda(String fenChar) {
      return color == PieceCharacteristics.WHITE ? fenChar.toUpperCase() : fenChar;
    }

    switch (type) {
      case PieceCharacteristics.KING:
        return caseLambda("k");
      case PieceCharacteristics.PAWN:
        return caseLambda("p");
      case PieceCharacteristics.KNIGHT:
        return caseLambda("n");
      case PieceCharacteristics.BISHOP:
        return caseLambda("b");
      case PieceCharacteristics.ROOK:
        return caseLambda("r");
      case PieceCharacteristics.QUEEN:
        return caseLambda("q");
      default:
        return "";
    }
  }

  String stringRepresentation() {
    if (this == none) return "none";
    String pieceColor = color == PieceCharacteristics.WHITE ? "White" : "Black";
    String typeName;
    switch (type) {
      case PieceCharacteristics.KING:
        typeName = "king";
      case PieceCharacteristics.PAWN:
        typeName = "pawn";
      case PieceCharacteristics.KNIGHT:
        typeName = "knight";
      case PieceCharacteristics.BISHOP:
        typeName = "bishop";
      case PieceCharacteristics.ROOK:
        typeName = "rook";
      case PieceCharacteristics.QUEEN:
        typeName = "queen";
      default:
        return "";
    }
    return "$pieceColor $typeName";
  }
}

class ChessMove {
  final int startSquare;
  final int endSquare;
  final MoveFlag flag;

  const ChessMove(this.startSquare, this.endSquare, this.flag);

  static ChessMove fromInt(int move) => ChessMove(move & 63, (move >> 6) & 63, MoveFlag.fromInt(move >> 12));

  int toInt() => (startSquare) + (endSquare << 6) + (flag.value << 12);

  String toStringWithBoard(ChessPositionData state) {
    return '${ChessEngine()._library.pieceAtIndex(state.ref.board, startSquare).fenChar()} ($startSquare) '
        'to ${ChessEngine()._library.pieceAtIndex(state.ref.board, endSquare).fenChar()} ($endSquare)';
  }

  @override
  String toString() {
    return 'ChessMove(startSquare: $startSquare, endSquare: $endSquare, flag: $flag)';
  }
}

typedef ChessPositionData = ffi.Pointer<ChessPosition>;
typedef ChessGameData = ffi.Pointer<ChessGame>;

extension ChessGameUtility on ChessGameData {
  ChessPositionData get currentState => ref.currentState;
}

extension ChessPositionUtility on ChessPositionData {

  PieceColor get colorToGo => ref.colorToGo;

  ChessPiece pieceAt(int index) => ChessEngine()._library.pieceAtIndex(ref.board, index);

  void copyFrom(ChessPositionData src) {
    ref.board = src.ref.board;
    ref.colorToGo = src.ref.colorToGo;
    ref.castlingPerm = src.ref.castlingPerm;
    ref.enPassantTargetSquare = src.ref.enPassantTargetSquare;
    ref.turnsForFiftyRule = src.ref.turnsForFiftyRule;
    ref.nbMoves = src.ref.nbMoves;
    ref.key = src.ref.key;
  }

  ChessPositionData clone() {
    final result = malloc.allocate<ChessPosition>(ffi.sizeOf<ChessPosition>());

    result.ref.board = ref.board;
    result.ref.colorToGo = ref.colorToGo;
    result.ref.castlingPerm = ref.castlingPerm;
    result.ref.enPassantTargetSquare = ref.enPassantTargetSquare;
    result.ref.turnsForFiftyRule = ref.turnsForFiftyRule;
    result.ref.nbMoves = ref.nbMoves;
    result.ref.key = ref.key;

    return result;
  }

  String toFenString() {
    var fenString = "";
    // Add board
    var emptySpots = 0;
    for (int i = 0; i < BOARD_SIZE; i++) {
      if (i % 8 == 0 && i > 0) {
        if (emptySpots != 0) {
          fenString += emptySpots.toString();
        }
        fenString += "/";
        emptySpots = 0;
      }
      final piece = pieceAt(i);
      if (piece == PieceUtility.none) {
        emptySpots++;
      } else {
        fenString += (emptySpots != 0) ? "$emptySpots${piece.fenChar()}" : piece.fenChar();
        emptySpots = 0;
      }
    }

    // Add turn
    fenString += (ref.colorToGo == PieceCharacteristics.BLACK) ? " b " : " w ";
    // Add castling
    fenString += ((ref.castlingPerm >> 3) & 1 == 1) ? "K" : "";
    fenString += ((ref.castlingPerm >> 2) & 1 == 1) ? "Q" : "";
    fenString += ((ref.castlingPerm >> 1) & 1 == 1) ? "k" : "";
    fenString += ((ref.castlingPerm >> 0) & 1 == 1) ? "q" : "";
    fenString += (ref.castlingPerm == 0) ? "-" : "";
    // Add en-passant
    fenString += (ref.enPassantTargetSquare != 0) ? " ${positionToAlgebraic(ref.enPassantTargetSquare)}" : " -";
    // Add fifty-fifty rule
    fenString += " ${ref.turnsForFiftyRule} ";
    // Add total number of moves
    fenString += ref.nbMoves.toString();

    return fenString;
  }

  String boardAsString() {
    String result = "";
    for (int i = 0; i < BOARD_SIZE; i++) {
      final fenChar = pieceAt(i).fenChar();
      result += (fenChar.isNotEmpty) ? "[ $fenChar ]" : "[   ]";
      if ((i + 1) % 8 == 0) {
        result += "\n";
      }
    }
    return result.substring(0, result.length - 1); // Remove last new line
  }
}

void wrappedPrint(ffi.Pointer<Utf8> arg){
  print(arg.toDartString());
}

typedef _wrappedPrint_C = ffi.Void Function(ffi.Pointer<Utf8> a);

class ChessEngine {
  late final _NativeLibrary _library;

  ChessEngine.init(ffi.DynamicLibrary dynamicLibrary) {
    if (_onlyInstance == null) {
      _library = _NativeLibrary(dynamicLibrary);
      final wrappedPrintPointer = ffi.Pointer.fromFunction<_wrappedPrint_C>(wrappedPrint);
      _library.initializeFFILogging(wrappedPrintPointer);
      // IMPORTANT: Order of these initialization matters!
      // If magicBitBoardInitialize is not last the memory seems to get corrupted
      // The only thing I can see is that since the rookPseudoLegalMovesBitBoard pointer is so big (~700kb)
      // then its size has an effect. Else I do not know
      _library.zobristKeyInitialize();
      _library.pieceSquareTableInitialize();
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

  /// Allocates a new ChessGameData object and puts the starting game state in it
  ChessGameData startingGameState() => setupGameFromFenString(null, startingFenString);

  /// Setups the game data from the fen string.
  /// If pointer is non-null the data will be put in the pointer.
  /// If pointer is null a new pointer will be allocated, fill with the game data and returned
  ChessGameData setupGameFromFenString(ChessGameData? pointer, String fenString) {
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
    final cState = ChessEngine()._library.setupChesGame(pointer ?? ffi.nullptr, cFenString);
    malloc.free(cFenString);

    return cState;
  }

  void makeMove(ChessMove move, ChessGameData state) {
    int from = move.startSquare;
    int to = move.endSquare << 6;
    int flag = move.flag.value << 12;
    int cMove = from + to + flag;

    _library.playMove(cMove, state);
  }

  List<ChessMove> getMovesFromState(ChessGameData gameState) {

    // Here I put 256 because it is the power of 2 closest to the MAX_LEGAL_MOVES (218)
    final cResult = calloc.allocate<Move>(ffi.sizeOf<Move>() * 256);
    final numMoves = malloc.allocate<ffi.Int>(ffi.sizeOf<ffi.Int>());

    _library.getValidMoves(cResult, numMoves, gameState);

    final result = <ChessMove>[];

    for (int i = 0; i < numMoves.value; i++) {
      final move = cResult.elementAt(i);
      final chessMove = ChessMove.fromInt(move.value);
      result.add(chessMove);
    }

    malloc.free(numMoves);
    calloc.free(cResult);
    return result;
  }

  List<ChessMove> getBestMovesAccordingToComputer(ChessGameData state) {

    final cMoves = _library.think(state);

    return <ChessMove>[ChessMove.fromInt(cMoves)];
  }

  bool isCheckmate(ChessGameData game) {
    return getMovesFromState(game).isEmpty && ChessEngine()._library.isKingInCheck();
  }

  bool isStalemate(ChessGameData game) {
    return ChessEngine().getMovesFromState(game).isEmpty && !ChessEngine()._library.isKingInCheck();
  }

  bool isDrawByRepetition(ChessGameData game) {
    bool hasOneDuplicate = false;

    for (int i = 0; i < game.ref.previousStatesCount; i++) {
      int key = game.ref.previousStates.elementAt(i).value;
      if (key == game.ref.currentState.ref.key) {
        if (hasOneDuplicate) {
          return true;
        }
        hasOneDuplicate = true;
      }
    }

    return false;
  }

  bool isDrawByFiftyMoveRule(ChessGameData game) {
    return game.ref.currentState.ref.turnsForFiftyRule >= 50;
  }

  bool isDraw(ChessGameData game) => isDrawByFiftyMoveRule(game) || isDrawByRepetition(game);

  void terminate(ChessGameData state) {
    // We are good programmers and we clean up after ourselves
    _library.freeChessGame(state);
    _library.zobristKeyTerminate();
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