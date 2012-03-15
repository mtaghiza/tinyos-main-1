configuration TDMANonRootC{
  provides interface SplitControl;

  uses interface Send;
  uses interface TDMARootControl;
  uses interface SplitControl as SubSplitControl;
} implementation{
  SplitControl = SubSplitControl;
  components TDMANonRootP;
  
  TDMANonRootP.Send = Send;
  TDMANonRootP.TDMARootControl = TDMARootControl;
}
