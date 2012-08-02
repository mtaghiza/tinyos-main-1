#ifndef SF_DEBUG_H
#define SF_DEBUG_H

#if DEBUG_SF_TESTBED_AW == 1
#define printf_SF_TESTBED_AW(...) printf(__VA_ARGS__)
#else
#define printf_SF_TESTBED_AW(...)
#endif

#if DEBUG_SF_TESTBED_PR == 1
#define printf_SF_TESTBED_PR(...) printf(__VA_ARGS__)
#else
#define printf_SF_TESTBED_PR(...)
#endif

#if DEBUG_SF_TESTBED == 1
#define printf_SF_TESTBED(...) printf(__VA_ARGS__)
#else
#define printf_SF_TESTBED(...)
#endif

#if DEBUG_SF_STATE == 1
#define printf_SF_STATE(...) printf(__VA_ARGS__)
#else
#define printf_SF_STATE(...)
#endif

#if DEBUG_SF_GP == 1
#define printf_SF_GP(...) printf(__VA_ARGS__)
#else
#define printf_SF_GP(...)
#endif

#if DEBUG_SF_RX == 1
#define printf_SF_RX(...) printf(__VA_ARGS__)
#else
#define printf_SF_RX(...)
#endif

#if DEBUG_SF_SV == 1
#define printf_SF_SV(...) printf(__VA_ARGS__)
#else
#define printf_SF_SV(...) 
#endif

#if DEBUG_SF_ROUTE == 1
#define printf_SF_ROUTE(...) printf(__VA_ARGS__)
#else
#define printf_SF_ROUTE(...) 
#endif

#if DEBUG_SF_CLEARTIME == 1
#define printf_SF_CLEARTIME(...) printf(__VA_ARGS__)
#else
#define printf_SF_CLEARTIME(...) 
#endif

#if defined PORT_SF_GPO && defined PIN_SF_GPO
#define SF_GPO_TOGGLE_PIN TDMA_TOGGLE_PIN(PORT_SF_GPO, PIN_SF_GPO)
#define SF_GPO_CLEAR_PIN TDMA_CLEAR_PIN(PORT_SF_GPO, PIN_SF_GPO)
#define SF_GPO_SET_PIN TDMA_SET_PIN(PORT_SF_GPO, PIN_SF_GPO)
#else 
#define SF_GPO_TOGGLE_PIN 
#define SF_GPO_CLEAR_PIN 
#define SF_GPO_SET_PIN 
#endif

#if defined PORT_SF_GPF && defined PIN_SF_GPF
#define SF_GPF_TOGGLE_PIN TDMA_TOGGLE_PIN(PORT_SF_GPF, PIN_SF_GPF)
#define SF_GPF_CLEAR_PIN TDMA_CLEAR_PIN(PORT_SF_GPF, PIN_SF_GPF)
#define SF_GPF_SET_PIN TDMA_SET_PIN(PORT_SF_GPF, PIN_SF_GPF)
#else 
#define SF_GPF_TOGGLE_PIN 
#define SF_GPF_CLEAR_PIN 
#define SF_GPF_SET_PIN 
#endif


#endif
