import 'dart:collection';
import 'dart:ffi' as ffi;
import 'dart:math';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_layout_grid/flutter_layout_grid.dart';
import 'package:flutter_svg/svg.dart';

import '../engine/chess_engine.dart';
import 'dialogs.dart';
import 'draggable_widget.dart';
import 'routes.dart';

class ChessBoard extends StatefulWidget {
  final Color color1 = const Color.fromRGBO(235, 235, 208, 1.0);
  final Color color2 = const Color.fromRGBO(119, 148, 85, 1.0);

  final PieceColor humanPieceColor;

  const ChessBoard(this.humanPieceColor, {super.key});

  @override
  State<ChessBoard> createState() => _ChessBoardState();
}

// Plan:
// - Make the app not freeze when the ai is calculating moves (DONE)
// - Make a way to undo moves (DONE)
// - Draggable pieces (DONE)
// - Add repeating moves draw (DONE)
// - Add own ai evaluation
// - Timer
// - Add multiple depth strategy
//    - Position starter and current fen string
//    - Depth of computer
//    - StockFish analysis?

class _ChessBoardState extends State<ChessBoard> {
  late final ChessGameData _gameState;
  late List<ChessMove> _currentLegalMoves;
  late final LinkedHashMap<ChessMove, ChessPositionData> _gameHistory;

  late int _clickedPieceIndex;
  late final List<bool> _highlightedSquares;

  late final ChessEngine _engine;

  late final PieceColor _aiPieceColor;

  @override
  void initState() {
    super.initState();
    _engine = ChessEngine();
    _gameState = _engine.startingGameState();
    _gameHistory = LinkedHashMap<ChessMove, ChessPositionData>();
    _highlightedSquares = List.filled(81, false);
    _currentLegalMoves = _engine.getMovesFromState(_gameState);
    _clickedPieceIndex = -1;
    _aiPieceColor = widget.humanPieceColor == PieceCharacteristics.WHITE
        ? PieceCharacteristics.BLACK
        : PieceCharacteristics.WHITE;
    resetBoard();
  }

