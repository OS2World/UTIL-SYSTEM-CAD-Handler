{&Use32+}
program list_sm_hotkeys;

uses
  Os2Def,
  Os2Base,
  VpUtils,
  Strings;

var
  keyb                  :longint;
  para_0                :SmallWord;
  para_1                :SmallWord;
  data                  :array[1..16] of hotkey;
  para_len,data_len     :longint;
  i                     :word;
  rc                    :ApiRet;

const
  keys                  :array[1..$7f] of PChar=
    ((* 01 *) 'Esc',
     (* 02 *) '1',
     (* 03 *) '2',
     (* 04 *) '3',
     (* 05 *) '4',
     (* 06 *) '5',
     (* 07 *) '6',
     (* 08 *) '7',
     (* 09 *) '8',
     (* 0a *) '9',
     (* 0b *) '0',
     (* 0c *) '',
     (* 0d *) '',
     (* 0e *) 'Backspace',
     (* 0f *) 'Tab',
     (* 10 *) '',
     (* 11 *) '',
     (* 12 *) '',
     (* 13 *) '',
     (* 14 *) '',
     (* 15 *) '',
     (* 16 *) '',
     (* 17 *) '',
     (* 18 *) '',
     (* 19 *) '',
     (* 1a *) '',
     (* 1b *) '',
     (* 1c *) 'Enter',
     (* 1d *) '',
     (* 1e *) '',
     (* 1f *) '',
     (* 20 *) '',
     (* 21 *) '',
     (* 22 *) '',
     (* 23 *) '',
     (* 24 *) '',
     (* 25 *) '',
     (* 26 *) '',
     (* 27 *) '',
     (* 28 *) '',
     (* 29 *) '',
     (* 2a *) '',
     (* 2b *) '',
     (* 2c *) '',
     (* 2d *) '',
     (* 2e *) '',
     (* 2f *) '',
     (* 30 *) '',
     (* 31 *) '',
     (* 32 *) '',
     (* 33 *) '',
     (* 34 *) '',
     (* 35 *) '',
     (* 36 *) '',
     (* 37 *) 'Num*',
     (* 38 *) '',
     (* 39 *) 'Space',
     (* 3a *) 'Caps Lock',
     (* 3b *) 'F1',
     (* 3c *) 'F2',
     (* 3d *) 'F3',
     (* 3e *) 'F4',
     (* 3f *) 'F5',
     (* 40 *) 'F6',
     (* 41 *) 'F7',
     (* 42 *) 'F8',
     (* 43 *) 'F9',
     (* 44 *) 'F10',
     (* 45 *) '',
     (* 46 *) 'Scroll Lock',
     (* 47 *) 'Num7/Home',
     (* 48 *) 'Num8/Up',
     (* 49 *) 'Num9/PgUp',
     (* 4a *) 'Num-',
     (* 4b *) 'Num4/Left',
     (* 4c *) 'Num5',
     (* 4d *) 'Num6/Right',
     (* 4e *) 'Num+',
     (* 4f *) 'Num1/End',
     (* 50 *) 'Num2/Down',
     (* 51 *) 'Num3/PgDn',
     (* 52 *) 'Num0/Ins',
     (* 53 *) 'Num Del',
     (* 54 *) 'Sys Req',
     (* 55 *) '',
     (* 56 *) '',
     (* 57 *) 'F11',
     (* 58 *) 'F12',
     (* 59 *) '',
     (* 5a *) '',
     (* 5b *) '',
     (* 5c *) '',
     (* 5d *) '',
     (* 5e *) '',
     (* 5f *) '',
     (* 60 *) '',
     (* 61 *) '',
     (* 62 *) '',
     (* 63 *) '',
     (* 64 *) '',
     (* 65 *) '',
     (* 66 *) '',
     (* 67 *) '',
     (* 68 *) '',
     (* 69 *) '',
     (* 6a *) '',
     (* 6b *) '',
     (* 6c *) '',
     (* 6d *) '',
     (* 6e *) '',
     (* 6f *) '',
     (* 70 *) '',
     (* 71 *) '',
     (* 72 *) '',
     (* 73 *) '',
     (* 74 *) '',
     (* 75 *) '',
     (* 76 *) '',
     (* 77 *) '',
     (* 78 *) '',
     (* 79 *) '',
     (* 7a *) '',
     (* 7b *) '',
     (* 7c *) '',
     (* 7d *) '',
     (* 7e *) '',
     (* 7f *) '');

begin
  rc:=SysFileOpen('KBD$',{open_flags_Fail_On_Error+open_share_DenyNone}0,keyb);
  if rc<>0 then RunError(rc);

  para_0:=0;
  para_len:=SizeOf(para_0);
  rc:=DosDevIOCtl(keyb,4,$76,@para_0,para_len,@para_len,nil,0,nil);
  if rc<>0 then RunError(rc);

  if SizeOf(data)<>para_0*SizeOf(hotkey) then
    begin
      WriteLn('Hotkey table has unexcpected entry count of ',para_0,'!');
      Halt(1);
    end;

  para_1:=1;
  para_len:=SizeOf(para_1);
  data_len:=SizeOf(data);
  rc:=DosDevIOCtl(keyb,4,$76,@para_1,para_len,@para_len,@data,data_len,@data_len);
  if rc<>0 then RunError(rc);

  WriteLn('Current SessionManager Hotkeys are:');
  for i:=1 to para_1 do
    with data[i] do
      begin
        //if (fsHotKey=0) and (uchScancodeMake=0) and (uchScancodeBreak=0) and (idHotKey=0) then
        //  Continue;
        WriteLn('* fsHotKey=',Int2Hex(fsHotKey,4),
          ' uchScancodeMake=',Int2Hex(uchScancodeMake,2),
          ' uchScancodeBreak=',Int2Hex(uchScancodeBreak,2),
          ' idHotKey=',Int2Hex(idHotKey,4));
        Write('  ');
        if Odd(fsHotKey shr 11) then Write('Right-Alt + ');
        if Odd(fsHotKey shr 10) then Write('Right-Ctr + ');
        if Odd(fsHotKey shr  9) then Write('Left-Alt + ');
        if Odd(fsHotKey shr  8) then Write('Left-Ctr + ');
        if Odd(fsHotKey shr  1) then Write('Left-Shift + ');
        if Odd(fsHotKey shr  0) then Write('Right-Shift + ');
        if (uchScancodeMake>=Low(keys)) and (uchScancodeMake<=High(keys)) and (Strlen(keys[uchScancodeMake])<>0) then
          Write(keys[uchScancodeMake])
        else
          Write('?');
        WriteLn;
      end;

  SysFileClose(keyb);
end.

