{&Use32+}
unit plist;

interface

const
  max_processname_stringlen=20;

type
  processname_string    =string[max_processname_stringlen];
  exclude_list_type     =array[1..$ffff] of processname_string;
  ps_list               =array[1..$ffff] of
    record
      pl_pid            :word;
      pl_type           :word;
      pl_sgid           :word;
      pl_pname          :processname_string;
    end;

var
  exclude_list          :^exclude_list_type     =nil;
  exclude_list_count    :word                   =0;

  process_list          :^ps_list               =nil;
  process_list_count    :word                   =0;

  processfilter         :boolean                =true;

procedure load_hide_list;
function  search_in_hide_list(const s:string):boolean;
procedure get_processlist;
procedure free_processlist;
procedure unlock_executable_modules(drive:char);

implementation

Uses
  Dos,
  Os2Base,
  Os2Def,
  Strings;

// from bsedos.h

type

  UCHAR                 =byte;
  USHORT                =smallword;

  // Global Record structure
  // Holds all global system information. Placed first in user buffer
  qsGrec                =
    packed record
      cThrds            :ULONG;
      c32SSem           :ULONG;
      cMFTNodes         :ULONG;
    end;

  // Thread Record structure
  // Holds all per thread information.
  qsTrec                =
    packed record
      RecType           :ULONG;         // Record Type
      tid               :USHORT;        // thread ID
      slot              :USHORT;        // "unique" thread slot number
      sleepid           :ULONG;         // sleep id thread is sleeping on
      priority          :ULONG;         // thread priority
      systime           :ULONG;         // thread system time
      usertime          :ULONG;         // thread user time
      state             :UCHAR;         // thread state
      PADCHAR           :UCHAR;
      PADSHORT          :USHORT;
    end;


  // Process Record structure
  // Holds all per process information.
  qsPrec                =
    packed record
      RecType           :ULONG;         // type of record being processed
      pThrdRec          :pointer{^QSTREC}; // ptr to thread recs for this proc
      pid               :USHORT;        // process ID
      ppid              :USHORT;        // parent process ID
      proc_type         :ULONG;         // process type
      stat              :ULONG;         // process status
      sgid              :ULONG;         // process screen group
      hMte              :USHORT;        // program module handle for process
      cTCB              :USHORT;        // # of TCBs in use
      c32PSem           :ULONG;         // # of private 32-bit sems in use
      p32SemRec         :pointer;       // pointer to head of 32bit sem info
      c16Sem            :USHORT;        // # of 16 bit system sems in use
      cLib              :USHORT;        // number of runtime linked libraries
      cShrMem           :USHORT;        // number of shared memory handles
      cFH               :USHORT;        // number of open files
                                        // NOTE: cFH is size of active part of
                                        //       handle table if QS_FILE specified
      p16SemRec         :^SmallWord;    // pointer to head of 16 bit sem info
      pLibRec           :^SmallWord;    // ptr to list of runtime libraries
      pShrMemRec        :^SmallWord;    // ptr to list of shared mem handles
      pFSRec            :^SmallWord;    // pointer to list of file handles
                                        // $FFFF means it's closed, otherwise
                                        //       it's an SFN if non-zero
    end;

  qsLOrec               =
    packed record
      oaddr             :ULONG;         // object address
      osize             :ULONG;         // object size
      oflags            :ULONG;         // object flags
    end;


 qsLrec                 =
   packed record
     pNextRec           :pointer;       // pointer to next record in buffer
     hmte               :USHORT;        // handle for this mte
     fFlat              :USHORT;        // true if 32 bit module
     ctImpMod           :ULONG;         // # of imported modules in table
     ctObj              :ULONG;         // # of objects in module (mte_objcnt)
     pObjInfo           :^qsLOrec;      // pointer to per object info if any
     pName              :pChar;         // -> name string following struc
   end;



  // dummy declarartions (not needed for ps)
  qsS16Hrec             =byte;
  qsS32rec              =byte;
  qsMrec                =byte;
  qsFrec                =byte;


  // Pointer Record Structure
  //      This structure is the first in the user buffer.
  //      It contains pointers to heads of record types that are loaded
  //      into the buffer.
  qsPtrRec              =
    packed record
      pGlobalRec        :^qsGrec;
      pProcRec          :^qsPrec;               // ptr to head of process records
      p16SemRec         :^qsS16Hrec;            // ptr to head of 16 bit sem recds
      p32SemRec         :^qsS32rec;             // ptr to head of 32 bit sem recds
      pMemRec           :^qsMrec;               // ptr to head of shared mem recs
      pLibRec           :^qsLrec;               // ptr to head of mte records
      pShrMemRec        :^qsMrec;               // ptr to head of shared mem records
      pFSRec            :^qsFrec;               // ptr to head of file sys records
    end;

const
   (* record types *)
   QS_PROCESS           =$0001;
   QS_SEMAPHORE         =$0002;
   QS_MTE               =$0004;
   QS_FILESYS           =$0008;
   QS_SHMEMORY          =$0010;
   QS_DISK              =$0020;
   QS_HWCONFIG          =$0040;
   QS_NAMEDPIPE         =$0080;
   QS_THREAD            =$0100;
   QS_MODVER            =$0200;


