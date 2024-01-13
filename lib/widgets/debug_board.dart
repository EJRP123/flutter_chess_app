import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_layout_grid/flutter_layout_grid.dart';
import 'package:flutter_svg/svg.dart';

import '../engine/chess_engine.dart';
import 'dialogs.dart';
import 'draggable_widget.dart';
import 'routes.dart';

class DebugBoard extends StatefulWidget {
  final Color color1 = const Color.fromRGBO(235, 235, 208, 1.0);
  final Color color2 = const Color.fromRGBO(119, 148, 85, 1.0);

  DebugBoard({super.key}) {
    ChessEngine.init(dynamicLibProvider());
  }

  @override
  State<DebugBoard> createState() => _DebugBoardState();
}

class _DebugBoardState extends State<DebugBoard> {
  late final ChessGameState _gameState;
  late List<ChessMove> _currentLegalMoves;
  late final LinkedHashMap<ChessMove, ChessGameState> _movesMade;

  late int _clickedPieceIndex;
  late final List<bool> _highlightedSquares;

  late final ChessEngine _engine;

  late final TextEditingController _myController;

  @override
  void initState() {
    super.initState();
    _gameState = ChessGameState.startingGameState();
    _engine = ChessEngine();
    _movesMade = LinkedHashMap<ChessMove, ChessGameState>();
    _highlightedSquares = List.filled(81, false);
    _currentLegalMoves = _engine.getMovesFromState(_gameState, _previousStates);
    _clickedPieceIndex = -1;
    _myController = TextEditingController();
    resetBoard();
  }

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed.
    _myController.dispose();
    super.dispose();
  }

  List<ChessGameState> get _previousStates {
    return _movesMade.values.toList();
  }
// rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8
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
          undoMove();
          return null;
        })
      },
      child: ListView(
          children: [
        AspectRatio(
          aspectRatio: 1.0,
          child: LayoutGrid(
              columnSizes: List.filled(8, 8.fr),
              rowSizes: List.filled(8, 8.fr),
              children: List.generate(64, (index) {
                if (index % 8 == 0) changeColor = !changeColor;
                Color color;
                if (index % 2 == 0) {
                  if (changeColor) {
                    color = widget.color1;
                  } else {
                    color = widget.color2;
                  }
                } else {
                  if (changeColor) {
                    color = widget.color2;
                  } else {
                    color = widget.color1;
                  }
                }

                if (_movesMade.keys.isNotEmpty) {
                  if (index == _movesMade.keys.last.startSquare ||
                      index == _movesMade.keys.last.endSquare) {
                    color = Color.alphaBlend(
                        Colors.yellowAccent.withOpacity(0.5), color);
                  }
                }
                final Piece piece = _gameState.boardArray[index];
                final isHighlighted = _highlightedSquares[index];
                return GestureDetector(
                    onTap: () {
                      // This is at the top so that this behaviour triggers first
                      if (isHighlighted) {
                        // We clicked a highlighted squares
                        clickedHighlightedSquare(index);
                        return; // To get no await bugs
                      }

                      if (piece.type != PieceType.none) {
                        // We clicked a piece
                        clickedAPiece(index);
                      } else {
                        // To get a clean board back
                        setState(() {
                          removeAllHighlightedSquares();
                          _clickedPieceIndex = -1;
                        });
                      }
                    },
                    child: _Square(
                        index, piece, color, isHighlighted, droppedPiece));
              })),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextField(
              controller: _myController,
              onEditingComplete: () {
                try {
                  setState(() {
                    _gameState.copyFrom(ChessGameState.fromFenString(_myController.text));

                    _currentLegalMoves =
                        _engine.getMovesFromState(_gameState, _previousStates);
                    _clickedPieceIndex = -1;
                    removeAllHighlightedSquares();
                  });
                } catch (_) {

                }
              },
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter a Fen String',
              ),
            ),
            SelectableText(_gameState.toFenString(),

              style: const TextStyle(
                  fontSize: 28.0,
                  fontWeight: FontWeight.bold
              ),)
          ],
        )
      ]
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

  void resetBoard() {
    setState(() {
      // _gameState.copyFrom(ChessGameState.startingGameState());
      _gameState.copyFrom(ChessGameState.startingGameState());
      _movesMade.clear();
      _currentLegalMoves =
          _engine.getMovesFromState(_gameState, _previousStates);
      _clickedPieceIndex = -1;
      removeAllHighlightedSquares();
    });
  }

  void undoMove() {
    if (_movesMade.isEmpty) {
      return;
    }

    _gameState.copyFrom(_movesMade.values.last);
    _movesMade.remove(_movesMade.keys.last); // Undoing the last move made

    setState(() {
      _currentLegalMoves =
          _engine.getMovesFromState(_gameState, _previousStates);
      _clickedPieceIndex = -1;
      removeAllHighlightedSquares();
    });
  }

  void droppedPiece(int from, int to) {
    final potentialMove = _currentLegalMoves.firstWhere(
        (move) => move.startSquare == from && move.endSquare == to,
        orElse: () => const ChessMove(-1, -1, MoveFlag.noFlag));
    if (potentialMove.startSquare == -1) {
      return;
    }
    _clickedPieceIndex = from;
    clickedHighlightedSquare(to);
  }

  void makeMove(ChessMove move) {
    setState(() {
      _movesMade[move] = _gameState.copy();
      _gameState.makeMove(move);
      _currentLegalMoves =
          _engine.getMovesFromState(_gameState, _previousStates);
      _clickedPieceIndex = -1;
    });
  }

  void clickedHighlightedSquare(int index) async {
    removeAllHighlightedSquares();

    var moves = _currentLegalMoves.where((element) =>
        element.startSquare == _clickedPieceIndex &&
        element.endSquare == index);

    final move = await getMoveToMake(
        moves, moves.any((e) => e.flag == MoveFlag.promoteToQueen));
    makeMove(move);
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
}

typedef _DroppedPiece = void Function(int from, int to);

class _Square extends StatelessWidget {
  final int index;
  final Piece piece;
  final Color color;
  final bool isHighlighted;
  final _DroppedPiece droppedPiece;

  const _Square(
      this.index, this.piece, this.color, this.isHighlighted, this.droppedPiece,
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
                        Text("${positionToAlgebraic(index)} $index"),
                        if (piece.type != PieceType.none) getDraggablePicture(),
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
          child: getPieceSVG(false),
        ),
        childWhenDragging: Container(),
        child: getPieceSVG(true),
      );
    });
  }

  Widget getPieceSVG(bool keepRotation) {
    String assetName =
        "assets/images/${piece.toString().toLowerCase().replaceAll(" ", "_")}.svg";
    return SvgPicture.asset(assetName, semanticsLabel: piece.toString());
  }
}

class UndoMoveIntent extends Intent {
  const UndoMoveIntent();
}
