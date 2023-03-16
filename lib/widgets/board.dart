import 'dart:collection';
import 'dart:math';

import 'package:chess_app/engine/chess_ai.dart';
import 'package:chess_app/engine/gameEmulator.dart';
import 'package:chess_app/widgets/draggable_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_layout_grid/flutter_layout_grid.dart';

import 'package:flutter_svg/svg.dart';

import '../engine/c_chess_engine_library.dart';
import '../engine/chess_engine_api.dart';
import 'dialogs.dart';

class Board extends StatefulWidget {
  final Color color1 = const Color.fromRGBO(235, 235, 208, 1.0);
  final Color color2 = const Color.fromRGBO(119, 148, 85, 1.0);

  final int humanPieceColor;

  const Board(this.humanPieceColor, {Key? key}) : super(key: key);

  @override
  State<Board> createState() => _BoardState();
}

// Plan:
// - Make the app not freeze when the ai is calculating moves (DONE)
// - Make a way to undo moves (DONE)
// - Draggable pieces (DONE)

// - TODO: Add repeating moves draw (If three fen strings are the same in a game then it is a draw)
// Note: This will require to mostly rework the engine
// The engine will need to track the positions and see if the position happened more than once
// I think that the idea that I go for right now is to let the user provide the
// list of played positions in the argument of the `getValidMoves` function
// I will not modify the signature of the GameState struct to include
// a list of played positions because copying that list will become expensive
// when you pass it around by value


// - Timer
//    - Position starter and current fen string
//    - Depth of computer
//    - StockFish analysis?

class _BoardState extends State<Board> {
  late final ChessGameState _gameState;
  late List<ChessMove> _currentLegalMoves;
  late final LinkedHashMap<ChessMove, ChessGameState> _playerMoves;
  late ChessMove? _lastMoveMade;
  late List<ChessMove> _allAiMoves;

  late int _clickedPieceIndex;
  late final List<bool> _highlightedSquares;

  late final ChessEngine _engine;

  late final int _aiPieceColor;

  @override
  void initState() {
    super.initState();
    _gameState = ChessGameState.startingGameState();
    _engine = ChessEngine();
    _highlightedSquares = List.filled(81, false);
    _currentLegalMoves = _engine.getMovesFromState(_gameState);
    _playerMoves = LinkedHashMap<ChessMove, ChessGameState>();
    _clickedPieceIndex = -1;
    _aiPieceColor =
        widget.humanPieceColor == PIECE.WHITE ? PIECE.BLACK : PIECE.WHITE;
    _lastMoveMade = null;
    _allAiMoves = <ChessMove>[];
    resetBoard();
  }

