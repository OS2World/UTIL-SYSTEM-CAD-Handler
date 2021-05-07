{&Use32+}
unit ShutKill;

(* verifies that cad_pop.exe is in the estyler ini KillList *)
(* programmed after shutkill.cmd / Alex Taylor [1.01] *)

interface

uses
  Os2PmApi,
  Os2Def;

var
  anchorblock           :Hab;

procedure add_to_KillList;

implementation

uses
  Dos,
  Strings;

const
  app                   :PChar='Shutdown';
  key                   :PChar='KillList';
  insertstring          ='CAD_POP.EXE';

function add_to_KillList_ini(const inipath:string):boolean;
  var
    ininame             :string;
    f                   :file;
    estyler_ini         :HIni;
    killist_len         :ULong;
    killist             :PChar;
    found               :boolean;
    w                   :word;
  begin
    Result:=false;

    ininame:=inipath+'\estyler.ini';
    FileMode:=$40;
    Assign(f,ininame);
    {$I-}
    Reset(f,1);
    {$I+}
    if IOResult<>0 then
      Exit;
    Close(f);

    estyler_ini:=PrfOpenProfile(anchorblock,@(ininame+#0)[1]);
    if estyler_ini=NULLHANDLE then
      Result:=false;

    if not PrfQueryProfileSize(estyler_ini,app,key,killist_len) then
      begin
        killist_len:=0;
        GetMem(killist,killist_len+2);
        FillChar(killist^,killist_len+2,0);
      end
    else
      begin
        GetMem(killist,killist_len+2);
        FillChar(killist^,killist_len+2,0);
        if not PrfQueryProfileData(estyler_ini,app,key,killist,killist_len) then
          killist_len:=0;
      end;

    found:=false;
    w:=0;
    while w<killist_len do
      if killist[w]=#0 then
        Break
      else
      if StrIComp(killist+w,insertstring)=0 then
        begin
          found:=true;
          Break;
        end
      else
        Inc(w,StrLen(killist+w)+1);

    if found then
      Result:=true
    else
      begin
        killist_len:=w+Length(insertstring)+1+1;
        ReallocMem(killist,killist_len);
        StrCopy(killist+w,insertstring);
        Inc(w,Length(insertstring)+1);
        killist[w]:=#0;
        Result:=PrfWriteProfileData(estyler_ini,app,key,killist,killist_len);
      end;

    PrfCloseProfile(estyler_ini);
  end;

procedure add_to_KillList;
  var
    p                   :PathStr;
    n                   :NameStr;
    e                   :ExtStr;
  begin
    FSplit(GetEnv('USER_INI'),p,n,e);
    if p<>'' then
      if add_to_KillList_ini(p) then Exit;

    p:=GetEnv('HOME');
    if p<>'' then
      if add_to_KillList_ini(p) then Exit;

    p:=GetEnv('OSDIR');
    if p<>'' then
      if add_to_KillList_ini(p+'\system\estyler') then Exit;

  end;

end.