  @override
  void deactivate() {

    for (final position in _gameHistory.values) {
      malloc.free(position);
    }

    _engine.freeChessGame(_gameState);
    super.deactivate();
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
          if (_gameState.currentState.colorToGo == _aiPieceColor) return;
          undoMove();
          return null;
        })
      },
      child: AspectRatio(
        aspectRatio: 1.0,
        child: LayoutGrid(
              columnSizes: List.filled(8, 8.fr),
              rowSizes: List.filled(8, 8.fr),
              children: List.generate(64, (index) {
                final realIndex = _aiPieceColor == PieceCharacteristics.WHITE ? 63 - index : index;

                if (index % 8 == 0) changeColor = !changeColor;
                var color = (index % 2 == 0)
                    ? (changeColor)
                        ? widget.color1
                        : widget.color2
                    : (changeColor)
                        ? widget.color2
                        : widget.color1;

                if (_gameHistory.keys.isNotEmpty) {

                  if (realIndex == _gameHistory.keys.last.startSquare ||
                      realIndex == _gameHistory.keys.last.endSquare) {
                    color = Color.alphaBlend(
                        Colors.yellowAccent.withOpacity(0.5), color);
                  }

                }

                final ChessPiece piece = _gameState.currentState.pieceAt(realIndex);
                final isDraggable = piece.color != _aiPieceColor;
                final isHighlighted = _highlightedSquares[realIndex];
                return GestureDetector(
                    onTap: () {
                      // This is at the top so that this behaviour triggers first
                      if (isHighlighted) {
                        // We clicked a highlighted squares
                        clickedHighlightedSquare(realIndex);
                        return; // To get no await bugs
                      }

                      if (piece.type != PieceUtility.none && isDraggable) {
                        // We clicked our own piece
                        clickedAPiece(realIndex);
                      } else {
                        // To get a clean board back
                        setState(() {
                          removeAllHighlightedSquares();
                          _clickedPieceIndex = -1;
                        });
                      }
                    },
                    child: Square(
                        realIndex,
                        piece,
                        color,
                        isHighlighted,
                        isDraggable,
                        _aiPieceColor == PieceCharacteristics.WHITE,
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
        moves, moves.any((e) => e.flag == MoveFlag.promoteToQueen));
    await makeHumanMoveThenAiMove(move);
  }

  Future<ChessMove> getMoveToMake(
      Iterable<ChessMove> moves, bool isPromotion) async {
    if (isPromotion) {
      final moveFlag = await showDialog(
          context: context,
          builder: (context) => PromotionDialog(
              color: _gameState.currentState.colorToGo, contextOfPopup: context));
      return moves.where((e) => e.flag == moveFlag).first;
    } else {
      return moves.first;
    }
  }

  void removeAllHighlightedSquares() {
    _highlightedSquares.fillRange(0, _highlightedSquares.length, false);
  }

  bool computeGameEnd() {
    if (_engine.isDraw(_gameState)) {
      draw();
      return true;
    }

    if (_engine.isStalemate(_gameState)) {
      stalemate();
      return true;
    }
    if (_engine.isCheckmate(_gameState)) {
      checkmate(_gameState.currentState.colorToGo == PieceCharacteristics.WHITE
          ? PieceCharacteristics.BLACK
          : PieceCharacteristics.WHITE);
      return true;
    }
    return false;
  }

  void draw() {
    showDialog(
        context: context,
        builder: (context) => GameEndDialog(
              title: "It is a draw by repetition",
              message:
                  "This game has unfortunately ended with a draw by repetition. "
                  "This is kinda cringe ngl, except if it was forced, cause those are sorta cool",
              undoMove: () => undoMove(),
              resetBoard: () => resetBoard(),
            ));
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

  void checkmate(PieceColor whoWon) {
    showDialog(
        context: context,
        builder: (context) => GameEndDialog(
              title: "There is a winner!",
              message: "It is a great honor to inform you that "
                  "${whoWon == PieceCharacteristics.WHITE ? "white" : "black"} has won! "
                  "You are truly a player with immense skill and you should "
                  "celebrate this victory over the enemy with a dance!",
              undoMove: () => undoMove(),
              resetBoard: () => resetBoard(),
            ));
  }

  void resetBoard() {
    setState(() {
      // To avoid memory leaks
      malloc.free(_gameState.ref.previousStates);
      _engine.setupGameFromFenString(_gameState, startingFenString);

      for (final position in _gameHistory.values) {
        malloc.free(position);
      }
      _gameHistory.clear();
      _gameState.ref.previousStatesCount = 0;

      _currentLegalMoves =
          _engine.getMovesFromState(_gameState);
      _clickedPieceIndex = -1;
      removeAllHighlightedSquares();
    });
    if (_gameState.currentState.colorToGo == _aiPieceColor) {
      makeAiResponseMove(); // No need to compute game end cause impossible
    }
  }

  void undoMove() {
    if (_gameHistory.length <= 1) return;

    // It is never the bots turn to go (we check that before this function is called
    final removedValue = _gameHistory.remove(_gameHistory.keys.last); // Undoing the ai move
    malloc.free(removedValue!);
    _gameState.ref.previousStatesCount--;

    if (_gameHistory.isNotEmpty) {
      final previousPosition = _gameHistory.values.last;
      _gameState.currentState.copyFrom(previousPosition);

      final removedValue = _gameHistory.remove(_gameHistory.keys.last); // Undoing the player move
      malloc.free(removedValue!);
      _gameState.ref.previousStatesCount--;

    } else {
      // To avoid memory leaks
      malloc.free(_gameState.ref.previousStates);
      _engine.setupGameFromFenString(_gameState, startingFenString);
    }


    setState(() {
      _currentLegalMoves =
          _engine.getMovesFromState(_gameState);
      _clickedPieceIndex = -1;
      removeAllHighlightedSquares();
    });
  }

  void droppedPiece(int from, int to) {
    if (_gameState.currentState.colorToGo == _aiPieceColor) {
      return;
    }
    final potentialMove = _currentLegalMoves.firstWhere(
        (move) => move.startSquare == from && move.endSquare == to,
        orElse: () => const ChessMove(-1, -1, MoveFlag.noFlag));
    if (potentialMove.startSquare == -1) {
      return;
    }
    _clickedPieceIndex = from;
    clickedHighlightedSquare(to);
  }

  Future<void> makeHumanMoveThenAiMove(ChessMove move) async {
    makeMove(move);
    if (computeGameEnd()) {
      return;
    }
    await makeAiResponseMove();
    computeGameEnd();
  }

  void makeMove(ChessMove move) {
    setState(() {
      _gameHistory[move] = _gameState.currentState.clone();
      _engine.makeMove(move, _gameState);
      _currentLegalMoves =
          _engine.getMovesFromState(_gameState);
      _clickedPieceIndex = -1;
    });
  }

  Future<void> makeAiResponseMove() async {

    final keys = <int>[];
    for (int i = 0; i < _gameState.ref.previousStatesCount; i++) {
      keys.add(_gameState.ref.previousStates.elementAt(i).value);
    }

    final responseMoves = await compute<AiMoveParam, List<ChessMove>>(
        getMoveFromAiIsolate, AiMoveParam(keys, _gameState.currentState.toFenString()));
    makeMove(responseMoves[Random().nextInt(responseMoves.length)]);
  }
}

typedef DroppedPiece = void Function(int from, int to);

class Square extends StatelessWidget {
  final int index;
  final ChessPiece piece;
  final Color color;
  final bool isHighlighted;
  final bool isDraggable;
  final bool rotate;
  final DroppedPiece droppedPiece;

  const Square(this.index, this.piece, this.color, this.isHighlighted,
      this.isDraggable, this.rotate, this.droppedPiece,
      {super.key});

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
                        if (piece.type != PieceUtility.none)
                          if (isDraggable)
                            getDraggablePicture()
                          else
                            getPieceSVG(),
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
          size: Size(constraint.maxWidth, constraint.maxHeight),
          child: getPieceSVG(),
        ),
        childWhenDragging: Container(),
        child: getPieceSVG(),
      );
    });
  }

  Widget getPieceSVG() {
    String assetName =
        "assets/images/${piece.stringRepresentation().toLowerCase().replaceAll(" ", "_")}.svg";
    return SvgPicture.asset(assetName, semanticsLabel: piece.stringRepresentation());
  }
}

class UndoMoveIntent extends Intent {
  const UndoMoveIntent();
}
