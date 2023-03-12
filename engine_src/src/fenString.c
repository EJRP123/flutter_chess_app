#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include "fenString.h"

int getCastlingPermFromFenString(char* fen) {
    int result = 0;
    if (strcmp(fen,"-") == 0) return result;
    for (int i = 0; i < strlen(fen); i++) {
        char c = fen[i];
        if (c == 'K') {
            result |= (1 << 3);
        } else if (c == 'Q') {
            result |= (1 << 2);
        } else if (c == 'k') {
            result |= (1 << 1);
        } else if (c == 'q') {
            result |= (1 << 0);
        }
    }
    return result;
}

void setBoardArrayFromFenString(char *fen, int *board) {
  int row = 0, col = 0;
  for (int i = 0; i < strlen(fen); i++) {
    char fenChar = fen[i];
    if (fenChar == '/') {
      row++;
      col = 0;
    } else if (fenChar >= '1' && fenChar <= '8') {
      int emptySquares = fenChar - '0';
      for (int j = 0; j < emptySquares; j++) {
        board[row * 8 + col] = NONE;
        col++;
      }
    } else {
      switch (fenChar) {
        case 'P':
          board[row * 8 + col] = WHITE | PAWN;
          break;
        case 'N':
          board[row * 8 + col] = WHITE | KNIGHT;
          break;
        case 'B':
          board[row * 8 + col] = WHITE | BISHOP;
          break;
        case 'R':
          board[row * 8 + col] = WHITE | ROOK;
          break;
        case 'Q':
          board[row * 8 + col] = WHITE | QUEEN;
          break;
        case 'K':
          board[row * 8 + col] = WHITE | KING;
          break;
        case 'p':
          board[row * 8 + col] = BLACK | PAWN;
          break;
        case 'n':
          board[row * 8 + col] = BLACK | KNIGHT;
          break;
        case 'b':
          board[row * 8 + col] = BLACK | BISHOP;
          break;
        case 'r':
          board[row * 8 + col] = BLACK | ROOK;
          break;
        case 'q':
          board[row * 8 + col] = BLACK | QUEEN;
          break;
        case 'k':
          board[row * 8 + col] = BLACK | KING;
          break;
      }
      col++;
    }
  }
}

int convertSquareToIndex(char* square) {
    if (strcmp(square,"-") == 0) return -1;
    int file = square[0] - 'a';
    int rank = 8 - (square[1] - '0');
    return rank * 8 + file;
}

#define splitString \
do { \
    split = strtok(NULL, " "); \
    if (split == NULL) { printf("Invalid fen string!\n"); return NULL; } \
} while (0);

GameState* setGameStateFromFenString(char *fen, GameState* result) {
    if (result == NULL) result = malloc(sizeof(GameState));
    assert(result != NULL && "Buy more RAM lol");
    char copy[100];
    strcpy(copy, fen);
    char* split = strtok(copy, " ");
    int* boardArray = (int*) malloc(sizeof(int) * BOARD_SIZE);
    setBoardArrayFromFenString(split, boardArray);
    result->boardArray = boardArray; 
    splitString;
    result->colorToGo = (strcmp(split, "w") == 0) ? WHITE : BLACK;
    splitString;
    result->castlinPerm = getCastlingPermFromFenString(split);
    splitString;
    result->enPassantTargetSquare = convertSquareToIndex(split);
    splitString;
    result->nbMoves = (int) strtol(split, NULL, 10);
    splitString;
    result->turnsForFiftyRule = (int) strtol(split, NULL, 10);
    return result;
}