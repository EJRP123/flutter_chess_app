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
    const maxDepth = 3;
    final List<ChessMove> legalMoves =
        _engine.getMovesFromState(state, previousStates);
    var bestEval = _negativeInfinity;

    final bestMoves = <ChessMove>[];

    for (final move in legalMoves) {
      final newState = state.copy();
      newState.makeMove(move);
      previousStates.add(state); // Because this is now a previous move
      int eval = _search(maxDepth, _negativeInfinity, _positiveInfinity,
          newState, previousStates) * -1;
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
  int evaluatePosition(ChessGameState state) {
    // material
    final whiteMaterial = state.boardArray
        .where((element) => element.color == PieceColor.white)
        .map((e) => _pieceToValue(e))
        .reduce((value, element) => value + element);
    final blackMaterial = state.boardArray
        .where((element) => element.color == PieceColor.black)
        .map((e) => _pieceToValue(e))
        .reduce((value, element) => value + element);
    final materialScore = whiteMaterial - blackMaterial;
    // mobility
    state.colorToGo = PieceColor.black;
    // Note: Previous states not taken into account to speed up the app
    final blackLegalMoves =
        _engine.getMovesFromState(state, List.empty(growable: true)).length;
    state.colorToGo = PieceColor.white;
    final whiteLegalMoves =
        _engine.getMovesFromState(state, List.empty(growable: true)).length;
    final mobilityScore = (whiteLegalMoves - blackLegalMoves) * _mobilityWeight;

    return materialScore + mobilityScore;
  }

  int _search(int depth, int alpha, int beta, ChessGameState currentState,
      List<ChessGameState> previousStates) {
    if (depth == 0) {
      final perspective = currentState.colorToGo == PieceColor.white ? 1 : -1;
      return evaluatePosition(currentState.copy()) * perspective;
    }

    final moves = _engine.getMovesFromState(currentState, previousStates);
    orderMoves(moves, currentState);

    if (moves.length == 1) {
      if (moves[0].flag == MoveFlag.checkmate) {
        return _negativeInfinity;
      } else if (moves[0].flag == MoveFlag.stalemate ||
          moves[0].flag == MoveFlag.draw) {
        return 0;
      }
    }

    for (int i = 0; i < moves.length; i++) {
      final move = moves[i];
      final newState = currentState.copy();
      previousStates.add(currentState);
      newState.makeMove(move);
      // Eval is the worse case scenario of this move
      // It is the best response that the opponent can make
      final evaluation =
          _search(depth - 1, -beta, -alpha, newState, previousStates) * -1;
      // Removing moves done in this depth
      previousStates.removeLast();
      if (evaluation >= beta) {
        // The previous evaluation (beta) was worse than the current evaluation
        // Since we assume that the opponent will always make the best move,
        // then we cannot make this move as this would lead to an even better
        // position for the opponent. We can therefore prune this branch
        return beta;
      }
      alpha = max(alpha, evaluation);
    }
    return alpha;
  }

  final _capturedPieceValueMultiplier = 10;

  void orderMoves(List<ChessMove> moves, ChessGameState state) {
    final LinkedHashMap<int, List<int>> order = LinkedHashMap();
    for (int i = 0; i < moves.length; i++) {
      final move = moves[i];
      int score = 0;
      final pieceThatMoves = state.boardArray[move.startSquare];
      final pieceToCapture = state.boardArray[move.endSquare];

      // Captures a piece with a smaller piece
      if (pieceToCapture.type != PieceType.none) {
        score += _capturedPieceValueMultiplier * _pieceToValue(pieceToCapture) -
            _pieceToValue(pieceThatMoves);
      }

      // Promote a piece
      if ((pieceThatMoves.type) == PieceType.pawn) {
        final flag = move.flag;
        if (flag == MoveFlag.promoteToQueen) {
          score += _queenValue;
        } else if (flag == MoveFlag.promoteToKnight) {
          score += _knightValue;
        } else if (flag == MoveFlag.promoteToRook) {
          score += _rookValue;
        } else if (flag == MoveFlag.promoteToBishop) {
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