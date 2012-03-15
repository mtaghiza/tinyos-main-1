#ifndef STATE_SAFETY_H
#define STATE_SAFETY_H

#define TMP_STATE uint8_t tmpState
#define CACHE_STATE atomic tmpState = state

#define CHECK_STATE(target) (tmpState == target)
#define SET_STATE_DEF bool setState(uint8_t from, uint8_t to, uint8_t error){\
  atomic {\
    if (state == from){\
      state = to;\
    } else { \
      state = error;\
    }\
    return state == to;\
  }\
}

#define SET_STATE(target, error) (setState(tmpState, target, error))
#define SET_ESTATE(error) (setState(error, error, error))

#endif
