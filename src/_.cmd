@echo off
cls
if [%1]==[WPI] goto l1
rem descript.ion in EA umwandeln?
cls

cd basedev
call _.bat

cd ..\pas
call _.cmd

cd ..\pas_smh
call _.cmd

cd ..

:l1

cd cadh.vk

call noea * boot\* doc\* exe\* > nul
call vptouch -s *

call D:\extra\FM2UTIL\CVT4OS2ND.CMD
cd boot
call D:\extra\FM2UTIL\CVT4OS2ND.CMD
cd ..\doc
call D:\extra\FM2UTIL\CVT4OS2ND.CMD
cd ..\exe
call D:\extra\FM2UTIL\CVT4OS2ND.CMD
cd ..

rem *** warpin

if "%warpin_dir%"=="" set warpin_dir=D:\extra\warpin
set beginlibpath=%warpin_dir%
if exist cadh.wpi del cadh.wpi

rem add_smh.exe list_smh.exe?

%warpin_dir%\wic.exe -t ..\cadh.wis
if errorlevel 1 goto fehler
%warpin_dir%\wic.exe cadh -a 1 -c.\boot cadh.??? -s ..\cadh.wis
%warpin_dir%\wic.exe cadh -a 2 -c.\exe cad_pop.???
%warpin_dir%\wic.exe cadh -a 3 -c.\exe add_smh.exe list_smh.exe popup.cmd  
%warpin_dir%\wic.exe cadh -a 4 -c.\doc *


rem *** end warpin
cd ..

call ..\genvk cadh

cd cadh.vk
call genpgp
cd ..

find "PackageId" < cadh.wis
goto ende

:fehler
pause
:ende
