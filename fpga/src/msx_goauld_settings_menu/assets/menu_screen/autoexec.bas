5 'save"autoexec.bas",a
10 SCREEN0:WIDTH80:KEYOFF
11 BLOAD"menu_scr.sc0",S
12 LOCATE 20,4:PRINT"Enable Mapper          -          Slot -"
13 LOCATE 20,6:PRINT"Enable Megaram         -          Slot -"
14 LOCATE 20,8:PRINT"Slot1 Ghost SCC        -"
15 LOCATE 20,10:PRINT"Enable Scanlines       -"
16 LOCATE 20,12:PRINT"Save & Exit"
17 LOCATE 20,14:PRINT"Save & Reset"
20 A$=INPUT$(1)
30 IF A$=CHR$(27) THEN GOTO 60
40 PRINT A$;
50 GOTO 20
60 BSAVE"menu_scr.sc0",0,&H1000,S
