#include <stdio.h>
#include <stdbool.h>
#include "chessGameEmulator.h"

void updateCastlePerm(int pieceToMove, int from, GameState* state) {
  bool kingWhiteRookHasMoved = false;
  bool queenWhiteRookHasMoved = false;
  bool kingBlackRookHasMoved = false;
  bool queenBlackRookHasMoved = false;
  bool whiteKingHasMoved = false;
  bool blackKingHasMoved = false;
  if (state->castlinPerm == 0) return;
  if (pieceToMove == (WHITE | ROOK)) {
    if (from == 63) {
      kingWhiteRookHasMoved = true;
    } else if (from == 56) {
      queenWhiteRookHasMoved = true;
    }
  } else if (pieceToMove == (BLACK | ROOK)) {
    if (from == 7) {
      kingBlackRookHasMoved = true;
    } else if (from == 0) {
      queenBlackRookHasMoved = true;
    }
  } else if (pieceToMove == (WHITE | KING)) {
    whiteKingHasMoved = true;
  } else if (pieceToMove == (BLACK | KING)) {
    blackKingHasMoved = true;
  }
  if (whiteKingHasMoved) {
    state->castlinPerm &= 0b0011; // The white king castling perm is none existant
  }
  if (blackKingHasMoved) {
    state->castlinPerm &= 0b1100; // The black king castling perm is none existant
  }
  if (kingWhiteRookHasMoved) {
    state->castlinPerm &= 0b0111; // Removing white king side
  }
  if (queenWhiteRookHasMoved) {
    state->castlinPerm &= 0b1011; // Removing white queen side
  }
  if (kingBlackRookHasMoved) {
    state->castlinPerm &= 0b1101; // Removing black king side
  }
  if (queenBlackRookHasMoved) {
    state->castlinPerm &= 0b1110; // Removing black queen side
  }    
}

void updateFiftyFiftyMove(int pieceToMove, int to, GameState* state) {
  if ((pieceToMove & pieceTypeBitMask) == PAWN) {
    state->turnsForFiftyRule = 0; // A pawn has moved
  } else if (state->boardArray[to] != NONE) {
    state->turnsForFiftyRule = 0; // There has been a capture
  }
}

void makeMove(unsigned short move, GameState* state) {
  int from = move & 0b111111;
  int to = (move >> 6) & 0b111111;
  int flag = (move >> 12);
  int pieceToMove = state->boardArray[from];
  updateCastlePerm(pieceToMove, from, state);
  updateFiftyFiftyMove(pieceToMove, to, state);

  state->boardArray[from] = NONE;
  if (state->boardArray[to] != NONE) {
    state->turnsForFiftyRule++;
  }
  state->boardArray[to] = pieceToMove;
  int rookIndex;
  int rookPiece;
  int enPassantTargetSquare;
  int pawnIndex;
  switch (flag) {
  case NOFlAG:
    // Just for completeness
    break;
  case EN_PASSANT:
    pawnIndex = state->colorToGo == WHITE ? to + 8 : to - 8;
    state->boardArray[pawnIndex] = NONE;
    break;
  case DOUBLE_PAWN_PUSH:
    enPassantTargetSquare = state->colorToGo == WHITE ? to + 8 : to - 8;
    state->enPassantTargetSquare = enPassantTargetSquare;
    break;
  case KING_SIDE_CASTLING:
    rookIndex = from + 3;
    rookPiece = state->boardArray[rookIndex];
    state->boardArray[rookIndex] = NONE;
    state->boardArray[to - 1] = rookPiece;
    break;
  case QUEEN_SIDE_CASTLING:
    rookIndex = from - 4;
    rookPiece = state->boardArray[rookIndex];
    state->boardArray[rookIndex] = NONE;
    state->boardArray[to + 1] = rookPiece;
    break;
  case PROMOTE_TO_QUEEN: 
    state->boardArray[to] = state->colorToGo | QUEEN;
    break;
  case PROMOTE_TO_KNIGHT: 
    state->boardArray[to] = state->colorToGo | KNIGHT;
    break;
  case PROMOTE_TO_ROOK: 
    state->boardArray[to] = state->colorToGo | ROOK;
    break;
  case PROMOTE_TO_BISHOP: 
    state->boardArray[to] = state->colorToGo | BISHOP;
    break;
  default:
    printf("ERROR: Invalid flag %d\n", flag);
    return;
  }
  state->colorToGo = state->colorToGo == WHITE ? BLACK : WHITE;
  if (flag != DOUBLE_PAWN_PUSH && state->enPassantTargetSquare != -1) {
    state->enPassantTargetSquare = -1;
  }
  state->turnsForFiftyRule++;
  state->nbMoves++;
}