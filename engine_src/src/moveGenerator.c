// This file is a port to C of this file from Sebastian Lague
// https://github.com/SebLague/Chess-AI/blob/main/Assets/Scripts/Core/MoveGenerator.cs
#include <math.h>
#include <assert.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include "moveGenerator.h"

#define BOARD_LENGTH 8

GameState* state;

int opponentColor;
int friendlyKingIndex;

// For O(1) .contains call
// Global variables are zero initialize so no need for {0}
bool* attackedSquares;
bool* doubleAttackedSquares;
bool* protectKingSquares;

// So that we don't need to recalculate the piece potential valid moves
IntList** isPieceAtLocationPinned;

bool inDoubleCheck;
bool inCheck;

GameState* createState(
    int *boardArray,
    int colorToGo, 
    int castlinPerm, 
    int enPassantTargetSquare, 
    int turnsForFiftyRule, 
    int nbMoves
) {
    GameState* result = malloc(sizeof(GameState));
    result->boardArray = malloc(sizeof(int) * BOARD_SIZE);
    for (int i = 0; i < BOARD_SIZE; i++) {
        result->boardArray[i] = boardArray[i];
    }
    result->castlinPerm = castlinPerm;
    result->colorToGo = colorToGo;
    result->enPassantTargetSquare = enPassantTargetSquare;
    result->nbMoves = nbMoves;
    result->turnsForFiftyRule = turnsForFiftyRule;
    return result;
}

void resetRayResult(int ray[BOARD_LENGTH]) {
    for (int i = 0; i < BOARD_LENGTH; i++) {
        ray[i] = -1;
    }
}

void appendIntListToAttackedSquare(int src[BOARD_LENGTH]) {
    // Assuming that the items of the src are in the range of the index of the dest
    for (int i = 0; i < BOARD_LENGTH; i++) {
        int square = src[i];
        if (square == -1) { continue; }
        if (attackedSquares[square]) {
            doubleAttackedSquares[square] = true; // To find double checks
        }
        attackedSquares[square] = true;
    }
}

void appendMove(int startSquare, int targetSquare, int flag, Moves* validMoves) {
    unsigned short move = startSquare;
    move |= (targetSquare << 6);
    move |= (flag << 12);
    da_append(validMoves, move);
}

void getTopRightNetRay(int currentIndex, int colorToNotInclude, int result[BOARD_LENGTH]) {
    if (currentIndex % 8 == 7) return;
    int count = 0;
    for (int i = currentIndex - 7; i >= 0; i -= 7) {
        result[count++] = i;
        if (i % 8 == 7 || state->boardArray[i] != NONE) {
            if (colorToNotInclude != 0 && (state->boardArray[i] & pieceColorBitMask) == colorToNotInclude) {
                result[count - 1] = -1; // This is remove the last item of the array
            }
            return; // We are at the right end of the board
        }
    }
    return;
}

void getTopLeftNetRay(int currentIndex, int colorToNotInclude, int result[BOARD_LENGTH]) {
    if (currentIndex % 8 == 0) return; 
    int count = 0;
    for (int i = currentIndex - 9; i >= 0; i -= 9) {
        result[count++] = i;
        if (i % 8 == 0 || state->boardArray[i] != NONE) {
            if (colorToNotInclude != 0 && (state->boardArray[i] & pieceColorBitMask) == colorToNotInclude) {
                result[count - 1] = -1; // This is remove the last item of the array
            }
            break; // We are at the left end of the board or hit an ennemy piece
        }
    }
    return;
}

void getBottomLeftNetRay(int currentIndex, int colorToNotInclude, int result[BOARD_LENGTH]) {
    if (currentIndex % 8 == 0) return;
    int count = 0;
    for (int i = currentIndex + 7; i <= 63; i += 7) {
        result[count++] = i;
        if (i % 8 == 0 || state->boardArray[i] != NONE) {
            if (colorToNotInclude != 0 && (state->boardArray[i] & pieceColorBitMask) == colorToNotInclude) {
                result[count - 1] = -1; // This is remove the last item of the array
            }
            break; // We are at the left end of the board or hit an ennemy piece
        }
    }
    return;
}

void getBottomRightNetRay(int currentIndex, int colorToNotInclude, int result[BOARD_LENGTH]) {
    if (currentIndex % 8 == 7) return;
    int count = 0;
    for (int i = currentIndex + 9; i <= 63; i += 9) {
        result[count++] = i;
        if (i % 8 == 7 || state->boardArray[i] != NONE) {
            if (colorToNotInclude != 0 && (state->boardArray[i] & pieceColorBitMask) == colorToNotInclude) {
                result[count - 1] = -1; // This is remove the last item of the array
            }
            break; // We are at the right end of the board of hit an ennemy piece
        }
    }
    return;
}

void getTopNetRay(int currentIndex, int colorToNotInclude, int result[BOARD_LENGTH]) {
    if (currentIndex / 8 == 0) return;
    int count = 0;
    for (int i = currentIndex - 8; i >= 0; i -= 8) {
        result[count++] = i;
        if (i / 8 == 0 || state->boardArray[i] != NONE) {
            if (colorToNotInclude != 0 && (state->boardArray[i] & pieceColorBitMask) == colorToNotInclude) {
                result[count - 1] = -1; // This is remove the last item of the array
            }    
            break; // We are at the beginning row of the board of hit an ennemy piece
        }
    }
    return;
}

void getBottomNetRay(int currentIndex, int colorToNotInclude, int result[BOARD_LENGTH]) {
    if (currentIndex / 8 == 7) return;
    int count = 0;
    for (int i = currentIndex + 8; i <= 63; i += 8) {
        result[count++] = i;
        if (i / 8 == 7 || state->boardArray[i] != NONE) {
            if (colorToNotInclude != 0 && (state->boardArray[i] & pieceColorBitMask) == colorToNotInclude) {
                result[count - 1] = -1; // This is remove the last item of the array
            }  
            break; // We are at the end row of the board of hit an ennemy piece
        }
    }
    return;
}

