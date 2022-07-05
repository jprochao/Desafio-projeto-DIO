program Feliciano;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, Principal, DataM, login, carrega
  { you can add units after this };

{$R *.res}

begin
  Application.Title:='PDCAVAN';
  RequireDerivedFormResource:=True;
  Application.Initialize;
  Application.CreateForm(TFLogar, FLogar);
  Application.CreateForm(TFPDCA, FPDCA);
  Application.CreateForm(TFCarrega, FCarrega);
  Application.CreateForm(TDM, DM);
  Application.Run;
end.