  @override
  Widget build(BuildContext context) {
    bool changeColor = false;
    return FocusableActionDetector(
      autofocus: true,
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyZ, control: true):
            UndoMoveIntent()
      },
      actions: {
        UndoMoveIntent: CallbackAction<UndoMoveIntent>(onInvoke: (_) {
          // So that we don't undo a move when the ai is calculating a move
          // Without this line, the app crashed when this happens
          // Since Chess.com has the same behaviour in their app,
          // (you cannot take back a move while a bot is "thinking")
          // this is not a bug, but a feature
          if (_gameState.colorToGo == _aiPieceColor) return;
          undoMove();
          return null;
        })
      },
      child: Transform.rotate(
        angle: _aiPieceColor == PIECE.WHITE ? pi : 0,
        child: LayoutGrid(
            columnSizes: List.filled(8, 8.fr),
            rowSizes: List.filled(8, 8.fr),
            children: List.generate(64, (index) {
              if (index % 8 == 0) changeColor = !changeColor;
              var color = (index % 2 == 0)
                  ? (changeColor)
                      ? widget.color1
                      : widget.color2
                  : (changeColor)
                      ? widget.color2
                      : widget.color1;

              if (_lastMoveMade != null) {
                if (index == _lastMoveMade!.startSquare ||
                    index == _lastMoveMade!.endSquare) {
                  color = Color.alphaBlend(
                      Colors.yellowAccent.withOpacity(0.5), color);
                }
              }
              final int piece = _gameState.boardArray[index];
              final isDraggable = piece & pieceColorBitMask != _aiPieceColor;
              final isHighlighted = _highlightedSquares[index];
              return GestureDetector(
                  onTap: () {
                    // This is at the top so that this behaviour triggers first
                    if (isHighlighted) {
                      // We clicked a highlighted squares
                      clickedHighlightedSquare(index);
                      return; // To get no await bugs
                    }

                    if (piece != PIECE.NONE && isDraggable) {
                      // We clicked our own piece
                      clickedAPiece(index);
                    } else {
                      // To get a clean board back
                      setState(() {
                        removeAllHighlightedSquares();
                        _clickedPieceIndex = -1;
                      });
                    }
                  },
                  child: Square(index, piece, color, isHighlighted, isDraggable,
                      _aiPieceColor == PIECE.WHITE,
                      droppedPiece));
            })),
      ),
    );
  }

  void clickedAPiece(int index) {
    _clickedPieceIndex = index;
    removeAllHighlightedSquares();
    List<int> squareToColor = _currentLegalMoves
        .where((element) => element.startSquare == index)
        .map((e) => e.endSquare)
        .toList();
    setState(() {
      for (final square in squareToColor) {
        _highlightedSquares[square] = true;
      }
    });
  }

  void clickedHighlightedSquare(int index) async {
    removeAllHighlightedSquares();

    var moves = _currentLegalMoves.where((element) =>
        element.startSquare == _clickedPieceIndex &&
        element.endSquare == index);

    final move = await getMoveToMake(
        moves, moves.any((e) => e.flag == MoveFlag.PROMOTE_TO_QUEEN));
    await makeHumanMoveThenAiMove(move);
  }

  Future<ChessMove> getMoveToMake(
      Iterable<ChessMove> moves, bool isPromotion) async {
    if (isPromotion) {
      final moveFlag = await showDialog(
          context: context,
          builder: (context) => PromotionDialog(
              color: _gameState.colorToGo, contextOfPopup: context));
      return moves.where((e) => e.flag == moveFlag).first;
    } else {
      return moves.first;
    }
  }

  void removeAllHighlightedSquares() {
    _highlightedSquares.fillRange(0, _highlightedSquares.length, false);
  }

  bool computeGameEnd() {
    final move0 = _currentLegalMoves[0];

    if (move0.flag == MoveFlag.STALEMATE) {
      stalemate();
      return true;
    }
    if (move0.flag == MoveFlag.CHECMATE) {
      checkmate(
          _gameState.colorToGo == PIECE.WHITE ? PIECE.BLACK : PIECE.WHITE);
      return true;
    }
    return false;
  }

  void stalemate() {
    showDialog(
        context: context,
        builder: (context) => GameEndDialog(
              title: "It is a stalemate :(",
              message: "This game has unfortunately ended with a stalemate. "
                  "I personally apologize for the anti-climactic ending this "
                  "game had (or maybe it was an insane stalemate, who knows...)",
              undoMove: () => undoMove(),
              resetBoard: () => resetBoard(),
            ));
  }

  void checkmate(int color) {
    showDialog(
        context: context,
        builder: (context) => GameEndDialog(
              title: "There is a winner!",
              message: "It is a great honor to inform you that "
                  "${color == PIECE.WHITE ? "white" : "black"} has won! "
                  "You are truly a player with immense skill and you should "
                  "celebrate this victory over the enemy with a dance!",
              undoMove: () => undoMove(),
              resetBoard: () => resetBoard(),
            ));
  }

  void resetBoard() {
    setState(() {
      _gameState.copyFrom(ChessGameState.startingGameState());
      _currentLegalMoves = _engine.getMovesFromState(_gameState);
      _clickedPieceIndex = -1;
      _playerMoves.clear();
      removeAllHighlightedSquares();
      _lastMoveMade = null;
    });
    if (_gameState.colorToGo == _aiPieceColor) {
      makeAiResponseMove(); // No need to compute game end cause impossible
    }
  }

  void undoMove() {
    if (_playerMoves.isEmpty) return;
    final lastEntry = _playerMoves.entries.last;
    final lastGameState = lastEntry.value;
    _playerMoves.remove(lastEntry.key);
    _allAiMoves.removeLast();
    _gameState.copyFrom(lastGameState);
    setState(() {
      _currentLegalMoves = _engine.getMovesFromState(_gameState);
      _lastMoveMade = _allAiMoves.isEmpty ? null : _allAiMoves.last;
      _clickedPieceIndex = -1;
      removeAllHighlightedSquares();
    });
  }

  void droppedPiece(int from, int to) {
    if (_gameState.colorToGo == _aiPieceColor) {
      return;
    }
    final potentialMove = _currentLegalMoves.firstWhere(
        (move) => move.startSquare == from && move.endSquare == to,
        orElse: () => const ChessMove(-1, -1, MoveFlag.NOFlAG));
    if (potentialMove.startSquare == -1) { return; }
    _clickedPieceIndex = from;
    clickedHighlightedSquare(to);
  }

  Future<void> makeHumanMoveThenAiMove(ChessMove move) async {
    makeMove(move, false);
    if (computeGameEnd()) {
      return;
    }
    await makeAiResponseMove();
    computeGameEnd();
  }

  void makeMove(ChessMove move, bool aiMove) {
    setState(() {
      if (!aiMove) {
        _playerMoves[move] = _gameState.copy();
      } else {
        _allAiMoves.add(move);
      }
      ChessMoveUpdater().makeMove(move, _gameState);
      _lastMoveMade = move;
      _currentLegalMoves = _engine.getMovesFromState(_gameState);
      _clickedPieceIndex = -1;
    });
  }

  Future<void> makeAiResponseMove() async {
    final responseMove =
        await compute<ChessGameState, ChessMove>(getMoveFromAi, _gameState);
    makeMove(responseMove, true);
  }
}