void getRightNetRay(int currentIndex, int colorToNotInclude, int result[BOARD_LENGTH]) {
    if (currentIndex % 8 == 7) return;
    int count = 0;
    for (int i = currentIndex + 1; i <= 63; i++) {
        result[count++] = i;
        if (i % 8 == 7 || state->boardArray[i] != NONE) {
            if (colorToNotInclude != 0 && (state->boardArray[i] & pieceColorBitMask) == colorToNotInclude) {
                result[count - 1] = -1; // This is remove the last item of the array
            }  
            break; // We are at the right end of the board of hit an ennemy piece
        }
    }
    return;
}

void getLeftNetRay(int currentIndex, int colorToNotInclude, int result[BOARD_LENGTH]) {
    if (currentIndex % 8 == 0) return;
    int count = 0;
    for (int i = currentIndex - 1; i >= 0; i--) {
        result[count++] = i;
        if (i % 8 == 0 || state->boardArray[i] != NONE) {
            if (colorToNotInclude != 0 && (state->boardArray[i] & pieceColorBitMask) == colorToNotInclude) {
                result[count - 1] = -1; // This is remove the last item of the array
            }  
            break; // We are at the left end of the board of hit an ennemy piece
        }
    }
    return;
}

bool isIndexValidForKnight(int currentIndex, int targetSquare, bool goDownOne) {
    int y = targetSquare / 8;
    bool wrappingCondition = (goDownOne) ? 
        abs(currentIndex / 8 - y) == 1 : 
        abs(currentIndex / 8 - y) == 2;
    return targetSquare >= 0 && targetSquare <= 63 && wrappingCondition;
}

void appendIntToList(IntList* list, int item) {
    list->count++;
    list->items[list->count] = item;
}

int* getKnightMoves(int currentIndex, int result[BOARD_LENGTH]) {
    int counter = 0;
    if (isIndexValidForKnight(currentIndex, currentIndex - 6 , true )) result[counter++] = currentIndex - 6 ;
    if (isIndexValidForKnight(currentIndex, currentIndex - 10, true )) result[counter++] = currentIndex - 10;
    if (isIndexValidForKnight(currentIndex, currentIndex - 15, false)) result[counter++] = currentIndex - 15;
    if (isIndexValidForKnight(currentIndex, currentIndex - 17, false)) result[counter++] = currentIndex - 17;
    if (isIndexValidForKnight(currentIndex, currentIndex + 6 , true )) result[counter++] = currentIndex + 6 ;
    if (isIndexValidForKnight(currentIndex, currentIndex + 10, true )) result[counter++] = currentIndex + 10;
    if (isIndexValidForKnight(currentIndex, currentIndex + 15, false)) result[counter++] = currentIndex + 15;
    if (isIndexValidForKnight(currentIndex, currentIndex + 17, false)) result[counter++] = currentIndex + 17;
} 

int* getPawnAttackingSquares(int currentIndex, int color, int result[2]) {
    int counter = 0;
    int forwardIndex = color == WHITE ? currentIndex - 8 : currentIndex + 8;
    if (forwardIndex < 0 || forwardIndex > 63) { return result; }
    if (forwardIndex % 8 != 7) { result[counter++] = forwardIndex + 1; }
    if (forwardIndex % 8 != 0) { result[counter++] = forwardIndex - 1; }
    return result;
}

int* getKingMoves(int currentIndex, int result[BOARD_LENGTH]) {
    int counter = 0;
    if (currentIndex % 8 != 0 && currentIndex / 8 != 0) { result[counter++] = currentIndex - 9; }
    if (currentIndex / 8 != 0                         ) { result[counter++] = currentIndex - 8; }
    if (currentIndex % 8 != 7 && currentIndex / 8 != 0) { result[counter++] = currentIndex - 7; }
    if (currentIndex % 8 != 0                         ) { result[counter++] = currentIndex - 1; }
    if (currentIndex % 8 != 7                         ) { result[counter++] = currentIndex + 1; }
    if (currentIndex % 8 != 0 && currentIndex / 8 != 7) { result[counter++] = currentIndex + 7; }
    if (currentIndex / 8 != 7                         ) { result[counter++] = currentIndex + 8; }
    if (currentIndex % 8 != 7 && currentIndex / 8 != 7) { result[counter++] = currentIndex + 9; }
}

bool isIndexPseudoLegalForKnight(int currentIndex, int targetSquare, bool goDownOne) {
    int y = targetSquare / 8;
    bool wrappingCondition = (goDownOne) ? 
        abs(currentIndex / 8 - y) == 1 : 
        abs(currentIndex / 8 - y) == 2;
    if (targetSquare < 0 || targetSquare > 63 || !wrappingCondition) return false;
    return (state->boardArray[targetSquare] & pieceColorBitMask) != state->colorToGo;
}

void getKnightPseudoLegalMoves(int currentIndex, int result[BOARD_LENGTH]) {
    int counter = 0;
    if (isIndexPseudoLegalForKnight(currentIndex, currentIndex - 6 , true )) result[counter++] = currentIndex - 6 ;
    if (isIndexPseudoLegalForKnight(currentIndex, currentIndex - 15, false)) result[counter++] = currentIndex - 15;
    if (isIndexPseudoLegalForKnight(currentIndex, currentIndex - 10, true )) result[counter++] = currentIndex - 10;
    if (isIndexPseudoLegalForKnight(currentIndex, currentIndex - 17, false)) result[counter++] = currentIndex - 17;
    if (isIndexPseudoLegalForKnight(currentIndex, currentIndex + 6 , true )) result[counter++] = currentIndex + 6 ;
    if (isIndexPseudoLegalForKnight(currentIndex, currentIndex + 10, true )) result[counter++] = currentIndex + 10;
    if (isIndexPseudoLegalForKnight(currentIndex, currentIndex + 15, false)) result[counter++] = currentIndex + 15;
    if (isIndexPseudoLegalForKnight(currentIndex, currentIndex + 17, false)) result[counter++] = currentIndex + 17;
} 

