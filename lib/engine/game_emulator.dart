part of 'c_engine_api.dart';

void _updateCastlePerm(Piece pieceToMove, int from, ChessGameState state) {
  if (state.castlingPerm == 0) return;
  bool kingWhiteRookHasMoved = false;
  bool queenWhiteRookHasMoved = false;
  bool kingBlackRookHasMoved = false;
  bool queenBlackRookHasMoved = false;
  bool whiteKingHasMoved = false;
  bool blackKingHasMoved = false;

  // We are assuming that the game has started from the beginning

  if (pieceToMove == Piece(PieceColor.white, PieceType.rook)) {
    if (from == 63) {
      kingWhiteRookHasMoved = true;
    } else if (from == 56) {
      queenWhiteRookHasMoved = true;
    }
  } else if (pieceToMove == Piece(PieceColor.black, PieceType.rook)) {
    if (from == 7) {
      kingBlackRookHasMoved = true;
    } else if (from == 0) {
      queenBlackRookHasMoved = true;
    }
  } else if (pieceToMove == Piece(PieceColor.white, PieceType.king)) {
    whiteKingHasMoved = true;
  } else if (pieceToMove == Piece(PieceColor.black, PieceType.king)) {
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

void _updateFiftyFiftyMove(Piece pieceToMove, int to, ChessGameState state) {
  if (pieceToMove.type == PieceType.pawn) {
    state.turnsForFiftyRule = 0; // A pawn has moved
  } else if (state.boardArray[to] != Piece.none) {
    state.turnsForFiftyRule = 0; // There has been a capture
  }
}

void _makeMove(ChessMove move, ChessGameState state) {
  int from = move.startSquare;
  int to = move.endSquare;
  MoveFlag flag = move.flag;

  Piece pieceToMove = state.boardArray[from];
  _updateCastlePerm(pieceToMove, from, state);
  _updateFiftyFiftyMove(pieceToMove, to, state);

  state.boardArray[from] = Piece.none;
  state.boardArray[to] = pieceToMove;
  int rookIndex;
  Piece rookPiece;
  int enPassantTargetSquare;
  int pawnIndex;
  switch (flag) {
    case MoveFlag.noFlag:
      // Just for completeness
      break;
    case MoveFlag.enPassant:
      pawnIndex = state.colorToGo == PieceColor.white ? to + 8 : to - 8;
      state.boardArray[pawnIndex] = Piece.none;
      break;
    case MoveFlag.doublePawnPush:
      enPassantTargetSquare = state.colorToGo == PieceColor.white ? to + 8 : to - 8;
      state.enPassantTargetSquare = enPassantTargetSquare;
      break;
    case MoveFlag.kingSideCastling:
      rookIndex = from + 3;
      rookPiece = state.boardArray[rookIndex];
      state.boardArray[rookIndex] = Piece.none;
      state.boardArray[to - 1] = rookPiece;
      break;
    case MoveFlag.queenSideCastling:
      rookIndex = from - 4;
      rookPiece = state.boardArray[rookIndex];
      state.boardArray[rookIndex] = Piece.none;
      state.boardArray[to + 1] = rookPiece;
      break;
    case MoveFlag.promoteToQueen:
      state.boardArray[to] = Piece(state.colorToGo, PieceType.queen);
      break;
    case MoveFlag.promoteToKnight:
      state.boardArray[to] = Piece(state.colorToGo, PieceType.knight);
      break;
    case MoveFlag.promoteToRook:
      state.boardArray[to] = Piece(state.colorToGo, PieceType.rook);
      break;
    case MoveFlag.promoteToBishop:
      state.boardArray[to] = Piece(state.colorToGo, PieceType.bishop);
      break;
    default:
      throw ArgumentError("ERROR: Invalid flag $flag");
  }
  state.colorToGo = state.colorToGo.oppositeColor;
  if (flag != MoveFlag.doublePawnPush && state.enPassantTargetSquare != -1) {
    state.enPassantTargetSquare = -1;
  }
  state.turnsForFiftyRule++; // Augmenting every half-move
  if (state.colorToGo == PieceColor.white) {
    state.nbMoves++; // Only recording full moves
  }
}
