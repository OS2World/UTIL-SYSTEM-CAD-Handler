{&Use32+}
unit helper;

interface

procedure statusline(const s:string);
procedure ClrScrC(a:byte);
procedure wait_for_key;
procedure Error_Wait;
function errordescription(e:longint):string;
function rc_errordescription(e:longint):string;
function UpCase2(const c:char):char;
procedure UpCase2Str(var s:string);
procedure WriteLnBlock(const s:string);
function SysReadKey2:smallword;
function SysReadKey2UpCase:smallword;
function SysKeyPressed2:boolean;
function String2KeyUpcase(const s:string):word;
procedure leer_filter(var s:string);

implementation

uses
  Crt,
  Os2Def,
  Os2Base,
  VpSysLow,
  cad_pops,
  VpUtils,
  Strings;

procedure inverse_TextAttr;
  begin
    TextAttr:=(TextAttr shr 4) or (Lo(TextAttr shl 4));
  end;

{
procedure statusline(const s:string);
  const
    hotkey1     :char='`';
    hotkey2     :char='`';
  var
    i           :word;
    s1          :string;
  begin
    GotoXY(1,Hi(WindMax)+1);
    inverse_TextAttr;
    ClrEol;
    Write(' ');
    s1:=s;
    while s1<>'' do
      begin

        i:=1;
        while i+2<=Length(s1) do
          if (s1[i]=hotkey1) and (s1[i+2]=hotkey2) then
            Break
          else
            Inc(i);

        if i+2>=Length(s1) then i:=Length(s1)+1;

        Write(Copy(s1,1,i-1));
        Delete(s1,1,i-1);

        if s1='' then Break;


        TextAttr:=TextAttr xor $08;
        Write(Copy(s1,2,1));
        Delete(s1,1,Length('(k)'));
        TextAttr:=TextAttr xor $08;

      end;
  end;}

procedure statusline(const s:string);
  const
    hotkey      :char='`';
  var
    i           :word;
    s1          :string;
  begin
    GotoXY(1,Hi(WindMax)+1);
    inverse_TextAttr;
    ClrEol;
    Write(' ');
    s1:=s;
    while s1<>'' do
      begin

        i:=Pos(hotkey,s1);
        if i=0 then i:=Length(s1)+1;
        Write(Copy(s1,1,i-1));
        Delete(s1,1,i-1);

        if s1='' then Break;


        TextAttr:=TextAttr xor $08;
        Delete(s1,1,Length(hotkey));

      end;
  end;


procedure ClrScrC(a:byte);
  const
    blink_data:viointensity=
  (cb   :sizeof(viointensity);
   rtype:2; (* Blink/bright *)
   fs   :1);   (* bright background *)
  begin
    TextAttr:=a;
    ClrScr;
    VioSetState(blink_data,0)
  end;

procedure wait_for_key;
  begin
    Write(textz__press_a_key_to_continue_^);
    repeat
      SysReadKey2;
    until not SysKeyPressed2;
    WriteLn;
  end;

procedure Error_Wait;
  begin
    SysBeepEx(1000,2000);
    Write(textz__press_a_key_to_quit_^);
    repeat
      SysReadKey2;
    until not SysKeyPressed2;
    WriteLn;
  end;

