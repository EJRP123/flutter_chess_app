import 'package:chess_app/widgets/board.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../engine/c_chess_engine_library.dart';

class MainMenu extends StatelessWidget {
  const MainMenu({Key? key}) : super(key: key);

  // Note: I could create a shared mutable ChessGameState object
  // However I am scared of what this could be become if this code ever gets larger
  @override
  Widget build(BuildContext context) {
    String whiteAsset =
        "assets/images/${PIECE.asString(PIECE.WHITE | PIECE.KING).toLowerCase().replaceAll(" ", "_")}.svg";
    String blackAsset =
        "assets/images/${PIECE.asString(PIECE.BLACK | PIECE.KING).toLowerCase().replaceAll(" ", "_")}.svg";
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: GestureDetector(
              onTap: () {
                Navigator.push(context, getRouteBuilder(PIECE.WHITE));
              },
              child: SvgPicture.asset(whiteAsset,
                  semanticsLabel: PIECE.asString(PIECE.WHITE | PIECE.KING))
          ),
        ),
        Expanded(
          child: GestureDetector(
              onTap: () {
                Navigator.push(context, getRouteBuilder(PIECE.BLACK));
              },
              child:SvgPicture.asset(blackAsset,
                  semanticsLabel: PIECE.asString(PIECE.BLACK | PIECE.KING)),
        )
        )
      ],
    );
  }

  PageRouteBuilder getRouteBuilder(int pieceColor) {
    // This animation for the route builder is ripped directly from the flutter docs
    return PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            GamePage(pieceColor: pieceColor),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.ease;

          final tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        });
  }
}

class GamePage extends StatelessWidget {
  final int pieceColor;
  const GamePage({Key? key, required this.pieceColor}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black38,
        title: Text(
            "Playing ${PIECE.asString(pieceColor)} against AI"),
      ),
      body: Board(pieceColor),
    );
  }
}
