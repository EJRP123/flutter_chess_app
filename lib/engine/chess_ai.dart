library chess_ai;

import 'dart:collection';
import 'dart:developer' as dev;
import 'dart:math';

import 'chess_engine.dart';

// TODO: Rewrite it in C (even better, in Rust)
class ChessAi {
  late final ChessEngine _engine;

  ChessAi() {
    try {
      _engine = ChessEngine();
    } on StateError catch (error, stackTrace) {
      dev.log(
          "You need to call ChessEngine.init() in every isolate that use the ChessEngine class",
          time: DateTime.now(),
          error: error,
          stackTrace: stackTrace);
    }
  }

  final int _pawnValue = 100;
  final int _knightValue = 300;
  final int _bishopValue = 300;
  final int _rookValue = 500;
  final int _queenValue = 900;

  final int _mobilityWeight = 1; // Mobility is not that important

  final int _positiveInfinity = 9999999;
  final int _negativeInfinity = -9999999;

  ChessMove getMoveToPlay(
      ChessGameState state, List<ChessGameState> previousStates) {
    const maxDepth = 2;
    final List<ChessMove> legalMoves =
        _engine.getMovesFromState(state, previousStates);
    var bestEval = _negativeInfinity;

    final bestMoves = <ChessMove>[];

    for (final move in legalMoves) {
      final newState = state.copy();
      newState.makeMove(move);
      previousStates.add(state); // Because this is now a previous move
      int eval = _search(maxDepth, maxDepth, newState, previousStates) * -1;
      if (eval > bestEval) {
        bestEval = eval;
        bestMoves.clear();
        bestMoves.add(move);
      } else if (eval == bestEval) {
        bestMoves.add(move);
      }
    }
    // So that we don't get always the same move for the same position
    return bestMoves[Random().nextInt(bestMoves.length)];
  }

  int _pieceToValue(Piece piece) {
    switch (piece.type) {
      case PieceType.pawn:
        return _pawnValue;
      case PieceType.knight:
        return _knightValue;
      case PieceType.bishop:
        return _bishopValue;
      case PieceType.rook:
        return _rookValue;
      case PieceType.queen:
        return _queenValue;
      default:
        return 0;
    }
  }

  /// Only checks at material and mobility
  /// Does not look into king safety, center control, ect...
  /// Returns a positive value if white is better else it is a negative value
  int evaluatePosition(
      ChessGameState state) {
    // material
    final whiteMaterial = state.boardArray
        .where((element) =>
            (element & Piece.pieceColorBitMask) == PieceColor.white.value)
        .map((e) => _pieceToValue(Piece(e)))
        .reduce((value, element) => value + element);
    final blackMaterial = state.boardArray
        .where((element) =>
            (element & Piece.pieceColorBitMask) == PieceColor.black.value)
        .map((e) => _pieceToValue(Piece(e)))
        .reduce((value, element) => value + element);
    final materialScore = whiteMaterial - blackMaterial;
    // mobility
    state.colorToGo = PieceColor.black.value;
    // Note: Previous states not taken into account to speed up the app
    final blackLegalMoves =
        _engine.getMovesFromState(state, List.empty(growable: true)).length;
    state.colorToGo = PieceColor.white.value;
    final whiteLegalMoves =
        _engine.getMovesFromState(state, List.empty(growable: true)).length;
    final mobilityScore = (whiteLegalMoves - blackLegalMoves) * _mobilityWeight;

    return materialScore + mobilityScore;
  }

  int _search(int depth, int maxDepth, ChessGameState currentState,
      List<ChessGameState> previousStates) {
    if (depth == 0) {
      final perspective =
          currentState.colorToGo == PieceColor.white.value ? 1 : -1;
      return evaluatePosition(currentState.copy()) * perspective;
    }

    final moves = _engine.getMovesFromState(currentState, previousStates);
    orderMoves(moves, currentState);

    if (moves.length == 1) {
      if (moves[0].flag == MoveFlag.CHECMATE) {
        return _negativeInfinity;
      } else if (moves[0].flag == MoveFlag.STALEMATE ||
          moves[0].flag == MoveFlag.DRAW) {
        return 0;
      }
    }

    var bestEvaluation = _negativeInfinity;

    for (int i = 0; i < moves.length; i++) {
      final move = moves[i];
      final newState = currentState.copy();
      previousStates.add(currentState.copy());
      newState.makeMove(move);
      final evaluation =
          _search(depth - 1, maxDepth, newState, previousStates) * -1;
      // Removing moves done in this depth
      previousStates.removeLast();
      bestEvaluation = max(bestEvaluation, evaluation);
    }

    return bestEvaluation;
  }

  final _capturedPieceValueMultiplier = 10;

  void orderMoves(List<ChessMove> moves, ChessGameState state) {
    final LinkedHashMap<int, List<int>> order = LinkedHashMap();
    for (int i = 0; i < moves.length; i++) {
      final move = moves[i];
      int score = 0;
      final pieceThatMoves = Piece(state.boardArray[move.startSquare]);
      final pieceToCapture = Piece(state.boardArray[move.endSquare]);

      // Captures a piece with a smaller piece
      if (pieceToCapture.type != PieceType.none) {
        score += _capturedPieceValueMultiplier * _pieceToValue(pieceToCapture) -
            _pieceToValue(pieceThatMoves);
      }

      // Promote a piece
      if ((pieceThatMoves.type) == PieceType.pawn) {
        final flag = move.flag;
        if (flag == MoveFlag.PROMOTE_TO_QUEEN) {
          score += _queenValue;
        } else if (flag == MoveFlag.PROMOTE_TO_KNIGHT) {
          score += _knightValue;
        } else if (flag == MoveFlag.PROMOTE_TO_ROOK) {
          score += _rookValue;
        } else if (flag == MoveFlag.PROMOTE_TO_BISHOP) {
          score += _bishopValue;
        }
      }

      if (!order.containsKey(score)) {
        order[score] = <int>[i];
      } else {
        order[score]!.add(i);
      }
    }
    sortMoves(order, moves);
  }

  void sortMoves(Map<int, List<int>> order, List<ChessMove> moves) {
    // Sort the moves list based on scores
    final copy = List.from(moves);
    final sortedKeys = order.keys.toList();
    sortedKeys.sort((i1, i2) => -i1.compareTo(i2));
    for (int i = 0; i < sortedKeys.length; i++) {
      final indices = order[sortedKeys[i]]!;
      for (int index in indices) {
        // This works because the keys of order contains all indices of moves
        moves[index] = copy[index];
      }
    }
  }
}