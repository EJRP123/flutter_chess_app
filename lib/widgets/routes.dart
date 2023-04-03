import 'package:chess_app/widgets/board.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../engine/chess_engine_ffi.dart';
import '../engine/chess_engine_api.dart';

class MainMenu extends StatelessWidget {
  const MainMenu({Key? key}) : super(key: key);

  // Note: I could create a shared mutable ChessGameState object
  // However I am scared of what this could be become if this code ever gets larger
  @override
  Widget build(BuildContext context) {
    String whiteAsset =
        "assets/images/${Piece.asString(PIECE.WHITE | PIECE.KING).toLowerCase().replaceAll(" ", "_")}.svg";
    String blackAsset =
        "assets/images/${Piece.asString(PIECE.BLACK | PIECE.KING).toLowerCase().replaceAll(" ", "_")}.svg";
    return Material(
      color: Colors.grey,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: InkWell(
                onTap: () {
                  Navigator.push(context, getRouteBuilder(PIECE.WHITE));
                },
                child: SvgPicture.asset(whiteAsset,
                    semanticsLabel: Piece.asString(PIECE.WHITE | PIECE.KING))),
          ),
          Expanded(
              child: InkWell(
            onTap: () {
              Navigator.push(context, getRouteBuilder(PIECE.BLACK));
            },
            child: SvgPicture.asset(blackAsset,
                semanticsLabel: Piece.asString(PIECE.BLACK | PIECE.KING)),
          ))
        ],
      ),
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
        backgroundColor: Colors.blueGrey,
        title: Text("Playing ${Piece.asString(pieceColor)} against AI"),
      ),
      body: Center(child: Board(pieceColor)),
      backgroundColor: Colors.blueGrey,
    );
  }
}
