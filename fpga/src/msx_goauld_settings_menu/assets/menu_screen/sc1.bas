5 'save"autoexec.bas",a
10 COLOR 15,4,7: SCREEN 1: WIDTH 32: KEY OFF
11 LOCATE 0,0
12 PRINT"XWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWY";
13 PRINT"V                              V";
14 PRINT"ZWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW[";
20 LOCATE 7,1
30 PRINT "MSX GOA'ULD CONFIG"
40 LOCATE 5,4
50 PRINT "1-Enable Mapper"
60 LOCATE 5,5
70 PRINT "2-Enable Megaram"
80 LOCATE 5,6
90 PRINT "3-Enable Scanlines"
100 LOCATE 5,7
110 PRINT "4-Mapper Slot"
120 LOCATE 5,8
130 PRINT "5-Save & Exit"
140 LOCATE 5,9
150 PRINT "6-Save & Reset"
10000 BSAVE"menu_scr.sc1",0,&H3FFF,S
10010 A$=INPUT$(1)
10020 SCREEN 0
10030 LIST
