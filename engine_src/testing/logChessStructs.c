#include <stdio.h>
#include "../src/moveGenerator.h"
#include "logChessStructs.h"

void printMove(unsigned short move) {
    printf("Original Square: %d, Target Square: %d, Flag: %d\n", 
      move & 0b111111,
      (move >> 6) & 0b111111,
      (move >> 12)
    );
}

void printMoveToAlgebraic(unsigned short move) {
  int from = move & 0b111111;
  int to = (move >> 6) & 0b111111;
  char algebraic[5];
  int row1 = from / 8;
  int col1 = from % 8;
  algebraic[0] = 'a' + col1;
  algebraic[1] = '1' + (7 - row1);
  int row2 = to / 8;
  int col2 = to % 8;
  algebraic[2] = 'a' + col2;
  algebraic[3] = '1' + (7 - row2);
  algebraic[4] = '\0';
  printf("%s", algebraic);
}

void printBoard(int board[BOARD_SIZE]) {
  for (int i = 0; i < BOARD_SIZE; i++) {
    int pieceAtPosition = board[i];
    printf("[%d%s]", pieceAtPosition, pieceAtPosition / 10 == 0 ? " " : "");
    printf((i + 1) % 8 == 0 ? "\n" : " ");
  }
}