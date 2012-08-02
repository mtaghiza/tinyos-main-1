#ifndef F_DEBUG_H
#define F_DEBUG_H

#if DEBUG_F_TESTBED == 1
#define printf_F_TESTBED(...) printf(__VA_ARGS__)
#else
#define printf_F_TESTBED(...) 
#endif


#if DEBUG_F_STATE == 1
#define printf_F_STATE(...) printf(__VA_ARGS__)
#else
#define printf_F_STATE(...) 
#endif

#if DEBUG_F_RX == 1
#define printf_F_RX(...) printf(__VA_ARGS__)
#else
#define printf_F_RX(...) 
#endif

#if DEBUG_F_SCHED == 1
#define printf_F_SCHED(...) printf(__VA_ARGS__)
#else
#define printf_F_SCHED(...) 
#endif

#if DEBUG_F_GP == 1
#define printf_F_GP(...) printf(__VA_ARGS__)
#else
#define printf_F_GP(...) 
#endif

#if DEBUG_F_SV == 1
#define printf_F_SV(...) printf(__VA_ARGS__)
#else
#define printf_F_SV(...) 
#endif

#if DEBUG_F_CLEARTIME == 1
#define printf_F_CLEARTIME(...) printf(__VA_ARGS__)
#else
#define printf_F_CLEARTIME(...) 
#endif

#if defined PORT_F_GPO && defined PIN_F_GPO
#define F_GPO_TOGGLE_PIN TDMA_TOGGLE_PIN(PORT_F_GPO, PIN_F_GPO)
#define F_GPO_CLEAR_PIN TDMA_CLEAR_PIN(PORT_F_GPO, PIN_F_GPO)
#define F_GPO_SET_PIN TDMA_SET_PIN(PORT_F_GPO, PIN_F_GPO)
#else 
#define F_GPO_TOGGLE_PIN 
#define F_GPO_CLEAR_PIN 
#define F_GPO_SET_PIN 
#endif

#if defined PORT_F_GPF && defined PIN_F_GPF
#define F_GPF_TOGGLE_PIN TDMA_TOGGLE_PIN(PORT_F_GPF, PIN_F_GPF)
#define F_GPF_CLEAR_PIN TDMA_CLEAR_PIN(PORT_F_GPF, PIN_F_GPF)
#define F_GPF_SET_PIN TDMA_SET_PIN(PORT_F_GPF, PIN_F_GPF)
#else 
#define F_GPF_TOGGLE_PIN 
#define F_GPF_CLEAR_PIN 
#define F_GPF_SET_PIN 
#endif

#if defined PORT_FLOOD_ATOMIC && defined PIN_FLOOD_ATOMIC
#define FLOOD_ATOMIC_TOGGLE_PIN TDMA_TOGGLE_PIN(PORT_FLOOD_ATOMIC, PIN_FLOOD_ATOMIC)
#define FLOOD_ATOMIC_CLEAR_PIN TDMA_CLEAR_PIN(PORT_FLOOD_ATOMIC, PIN_FLOOD_ATOMIC)
#define FLOOD_ATOMIC_SET_PIN TDMA_SET_PIN(PORT_FLOOD_ATOMIC, PIN_FLOOD_ATOMIC)
#else 
#define FLOOD_ATOMIC_TOGGLE_PIN 
#define FLOOD_ATOMIC_CLEAR_PIN 
#define FLOOD_ATOMIC_SET_PIN 
#endif



#endif
