unit DataM;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, odbcconn, sqldb, db, FileUtil;

type

  { TDM }

  TDM = class(TDataModule)
    DSLOGIN: TDataSource;
    DSCC: TDataSource;
    DSPDCA: TDataSource;
    logix11: TODBCConnection;
    SQLQPDCA: TSQLQuery;
    SQLQCC: TSQLQuery;
    SQLQLOGIN: TSQLQuery;
    SQLQCARR: TSQLQuery;
    SQLQSEQ: TSQLQuery;
    SQLQPASSWD: TSQLQuery;
    SQLQUSER: TSQLQuery;
    SQLTrans: TSQLTransaction;
    procedure DataModuleCreate(Sender: TObject);
    procedure logix11AfterConnect(Sender: TObject);

  private
    { private declarations }
  public
    { public declarations }
  end;

var
  DM: TDM;

implementation

{$R *.lfm}

{ TDM }



procedure TDM.DataModuleCreate(Sender: TObject);
begin
  logix11.Open;
end;

procedure TDM.logix11AfterConnect(Sender: TObject);
begin

end;

end.