function errordescription(e:longint):string;
  {$IfDef VirtualPascal}
  var
    buffer              :array[0..512] of char;
    msglen              :word;
    message_start       :PChar;
    wrap                :word;
  {$EndIf VirtualPascal}
  begin
    case e of
       13:errordescription:=textz_err_13^;
       21:errordescription:=textz_err_21^;
       32:errordescription:=textz_err_32^;
       50:errordescription:=textz_err_50^;
       87:errordescription:=textz_err_87^;
       99:errordescription:=textz_err_99^;
      107:errordescription:=textz_err_107^;
      108:errordescription:=textz_err_108^;
      217:errordescription:=textz_err_217^;
      303:errordescription:=textz_err_303^;
      305:errordescription:=textz_err_305^;
    else
      {$IfDef VirtualPascal}
      FillChar(buffer,SizeOf(buffer),0);
      SysGetSystemError(e,buffer,SizeOf(buffer),msglen);
      if msglen>0 then
        begin
          msglen:=Min(High(buffer),msglen);
          while (msglen>0) and (buffer[msglen-1] in [#13,#10,' ',#9,'.']) do
            Dec(msglen);
          buffer[msglen]:=#0;
          message_start:=@buffer[0];
          if StrLComp(@('SYS'+Int2StrZ(e,4)+#0)[1],message_start,3+4)=0 then
            begin
              Inc(message_start,3+4);
              while message_start[0] in [' ',':'] do Inc(message_start);
            end;
          Result:=' ('+StrPas(message_start)+')';
          repeat
            wrap:=Pos(#13#10,Result);
            if wrap=0 then Break;
            Delete(Result,wrap,1);
            Result[wrap]:=' ';
          until false;
        end
      else
      {$EndIf VirtualPascal}
        errordescription:='';
    end;
  end;

function rc_errordescription(e:longint):string;
  begin
    Result:=', rc='+Int2Str(e)+errordescription(e);
  end;

function UpCase2(const c:char):char;
  var
    a                   :array[0..1] of char;
  begin
    a[0]:=c;
    a[1]:=#0;
    SysUpperCase(a);
    Result:=a[0];
  end;

procedure UpCase2Str(var s:string);
  var
    a                   :array[0..256] of char;
  begin
    StrPCopy(a,s);
    SysUpperCase(a);
    s:=StrPas(a);
  end;

const
  writel_sem:longint=0;

procedure WriteLnBlock(const s:string);
  begin
    SysSysWaitSem(writel_sem);
    WriteLn(s);
    writel_sem:=0;
  end;

var
  kki                   :KbdKeyInfo;

function SysReadKey2:smallword;
  begin
    KbdCharIn(kki,0,0);
    with kki do
      if Odd(fbStatus shr 1) then (* extended key code *)
        case chScan of
          $3b..$44:Result:=$100+ 1+chScan-$3b; (* F1..F10 *)
          $85..$86:Result:=$100+10+chScan-$85; (* F11..F12 *)
        else       Result:=0;
        end
      else (* character *)
        Result:=Ord(chChar)
  end;

function SysReadKey2UpCase:smallword;
  begin
    Result:=SysReadKey2;
    if Result<$100 then
      Result:=Ord(Upcase2(Chr(Result)));
  end;

function SysKeyPressed2:boolean;
  begin
    KbdPeek(kki,0);
    with kki do
      Result:=(fbStatus and kbdtrf_Final_Char_In)<>0;
  end;

function String2KeyUpCase(const s:string):word;
  begin

    if Length(s)=1 then
      Result:=Ord(UpCase2(s[1]))

    else
    if  (Length(s)=Length('F1'))
    and (UpCase(s[1])='F')
    and (s[2] in ['1'..'9']) then
      Result:=$100+ 1+Ord(s[2])-Ord('1')

    else
    if  (Length(s)=Length('F12'))
    and (UpCase(s[1])='F')
    and (s[2]='1')
    and (s[3] in ['0'..'2']) then
      Result:=$100+10+Ord(s[3])-Ord('0')

    else
    if  (Length(s)=Length('ESC'))
    and (UpCase(s[1])='E')
    and (UpCase(s[2])='S')
    and (UpCase(s[3])='C') then
      Result:=Ord(#27)

    else
      Result:=0;

  end;

procedure leer_filter(var s:string);
  begin
    while (s<>'') and (s[Length(s)] in [' ',#9]) do Delete(s,Length(s),1);
    while (s<>'') and (s[1        ] in [' ',#9]) do Delete(s,1        ,1);
  end;

end.
