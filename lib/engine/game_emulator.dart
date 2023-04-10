part of 'c_engine_api.dart';

void _updateCastlePerm(int pieceToMove, int from, ChessGameState state) {
  if (state.castlingPerm == 0) return;
  bool kingWhiteRookHasMoved = false;
  bool queenWhiteRookHasMoved = false;
  bool kingBlackRookHasMoved = false;
  bool queenBlackRookHasMoved = false;
  bool whiteKingHasMoved = false;
  bool blackKingHasMoved = false;

  // We are assuming that the game has started from the beginning

  if (pieceToMove == (PIECE.WHITE | PIECE.ROOK)) {
    if (from == 63) {
      kingWhiteRookHasMoved = true;
    } else if (from == 56) {
      queenWhiteRookHasMoved = true;
    }
  } else if (pieceToMove == (PIECE.BLACK | PIECE.ROOK)) {
    if (from == 7) {
      kingBlackRookHasMoved = true;
    } else if (from == 0) {
      queenBlackRookHasMoved = true;
    }
  } else if (pieceToMove == (PIECE.WHITE | PIECE.KING)) {
    whiteKingHasMoved = true;
  } else if (pieceToMove == (PIECE.BLACK | PIECE.KING)) {
    blackKingHasMoved = true;
  }

  if (whiteKingHasMoved) {
    state.castlingPerm &= 3; // The white king cannot caste (3 0b0011)
  }
  if (blackKingHasMoved) {
    state.castlingPerm &= 12; // The black king cannot castle (12 0b1100)
  }
  if (kingWhiteRookHasMoved) {
    state.castlingPerm &= 7; // Removing white king side (7 0b0111)
  }
  if (queenWhiteRookHasMoved) {
    state.castlingPerm &= 11; // Removing white queen side (11 0b1011)
  }
  if (kingBlackRookHasMoved) {
    state.castlingPerm &= 13; // Removing black king side (13 0b1101)
  }
  if (queenBlackRookHasMoved) {
    state.castlingPerm &= 14; // Removing black queen side (14 0b1110)
  }
}

void _updateFiftyFiftyMove(int pieceToMove, int to, ChessGameState state) {
  if ((pieceToMove & _pieceTypeBitMask) == PIECE.PAWN) {
    state.turnsForFiftyRule = 0; // A pawn has moved
  } else if (state.boardArray[to] != PIECE.NONE) {
    state.turnsForFiftyRule = 0; // There has been a capture
  }
}

void _makeMove(ChessMove move, ChessGameState state) {
  int from = move.startSquare;
  int to = move.endSquare;
  MoveFlag flag = move.flag;

  int pieceToMove = state.boardArray[from];
  _updateCastlePerm(pieceToMove, from, state);
  _updateFiftyFiftyMove(pieceToMove, to, state);

  state.boardArray[from] = PIECE.NONE;
  state.boardArray[to] = pieceToMove;
  int rookIndex;
  int rookPiece;
  int enPassantTargetSquare;
  int pawnIndex;
  switch (flag) {
    case MoveFlag.NOFlAG:
      // Just for completeness
      break;
    case MoveFlag.EN_PASSANT:
      pawnIndex = state.colorToGo == PIECE.WHITE ? to + 8 : to - 8;
      state.boardArray[pawnIndex] = PIECE.NONE;
      break;
    case MoveFlag.DOUBLE_PAWN_PUSH:
      enPassantTargetSquare = state.colorToGo == PIECE.WHITE ? to + 8 : to - 8;
      state.enPassantTargetSquare = enPassantTargetSquare;
      break;
    case MoveFlag.KING_SIDE_CASTLING:
      rookIndex = from + 3;
      rookPiece = state.boardArray[rookIndex];
      state.boardArray[rookIndex] = PIECE.NONE;
      state.boardArray[to - 1] = rookPiece;
      break;
    case MoveFlag.QUEEN_SIDE_CASTLING:
      rookIndex = from - 4;
      rookPiece = state.boardArray[rookIndex];
      state.boardArray[rookIndex] = PIECE.NONE;
      state.boardArray[to + 1] = rookPiece;
      break;
    case MoveFlag.PROMOTE_TO_QUEEN:
      state.boardArray[to] = state.colorToGo | PIECE.QUEEN;
      break;
    case MoveFlag.PROMOTE_TO_KNIGHT:
      state.boardArray[to] = state.colorToGo | PIECE.KNIGHT;
      break;
    case MoveFlag.PROMOTE_TO_ROOK:
      state.boardArray[to] = state.colorToGo | PIECE.ROOK;
      break;
    case MoveFlag.PROMOTE_TO_BISHOP:
      state.boardArray[to] = state.colorToGo | PIECE.BISHOP;
      break;
    default:
      throw ArgumentError("ERROR: Invalid flag $flag");
  }
  state.colorToGo = state.colorToGo == PIECE.WHITE ? PIECE.BLACK : PIECE.WHITE;
  if (flag != MoveFlag.DOUBLE_PAWN_PUSH && state.enPassantTargetSquare != -1) {
    state.enPassantTargetSquare = -1;
  }
  state.turnsForFiftyRule++; // Augmenting every half-move
  if (state.colorToGo == PIECE.WHITE) {
    state.nbMoves++; // Only recording full moves
  }
}
