#ifndef SF_DEBUG_H
#define SF_DEBUG_H

#ifdef DEBUG_SF_TESTBED_AW
#define printf_SF_TESTBED_AW(...) printf(__VA_ARGS__)
#else
#define printf_SF_TESTBED_AW(...)
#endif

#ifdef DEBUG_SF_TESTBED
#define printf_SF_TESTBED(...) printf(__VA_ARGS__)
#else
#define printf_SF_TESTBED(...)
#endif

#ifdef DEBUG_SF_STATE
#define printf_SF_STATE(...) printf(__VA_ARGS__)
#else
#define printf_SF_STATE(...)
#endif

#ifdef DEBUG_SF_GP
#define printf_SF_GP(...) printf(__VA_ARGS__)
#else
#define printf_SF_GP(...)
#endif

#ifdef DEBUG_SF_RX
#define printf_SF_RX(...) printf(__VA_ARGS__)
#else
#define printf_SF_RX(...)
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
