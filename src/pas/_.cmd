@echo off
call unlock ..\cadh.vk\exe\* > nul

call pasvpo cad_popd %tmp%\ @cad_pop.cfg
%tmp%\cad_popd.exe
del %tmp%\cad_popd.exe

call stampdef cad_pop.def
call pasvpo cad_pop ..\cadh.vk\exe\ @cad_pop.cfg

if exist e:\os2\apps\cad_pop.exe call unlock e:\os2\apps\cad_pop.exe
if exist e:\os2\apps\cad_pop.exe copy ..\cadh.vk\exe\cad_pop.exe e:\os2\apps\cad_pop.exe
