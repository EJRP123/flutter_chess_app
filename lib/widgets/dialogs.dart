import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../engine/c_chess_engine_library.dart';
import '../engine/chess_engine_api.dart';

class PromotionDialog extends StatelessWidget {
  final int color;
  final BuildContext contextOfPopup;

  const PromotionDialog(
      {Key? key, required this.color, required this.contextOfPopup})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        getPieceChoice(color | PIECE.QUEEN, MoveFlag.PROMOTE_TO_QUEEN),
        getPieceChoice(color | PIECE.KNIGHT, MoveFlag.PROMOTE_TO_KNIGHT),
        getPieceChoice(color | PIECE.ROOK, MoveFlag.PROMOTE_TO_ROOK),
        getPieceChoice(color | PIECE.BISHOP, MoveFlag.PROMOTE_TO_BISHOP),
      ],
    );
  }

  Widget getPieceChoice(int piece, MoveFlag flag) {
    String assetName =
        "assets/images/${PIECE.asString(piece).toLowerCase().replaceAll(" ", "_")}.svg";
    return GestureDetector(
      onTap: () => Navigator.pop(contextOfPopup, flag),
      child: SvgPicture.asset(assetName, semanticsLabel: PIECE.asString(piece)),
    );
  }
}

class GameEndDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback undoMove;
  final VoidCallback resetBoard;
  const GameEndDialog({Key? key, required this.title, required this.message, required this.undoMove, required this.resetBoard}) : super(key: key);

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
