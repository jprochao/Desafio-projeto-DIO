unit carrega;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, CheckLst,
  StdCtrls, DbCtrls;

type

  { TFCarrega }

  TFCarrega = class(TForm)
    Button1: TButton;
    Button2: TButton;
    CLBProj: TCheckListBox;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure DBListBox1Click(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure carrega;
    procedure consulta;
  private
    { private declarations }
  public
    { public declarations }
    log_user:String;
  end;

var
  FCarrega: TFCarrega;

implementation

uses DataM, login, Principal;

{$R *.lfm}

{ TFCarrega }

procedure TFCarrega.carrega();
begin
  CLBProj.Items.Clear;
  while not DM.SQLQCARR.eof do
  begin
    CLBProj.Items.Add(DM.SQLQCARR.FieldByName('num_projeto').AsString + ' ) '+
                      DM.SQLQCARR.FieldByName('nom_projeto').AsString);
    DM.SQLQCARR.Next;
  end;
end;

procedure TFCarrega.consulta();
begin
  with dm.SQLQCARR do
    dm.SQLQCARR.Close;
    dm.SQLQCARR.SQL.Clear;
    dm.SQLQCARR.SQL.Add('select distinct num_projeto, nom_projeto from pdca_van');
    dm.SQLQCARR.SQL.Add('where usuario_resp like' +QuotedStr(log_user+'%'));
    //dm.SQLQCARR.ParamByName('prmUser').AsString:=log_user;
    dm.SQLQCARR.Open;
end;
procedure TFCarrega.Button1Click(Sender: TObject);
var
  i, x : Integer;
  l_num_projeto : String;
  l_tam : Integer;
  l_aux, l_aux2 : String;
  l_string : String;
begin
  l_string:=')';
  for i := 0 to CLBProj.Items.Count - 1 do
      if CLBProj.Checked[i] then //Se o item corrente estiver selecionado
          //lbSelecionados.Items.Add(TTexto(clbItems.Items.Objects[i]).Valor);
          l_num_projeto:=trim(CLBProj.Items[i]);
          l_tam:=Length(l_num_projeto);
          //ShowMessage(l_num_projeto + ' - ' + IntToStr(l_tam));   //
          for x := 0 to l_tam do
              begin
                //ShowMessage('passou for ->x ' + IntToStr(x));//
                l_aux:=Copy(l_num_projeto, x, 1);
                //ShowMessage('String -> ' + l_aux);
                if l_aux = l_string then
                begin
                  l_aux:=Copy(l_num_projeto, 1, x - 1);
                  l_aux2:=Copy(l_num_projeto, x + 2, l_tam);
                  FPDCA.LEnum_proj.Text:=l_aux;
                  FPDCA.LEnom_proj.Text:=l_aux2;
                  //ShowMessage('Deu boa ->num. ' + l_aux);//
                  Close;
                  Break;
                end;
                //ShowMessage('de novo ->x ' + IntToStr(x));
                //Inc(x);
              end;

end;
procedure TFCarrega.Button2Click(Sender: TObject);
begin
  Close;
end;

procedure TFCarrega.DBListBox1Click(Sender: TObject);
begin

end;

procedure TFCarrega.FormShow(Sender: TObject);
begin
  log_user:=FLogar.glob_user;
  consulta;
  carrega;
end;

end.

