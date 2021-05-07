{&Use32+}
unit param;

(* evalute config file and command line parameters *)

interface

uses
  cadh;

var
  no_sound      :boolean=true;
  no_cadh       :boolean=false;
  event_rec     :register_eventsem_param=(Sem:0;Event:7;Event_Mask:$ff;Argument:0;Argument_Mask:0);
  confirm_reboot:boolean=true;
  confirm_remove:boolean=true;
  password      :string='';
  textmode_columns:word=0;
  textmode_lines:word=0;
  TextAttrMain  :byte=$1e;
  TextAttrUtil  :byte=$30;
  TextAttrCMD   :byte=$07;



procedure process_commandline;
procedure read_config_file;

implementation

uses
  Dos,
  helper,
  VpUtils;

procedure show_help;
  begin
    WriteLn('CAD_POP.EXE [/NoSound] [/NoCadH] [/Event:$07,$ff,0,0]');
    Error_Wait;
    Halt(99);
  end;

procedure parse_configuration(z:string);

  function Pos2(const s1,s2:string):word;
    var
      p1,p2             :word;
    begin
      p1:=Pos(s1,z);
      p2:=Pos(s2,z);
      if p1=0 then p1:=p2;
      if p2=0 then p2:=p1;
      Result:=Min(p1,p2);
    end;

  var
    anfang              :string;
    p1                  :word;
    k                   :integer;

  procedure Fehler(const s:string);
    begin
      WriteLn(s);
      Error_Wait;
    end;

  procedure werte_boolean(var b:boolean);
    begin
      if (z='0') or (z='-') then
        b:=false
      else
      if (z='1') or (z='+') then
        b:=true
      else
      if z='' then
        b:=not b
      else
        Fehler(anfang+' - '+z+'?');
    end;

  begin
    p1:=Pos2(':','=');
    if p1=0 then
      begin
        anfang:=z;
        z:='';
      end
    else
      begin
        anfang:=Copy(z,1,p1-1);
        Delete(z,1,p1);
      end;

    UpCase2Str(anfang);
    leer_filter(anfang);
    leer_filter(z);

    if anfang='?' then
      show_help

    else
    if anfang='NOSOUND' then
      werte_boolean(no_sound)

    else
    if anfang='NOCADH' then
      werte_boolean(no_cadh)

    else
    if anfang='EVENT' then
      begin
        p1:=Pos(',',z);
        if p1=0 then Fehler('EVENT - '+z+'?');
        Val(Copy(z,1,p1-1),event_rec.Event,k);
        if k<>0 then Fehler('EVENT - '+z+'?');
        Delete(z,1,p1);

        p1:=Pos(',',z);
        if p1=0 then Fehler('EVENT - '+z+'?');
        Val(Copy(z,1,p1-1),event_rec.Event_Mask,k);
        if k<>0 then Fehler('EVENT - '+z+'?');
        Delete(z,1,p1);

        p1:=Pos(',',z);
        if p1=0 then Fehler('EVENT - '+z+'?');
        Val(Copy(z,1,p1-1),event_rec.Argument,k);
        if k<>0 then Fehler('EVENT - '+z+'?');
        Delete(z,1,p1);

        p1:=Pos(',',z);
        if p1<>0 then Fehler('EVENT - '+z+'?');
        Val(z,event_rec.Argument_Mask,k);
        if k<>0 then Fehler('EVENT - '+z+'?');
      end

    else
    if anfang='PASSWORD' then
      password:=z

    else
    if anfang='CONFIRM_REBOOT' then
      werte_boolean(confirm_reboot)

    else
    if anfang='CONFIRM_REMOVE' then
      werte_boolean(confirm_remove)

    else
    if anfang='TEXTMODE_LINES' then
      begin
        Val(z,textmode_lines,k);
        if k<>0 then Fehler('TEXTMODE_LINES - '+z+'?');
      end

    else
    if anfang='TEXTMODE_COLUMNS' then
      begin
        Val(z,textmode_columns,k);
        if k<>0 then Fehler('TEXTMODE_COLUMNS - '+z+'?');
      end

    else
    if anfang='TEXTATTRMAIN' then
      begin
        Val(z,TextAttrMain,k);
        if k<>0 then Fehler('TextAttrMain - '+z+'?');
      end

    else
    if anfang='TEXTATTRUTIL' then
      begin
        Val(z,TextAttrUtil,k);
        if k<>0 then Fehler('TextAttrUtil - '+z+'?');
      end

    else
    if anfang='TEXTATTRCMD' then
      begin
        Val(z,TextAttrCMD,k);
        if k<>0 then Fehler('TextAttrCMD - '+z+'?');
      end

    else
      begin
        WriteLn(anfang+':'+z);
        show_help;
      end;

  end;

procedure process_commandline;
  var
    i                   :longint;
    ParamStr_i          :string;
  begin
    for i:=1 to ParamCount Do
      begin
        ParamStr_i:=ParamStr(i);
        if ParamStr_i='' then show_help;
        if not (ParamStr_i[1] in ['-','/']) then show_help;
        Delete(ParamStr_i,1,1);
        parse_configuration(ParamStr_i);
      end;
  end;

function read_config_file2(const fn:string):boolean;
  var
    cfg                 :text;
    z                   :string;
    i                   :word;
  begin
    Result:=false;
    Assign(cfg,fn);
    TextModeRead:=$40;
    {$I-}
    Reset(cfg);
    {$I+}
    if IOResult<>0 then Exit;
    while not Eof(cfg) do
      begin
        ReadLn(cfg,z);
        for i:=1 to Length(z) do if z[i]<' ' then z[i]:=' ';
        leer_filter(z);
        if z<>'' then
          if not (z[1] in [';','#','%']) then
            parse_configuration(z);
      end;
    Result:=true;
    Close(cfg);
  end;

procedure read_config_file;
  var
    cfg_dir             :DirStr;
    cfg_name            :NameStr;
    cfg_ext             :ExtStr;

  begin
    FSplit(ParamStr(0),cfg_dir,cfg_name,cfg_ext);
    if DebugHook then
      cfg_dir:='c:\v\cadh\cadh.vk\';
    cfg_ext:='.cfg';
    if not read_config_file2(GetEnv('HOME')+'\'+cfg_name+cfg_ext) then
      if not read_config_file2(cfg_dir+cfg_name+cfg_ext) then
        ; (* optional *)

  end;

end.


