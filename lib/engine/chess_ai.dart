import 'dart:math';

import 'package:chess_app/engine/c_chess_engine_library.dart';
import 'package:chess_app/engine/chess_engine_api.dart';
import 'package:chess_app/engine/gameEmulator.dart';

// I need to do this to use the Flutter compute function
ChessMove getMoveFromAi(ChessGameState state) {
  return ChessAi().getMoveToPlay(state);
}

class ChessAi {
  static final ChessAi _singleton = ChessAi._internal();
  factory ChessAi() {
    return _singleton;
  }
  ChessAi._internal();

  final engine = ChessEngine();

  final int _pawnValue = 100;
  final int _knightValue = 300;
  final int _bishopValue = 300;
  final int _rookValue = 500;
  final int _queenValue = 900;

  final int _mobilityWeight = 1; // Mobility is not that important

  final int _positiveInfinity = 9999999;
  final int _negativeInfinity = -9999999;

  final maxDepth = 3;

  ChessMove getMoveToPlay(ChessGameState state) {
    final legalMoves = engine.getMovesFromState(state);
    var bestEval = _negativeInfinity;

    final moves = <ChessMove>[];

    for (final move in legalMoves) {
      final newState = state.copy();
      ChessMoveUpdater().makeMove(move, newState);
      final statesBeforeDepth = List<ChessGameState?>.generate(
          maxDepth + 1, (index) => null,
          growable: false);
      statesBeforeDepth[maxDepth] = newState;
      int eval = -1 * _search(maxDepth, _negativeInfinity, _positiveInfinity,
              statesBeforeDepth);
      if (eval > bestEval) {
        bestEval = eval;
        moves.clear();
        moves.add(move);
      } else if (eval == bestEval) {
        moves.add(move);
      }
    }
    moves.shuffle(); // So that we don't get always the same move for the same position
    return moves.first;
  }

  int _pieceToValue(int piece) {
    switch (piece & pieceTypeBitMask) {
      case PIECE.PAWN:
        return _pawnValue;
      case PIECE.KNIGHT:
        return _knightValue;
      case PIECE.BISHOP:
        return _bishopValue;
      case PIECE.ROOK:
        return _rookValue;
      case PIECE.QUEEN:
        return _queenValue;
      default:
        return 0;
    }
  }

  // Only checks at material and mobility
  // Note: Does not look into king safety, center control, ect...
  int evaluatePosition(ChessGameState state) {
    final colorToGo = state.colorToGo;
    // material
    final whiteMaterial = state.boardArray
        .where((element) => (element & pieceColorBitMask) == PIECE.WHITE)
        .map((e) => _pieceToValue(e))
        .reduce((value, element) => value + element);
    final blackMaterial = state.boardArray
        .where((element) => (element & pieceColorBitMask) == PIECE.BLACK)
        .map((e) => _pieceToValue(e))
        .reduce((value, element) => value + element);
    final materialScore = whiteMaterial - blackMaterial;
    // mobility
    state.colorToGo = PIECE.BLACK;
    final blackLegalMoves = engine.getMovesFromState(state).length;
    state.colorToGo = PIECE.WHITE;
    final whiteLegalMoves = engine.getMovesFromState(state).length;
    final mobilityScore = (whiteLegalMoves - blackLegalMoves) * _mobilityWeight;

    final whoToMove = colorToGo == PIECE.WHITE ? 1 : -1;
    return (materialScore + mobilityScore) * whoToMove;
  }

  int _search(
      int depth, int alpha, int beta, List<ChessGameState?> statesBeforeDepth) {
    if (depth == 0) {
      return evaluatePosition(statesBeforeDepth[0]!);
    }

    final previousState = statesBeforeDepth[depth]!;
    final moves = engine.getMovesFromState(previousState);
    _orderMoves(moves, previousState);
    if (moves.length == 1) {
      if (moves[0].flag == MoveFlag.CHECMATE) {
        return _negativeInfinity;
      } else if (moves[0].flag == MoveFlag.STALEMATE) {
        return 0;
      }
    }

    for (final move in moves) {
      final newState = previousState.copy();
      ChessMoveUpdater().makeMove(move, newState);
      statesBeforeDepth[depth - 1] = newState;
      final evaluation = -_search(depth - 1, -beta, -alpha, statesBeforeDepth);
      if (evaluation >= beta) {
        return beta;
      }
      alpha = max(alpha, evaluation);
    }

    return alpha;
  }

  final _capturedPieceValueMultiplier = 10;

  void _orderMoves(List<ChessMove> moves, ChessGameState state) {
    final order = <int, int>{};
    for (int i = 0; i < moves.length; i++) {
      final move = moves[i];
      int score = 0;
      final pieceThatMoves = state.boardArray[move.startSquare];
      final pieceToCapture = state.boardArray[move.endSquare];

      // Captures a piece with a smaller piece
      if (pieceToCapture != PIECE.NONE) {
        score += _capturedPieceValueMultiplier * _pieceToValue(pieceToCapture) -
            _pieceToValue(pieceThatMoves);
      }

      // Promote a piece
      if ((pieceThatMoves & pieceTypeBitMask) == PIECE.PAWN) {
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

      order[score] = i;
    }
    _sortMoves(order, moves);
  }

  void _sortMoves(Map<int, int> order, List<ChessMove> moves) {
    // Sort the moves list based on scores
    final copy = List.from(moves);
    final sortedKeys = order.keys.toList();
    sortedKeys.sort((i1, i2) => -i1.compareTo(i2));
    for (int i = 0; i < sortedKeys.length; i++) {
      final index = order[sortedKeys[i]]!;
      moves[i] = copy[index];
    }
  }
}