void init() {
    opponentColor = state->colorToGo == WHITE ? BLACK : WHITE;
    friendlyKingIndex = -1;
    inCheck = false;
    inDoubleCheck = false;
    attackedSquares = malloc(sizeof(bool) * BOARD_SIZE);
    doubleAttackedSquares = malloc(sizeof(bool) * BOARD_SIZE);
    protectKingSquares = malloc(sizeof(bool) * BOARD_SIZE);
    isPieceAtLocationPinned = malloc(sizeof(IntList*) * BOARD_SIZE);
    memset(attackedSquares, false, sizeof(bool) * BOARD_SIZE);
    memset(doubleAttackedSquares, false, sizeof(bool) * BOARD_SIZE);
    memset(protectKingSquares, false, sizeof(bool) * BOARD_SIZE);
    for (int i = 0; i < BOARD_SIZE; i++) {
        isPieceAtLocationPinned[i] = NULL;
    }
}

void extendRayIfCheckKing(
    int ray[BOARD_LENGTH], 
    void (*getRay)(int index, int colorNotToInclude, int result[BOARD_LENGTH])) {
    if (ray[0] == 0) return;
    int lastIndex = -1;
    for (int i = 0; i < 8; i++) {
        if (ray[i + 1] == -1) { 
            lastIndex = ray[i];
            break;
        }
    }
    if (lastIndex == -1) return;
    int lastIndexPiece = state->boardArray[lastIndex];
    if (lastIndexPiece != (state->colorToGo | KING)) return;
    // King is in check by this piece and we need to generate the square behind the king
    int newRay[BOARD_LENGTH] = { -1, -1, -1, -1, -1, -1, -1, -1 };
    getRay(lastIndex, 0, newRay);
    appendIntListToAttackedSquare(newRay);
}

void calculateAttackSquares() {
    int attackingSquares[BOARD_LENGTH] = { -1, -1, -1, -1, -1, -1, -1, -1 };
    for (int currentIndex = 0; currentIndex < BOARD_SIZE; currentIndex++) {
        const int piece = state->boardArray[currentIndex];
        if (piece == NONE) continue;
        if ((piece & pieceColorBitMask) != opponentColor) {
            if ((piece & pieceTypeBitMask) == KING) {
                friendlyKingIndex = currentIndex;
            }
            continue;
        }
        switch (piece & pieceTypeBitMask) {
        // Note: The 0 means that if the ray stops at a piece it will include it, regarless of its color
        case ROOK: 
            getTopNetRay(currentIndex, 0, attackingSquares);
            extendRayIfCheckKing(attackingSquares, getTopNetRay);
            appendIntListToAttackedSquare(attackingSquares);
            resetRayResult(attackingSquares);

            getBottomNetRay(currentIndex, 0, attackingSquares);
            extendRayIfCheckKing(attackingSquares, getBottomNetRay);
            appendIntListToAttackedSquare(attackingSquares);
            resetRayResult(attackingSquares);

            getRightNetRay(currentIndex, 0, attackingSquares);
            extendRayIfCheckKing(attackingSquares, getRightNetRay);
            appendIntListToAttackedSquare(attackingSquares);
            resetRayResult(attackingSquares);

            getLeftNetRay(currentIndex, 0, attackingSquares);
            extendRayIfCheckKing(attackingSquares, getLeftNetRay);
            appendIntListToAttackedSquare(attackingSquares);
            resetRayResult(attackingSquares);
            break;
        
        case BISHOP:
            getTopRightNetRay(currentIndex, 0, attackingSquares);
            extendRayIfCheckKing(attackingSquares, getTopRightNetRay);
            appendIntListToAttackedSquare(attackingSquares);
            resetRayResult(attackingSquares);

            getTopLeftNetRay(currentIndex, 0, attackingSquares);
            extendRayIfCheckKing(attackingSquares, getTopLeftNetRay);
            appendIntListToAttackedSquare(attackingSquares);
            resetRayResult(attackingSquares);

            getBottomRightNetRay(currentIndex, 0, attackingSquares);
            extendRayIfCheckKing(attackingSquares, getBottomRightNetRay);
            appendIntListToAttackedSquare(attackingSquares);
            resetRayResult(attackingSquares);

            getBottomLeftNetRay(currentIndex, 0, attackingSquares);
            extendRayIfCheckKing(attackingSquares, getBottomLeftNetRay);
            appendIntListToAttackedSquare(attackingSquares);
            resetRayResult(attackingSquares);
            break;
        case QUEEN:
            getTopNetRay(currentIndex, 0, attackingSquares);
            extendRayIfCheckKing(attackingSquares, getTopNetRay);
            appendIntListToAttackedSquare(attackingSquares);
            resetRayResult(attackingSquares);
            
            getBottomNetRay(currentIndex, 0, attackingSquares);
            extendRayIfCheckKing(attackingSquares, getBottomNetRay);
            appendIntListToAttackedSquare(attackingSquares);
            resetRayResult(attackingSquares);

            getRightNetRay(currentIndex, 0, attackingSquares);
            extendRayIfCheckKing(attackingSquares, getRightNetRay);
            appendIntListToAttackedSquare(attackingSquares);
            resetRayResult(attackingSquares);

            getLeftNetRay(currentIndex, 0, attackingSquares);
            extendRayIfCheckKing(attackingSquares, getLeftNetRay);
            appendIntListToAttackedSquare(attackingSquares);
            resetRayResult(attackingSquares);

            getTopRightNetRay(currentIndex, 0, attackingSquares);
            extendRayIfCheckKing(attackingSquares, getTopRightNetRay);
            appendIntListToAttackedSquare(attackingSquares);
            resetRayResult(attackingSquares);

            getTopLeftNetRay(currentIndex, 0, attackingSquares);
            extendRayIfCheckKing(attackingSquares, getTopLeftNetRay);
            appendIntListToAttackedSquare(attackingSquares);
            resetRayResult(attackingSquares);

            getBottomRightNetRay(currentIndex, 0, attackingSquares);
            extendRayIfCheckKing(attackingSquares, getBottomRightNetRay);
            appendIntListToAttackedSquare(attackingSquares);
            resetRayResult(attackingSquares);

            getBottomLeftNetRay(currentIndex, 0, attackingSquares);
            extendRayIfCheckKing(attackingSquares, getBottomLeftNetRay);
            appendIntListToAttackedSquare(attackingSquares);
            resetRayResult(attackingSquares);
            break;
        case KNIGHT:
            getKnightMoves(currentIndex, attackingSquares);
            appendIntListToAttackedSquare(attackingSquares);
            resetRayResult(attackingSquares);
            break;
        case PAWN:
            getPawnAttackingSquares(currentIndex, opponentColor, attackingSquares);
            appendIntListToAttackedSquare(attackingSquares);
            resetRayResult(attackingSquares);
            break;
        case KING:
            getKingMoves(currentIndex, attackingSquares);
            appendIntListToAttackedSquare(attackingSquares);
            resetRayResult(attackingSquares);
            break;
        default:
            break;
        }
    }
}

