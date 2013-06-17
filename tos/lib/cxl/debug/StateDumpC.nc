module StateDumpC {
  provides interface StateDump;
} implementation {
  command void StateDump.requestDump(){
    signal StateDump.dumpRequested();
  }
}
