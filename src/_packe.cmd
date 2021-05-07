@echo off
cd ..\quelle
call quelle cadh
cd ..\prog
call prog cadh
cd ..\cadh
arj a -_ c:\fertig.q\cadh_nls.arj !cadh_nls.lst