bool isKingIndexLegal(int targetSquare) {
    // King does not land on a square which he will be eaten or does not eat one of his own square
    return !attackedSquares[targetSquare] && 
        (state->boardArray[targetSquare] & pieceColorBitMask) != state->colorToGo;
}

int addSlidingPiecePinned(void (*getRay)(int index, int colorNotToInclude, int result[BOARD_LENGTH]), int dangerousSlidingPiece) {
    int firstRay[BOARD_LENGTH] = { -1, -1, -1, -1, -1, -1, -1, -1 };
    getRay(friendlyKingIndex, 0, firstRay);
    if (firstRay[0] == -1) { 
        return -1; 
    }

    int firstLastSquare = -1; 
    for (int i = 0; i < BOARD_LENGTH; i++) {
        if (firstRay[i + 1] == -1) {
            firstLastSquare = firstRay[i];
            break;
        }
    }
    int firstLastSquareContent = state->boardArray[firstLastSquare];
    if (firstLastSquareContent == NONE) { 
        return - 1; 
    }

    if ((firstLastSquareContent & pieceColorBitMask) == state->colorToGo) {
        int secondRay[BOARD_LENGTH] = { -1, -1, -1, -1, -1, -1, -1, -1 };
        getRay(firstLastSquare, 0, secondRay);
        if (secondRay[0] == -1) { 
            return -1; 
        }
        int secondLastSquare = -1; 
            for (int i = 0; i < BOARD_LENGTH; i++) {
                if (secondRay[i + 1] == -1) {
                    secondLastSquare = secondRay[i];
                    break;
                }
            }

        int potentialDangerousPiece = state->boardArray[secondLastSquare];
        if (potentialDangerousPiece == dangerousSlidingPiece ||
            potentialDangerousPiece == (opponentColor | QUEEN)) {
            // The piece is pinned!
            IntList* potentialValidMoves = (IntList*) malloc(sizeof(IntList));
            potentialValidMoves->capacity = 8;
            potentialValidMoves->count = 0;
            potentialValidMoves->items = malloc(sizeof(int) * 8);
            // Appending the first ray and second ray to potential valid moves
            for (int i = 0; i < BOARD_LENGTH; i++) {
                if (firstRay[i] != -1) {
                    da_append(potentialValidMoves, firstRay[i]);
                }
            }
            for (int i = 0; i < BOARD_LENGTH; i++) {
                if (secondRay[i] != -1) {
                    da_append(potentialValidMoves, secondRay[i]);
                }
            }
            isPieceAtLocationPinned[firstLastSquare] = potentialValidMoves;
        } 
    } else {
        // Piece is opponent color
        if (firstLastSquareContent == dangerousSlidingPiece ||
            firstLastSquareContent == (opponentColor | QUEEN)) {
            // The piece is checking the piece
            return firstLastSquare;
        }  
    }
    return -1;
}

void appendIntListToBoolList(int src[BOARD_LENGTH], bool* dest) {
    // Assuming that the items of the src are in the range of the index of the dest
    for (int i = 0; i < BOARD_LENGTH; i++) {
        if (src[i] != -1) {
            dest[src[i]] = true;
        }
    }
}

