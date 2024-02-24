import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../engine/chess_engine.dart';

class PromotionDialog extends StatelessWidget {
  final PieceColor color;
  final BuildContext contextOfPopup;

  const PromotionDialog(
      {super.key, required this.color, required this.contextOfPopup});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        getPieceChoice(PieceUtility.fromColorAndType(color, PieceCharacteristics.QUEEN), MoveFlag.promoteToQueen),
        getPieceChoice(PieceUtility.fromColorAndType(color, PieceCharacteristics.KNIGHT), MoveFlag.promoteToKnight),
        getPieceChoice(PieceUtility.fromColorAndType(color, PieceCharacteristics.ROOK), MoveFlag.promoteToRook),
        getPieceChoice(PieceUtility.fromColorAndType(color, PieceCharacteristics.BISHOP), MoveFlag.promoteToBishop),
      ],
    );
  }

  Widget getPieceChoice(ChessPiece piece, MoveFlag flag) {
    String assetName =
        "assets/images/${piece.stringRepresentation().toLowerCase().replaceAll(" ", "_")}.svg";
    return GestureDetector(
      onTap: () => Navigator.pop(contextOfPopup, flag),
      child: SvgPicture.asset(assetName, semanticsLabel: piece.stringRepresentation()),
    );
  }
}

class GameEndDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback undoMove;
  final VoidCallback resetBoard;
  const GameEndDialog({super.key, required this.title, required this.message, required this.undoMove, required this.resetBoard});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () {
              undoMove();
              Navigator.pop(context);
            },
            child: const Text("Undo Last Move")),
        TextButton(
            onPressed: () {
              resetBoard();
              Navigator.pop(context);
            },
            child: const Text("Start again")),
      ],
    );
  }
}
