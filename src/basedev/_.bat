@echo off
cls

if exist %tmp%\cadh.obj del %tmp%\cadh.obj
if exist %tmp%\cadh.sys del %tmp%\cadh.sys
C:\bp\bin\tasm /t /oi /m /zi /ml /iTOOLKIT cadh.tas %tmp%\cadh.obj > err.pas
type err.pas
if not exist %tmp%\cadh.obj goto fehler

stampdef cadh.def
link /Alignment:1 /NoLogo /Map:Full %tmp%\cadh.obj,%tmp%\cadh.sys,%tmp%\cadh.map,,cadh.def
call nelite %tmp%\cadh.sys %tmp%\cadh.sys /s /e+ /p:255 /A:1 > nul
if not exist %tmp%\cadh.obj goto fehler

cd ..\cadh.vk\boot
copy %tmp%\cadh.sys 
mapsym %tmp%\cadh > nul
del %tmp%\cadh.map
del %tmp%\cadh.obj
del %tmp%\cadh.sys

copy cadh.sys e:\os2\boot
copy cadh.sym e:\os2\boot

goto ende


:fehler
pause

:ende
cd ..\..\basedev