void generateCastle(Moves* validMoves) {
    const int defaultKingIndex = state->colorToGo == WHITE ? 60 : 4;
    if (friendlyKingIndex != defaultKingIndex || inCheck) { return; }

    const int castlingBits = state->colorToGo == WHITE ? state->castlinPerm >> 2 : state-> castlinPerm & 0b11;
    if (castlingBits >> 1) { // Can castle king side
        // Trusting the caller that the the king nor the rook has moved
        // Note the first check is redundant, if we assume 
        // that the caller has done some proper checks to set the castling perm, which I do not
        const int rookIndex = friendlyKingIndex + 3;
        if (state->boardArray[rookIndex] == (state->colorToGo | ROOK) &&
            !attackedSquares[friendlyKingIndex + 1] &&
            !attackedSquares[friendlyKingIndex + 2] &&
            state->boardArray[friendlyKingIndex + 1] == NONE &&
            state->boardArray[friendlyKingIndex + 2] == NONE) {
            // Castling is valid
            appendMove(friendlyKingIndex, friendlyKingIndex + 2, KING_SIDE_CASTLING, validMoves);
        }
    }
    if (castlingBits & 1) { // Can castle queen side
        const int rookIndex = friendlyKingIndex - 4;
        // Trusting the caller that the the king nor the rook has moved
        // Note the first check is redundant, if we assume 
        // that the caller has done some proper checks to set the castling perm, which I do not
        if (state->boardArray[rookIndex] == (state->colorToGo | ROOK) &&
            !attackedSquares[friendlyKingIndex - 1] &&
            !attackedSquares[friendlyKingIndex - 2] && 
            // The rook can pass trough an attacked square, which means that we don't need to check for the third square
            state->boardArray[friendlyKingIndex - 1] == NONE &&
            state->boardArray[friendlyKingIndex - 2] == NONE && 
            state->boardArray[friendlyKingIndex - 3] == NONE) {
            // Castling is valid
            appendMove(friendlyKingIndex, friendlyKingIndex - 2, QUEEN_SIDE_CASTLING, validMoves);
        }
    }
}

void generateKingMoves(Moves* validMoves) {
    if (attackedSquares[friendlyKingIndex]) { inCheck = true; }
    if (doubleAttackedSquares[friendlyKingIndex]) { inDoubleCheck = true; }

    int pseudoLegalMoves[BOARD_LENGTH] = { -1, -1, -1, -1, -1, -1, -1, -1 };
    getKingMoves(friendlyKingIndex, pseudoLegalMoves);
    for (int i = 0; i < 8; i++) {
        const int targetSquare = pseudoLegalMoves[i];
        if (targetSquare != -1 && isKingIndexLegal(targetSquare)) {
            appendMove(friendlyKingIndex, targetSquare, NOFlAG, validMoves);
        }
    }

    generateCastle(validMoves);
    // Pinning own color pieces    
    // Checking for attacking sliding pieces
    int checkingPieceIndex = -1;
    void (*checkingPieceDirection)(int index, int colorNotToInclude, int result[BOARD_LENGTH]) = NULL;
    // Note: Could refactor all the function pointer into an array and iterate over them
    // Unfortunatly, I have better things to do for now

    if (addSlidingPiecePinned(getTopNetRay, opponentColor | ROOK) != -1)
        checkingPieceDirection = getTopNetRay; 
    if (addSlidingPiecePinned(getBottomNetRay, opponentColor | ROOK) != -1) 
        checkingPieceDirection = getBottomNetRay; 
    if (addSlidingPiecePinned(getRightNetRay, opponentColor | ROOK) != -1)
        checkingPieceDirection = getRightNetRay; 
    if (addSlidingPiecePinned(getLeftNetRay, opponentColor | ROOK) != -1) 
        checkingPieceDirection = getLeftNetRay; 
    
    if (addSlidingPiecePinned(getTopRightNetRay, opponentColor | BISHOP) != -1) 
        checkingPieceDirection = getTopRightNetRay; 
    if (addSlidingPiecePinned(getTopLeftNetRay, opponentColor | BISHOP) != -1) 
        checkingPieceDirection = getTopLeftNetRay; 
    if (addSlidingPiecePinned(getBottomRightNetRay, opponentColor | BISHOP) != -1) 
        checkingPieceDirection = getBottomRightNetRay;
    if (addSlidingPiecePinned(getBottomLeftNetRay, opponentColor | BISHOP) != -1) 
        checkingPieceDirection = getBottomLeftNetRay;

    if (!inCheck || inDoubleCheck) { return; } // Either the king is safe or only king moves are valid

    if (checkingPieceDirection != NULL) {
        // A sliding piece is checking the king
        int result[BOARD_LENGTH] = { -1, -1, -1, -1, -1, -1, -1, -1 };
        checkingPieceDirection(friendlyKingIndex, 0, result);
        appendIntListToBoolList(result, protectKingSquares);
        return;
    }
    // It is a pawn or a knight who is checking the king
    // The only valid moves for other pieces is to eat the checking piece
    
    // Checking for pawns
    const int delta = state->colorToGo == WHITE ? -1 : 1;
    int potentialPawn;
    // For loop is remove copy pasting. I know sometimes I copy paste a lot but I was fed up this time
    for (int i = 0; i < 2; i++) {
        potentialPawn = friendlyKingIndex + (i == 0 ? 7 : 9) * delta;
        if (state->boardArray[potentialPawn] == (opponentColor | PAWN)) {
            protectKingSquares[potentialPawn] = true;
            return; // Can return without checking the others since there is no double check
        }
    }
    
    // Checking for knights 
    int potentialKnigths[BOARD_LENGTH] = { -1, -1, -1, -1, -1, -1, -1, -1 };
    getKnightMoves(friendlyKingIndex, potentialKnigths);
    for (int i = 0; i < BOARD_LENGTH; i++) {
        int index = potentialKnigths[i];
        if (index != -1 && state->boardArray[index] == (opponentColor | KNIGHT)) {
            protectKingSquares[index] = true;
            return; // Can return without checking the others since there is no double check
        }
    }
}

void appendPromotionMove(int from, int to, Moves* validMoves) {
    appendMove(from, to, PROMOTE_TO_QUEEN, validMoves);
    appendMove(from, to, PROMOTE_TO_KNIGHT, validMoves);
    appendMove(from, to, PROMOTE_TO_ROOK, validMoves);
    appendMove(from, to, PROMOTE_TO_BISHOP, validMoves);
} 

