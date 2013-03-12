interface Compare<t>{
  //return true if l <= r
  command bool leq(t l, t r);
}
