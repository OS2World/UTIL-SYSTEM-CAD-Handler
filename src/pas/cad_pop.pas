program cad_popup;

{&Use32+}
{$IfNDef Debug}
{&PMType NoVIO}
{$EndIf Debug}

(* 2003.04.05 Veit Kannegieser - primitive, but working version.
                                 by executing external programs...
                                 nolist - hide/unhide
                                 go - try to jump back to previous program after popup
                                 top - show & kill
   2003.04.06                  - replaced nolist.exe with Win*SwitchEntry
                                 replaced go.exe with VioPopup - documentation says that Exec is not permitted?
                                 ReadLn->SysReadKey

   2003.04.15                  - implemented menu,switch list,un/re mount

   2003.05.19                  - cosmetical corections, colour, translation
                                 warpin, rexx-problems
   2003.06.19                  - exec/init error handling

   2003.07.20                  - WindMax problems if detached during crt init
                               - process list (like pstat/go/ps/..) merged
                                 with switchlist, hide list
   2003.07.21                  - process list filter switchable ('F')

   2004.08.18                  - menu configurable, restore switch list

   2004.08.31                  - nl translation by Jan van der Heide
                               - corrected handling of non-printable
                                 keys in menu (example: Delete)

   2004.09.09                  - block during writeln for unmount/remount
                               - fallback to system error messages

   2004.12.06                  - ru translation, exclude FAT32
   2005.01.15                  - DosSetPriority ProcessTree+TimeCritical

   2005.02.11                  - /Event... option
                               - cfg file, confirm, password, text modes
                               - function keys
                               ? message queue

   2005.05.11                  - global NO_PM define to test with
                                 protshell=cmd.exe
                               - replaced DOSCALLS.DLL usage with DOSCALLS.

                               - tw translation

   2005.05.20                  - updated to tw translation 2005.05.16
   2005.05.26                  - updated to tw translation 2005.05.21
   2005.06.11                  - fr translation
   2005.06.12                  - fr translation updated
                                 use color coded keys in menu status line
   2005.06.13 - Eberhard 60    - updated dutch and russian translation
   2005.06.16                  - updated italian translation
   2006.01.31                  - added es translation

 *)


{-$Define NO_PM}


uses
  Crt,
  Dos,
  Os2Base,
  Os2Def,
  {$IfNDef NO_PM}
  Os2PmApi,
  {$EndIf NO_PM}
  PList,
  LMenu,
  helper,
  Strings,
  VpSysLow,
  VpUtils,
  WinDos,
  cad_pops,
  spr2_aus,
  CadH,
  Param,
  ShutKill;

var
  cad_Tib       :PTib;
  cad_Pib       :PPib;
  rc            :ApiRet;
  devicehandle  :longint;
  eventsem      :HEv;
  para_len      :longint;
  postcount     :longint; (* ignored *)
  terminate     :boolean                =false;
  popupoptions  :smallword;
  {$IfNDef NO_PM}
  handleswitch  :LHandle;
  switchdata    :SwCntrl;
  {$EndIf NO_PM}
  program_detached:boolean;
  first_beep    :boolean=true;
  x00           :word=0; (* text mode correction to center items as in 80*25 full *)
  y00           :word=0;

const
  datum         ='2006.01.31';

  drive_open_errors_exit=[msg_Error_Not_Ready,
                          msg_Net_Req_Not_Support,      // RAMFS.IFS
                          msg_Invalid_Drive,
                          msg_Drive_Not_Ready,          // no media (A:)
                          msg_Disk_Change];             // does not exist (B:)

  driver_open_mode=
     open_flags_Write_Through
    +open_flags_Fail_On_Error
    +open_flags_No_Cache
    +open_flags_No_Locality
    +open_flags_NoInherit
    +open_share_DenyNone
    +open_access_ReadOnly;

