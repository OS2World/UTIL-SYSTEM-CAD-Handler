program ps;

uses
  Os2Base,Os2Def,Strings,VpUtils;

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



var
  m:array[0..1024*1024-1] of byte;
  p:pointer;

// groesse 4K/16K/32K/64K/128K/...1M

{&Cdecl+}
function Dos32QuerySysState(EntityList:ULONG;EntityLevel:ULONG;pid:PID;tid:TID;var pDataBuf;cbBuf:ULONG):ApiRet;
 external 'DOSCALLS' index 368;
{&Cdecl-}

function mte_name(w:word):string;
  var
    mte:^qsLrec;
    p1:pointer;
    tmp:string;
  begin
    p1:=@m;
    mte:=pointer(qsPtrRec(p1^).pLibRec);
    while Assigned(mte) do
      with mte^ do
        begin
          //WriteLn(Int2Hex(hmte,4),' ',StrPas(pName));
          if w=hmte then
            begin
              tmp:=StrPas(pName);
              while Pos('\',tmp)<>0 do Delete(tmp,1,Pos('\',tmp));
              mte_name:=tmp;
              Exit;
            end;
          mte:=pNextRec
        end;
    mte_name:='?';
  end;

begin
  FillChar(m,SizeOf(m),0);
  Dos32QuerySysState(QS_PROCESS+QS_MTE, // EntityList
                     0, // EntityLevel
                     0, // PID:all
                     0, // TID:all
                     m, // pDataBuf
                     SizeOf(m));// cbBuf
  p:=@m;
  with qsPtrRec(p^).pGlobalRec do
    begin
      Writeln(cThrds);
    end;

  p:=qsPtrRec(p^).pProcRec;
  while Assigned(p) do
    case qsPrec(p^).RecType of
      0: Break;
      QS_PROCESS:
        with qsPrec(p^) do
          begin
            WriteLn(pid:5,ppid:5,' ',mte_name(hMte));
            p:=pThrdRec;
          end;
      QS_THREAD:
        Inc(longint(p),SizeOf(qsTrec));
    else
      Break;
    end;

end.

