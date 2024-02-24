library chess_engine;

import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';

export 'chess_engine.dart'
    show
        ChessEngine,
        ChessGameData,
        ChessPositionData,
        ChessPiece,
        ChessMove,
        MoveFlag,
        PieceColor,
        PieceUtility,
        ChessGameUtility,
        ChessPositionUtility;

part 'c_engine_api.dart';
part 'c_engine_ffi.dart';
// part of 'chess_engine.dart'; // Line added by EJRP

