#ifndef MOVEGENERATOR_H
#define MOVEGENERATOR_H

#define BOARD_SIZE 64

/**
* This is a dynamic array of integers. You can use the 
* da_append macro to append integer to this list
*/
typedef struct intList {
    int* items;
    size_t count;
    size_t capacity;
} IntList;

/** 
 * Dynamic array of moves
 * The structure is copied from Sebastian Lague chess program
 * A move is a 16 bit number
 * bit 0-5: from square (0 to 63)
 * bit 6-11: to square (0 to 63)
 * bit 12-15: flag
 */
typedef struct moves {
    unsigned short* items;
    size_t count;
    size_t capacity;
} Moves;

typedef struct gameState {
    int* boardArray;
    int colorToGo, 
        castlinPerm, // The first bit is for white king side, second bit is for white queen side and pattern continues but for black
        enPassantTargetSquare, 
        turnsForFiftyRule, 
        nbMoves;
} GameState;

enum Flag {
    NOFlAG,
    EN_PASSANT,
    DOUBLE_PAWN_PUSH,
    KING_SIDE_CASTLING,
    QUEEN_SIDE_CASTLING,
    PROMOTE_TO_QUEEN,
    PROMOTE_TO_KNIGHT,
    PROMOTE_TO_ROOK,
    PROMOTE_TO_BISHOP,
    STALEMATE,
    CHECKMATE
};

// First 2 bits are for the color
// Last 3 bits are for the type
enum PIECE {
    NONE   = 0, 
    KING   = 1, 
    QUEEN  = 2, 
    KNIGHT = 3, 
    BISHOP = 4, 
    ROOK   = 5, 
    PAWN   = 6, 
            
    WHITE  = 8, 
    BLACK  = 16
};

#define pieceColorBitMask 0b11000
#define pieceTypeBitMask 0b111

// Copy and pasted from https://github.com/tsoding/ded/blob/master/src/common.h#L34
#define DA_INIT_CAP 256
#define da_append(da, item)                                                          \
    do {                                                                             \
        if ((da)->count >= (da)->capacity) {                                         \
            (da)->capacity = (da)->capacity == 0 ? DA_INIT_CAP : (da)->capacity*2;   \
            (da)->items = realloc((da)->items, (da)->capacity*sizeof(*(da)->items)); \
            assert((da)->items != NULL && "Buy more RAM lol");                       \
        }                                                                            \
                                                                                     \
        (da)->items[(da)->count++] = (item);                                         \
    } while (0)

Moves* getValidMoves(GameState* gameState);

GameState* createState(
    int *boardArray,
    int colorToGo, 
    int castlinPerm, 
    int enPassantTargetSquare, 
    int turnsForFiftyRule, 
    int nbMoves
);

#endif