void checkUnPinnedEnPassant(int from, Moves* validMoves) {
    // king is in the same row of a pawn, the opponent pawn who just double pawn pushed and an attacking piece
    // Board position which satisfies these criteria: 7k/8/8/KPp4r/8/8/8/8
    if ((friendlyKingIndex / 8 ) != (from / 8)) { 
        appendMove(from, state->enPassantTargetSquare, EN_PASSANT, validMoves);
        return; // The king is not on the same rank as the from pawn
    }
    // TODO: Make function getNextPieceInDirection
    int squareInFromOfEnPassant = state->colorToGo == BLACK ? 
        state->enPassantTargetSquare - 8 :
        state->enPassantTargetSquare + 8;
    int leftRow[BOARD_LENGTH] = { -1, -1, -1, -1, -1, -1, -1, -1 };
    int rightRow[BOARD_LENGTH] = { -1, -1, -1, -1, -1, -1, -1, -1 };
    getLeftNetRay(squareInFromOfEnPassant, 0, leftRow);
    getRightNetRay(squareInFromOfEnPassant, 0, rightRow);

    int lastLeftRow = -1;
    for (int i = 0; i < BOARD_LENGTH; i++) {
        if (leftRow[i + 1] == -1) {
            lastLeftRow = leftRow[i];
            break;
        }
    }
    int lastRightRow = -1;
    for (int i = 0; i < BOARD_LENGTH; i++) {
        if (rightRow[i + 1] == -1) {
            lastRightRow = rightRow[i];
            break;
        }
    }

    if (lastRightRow == -1 || lastLeftRow == -1) {
        // There is no restriction for the pawn to do en-passant
        appendMove(from, state->enPassantTargetSquare, EN_PASSANT, validMoves);
        return;
    }
    
    // There are two cases of en passant pinned
    // Either the pawn that just double moved is between the from pawn and the king
    // or this pawn is between the from pawn and the attacking pieces
    void (*attackingPieceDirection)(int index, int colorNotToInclude, int result[BOARD_LENGTH]);
    int indexToCalculateAttackingPiece;
    if (lastRightRow == friendlyKingIndex || lastLeftRow == friendlyKingIndex) {
        // First case
        attackingPieceDirection = lastLeftRow == from ? getLeftNetRay : getRightNetRay;
        indexToCalculateAttackingPiece = from;

    } else {
        // second case
        // Note: Already checked if the king is on the same line in the first condition
        
        int squareAfterPawn[BOARD_LENGTH] = { -1, -1, -1, -1, -1, -1, -1, -1 };
        if (lastLeftRow == from) {
            attackingPieceDirection = getRightNetRay;
            getLeftNetRay(from, 0, squareAfterPawn);
        } else {
            attackingPieceDirection = getLeftNetRay;
            getRightNetRay(from, 0, squareAfterPawn);
        }

        int potentialKingIndex = -1;
        for (int i = 0; i < BOARD_LENGTH; i++) {
            if (squareAfterPawn[i + 1] == -1) {
                potentialKingIndex = squareAfterPawn[i];
                break;
            }
        }
        if (potentialKingIndex != friendlyKingIndex) {
            // There is a piece between the king and the from pawn removing the en passant pinned
            appendMove(from, state->enPassantTargetSquare, EN_PASSANT, validMoves);
            return;
        }

        indexToCalculateAttackingPiece = squareInFromOfEnPassant;
    } 

    int potentialAttackingPieceIndex[BOARD_LENGTH] = { -1, -1, -1, -1, -1, -1, -1, -1 };
    attackingPieceDirection(indexToCalculateAttackingPiece, 0, potentialAttackingPieceIndex);

    int lastPotentialAttackingPiece = -1;
    for (int i = 0; i < BOARD_LENGTH; i++) {
        if (potentialAttackingPieceIndex[i + 1] == -1) {
            lastPotentialAttackingPiece = potentialAttackingPieceIndex[i];
            break;
        }
    }
    
    if (state->boardArray[lastPotentialAttackingPiece] != (opponentColor | ROOK) && 
        state->boardArray[lastPotentialAttackingPiece] != (opponentColor | QUEEN)) {
        // The pawn is not en-passant pinned!
        appendMove(from, state->enPassantTargetSquare, EN_PASSANT, validMoves);
    }

}

void generateEnPassant(int from, Moves* validMoves) {
    if (state->boardArray[state->enPassantTargetSquare] != NONE) { return; }
    int difference = state->colorToGo == WHITE ? from - state->enPassantTargetSquare : state->enPassantTargetSquare - from;
    if ((difference != 7) && (difference != 9)) { return; }
    // If the pawn is "en-passant pinned"
    IntList* pinnedLegalMoves = isPieceAtLocationPinned[from];
    if (pinnedLegalMoves != NULL && inCheck) {
        // Pawn is pinned and the king is checked
        return;
    } 
    if (pinnedLegalMoves == NULL && !inCheck) {
        checkUnPinnedEnPassant(from, validMoves);
    } else if (pinnedLegalMoves != NULL && !inCheck) {
        for (int i = 0; i < pinnedLegalMoves->count; i++) {
            if (state->enPassantTargetSquare == pinnedLegalMoves->items[i]) {
                appendMove(from, state->enPassantTargetSquare, EN_PASSANT, validMoves);
                return;
            }
        }
    } else if (pinnedLegalMoves == NULL && inCheck) {
        // If the en-passant piece is checking the king 
        int squareInFrontOfEnPassantPawn = state->colorToGo == WHITE ? 
            state->enPassantTargetSquare + 16 :
            state->enPassantTargetSquare - 16;
        int attackedSquare1 = squareInFrontOfEnPassantPawn + 1;
        int attackedSquare2 = squareInFrontOfEnPassantPawn - 1;

        if (attackedSquare1 == friendlyKingIndex || attackedSquare2 == friendlyKingIndex) {
            appendMove(from, state->enPassantTargetSquare, EN_PASSANT, validMoves);
        } else if (protectKingSquares[state->enPassantTargetSquare]) {
            appendMove(from, state->enPassantTargetSquare, EN_PASSANT, validMoves);
        }
    }
}

