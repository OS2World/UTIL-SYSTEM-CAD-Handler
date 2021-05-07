uses
  crt;
begin
  repeat
  WriteLn(Port[$60]);
  until {keypressed}false;
end.