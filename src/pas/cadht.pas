program cadh_test;

Uses
  Os2Base,
  Os2Def,
  VpSysLow;

var
  rc            :ApiRet;
  devicehandle  :longint;
  eventsem      :HEv;
  para_len      :longint;

begin

  rc:=SysFileOpen('CADH$$$$',0,devicehandle);
  if rc<>0 then
    begin
      WriteLn('Can not open CAD-hook-driver (',rc,').');
      WriteLn('Please install BaseDev=CADH.SYS');
      Halt(rc);
    end;

  rc:=DosOpenEventSem('\SEM32\CADH',eventsem);
  if rc<>0 then
    rc:=DosCreateEventSem('\SEM32\CADH',eventsem,dc_Sem_Shared,false);
  if rc<>0 then
    begin
      WriteLn('Can not create event semaphore (',rc,').');
      Halt(rc);
    end;

  para_len:=SizeOf(eventsem);
  rc:=DosDevIOCtl(devicehandle,$80,0,
    @eventsem,para_len,@para_len,
    nil      ,0       ,nil);
  if rc<>0 then
    begin
      WriteLn('Can not register CAD-event semaphore (',rc,').');
      Halt(rc);
    end;

  WriteLn('Waiting for Ctrl+Alt+Del...');
  DosWaitEventSem(eventsem,sem_Indefinite_Wait);

  para_len:=SizeOf(eventsem);
  rc:=DosDevIOCtl(devicehandle,$80,1,
    @eventsem,para_len,@para_len,
    nil      ,0       ,nil);
  if rc<>0 then
    begin
      WriteLn('Can not de-register CAD-event semaphore (',rc,').');
      Halt(rc);
    end;

  DosCloseEventSem(eventsem);

  SysFileClose(devicehandle);
  WriteLn('Done.');
end.