function load_hide_list_file(const fn:string):boolean;
  var
    f                   :text;
    s                   :string;
  begin
    load_hide_list_file:=false;
    Assign(f,fn);
    {$I-}
    Reset(f);
    {$I+}
    if IOResult<>0 then Exit;

    while not Eof(f) do
      begin
        ReadLn(f,s);
        if s='' then Continue;
        if s[1] in ['#',';','%'] then Continue;
        if Length(s)>max_processname_stringlen then Continue;
        Inc(exclude_list_count);
        ReallocMem(exclude_list,SizeOf(exclude_list^[1])*exclude_list_count);
        exclude_list^[exclude_list_count]:=s;
      end;
    Close(f);
    load_hide_list_file:=true;
  end;

procedure load_hide_list;
  var
    s,p,n,e             :string;
  begin

    exclude_list:=nil;
    exclude_list_count:=0;

    FSplit(ParamStr(0),p,n,e);
    e:='.hid';

    if DebugHook then
      p:='c:\v\cadh\cadh.vk\';

    if not load_hide_list_file(GetEnv('HOME')+'\'+n+e) then
      load_hide_list_file(p+n+e)

  end;

function search_in_hide_list(const s:string):boolean;
  var
    i                   :word;
  begin
    if processfilter then
      begin
        search_in_hide_list:=true;
        for i:=1 to exclude_list_count do
          case Pos('.',exclude_list^[i]) of
            (* titel: case sensitive substring *)
            0:if Pos(exclude_list^[i],s)<>0 then Exit;
          else
            (* filename: case sensitive match *)
              if     exclude_list^[i]=s     then Exit;
          end;
      end;
    search_in_hide_list:=false;
  end;

{&Cdecl+}

function DosReplaceModule(OldModName,NewModName,BackModName: PChar): ApiRet;
  external 'DOSCALLS' index 417;

function Dos32QuerySysState(EntityList:ULONG;EntityLevel:ULONG;pid:PID;tid:TID;var pDataBuf;cbBuf:ULONG):ApiRet;
 external 'DOSCALLS' index 368;

{&Cdecl-}

procedure get_processlist;
  var
    buffer,work         :pointer;
  const
    buffersize          =1*1024*1024;

  procedure mte_name(w:word;var s:processname_string);
    var
      mte               :^qsLrec;
      tmp               :string;
    begin
      mte:=pointer(qsPtrRec(buffer^).pLibRec);
      while Assigned(mte) do
        with mte^ do
          if w=hmte then
            begin
              tmp:=StrPas(pName);
              while Pos('\',tmp)<>0 do Delete(tmp,1,Pos('\',tmp));
              s:=tmp;
              Exit;
            end
          else
            mte:=pNextRec;
      s:='?';
    end;


  begin
    process_list:=nil;
    process_list_count:=0;
    GetMem(buffer,buffersize);
    FillChar(buffer^,buffersize,0);
    if
    Dos32QuerySysState(QS_PROCESS+QS_MTE,       // EntityList
                       0,                       // EntityLevel
                       0,                       // PID:all
                       0,                       // TID:all
                       buffer^,                 // pDataBuf
                       buffersize)=0 then       // cbBuf
      begin
        work:=qsPtrRec(buffer^).pProcRec;
        while Assigned(work) do
          case qsPrec(work^).RecType of
            0:
              Break;

            QS_PROCESS:
              with qsPrec(work^) do
                begin
                  Inc(process_list_count);
                  ReallocMem(process_list,SizeOf(process_list^[1])*process_list_count);
                  with process_list^[process_list_count] do
                    begin
                      pl_pid:=pid;
                      pl_type:=proc_type;
                      pl_sgid:=sgid;
                      mte_name(hMte,pl_pname);
                      if (pl_pname='SYSINIT') and (pl_sgid<>0) and (pl_sgid<>$ff0) then
                        pl_pname:='';
                      //WriteLn(pl_pid:5,' ',pl_pname,Ofs(pThrdRec));
                    end;
                  work:=pThrdRec;
                end;

            QS_THREAD:
              Inc(longint(work),SizeOf(qsTrec));
          else
            Break;
          end; (* case *)

      end; (* Dos32QuerySysState *)
    Dispose(buffer);
  end;


procedure free_processlist;
  begin
    Dispose(process_list);
    process_list:=nil;
    process_list_count:=0;
  end;

procedure unlock_executable_modules(drive:char);
  var
    buffer              :pointer;
    mte                 :^qsLrec;
    tmp                 :string;

  const
    buffersize          =1*1024*1024;

  begin
    drive:=UpCase(drive);
    process_list:=nil;
    process_list_count:=0;
    GetMem(buffer,buffersize);
    FillChar(buffer^,buffersize,0);
    if
    Dos32QuerySysState(QS_PROCESS+QS_MTE,       // EntityList
                       0,                       // EntityLevel
                       0,                       // PID:all
                       0,                       // TID:all
                       buffer^,                 // pDataBuf
                       buffersize)=0 then       // cbBuf
      begin
        mte:=Pointer(qsPtrRec(buffer^).pLibRec);
        while Assigned(mte) do
          with mte^ do
            begin

              if StrLen(pName)>Length('X:\') then
                if StrLComp(pName+1,':\',Length(':\'))=0 then
                  if (UpCase(pName[0])=drive) or (drive='*') then
                    DosReplaceModule(pName,nil,nil);

              mte:=pNextRec;
            end;

      end; (* Dos32QuerySysState *)
    Dispose(buffer);
  end;


end.