typedef DroppedPiece = void Function(int from, int to);

class Square extends StatelessWidget {
  final int index;
  final int piece;
  final Color color;
  final bool isHighlighted;
  final bool isDraggable;
  final bool rotate;
  final DroppedPiece droppedPiece;

  const Square(this.index, this.piece, this.color, this.isHighlighted,
      this.isDraggable, this.rotate, this.droppedPiece,
      {Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DragTarget<int>(
        onAccept: (item) => droppedPiece(item, index),
        builder: (context, candidateItems, rejectedItems) {
          return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    color: color,
                    child: Stack(
                      alignment: Alignment.center,
                      fit: StackFit.expand,
                      children: [
                        if (piece != PIECE.NONE)
                          if (isDraggable)
                            getDraggablePicture()
                          else
                            getPieceSVG(true),

                        if (isHighlighted)
                          Icon(
                            Icons.circle,
                            color: Colors.grey.withOpacity(0.5),
                            size: 50,
                          ),
                      ],
                    ),
                  ),
                ),
              ]);
        });
  }

  Widget getDraggablePicture() {
    return LayoutBuilder(builder: (context, constraint) {
      return Draggable<int>(
        data: index,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: ChessPicture(
          size: Size(
              constraint.maxWidth, constraint.maxHeight),
          child: getPieceSVG(false),
        ),
        childWhenDragging: Container(),
        child: getPieceSVG(true),
      );
    });
  }

  Widget getPieceSVG(bool keepRotation) {
    String assetName =
        "assets/images/${PIECE.asString(piece).toLowerCase().replaceAll(" ", "_")}.svg";
      return Transform.rotate(
        angle: keepRotation && rotate ? pi : 0,
        child: SvgPicture.asset(assetName,
            semanticsLabel: PIECE.asString(piece)),
      );
    }
}

class UndoMoveIntent extends Intent {
  const UndoMoveIntent();
}
