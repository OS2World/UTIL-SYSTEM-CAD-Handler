{&Use32+}
program add_sm_hotkey;

uses
  Os2Def,
  Os2Base,
  VpUtils,
  cadh;

var
  keyb                  :longint;
  para                  :hotkey;
  para_len              :longint;
  rc                    :ApiRet;
  k                     :integer;

begin
  if ParamCount<>4 then
    begin
      WriteLn('Usage:   ADD_SMH shiftstate make break id');
      WriteLn('Example: ADD_SMH $0000      $4c  $cc   4');
      WriteLn(' = plain Num5 to index 4');
      Halt(1);
    end;

  rc:=SysFileOpen(cadh_drivername,open_flags_Fail_On_Error+open_share_DenyNone,keyb);
  if rc<>0 then RunError(rc);

  with para do
    begin
      Val(ParamStr(1),fsHotKey,k);
      if k<>0 then RunError(1);
      Val(ParamStr(2),uchScancodeMake,k);
      if k<>0 then RunError(2);
      Val(ParamStr(3),uchScancodeBreak,k);
      if k<>0 then RunError(3);
      Val(ParamStr(4),idHotKey,k);
      if k<>0 then RunError(4);
    end;
  para_len:=SizeOf(para);
(*rc:=DosDevIOCtl(keyb,ioctl_Keyboard,kbd_SetSesMgrHotKey,
        @para_0,para_len,@para_len,nil,0,nil);*)
  rc:=DosDevIOCtl(keyb,cadh_ioctl_category,cadh_ioctl_setsesmgrhotkey,
        @para,para_len,@para_len,nil,0,nil);
  if rc<>0 then RunError(rc);

  SysFileClose(keyb);
end.

