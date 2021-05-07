@echo off

call stampdef add_smh.def
call pasvpo add_smh ..\cadh.vk\exe\

call stampdef list_smh.def
call pasvpo list_smh ..\cadh.vk\exe\