void generatePawnDoublePush(int from, int increment, Moves* validMoves) {
    if (state->boardArray[from + increment] != NONE ||
        state->boardArray[from + 2 * increment] != NONE) { return; }
    IntList* pinnedLegalMoves = isPieceAtLocationPinned[from];
    if (pinnedLegalMoves != NULL && inCheck) {
        // Pawn is pinned and the king is checked
        return;
    } 
    if (pinnedLegalMoves == NULL && !inCheck) {
        appendMove(from, from + 2 * increment, DOUBLE_PAWN_PUSH, validMoves);
    } else if (pinnedLegalMoves != NULL && !inCheck) {
        for (int i = 0; i < pinnedLegalMoves->count; i++) {
            if ((from + 2 * increment) == pinnedLegalMoves->items[i]) {
                appendMove(from, from + 2 * increment, DOUBLE_PAWN_PUSH, validMoves);
                return;
            }
        }
    } else if (pinnedLegalMoves == NULL && inCheck) {
        if (protectKingSquares[from + 2 * increment]) {
            appendMove(from, from + 2 * increment, DOUBLE_PAWN_PUSH, validMoves);
        }
    }

}

void generateAddionnalPawnMoves(int from, bool pseudoLegalMoves[BOARD_SIZE], Moves* validMoves) {
    int increment = state->colorToGo == WHITE ? -8 : 8;
    bool pawnCanEnPassant = state->colorToGo == WHITE ? 
        from / 8 == 3 : 
        from / 8 == 4;
    bool pawnCanDoublePush = state->colorToGo == WHITE ? 
        from / 8 == 6 : 
        from / 8 == 1;
    if (pawnCanEnPassant && state->enPassantTargetSquare != -1) { 
        generateEnPassant(from, validMoves); 
    } else if (pawnCanDoublePush) {
        generatePawnDoublePush(from, increment, validMoves);
    }
}

void addLegalMovesFromPseudoLegalMoves(
    int from, 
    bool pseudoLegalMoves[BOARD_SIZE], 
    bool isPawn, 
    bool pawnBeforePromotion,
    Moves* validMoves) {
    if (isPawn) generateAddionnalPawnMoves(from, pseudoLegalMoves, validMoves);
    IntList* validSquaresIfPinned = isPieceAtLocationPinned[from];
    if (!inCheck && validSquaresIfPinned == NULL) {
        // King is not checked nor is the piece pinned
        for (int i = 0; i < BOARD_SIZE; i++) {
            if (pseudoLegalMoves[i]) {
                if (pawnBeforePromotion) { appendPromotionMove(from, i, validMoves); }
                else { appendMove(from, i, NOFlAG, validMoves); }
            }
        }
    } else if (inCheck && validSquaresIfPinned == NULL) {
        // The king is checked although the piece is not pinned
        for (int i = 0; i < BOARD_SIZE; i++) {
            if (protectKingSquares[i] && pseudoLegalMoves[i]) {
                if (pawnBeforePromotion) { appendPromotionMove(from, i, validMoves); }
                else { appendMove(from, i, NOFlAG, validMoves); }
            }
        }
    } else if (inCheck && validSquaresIfPinned != NULL) {
        // The king is checked and the piece is pinned
        for (int i = 0; i < validSquaresIfPinned->count; i++) {
            int index = validSquaresIfPinned->items[i];
            if (protectKingSquares[index] && pseudoLegalMoves[index]) {
                if (pawnBeforePromotion) { appendPromotionMove(from, index, validMoves); }
                else { appendMove(from, index, NOFlAG, validMoves); }
            }
        }
    // Note: Kinda redundant if statement since this is the only valid option but I kept it for clarity
    } else if (!inCheck && isPieceAtLocationPinned[from] != NULL) {
        // The king is not checked but the piece is pinned
        for (int i = 0; i < validSquaresIfPinned->count; i++) {
            int index = validSquaresIfPinned->items[i];
            if (pseudoLegalMoves[index]) {
                if (pawnBeforePromotion) { appendPromotionMove(from, index, validMoves); }
                else { appendMove(from, index, NOFlAG, validMoves); }
            }
        }
    }
}

void getPawnPseudoLegalMoveIndex(int index, bool result[BOARD_SIZE]) {
    int potentialNeutralMove = state->colorToGo == WHITE ? index - 8 : index + 8;
    if (potentialNeutralMove < 0 && potentialNeutralMove > 63) {
        return;
    }
    if (state->boardArray[potentialNeutralMove] == NONE) {
        result[potentialNeutralMove] = true;
    }
    int attacks[2] = { -1, -1 };
    getPawnAttackingSquares(index, state->colorToGo, attacks);
    for (int i = 0; i < 2; i++) {
        int potentialAttackMove = attacks[i];
        if (potentialAttackMove != -1 && (state->boardArray[potentialAttackMove] & pieceColorBitMask) == opponentColor) {
            result[potentialAttackMove] = true;
        }
    }
}

