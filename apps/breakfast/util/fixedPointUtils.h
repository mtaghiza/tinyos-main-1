#ifndef FIXED_POINT_UTILS_H
#define FIXED_POINT_UTILS_H
int32_t toFP(int32_t asInt, uint8_t dp){
  return (asInt << dp);
}

int32_t toInt(int32_t asFP, uint8_t dp){
  return (asFP + (1L << (dp - 1))) >> dp;
}

//n.b. same decimal places for each argument
int32_t fpMult(int32_t a, int32_t b, uint8_t dp){
  return (a*b + (1L << (dp - 1))) >> dp;
}

#endif
