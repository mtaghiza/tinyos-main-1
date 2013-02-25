 #include "printf.h"
module TestP{
  uses interface Boot;
} implementation {
  event void Boot.booted(){
    printf("Booted.\n");
    printfflush();
  }
}