void generateSupportingPiecesMoves(Moves* validMoves) {
    int rays[BOARD_LENGTH] = { -1, -1, -1, -1, -1, -1, -1, -1 };
    for (int currentIndex = 0; currentIndex < BOARD_SIZE; currentIndex++) {
        const int piece = state->boardArray[currentIndex];
        if (piece == NONE) continue;
        if ((piece & pieceColorBitMask) == opponentColor) continue;
        bool pseudoLegalMoves[BOARD_SIZE] = { false };
        switch (piece & pieceTypeBitMask) {
        case ROOK: 
            getTopNetRay(currentIndex, state->colorToGo, rays);
            appendIntListToBoolList(rays, pseudoLegalMoves);
            resetRayResult(rays);

            getBottomNetRay(currentIndex, state->colorToGo, rays);
            appendIntListToBoolList(rays, pseudoLegalMoves);
            resetRayResult(rays);
            
            getRightNetRay(currentIndex, state->colorToGo, rays);
            appendIntListToBoolList(rays, pseudoLegalMoves);
            resetRayResult(rays);
            
            getLeftNetRay(currentIndex, state->colorToGo, rays);
            appendIntListToBoolList(rays, pseudoLegalMoves);
            resetRayResult(rays);

            addLegalMovesFromPseudoLegalMoves(currentIndex, pseudoLegalMoves, false, false, validMoves);
        break;
        case BISHOP:
            getTopRightNetRay(currentIndex, state->colorToGo, rays);
            appendIntListToBoolList(rays, pseudoLegalMoves);
            resetRayResult(rays);
            
            getTopLeftNetRay(currentIndex, state->colorToGo, rays);
            appendIntListToBoolList(rays, pseudoLegalMoves);
            resetRayResult(rays);
            
            getBottomRightNetRay(currentIndex, state->colorToGo, rays);
            appendIntListToBoolList(rays, pseudoLegalMoves);
            resetRayResult(rays);
            
            getBottomLeftNetRay(currentIndex, state->colorToGo, rays);
            appendIntListToBoolList(rays, pseudoLegalMoves);   
            resetRayResult(rays);

            addLegalMovesFromPseudoLegalMoves(currentIndex, pseudoLegalMoves, false, false, validMoves);
        break;
        case QUEEN:
            getTopNetRay(currentIndex, state->colorToGo, rays);
            appendIntListToBoolList(rays, pseudoLegalMoves);
            resetRayResult(rays);            
            
            getBottomNetRay(currentIndex, state->colorToGo, rays);
            appendIntListToBoolList(rays, pseudoLegalMoves);
            resetRayResult(rays);            
            
            getRightNetRay(currentIndex, state->colorToGo, rays);
            appendIntListToBoolList(rays, pseudoLegalMoves);
            resetRayResult(rays);            
            
            getLeftNetRay(currentIndex, state->colorToGo, rays);
            appendIntListToBoolList(rays, pseudoLegalMoves);
            resetRayResult(rays);            
            
            getTopRightNetRay(currentIndex, state->colorToGo, rays);
            appendIntListToBoolList(rays, pseudoLegalMoves);
            resetRayResult(rays);            
            
            getTopLeftNetRay(currentIndex, state->colorToGo, rays);
            appendIntListToBoolList(rays, pseudoLegalMoves);
            resetRayResult(rays);            
            
            getBottomRightNetRay(currentIndex, state->colorToGo, rays);
            appendIntListToBoolList(rays, pseudoLegalMoves);
            resetRayResult(rays);            
            
            getBottomLeftNetRay(currentIndex, state->colorToGo, rays);
            appendIntListToBoolList(rays, pseudoLegalMoves);
            resetRayResult(rays);

            addLegalMovesFromPseudoLegalMoves(currentIndex, pseudoLegalMoves, false, false, validMoves);
        break;
        case KNIGHT:
            getKnightPseudoLegalMoves(currentIndex, rays);
            appendIntListToBoolList(rays, pseudoLegalMoves);
            resetRayResult(rays);

            addLegalMovesFromPseudoLegalMoves(currentIndex, pseudoLegalMoves, false, false, validMoves);
        break;
        case PAWN:
            getPawnPseudoLegalMoveIndex(currentIndex, pseudoLegalMoves);
            addLegalMovesFromPseudoLegalMoves(currentIndex, pseudoLegalMoves, true, 
                state->colorToGo == WHITE ? currentIndex / 8 == 1 : currentIndex / 8 == 6, validMoves);
            break;
        default:
            break;
        }
    }
}

void noMemoryLeaksPlease() {
    free(attackedSquares);
    free(doubleAttackedSquares);
    free(protectKingSquares);
    for (int i = 0; i < BOARD_SIZE; i++) {
        IntList* piecePinnedAtLocation = isPieceAtLocationPinned[i];
        if (piecePinnedAtLocation != NULL) {
            free(piecePinnedAtLocation->items);
            free(piecePinnedAtLocation);
        }
    }
    free(isPieceAtLocationPinned);
}

Moves* simplifyMoves(Moves og) {
    Moves* result = malloc(sizeof(Moves));
    result->capacity = og.count;
    result->count = og.count;
    result->items = malloc(sizeof(unsigned short) * result->capacity);
    for (int i = 0; i < result->count; i++) {
        result->items[i] = og.items[i];
    }
    free(og.items);
    return result;
}

Moves* getValidMoves(GameState *gameState) {
    Moves validMoves = { 0 };
    state = gameState;
    
    if (state->turnsForFiftyRule >= 50) {
        noMemoryLeaksPlease();
        appendMove(0, 0, STALEMATE, &validMoves); // This is the `draw` move
        return simplifyMoves(validMoves);
    }
    
    init();
    calculateAttackSquares();
    generateKingMoves(&validMoves);

    if (inDoubleCheck) { 

        if (validMoves.count == 0) {
            // A pretty cool double checkmate
            appendMove(0, 0, CHECKMATE, &validMoves); // This is the `checkmate` move
        }

        noMemoryLeaksPlease();
        return simplifyMoves(validMoves);
    }
    
    generateSupportingPiecesMoves(&validMoves);

    if (validMoves.count == 0) {
        // There is no valid move
        if (inCheck) {
            appendMove(0, 0, CHECKMATE, &validMoves); // This is the `checkmate` move
        } else {
            appendMove(0, 0, STALEMATE, &validMoves); // This is the `draw` move
        }
    }

    noMemoryLeaksPlease();
    return simplifyMoves(validMoves);
}