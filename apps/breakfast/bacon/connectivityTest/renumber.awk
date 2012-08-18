/CONNECTIVITY TEST/{
  snOffset[$2] += lastSN[$2]
  print "#Renumber", $2, "add", snOffset[$2]
}
($3 == "RX" && NF == 12){
  for ( i = 1 ; i <= NF; i++){
    if (i == 9){
      printf("%d ", $i + snOffset[$2])
    }else{
      printf("%s ", $i)
    }
  }
  printf("\n")
}
($3 == "TX"){
  lastSN[$2] = $9
  for ( i = 1; i < NF; i++ ){
    printf("%s ", $i)
  }
  printf("%d\n", $9 + snOffset[$2])
}
