{&Use32+}
unit lmenu;

interface

type
  menu_line     =
    packed record
      key       :word; (* $00..$ff=ascii char,$101..$10c=F1..F12 *)
      title     :string[40];
      call      :string[255];
      param     :string[255];
    end;

var
  menu_array    :array[1..23] of menu_line;

procedure load_menu_list;

implementation

uses
  Dos,
  cad_pops,
  spr2_aus,
  helper;

procedure load_menu_list;

  function load_menu_list_file(const fn:string):boolean;
    var
      mnu               :text;
      l                 :string;
      i,j               :word;

    function read_string:string;
      var
        s               :char;
        i               :word;
      begin
        leer_filter(l);
        if l='' then
          Result:=''
        else
          begin
            if l[1] in ['"',''''] then
              begin
                s:=l[1];
                Delete(l,1,1);
              end
            else
              s:=' ';
            i:=Pos(s,l);
            if i=0 then i:=Length(l)+1;
            Result:=Copy(l,1,i-1);
            Delete(l,1,i);
          end;
      end;

    function read_number:integer;
      var
        s1              :string;
        kontrolle       :integer;
      begin
        s1:=read_string;
        if s1='' then
          read_number:=0
        else
          begin
            Val(s1,Result,kontrolle);
            if kontrolle<>0 then
              Result:=0;
          end;
      end;

    function read_keydefinition:smallword;
      var
        s1              :string;
      begin
        s1:=read_string;

        if s1='@cmd' then
          s1:=textz_popup_key_cmd^
        else
        if s1='@top' then
          s1:=textz_popup_key_top^
        else
        if s1='@unmount' then
          s1:=textz_popup_key_unmount^
        else
        if s1='@mount' then
          s1:=textz_popup_key_mount^
        else
        if s1='@wps_reset' then
          s1:=textz_popup_key_wpsreset^
        else
        if s1='@process_list' then
          s1:=textz_popup_key_processlist^
        else
        if s1='@esc' then
          s1:=textz_popup_key_esc^
        else
        if s1='@exit' then
          s1:=textz_popup_key_exit^
        else
        if s1='@reboot' then
          s1:=textz_popup_key_reboot^;

        Result:=String2KeyUpCase(s1);
      end;


    begin
      load_menu_list_file:=false;
      Assign(mnu,fn);
      {$I-}
      Reset(mnu);
      {$I+}
      if IOResult<>0 then Exit;

      while not Eof(mnu) do
        begin
          ReadLn(mnu,l);
          if (l='') or (l[1] in [';','%','#']) then Continue;

          repeat
            i:=Pos(#9,l);
            if i=0 then Break;

            Delete(l,i,1);
            repeat
              Insert(' ',l,i);
              Inc(i);
            until (i mod 8)=1;

          until false;

          (* line number ' ' key ' ' '"' title '"' ' ' '"' action '"' ' ' '"' paraneter '"' *)
          i:=read_number;
          if (i<Low(menu_array)) or (i>High(menu_array)) then
            begin
              WriteLn(textz_Line_number_is_invalid^,i);
              Error_Wait;
              Halt(99);
            end;

          with menu_array[i] do
            begin

              if (key<>0) or (title<>'') or (call<>'') or (param<>'') then
                begin
                  WriteLn(textz_Menu_line_already_defined^,i);
                  Error_Wait;
                  Halt(99);
                end;

              key:=read_keydefinition;
              title:=read_string;
              call:=read_string;
              param:=read_string;

              if title='@cmd' then
                begin
                  title:=textz_popup_cmd^;
                  call:=GetEnv('COMSPEC');
                  param:='/k (echo.)&&(echo '+textz_Type_Exit_to_return_to_CAD_popup_^+')';
                end
              else
              if call='@cmd' then
                begin
                  call:=GetEnv('COMSPEC');
                  param:='/k (echo.)&&(echo '+textz_Type_Exit_to_return_to_CAD_popup_^+')';
                end
              else
              if title='@top' then
                begin
                  title:=textz_popup_top^;
                  call:='TOP.EXE';
                  param:='';
                end
              else
              if call='@top' then
                begin
                  call:='TOP.EXE';
                  param:='';
                end
              else
              if title='@unmount' then
                begin
                  call:=title;
                  title:=textz_popup_unmount^;
                end
              else
              if title='@mount' then
                begin
                  call:=title;
                  title:=textz_popup_mount^;
                end
              else
              if title='@wps_reset' then
                begin
                  call:=title;
                  title:=textz_popup_wpsreset^;
                end
              else
              if title='@process_list' then
                begin
                  call:=title;
                  title:=textz_popup_processlist^;
                end
              else
              if title='@reboot' then
                begin
                  call:=title;
                  title:=textz_popup_reboot^;
                end
              else
              if title='@exit' then
                begin
                  call:=title;
                  title:=textz_popup_exit^;
                end
              else
              if title='@esc' then
                begin
                  call:=title;
                  title:=textz_popup_esc^;
                end
            end;
        end;

      Close(mnu);

      for i:=Low(menu_array) to High(menu_array) do
        with menu_array[i] do
          if (key=0)
          and ((title<>'') or (call<>'') or (param<>'')) then
            begin
              WriteLn(textz_Invalid_menu_definition_for_line^,i);
              Error_Wait;
              Halt(99);
            end;

      for i:=Low(menu_array) to High(menu_array)-1 do
        if menu_array[i].key<>0 then
          for j:=i+1 to High(menu_array) do
            if menu_array[i].key=menu_array[j].key then
              begin
                WriteLn(StrFormat2(textz_equal_key_used_for_menu_definition_lines^,StrF(i),StrF(j)));
                Error_Wait;
                Halt(99);
              end;

      load_menu_list_file:=true;
    end;

  var
    mnu_dir             :DirStr;
    mnu_name            :NameStr;
    mnu_ext             :ExtStr;

  begin
    FillChar(menu_array,SizeOf(menu_array),0);
    FSplit(ParamStr(0),mnu_dir,mnu_name,mnu_ext);
    if DebugHook then
      mnu_dir:='c:\v\cadh\cadh.vk\exe\';
    mnu_ext:='.mnu';
    if not load_menu_list_file(GetEnv('HOME')+'\'+mnu_name+mnu_ext) then
      if not load_menu_list_file(mnu_dir+mnu_name+mnu_ext) then
        begin
          WriteLn(textz_can_not_load_cad_pop_mnu^);
          Error_Wait;
          Halt(99);
        end;
  end;


end.

