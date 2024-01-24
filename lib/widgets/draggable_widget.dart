import 'package:flutter/material.dart';

class ChessPicture extends StatelessWidget {
  final Widget child;
  final Size size;

  const ChessPicture({super.key, required this.size, required this.child});

  @override
  Widget build(BuildContext context) {
    return FractionalTranslation(
              translation: const Offset(-0.5, -0.5),
              child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: child
              ),
            );
      }
}