function confirm(const t:string):boolean;
  var
    c                   :word;
    y,n                 :char;
  begin
    y:=textz_key_yes^[1];
    n:=textz_key_no^[1];
    ClrScrC(TextAttrMain);
  //statusline(t+' '+y+'/'+n+' ? ');
    statusline(t+' '+textz_ask_yes_no^+' ? ');
    y:=UpCase2(y);
    n:=UpCase2(n);
    repeat
      c:=SysReadKey2Upcase;
      if (c=Ord(y)) or (c=Ord(^m)) then
        begin
          Result:=true;
          Break;
        end
      else
      if (c=Ord(n)) or (c=Ord(#27)) then
        begin
          Result:=false;
          Break;
        end
    until false;
    statusline('');
  end;

function open_drive(drv:char;var handle:longint):ApiRet;
  begin
    open_drive:=SysFileOpen(@(drv+':'#0)[1],open_flags_Dasd+open_flags_Fail_On_Error+open_share_DenyReadWrite+open_flags_NoInherit,handle);
  end;

function lock_drive(handle:longint):ApiRet;
  var
    para,data:byte;
    para_len,data_len:longint;
  begin
    para:=0;
    para_len:=SizeOf(para);
    data:=0;
    data_len:=SizeOf(data);
    lock_drive:=
      DosDevIOCtl(handle,ioctl_Disk,dsk_LockDrive,
        @para,para_len,@para_len,
        @data,data_len,@data_len);
  end;

function unlock_drive(handle:longint):ApiRet;
  var
    para,data:byte;
    para_len,data_len:longint;
  begin
    para:=0;
    para_len:=SizeOf(para);
    data:=0;
    data_len:=SizeOf(data);
    unlock_drive:=
      DosDevIOCtl(handle,ioctl_Disk,dsk_UnlockDrive,
        @para,para_len,@para_len,
        @data,data_len,@data_len);
  end;

function check_filesystem(drv:char):boolean;
  var
    Fsq_Buffer2         :
      record
        case boolean of
          0:(r          :FsqBuffer2);
          1:(b          :array[0..511] of byte);
      end;
    Fsq_Buffer2_len     :ULong;
    fsname              :string;
  begin
    Result:=false;

    (* retrieve filesystem type *)
    Fsq_Buffer2_len:=SizeOf(Fsq_Buffer2);
    if DosQueryFSAttach(@(drv+':'#0)[1],0,fsail_QueryName,@Fsq_Buffer2,Fsq_Buffer2_len)<>0 then
      Exit;
    with Fsq_Buffer2.r do
    fsname:=StrPas(szFSDName+cbName);

    (* FAT32 can be opned,locked, but then beginformat fails.
       because of cache??. Solution: skip FAT32.. *)

    if fsname='FAT32' then Exit;

    (* unmount makes no sense for CDROM.. *)
    (* UDF.. not sure. can a HD partition formated using UDF? *)
    if fsname='CDFS' then Exit;

    Result:=true;
  end;

function unmount_tf(Parameter: Pointer): Longint;
  var
    rc                  :longint;
    volume_handle       :longint;
    drv                 :char;
    para                :char;
    data                :byte;
    para_len,
    data_len            :longint;
  begin
    drv:=Chr(longint(Parameter));

    if DebugHook and (drv in ['C','Y']) then Exit; (* bad debugging whithout source *)

    if not check_filesystem(drv) then
      begin
        rc:=SysFileClose(volume_handle);
        Exit;
      end;

    (* open *)
    rc:=open_drive(drv,volume_handle);

    if rc in drive_open_errors_exit  then
      Exit; (* drive does not exist *)

    if rc<>0 then
      begin
        WriteLnBlock(StrFormat1(textz_Can_not_open_volume^,drv)+rc_errordescription(rc)+'.');
        Exit;
      end;

    (* lock *)
    rc:=lock_drive(volume_handle);

    if rc=msg_Drive_Locked then
      begin
        SysCtrlSleep(1500);
        WriteLnBlock(StrFormat1(textz_Drive_has_open_files_trying_to_unlock_executables^,drv));
        unlock_executable_modules(drv);
        rc:=lock_drive(volume_handle);
      end;

    if rc<>0 then
      begin
        WriteLnBlock(StrFormat1(textz_Can_not_lock_volume^,drv)+rc_errordescription(rc)+'.');
        rc:=SysFileClose(volume_handle);
        Exit;
      end;

    (* beginformat *)
    para:=#0;
    para_len:=SizeOf(para);
    data:=0;
    data_len:=SizeOf(data);
    rc:=
      DosDevIOCtl(volume_handle,ioctl_Disk,dsk_BeginFormat, (* dsk_UnlockEjectMedia?? *)
        @para,para_len,@para_len,
        @data,data_len,@data_len);
    if rc=0 then
      WriteLnBlock(StrFormat1(textz_Unmounted^,drv))
    else
      WriteLnBlock(StrFormat1(textz_Beginformat_for_failed^,drv)+rc_errordescription(rc)+'.');

    (* unlock *)
    rc:=unlock_drive(volume_handle);

    (* close *)
    rc:=SysFileClose(volume_handle);
  end;

function remount_tf(Parameter: Pointer): Longint;
  var
    rc                  :longint;
    volume_handle       :longint;
    drv                 :char;
    para,
    data                :byte;
    para_len,
    data_len            :longint;
  begin

    drv:=Chr(longint(Parameter));

    (* open *)
    rc:=open_drive(drv,volume_handle);
    if rc in drive_open_errors_exit then
      Exit; (* drive does not exist *)

    if not check_filesystem(drv) then
      begin
        rc:=SysFileClose(volume_handle);
        Exit;
      end;

    if rc<>0 then
      begin
        WriteLnBlock(StrFormat1(textz_Can_not_open_volume^,drv)+rc_errordescription(rc)+'.');
        Exit;
      end;

    (* lock *)
    rc:=lock_drive(volume_handle);
    if rc<>0 then
      begin
        WriteLnBlock(StrFormat1(textz_Can_not_lock_volume^,drv)+rc_errordescription(rc)+'.');
        rc:=SysFileClose(volume_handle);
        Exit;
      end;

    (* redetermine media *)
    para:=0;
    para_len:=SizeOf(para);
    data:=0;
    data_len:=SizeOf(data);
    rc:=
      DosDevIOCtl(volume_handle,ioctl_Disk,dsk_RedetermineMedia,
        @para,para_len,@para_len,
        @data,data_len,@data_len);
    if rc=0 then
      WriteLnBlock(StrFormat1(textz_Remounted_successful^,drv))
    else
      WriteLnBlock(StrFormat1(textz_Redetermine_media_for_failed^,drv)+rc_errordescription(rc)+'.');

    (* unlock *)
    rc:=unlock_drive(volume_handle);

    (* close *)
    rc:=SysFileClose(volume_handle);
  end;


procedure unmount;
  var
    l                   :char;
    tid                 :longint;
  begin
    for l:='A' to 'Z' do
      begin
        BeginThread(nil,16*1024,unmount_tf,Ptr(Ord(l)),0,tid);
        SysCtrlSleep(0);
      end;

    SysCtrlSleep(2500);
    wait_for_key;
  end;

procedure remount;
  var
    l                   :char;
    tid                 :longint;
  begin
    for l:='A' to 'Z' do
      begin
        BeginThread(nil,16*1024,remount_tf,Ptr(Ord(l)),0,tid);
        SysCtrlSleep(0);
      end;

    SysCtrlSleep(2500);
    wait_for_key;
  end;

procedure wps_reset; (* like the XWP-function *)
  {$IfNDef NO_PM}
  var
    profile             :PRFPROFILE;
    username,sysname    :array[0..260] of char;
    rc                  :ApiRet;
  {$EndIf NO_PM}
  begin
    {$IfDef NO_PM}
    WriteLn('not implemented in NO_PM test version.');
    {$Else NO_PM}
    FillChar(profile,SizeOf(profile),0);
    FillChar(username,SizeOf(username),0);
    FillChar(sysname,SizeOf(sysname),0);
    PrfQueryProfile(0,@profile);
    with profile do
      begin
        pszUserName :=@username;
        pszSysName  :=@sysname;
      end;
    if not PrfQueryProfile(0,@profile) then
      WriteLn(textz_PrfQueryProfile_failed_error^,WinGetLastError(0),'.')
    else
    if not PrfReset(0,@profile) then
      WriteLn(textz_PrfReset_failed_error^,WinGetLastError(0),'.')
    else
      WriteLn(textz_prfreset_Success^);
    {$EndIf NO_PM}

    SysCtrlSleep(2000);
    wait_for_key;
  end;

procedure reboot;
  var
    rc                  :ApiRet;
    dos_sys             :longint;
  begin
    rc:=SysFileOpen('\DEV\DOS$',driver_open_mode,dos_sys);
    if rc<>0 then
      WriteLn(textz_kann_DOS_SYS_nicht_oeffnen^)
    else
      begin
        rc:=DosDevIOCtl(dos_sys,$d5,$ab,
                        nil,0,nil,
                        nil,0,nil);
        if rc<>0 then
          begin
            WriteLn('DosDevIOCtl:',rc);
            WriteLn(errordescription(rc));
          end;

        SysFileClose(dos_sys);
      end;

    wait_for_key;
  end;

procedure kill(pid:longint;hard:boolean);
  var
    rc                  :ApiRet;
    fastio_handle       :longint;
    para                :smallword;
    para_len            :longint;
  begin
    if hard then
      begin
        rc:=SysFileOpen('\DEV\FASTIO$',driver_open_mode,fastio_handle);
        if rc=0 then
          begin
            para:=pid;
            para_len:=SizeOf(para);
            rc:=
              DosDevIOCtl(fastio_handle,$76,$65,
                @para,para_len,@para_len,
                nil  ,0       ,nil      );
            SysFileClose(fastio_handle);
            if rc=0 then Exit;

            WriteLn(textz_Failed^+rc_errordescription(rc)+'.');
            wait_for_key;
          end
        else
          begin
            rc:=SysFileOpen(cadh_drivername,driver_open_mode,fastio_handle);
            if rc=0 then
              begin
                para:=pid;
                para_len:=SizeOf(para);
                rc:=
                  DosDevIOCtl(fastio_handle,
                    cadh_ioctl_category,
                    cadh_ioctl_kill_proc,
                    @para,para_len,@para_len,
                    nil  ,0       ,nil      );
                SysFileClose(fastio_handle);
                if rc=0 then Exit;

                WriteLn(textz_Failed^+rc_errordescription(rc)+'.');
                wait_for_key;
              end
            else
              begin
                WriteLn(textz_xf86sup_sys_not_loaded_hard_kill_not_available^);
                wait_for_key;
              end;
          end;
        WriteLn(textz_Trying_DosKillProcess_^);
      end;

    rc:=DosKillProcess(dkp_Process,pid);
    if rc=0 then Exit;

    WriteLn(textz_Failed^+rc_errordescription(rc)+'.');
    wait_for_key;
  end;

procedure switchlist;
  type
    switch_block_type   =
      record
        cswentry        :longint;
        {$IfDef NO_PM}
        aswentry        :array[1..1] of byte
        {$Else NO_PM}
        aswentry        :array[1..10000] of SwEntry;
        {$EndIf NO_PM}
      end;
  var
    pid,e,i             :longint;
    rc                  :longint;
    line                :longint;
    key                 :word;
    processname         :string;
    check               :longint;
    buffersize          :longint;
    switch_block        :^switch_block_type;
    orgattr             :byte;
    num_processed       :longint;
    processed           :boolean;
    pl_index            :word;
  begin
    orgattr:=TextAttr;
    switch_block:=nil;
    repeat
      ClrScrC(orgattr);
      {$IfDef NO_PM}
      e:=0;
      {$Else NO_PM}
      e:=WinQuerySwitchList(0,nil,0);
      {$EndIf NO_PM}
      buffersize:=SizeOf(switch_block^.cswentry)+e*SizeOf(switch_block^.aswentry[1]);
      if switch_block<>nil then
        Dispose(switch_block);
      GetMem(switch_block,buffersize);
      {$IfDef NO_PM}
      FillChar(switch_block^,buffersize,0);
      {$Else NO_PM}
      WinQuerySwitchList(0,PSwbLock(switch_block),buffersize);
      {$EndIf NO_PM}
      if process_list<>nil then
        free_processlist;
      get_processlist;

      (* try to assign witch list entries a bit smarter *)
      {$IfNDef NO_PM}
      with switch_block do
        for e:=1 to cswentry do
          with aswentry[e].swctl do
            if (idSession>1) and (idSession<$ff0) then
              for i:=1 to process_list_count do
                if idSession=process_list^[i].pl_sgid then
                  if idProcess<process_list^[i].pl_pid then
                    if not search_in_hide_list(process_list^[i].pl_pname) then
                      begin
                        idProcess:=process_list^[i].pl_pid;
                        if StrLComp('FC/2: ',szSwtitle,Length('FC/2: '))=0 then
                          if not (Pos('FC.',process_list^[i].pl_pname)=1) then
                            idProcess:=0; // hide switch list entry
                      end;
      {$EndIf NO_PM}

      (* loop for all pid, then look for switch entrys *)
      line:=1;
      with switch_block do
        for pid:=1 to $ffff do
          begin
            processed:=false;
            pl_index:=-1;
            for i:=1 to process_list_count do
              if process_list^[i].pl_pid=pid then
                begin
                  pl_index:=i;
                  Break;
                end;

            (* process exist, and in hide list -> skip pid *)
            if pl_index<>-1 then
              if search_in_hide_list(process_list^[pl_index].pl_pname) then
                Continue;

            {$IfNDef NO_PM}
            (* search in switchlist *)
            for e:=1 to cswentry do
              with aswentry[e].swctl do
                begin
                  if idProcess<>pid then Continue;
                  processed:=true;

                  (* maybe ignore this window? *)
                  if search_in_hide_list(StrPas(szSwtitle)) then Continue;

                  if line=Hi(WindMax) then
                    wait_for_key;

                  Write(idProcess:5,' ');
                  if (uchVisibility and swl_Invisible)=0 then
                    Write('     ')
                  else
                    Write(textz_Inv__^);

                  case bProgType of
                    ssf_Type_Default      :Write('    ');
                    ssf_Type_FullScreen   :Write('FS  ');
                    ssf_Type_WindowableVio:Write('VIO ');
                    ssf_Type_Pm           :Write('PM  ');
                    ssf_Type_Vdm          :Write('VDM ');
                    ssf_Type_Group        :Write('GRP ');
                    ssf_Type_Dll          :Write('DLL ');
                    ssf_Type_WindowedVdm  :Write('WVM ');
                    ssf_Type_Pdd          :Write('PDD ');
                    ssf_Type_Vdd          :Write('VDD ');
                  else                     Write(Int2Hex(bProgType,3),' ');
                  end;

                  Write(szSwtitle);
                  WriteLn;
                  Inc(line);
                end;
            {$EndIf NO_PM}

            (* process present, but no switchlist entry *)
            if (not processed) and (pl_index<>-1) then
              with process_list^[pl_index] do
                begin
                  if line=Hi(WindMax) then
                    wait_for_key;

                  Write(pl_pid:5,' ');
                  if pl_sgid=0 then
                    Write(textz_Inv__^)
                  else
                    Write('     '); (* PM/FS *)


                  case pl_type of (* from go.exe *)
                    0:Write('Sys ');
                    1:Write('VDM ');
                    2:Write('VIO ');
                    3:Write('PM  ');
                    4:Write('Det ');
                  else
                      Write(Int2Hex(pl_type,3),' ');
                  end;

                  Write(pl_pname);
                  WriteLn;
                  Inc(line);
                end;

          end; (* pid:=1 to $ffff *)

      statusline(textz_Esc_exit_R_refresh_C_Close_K_kill_process_H_hard_kill_^);
      key:=SysReadKey2UpCase;
      statusline('');

      if key=Ord(#27) then
        Break

      else
      if key=String2KeyUpCase(textz_processlist_key_refresh^) then
        begin
        end

      else
      if key=String2KeyUpCase(textz_processlist_key_filter^) then
        begin
          processfilter:=not processfilter;
        end

      else
      if (key=String2KeyUpCase(textz_processlist_key_close^))
      or (key=String2KeyUpCase(textz_processlist_key_kill^))
      or (key=String2KeyUpCase(textz_processlist_key_hardkill^)) then
        begin
            statusline(textz_process_id_or_name_^);
            ReadLn(processname);
            ClrScrC(orgattr);
            num_processed:=0;
            if processname='' then Continue;

            Val(processname,pid,check);

            {$IfNDef NO_PM}
            if key=String2KeyUpCase(textz_processlist_key_close^) then
              begin
                if check=0 then
                  begin (* C:NUM *)
                    with switch_block do
                      for e:=1 to cswentry do
                        with aswentry[e].swctl do
                          if idProcess=pid then
                            begin
                              WinSendMsg(hwnd,wm_close,0,0);
                              Inc(num_processed);
                            end
                  end
                else (* C:STRING *)
                  with switch_block do
                    for e:=1 to cswentry do
                      with aswentry[e].swctl do
                        if Pos(processname,szSwtitle)>0 then
                          begin
                            WinSendMsg(hwnd,wm_close,0,0);
                            Inc(num_processed);
                          end;
              end
            else (* K/H *)
            {$EndIf NO_PM}
              begin
                if check=0 then
                  begin (* K/H:NUM *)
                    kill(pid,key=String2KeyUpCase(textz_processlist_key_hardkill^));
                    Inc(num_processed);
                  end
                else (* K/H:STRING *)
                  begin
                    {$IfNDef NO_PM}
                    with switch_block do
                      for e:=1 to cswentry do
                        with aswentry[e].swctl do
                          if Pos(processname,szSwtitle)>0 then
                            begin
                              (* found in switchlist, do not kill again
                                 by process list entry *)
                              for i:=1 to process_list_count do
                                if idProcess=process_list^[i].pl_pid then
                                  process_list^[i].pl_pname:='';
                              kill(idProcess,key=String2KeyUpCase(textz_processlist_key_hardkill^));
                              Inc(num_processed);
                            end;
                    {$EndIf NO_PM}
                    for i:=1 to process_list_count do
                      with process_list^[i] do
                        if Pos(processname,pl_pname)>0 then
                          begin
                            kill(pl_pid,key=String2KeyUpCase(textz_processlist_key_hardkill^));
                            Inc(num_processed);
                          end;
                  end; (* K/H:STRING *)
              end; (* K/H *)

            if num_processed=0 then
              begin
                WriteLn(processname,textz__not_found^);
                wait_for_key;
              end
            else
              SysCtrlSleep(500);

        end; (* C K H *)


    until false;

    Dispose(switch_block);
    free_processlist;

  end;

function compare_password:boolean;
  var
    pw                  :string;
    t0,t1               :longint;
    c                   :word;
  begin

    if password='' then
      begin
        Result:=true;
        Exit;
      end;

    ClrScrC(TextAttrMain);
    statusline(StrFormat1(textz_password^,datum));

    t0:=SysSysMsCount;
    pw:='';
    Result:=false;

    while pw<>password do
      begin

        t1:=SysSysMsCount;
        if Abs(t0-t1)>15*1000 (* 15 seconds *) then
          Break;

        if not SysKeyPressed2 then
          begin
            SysCtrlSleep(30);
            Continue;
          end;

        c:=SysReadKey2;

        case Chr(c) of
          #27,^m:
            if pw='' then
              Break
            else
              pw:='';
          ^h:
            if pw<>'' then Delete(pw,Length(pw),1);
        else
          if (Ord(' ')<=c) or (c<=$ff) then
            pw:=pw+Chr(c);
        end;

      end;

    Result:=password=pw;
  end; (* compare_password *)

procedure popup_menu;
  var
    key                 :word;
    top_filename        :array[0..fsPathName] of Char;

  procedure handle_exec_errors;
    var
      rc                :longint;
    begin
      rc:=Dos.DosError;
      if rc<>0 then
        WriteLn(textz__Exec_DosError^+rc_errordescription(rc)+'.')
      else
        begin
          rc:=DosExitCode;
          if rc=255 then rc:=0;
          if (rc<>0) then
            WriteLn(textz__Exec_ExitCode^,rc);
        end;
      if rc<>0 then
        wait_for_key;
    end;

  var
    repaint             :boolean;
    exit_menu           :boolean;
    i                   :word;

  begin

    if not compare_password then
      begin
        ClrScrC(TextAttrCMD);
        Exit;
      end;

    exit_menu:=false;
    terminate:=false;
    repaint:=true;
    repeat
      if repaint then
        begin
          ClrScrC(TextAttrMain);
         {GotoXY(1,7);
          WriteLn(tb,' C ..... ',textz_popup_c^);
          WriteLn(tb,' T ..... ',textz_popup_t^);
          WriteLn;
          WriteLn(tb,' U ..... ',textz_popup_u^);
          WriteLn(tb,' M ..... ',textz_popup_m^);
          WriteLn;
          WriteLn(tb,' W ..... ',textz_popup_w^);
          WriteLn(tb,' L ..... ',textz_popup_l^);
          WriteLn;
          WriteLn(tb,' Esc ... ',textz_popup_esc^);
          WriteLn(tb,' X ..... ',textz_popup_x^);}
          for i:=Low(menu_array) to High(menu_array) do
            with menu_array[i] do
              if key<>0 then
                begin
                  GotoXY(x00+23,y00+i);
                  if key=27 then
                    Write(' Esc ')
                  else
                  if ($100+1<=key) and (key<=$100+9) then
                    Write(' F',key-$100,' .')
                  else
                  if ($100+10<=key) and (key<=$100+12) then
                    Write(' F1',key-$100-10,' ')
                  else
                    Write(' ',Chr(key),' ..');
                  Write('... ',title)
                end;
          statusline(StrFormat1(textz_CAD_Popup^,datum));
          repaint:=false;
        end;

      key:=SysReadKey2UpCase;
      if key<>0 then
        for i:=Low(menu_array) to High(menu_array) do
          if menu_array[i].key=key then
            with menu_array[i] do
              begin
                repaint:=true;

                if call='@unmount' then
                  begin
                    ClrScrC(TextAttrUtil);
                    unmount;
                  end

                else
                if call='@mount' then
                  begin
                    ClrScrC(TextAttrUtil);
                    remount;
                  end

                else
                if call='@wps_reset' then
                  begin
                    ClrScrC(TextAttrUtil);
                    wps_reset;
                  end

                else
                if call='@process_list' then
                  begin
                    ClrScrC(TextAttrUtil);
                    switchlist;
                  end

                else
                if call='@reboot' then
                  begin

                    if confirm_reboot then
                      if not confirm(textz_popup_reboot^) then
                        Continue;

                    ClrScrC(TextAttrUtil);
                    reboot;
                  end

                else
                if call='@exit' then
                  begin
                    if confirm_remove then
                      if not confirm(textz_popup_exit^) then
                        Continue;

                    ClrScrC(TextAttrCMD);
                    exit_menu:=true;
                    terminate:=true;
                  end

                else
                if call='@esc' then
                  begin
                    ClrScrC(TextAttrCMD);
                    exit_menu:=true;
                  end

                else (* EXEC *)
                  begin
                    ClrScrC(TextAttrCMD);
                    WriteLn;

                    if Pos('\',call)=0 then
                      FileSearch(top_filename,@(call+#0)[1],GetEnvVar('PATH'))
                    else
                      StrPCopy(top_filename,call);

                    if StrLen(top_filename)=0 then
                      begin
                        WriteLn(StrFormat1(textz__TOP_EXE_not_found_in_PATH^,call));
                        wait_for_key;
                      end
                    else
                      begin
                        Exec(StrPas(top_filename),param);
                        handle_exec_errors;
                      end;
                  end; (* EXEC *)

              end; (* menu_array[i] *)

    until exit_menu;
  end; (* popup_menu *)

procedure update_crt_variables(popup:boolean);
  var
    cols,rows,colours   :word;
  begin
    WindMin:=$0000;
    if popup or (not program_detached) then
      begin
        GetVideoModeInfo(cols,rows,colours);
        WindMax:=Pred(cols)+Pred(rows) shl 8;
      end
    else
      WindMax:=Pred(80)+Pred(25) shl 8;

    x00:=Max((Lo(WindMax)-79) div 2,0);
    y00:=Max((Hi(WindMax)-24) div 2,0);
  end;

procedure alter_textmode;
  var
    x,y,c               :word;
  begin
    GetVideoModeInfo(x,y,c);
    if textmode_columns=0 then textmode_columns:=x;
    if textmode_lines=0 then textmode_lines:=y;
    if (textmode_columns<>x) or (textmode_lines<>y) then
      SetVideoMode(textmode_columns,textmode_lines);
    GetVideoModeInfo(textmode_columns,textmode_lines,c);
    update_crt_variables(true);
  end;

procedure hide_session(const hide:boolean);
  begin
    {$IfDef NO_PM}

    {$Else NO_PM}
    WinQuerySwitchEntry(handleswitch,@switchdata);
    with switchdata do
      if hide then
        begin
          uchVisibility := swl_Invisible;
          fbJump := swl_NotJumpable;
        end
      else
        begin
          uchVisibility := swl_Visible;
          fbJump := swl_Jumpable;
        end;
    WinChangeSwitchEntry(handleswitch,@switchdata);
    {$EndIf NO_PM}
  end;

function uses_cad_hotkey:boolean;
  begin
    with event_rec do
      Result:=(Event=7) and (Event_Mask=$ff);
  end;

function uses_sm_hotkey:boolean;
  begin
    with event_rec do
      Result:=(Event=6) and (Event_Mask=$ff);
  end;

procedure wait_for_cad;
  begin

    rc:=SysFileOpen(cadh_drivername,driver_open_mode,devicehandle);
    if rc<>0 then
      begin
        WriteLn(textz_Can_not_open_CAD_hook_driver__^,rc,').');
        WriteLn(textz_Please_install_BaseDev_CADH_SYS^);
        WriteLn(textz_Or_maybe_the_program_is_already_running^);
        if errordescription(rc)<>'' then
          WriteLn(errordescription(rc));
        Error_Wait;
        Halt(rc);
      end;

    rc:=DosOpenEventSem('\SEM32\CAD_POP',eventsem);
    if rc<>0 then
      rc:=DosCreateEventSem('\SEM32\CAD_POP',eventsem,dc_Sem_Shared,false);
    if rc<>0 then
      begin
        WriteLn(textz_Can_not_create_event_semaphore__^,rc,').');
        if errordescription(rc)<>'' then
          WriteLn(errordescription(rc));
        Error_Wait;
        Halt(rc);
      end;

    event_rec.Sem:=eventsem;

    //DosSetPriority(prtys_Thread,prtyc_ForegroundServer,+31,0);
    DosSetPriority(prtys_ProcessTree, prtyc_TimeCritical, prtyd_Maximum, 0);
    DosGetInfoBlocks(cad_Tib,cad_Pib);

    (* hide *)

    {$IfDef NO_PM}
    {$Else NO_PM}
    handleswitch:=WinQuerySwitchHandle(NULLHANDLE,cad_Pib^.Pib_ulPid);
    {$EndIf NO_PM}
    hide_session(true);

    (* main work loop *)
    repeat

      (* arm handler *)
      if uses_cad_hotkey then
        begin
          para_len:=SizeOf(eventsem);
          rc:=DosDevIOCtl(devicehandle,
            cadh_ioctl_category,
            cadh_ioctl_register_eventsem,
            @eventsem,para_len,@para_len,
            nil      ,0       ,nil);
        end
      else
        begin
          para_len:=SizeOf(event_rec);
          rc:=DosDevIOCtl(devicehandle,
            cadh_ioctl_category,
            cadh_ioctl_register_eventsem_enhanced,
            @event_rec,para_len,@para_len,
            nil       ,0       ,nil);
        end;

      if rc<>0 then
        begin
          WriteLn(textz_Can_not_register_CAD_event_semaphore__^,rc,'/$',Int2Hex(rc,8),').');
          if errordescription(rc)<>'' then
            WriteLn(errordescription(rc));
          hide_session(false);
          Error_Wait;
          Halt(rc);
        end;

      (* wait ... *)
      if not program_detached then
        begin
          if uses_cad_hotkey then
            Write(textz_Waiting_for_Ctrl_Alt_Del_____^)
          else
          if uses_sm_hotkey then
            Write(textz_Waiting_for_SM_Hotkey_____^)
          else
            Write(textz_Waiting_for_Event_____^);
        end;

      if not no_sound then
        begin
          if first_beep then
            first_beep:=false
          else
            begin
              DosBeep(800,31);
              DosBeep(200,31);
            end;
        end;
      DosWaitEventSem(eventsem,sem_Indefinite_Wait);
      DosResetEventSem(eventsem,postcount);
      if not no_sound then
        begin
          DosBeep(200,31);
          DosBeep(800,31);
        end;
      if not program_detached then
        WriteLn;

      (* un-arm *)
      if uses_cad_hotkey then
        begin
          para_len:=SizeOf(eventsem);
          rc:=DosDevIOCtl(devicehandle,
            cadh_ioctl_category,
            cadh_ioctl_deregister_eventsem,
            @eventsem,para_len,@para_len,
            nil      ,0       ,nil);
        end
      else
        begin
          para_len:=SizeOf(event_rec);
          rc:=DosDevIOCtl(devicehandle,
            cadh_ioctl_category,
            cadh_ioctl_deregister_eventsem_enhanced,
            @event_rec,para_len,@para_len,
            nil       ,0       ,nil);
        end;

      if rc<>0 then
        begin
          WriteLn(textz_Can_not_de_register_CAD_event_semaphore__^,rc,'/$',Int2Hex(rc,8),').');
          if errordescription(rc)<>'' then
            WriteLn(errordescription(rc));
          hide_session(false);
          Error_Wait;
          Halt(rc);
        end;

      if terminate then Break;

      popupoptions:=1; (* nontransparent,wait *)
      VioPopUp(popupoptions,0);
      alter_textmode;
      update_crt_variables(true);

      popup_menu;

      VioEndPopUp(0);
      update_crt_variables(false);

    until terminate;
    DosCloseEventSem(eventsem);

    SysFileClose(devicehandle);

    hide_session(false);

  end; (* wait_for_cad *)

(*
procedure morph_pm;
  var
    TB:PTib;
    PB:PPib;
  begin
    DosGetInfoBlocks(TB, PB);
    PB^.Pib_ulType := 3;
  end;

function msgq_thread(p:pointer):longint;
  var
    mq                  :Hmq;
    msg                 :QMsg;
  begin
    mq:=WinCreateMsgQueue(anchorblock,0);
    if mq=NULLHANDLE then RunError(1);

    WinCancelShutdown(mq,TRUE);

    //WinMessageBox(hwnd_Desktop, hwnd_Desktop, 'Msg', 'Title', 0, mb_Error+mb_Moveable);

    while WinGetMsg(anchorblock,msg,0,0,0) do
      begin
        WinDispatchMsg(anchorblock,msg);
        WinMessageBox(hwnd_Desktop, hwnd_Desktop, {'Msg'}@(Int2Hex(msg.msg,8)+#0)[1], 'Title', 0, {mb_Error+}mb_Moveable);
      end;

    WinDestroyMsgQueue(mq);

    DosBeep(2000,2000);
    no_sound:=true;
    terminate:=true;
    DosPostEventSem(eventsem);
  end;*)

begin
  Os2Base.DosError(ferr_DisableHardErr or ferr_EnableException);
  WriteLn('CAD-Popup * Veit Kannegieser 2003.03.27..',datum);
  program_detached:=IOResult<>0;

  read_config_file;
  process_commandline;

  //morph_pm;

  {$IfNDef NO_PM}
  anchorblock:=WinInitialize(0);
  if anchorblock=NULLHANDLE then
    begin
      WriteLn(textz_Presentation_Manager_not_present_can_operate^);
      Error_Wait;
      Halt(99);
    end;
  {$EndIf NO_PM}

  //VPBeginThread(msgq_thread,32*1024,nil);

  load_hide_list;
  load_menu_list;

  if not program_detached then
    alter_textmode;

  {$IfDef NO_PM}

  {$Else}
  add_to_KillList;
  {$EndIf NO_PM}

  if no_cadh or debughook then
    popup_menu
  else
    wait_for_cad;

  {$IfNDef NO_PM}
  WinTerminate(anchorblock);
  {$EndIf NO_PM}
end.

