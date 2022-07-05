unit login;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, DBGrids;

type

  { TFLogar }

  TFLogar = class(TForm)
    btentrar: TButton;
    BTNsenha: TButton;
    btsair: TButton;
    LERNsenha: TLabeledEdit;
    euser: TEdit;
    esenha: TEdit;
    LENsenha: TLabeledEdit;
    Image1: TImage;
    Label1: TLabel;
    Label2: TLabel;
    Panel1: TPanel;
    procedure btentrarClick(Sender: TObject);
    procedure BTNsenhaClick(Sender: TObject);
    procedure btsairClick(Sender: TObject);
    procedure LENsenhaExit(Sender: TObject);
    procedure euserExit(Sender: TObject);
    procedure eusuarioChange(Sender: TObject);
    procedure eusuarioExit(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure LERNsenhaExit(Sender: TObject);
    procedure Panel1Click(Sender: TObject);
    procedure verificaLogin;
    procedure verificaUsuarioLogix;
    procedure insereUsuario;
    procedure cadastraSenha;
    procedure grava_dados;

  private
    { private declarations }
  public
    { public declarations }
    retorno : boolean;
    glob_user : string;
  end;

var
  FLogar: TFLogar;

implementation

uses DataM, Principal;

{$R *.lfm}

{ TFLogar }

procedure TFLogar.grava_dados();
begin
  try
     dm.SQLTrans.CommitRetaining;
     Showmessage('Senha cadastrada com sucesso!');
     Panel1.Visible:=false;
     Close;
  except
  On E:Exception do
     begin
        dm.SQLTrans.RollbackRetaining;
        Showmessage('Falha no cadastro da senha!'#13#10'Mensagem: '+E.Message);
     end;
  end;
end;

procedure TFLogar.cadastraSenha;
var
  senha, senha1, senha2 : String;
begin
  senha1:=trim(LENsenha.Text);
  senha2:=trim(LERNsenha.Text);
  ShowMessage('senhas: |' + senha1 +'|'+ senha2);
  if senha1 = senha2 then
    begin
       senha:=senha2;
       with dm.SQLQLOGIN do
       begin
            Close;
            SQL.Clear;
            SQL.Text:='update login_van set senha' +
                              'where usuario=:prmSenha';
            ParamByName('prmSenha').AsString:=senha;
            ExecSQL;
            grava_dados;
       end;
    end
    else
    begin
       ShowMessage('Campos senha não são iguais!');
       LENsenha.SetFocus;
    end;
end;

procedure TFLogar.insereUsuario();
begin
    with dm.SQLQLOGIN do
    dm.SQLQLOGIN.Close;
    dm.SQLQLOGIN.SQL.Clear;
    dm.SQLQLOGIN.SQL.Add(' insert into login_van (usuario, senha) '+
                         ' values '+
                         '(:prmUser, :prmSenha)');
    dm.SQLQLOGIN.ParamByName('prmUser').AsString:=euser.Text;
    dm.SQLQLOGIN.ParamByName('prmSenha').AsString:='!@#';
    dm.SQLQLOGIN.ExecSQL;
end;

procedure TFLogar.verificaUsuarioLogix;
var
  l_user : String;
  l_cont : Integer;
begin
    //ShowMessage('Entrou no user logix: ' + euser.Text);
    l_user:=euser.Text;
    with dm.SQLQUSER do
    begin
         Close;
         SQL.Clear;
         sql.Text:='select * from usuarios';
         SQL.Add('where cod_usuario like' + QuotedStr(l_user+'%'));
         if dm.SQLQLOGIN.Prepared then
         begin
            prepare;
            open;
            if dm.SQLQUSER.IsEmpty then
            begin
               ShowMessage('Usuário não cadastrado no Logix! Entre em contato'+
                           ' com o administrador do Logix.');
               retorno := false;
            end
            else
            begin
               ShowMessage('vou inserir o user: ' + l_user);
               insereUsuario;
               retorno := true;
            end;
         end
         else
         ShowMessage('Erro prepare.');
    end;
end;

procedure TFLogar.verificaLogin;
var
  loger : String;
  login : String;
  lsenha : String;
begin
    //ShowMessage(euser.Text);
    loger:=euser.Text;
    with dm.SQLQLOGIN do
    begin
       close;
       sql.clear;
       sql.Text:='select * from login_van';
       SQL.Add('where usuario like' + QuotedStr(loger+'%'));
       begin
          prepare;
          open;
          login  :=FieldByName('usuario').AsString;
          lsenha :=FieldByName('senha').AsString
       end
    end;

    //ShowMessage('Login: ' + login);
    if (login = '' ) then
    begin
         verificaUsuarioLogix;
         if (retorno <> false) then
         begin
              ShowMessage('Para o primeiro acesso, cadastre sua senha.');
              Panel1.Visible:=true;
              LENsenha.SetFocus;
         end
         else if (lsenha = '') then
    end;
end;

procedure TFLogar.eusuarioChange(Sender: TObject);
begin

end;

procedure TFLogar.BTNsenhaClick(Sender: TObject);
begin
end;

procedure TFLogar.btentrarClick(Sender: TObject);
var

  l_user, l_senha, l_user2, l_senha2 : String;

  l_tam1, l_tam2, l_i, l_x, l_d, x : Integer;

  l_senha_usuario : String;

  l_aux1, l_aux2, l_aux3, l_aux4, l_aux5 : String;

begin

  l_user:=trim(euser.Text);

  l_senha:=trim(esenha.Text);

  with DM.SQLQPASSWD do

  begin

       Close;

       SQL.Clear;

       SQL.Text:='select * from usuario_senha ' +

                 ' where cod_usuario like '+QuotedStr(l_user+'%');

       //if DM.SQLQPASSWD.prepared then

       begin

            prepare;

            open;

            l_user2  :=DM.SQLQPASSWD.FieldByName('cod_usuario').AsString;

            l_senha2 :=DM.SQLQPASSWD.FieldByName('senha').AsString;

            //ShowMessage('l_senha2 é: ' + l_senha2);

       end;
       {else
       begin
            ShowMessage('erro prepare');
            Abort;
       end;}

       l_tam1:=Length(l_user);

       l_tam2:=Length(l_senha);

       //cod_asc:=Ord(l_senha[1]);

       //ShowMessage(IntToStr(cod_asc));

       //l_senha_usuario:='000000000000000000000000';

       for l_i := l_tam1 DownTo 1 do
       begin
          l_aux1:=FormatFloat('000',ord(l_user[l_i]));
          l_aux2:=l_aux2+l_aux1;
          //ShowMessage('Aux2 é: ' + l_aux2);
       end;

       l_d:=8 - l_tam1;

       //ShowMessage('l_d é: ' + IntToStr(l_d));

       for l_i:=1 to l_d do
       begin
            l_aux2:=l_aux2+FormatFloat('000', 0);
            //ShowMessage('Aux2 agora é: ' + l_aux2);
       end;

       for l_i := 1 To l_tam2 do
       begin
          l_aux3:=FormatFloat('000',ord(l_senha[l_i]));
          l_aux4:=l_aux4+l_aux3;
          //ShowMessage('for - Aux2 é: ' + l_aux2);
       end;
       l_d:=8 - l_tam2;

       //ShowMessage('l_d é: ' + IntToStr(l_d));

       for l_i:=1 to l_d do
       begin
            l_aux4:=l_aux4+FormatFloat('000', 0);
       end;

       l_x:=1;
       for l_i:= 1 to 8 do
       begin
          l_aux5:=IntToStr(StrToInt(Copy(l_aux2, l_x,3)) + StrToInt(Copy(l_aux4, l_x, 3)));
          l_aux5:=FormatFloat('000', StrToInt(l_aux5));
          l_senha_usuario:=l_senha_usuario + l_aux5;
          //ShowMessage(IntToStr(l_x) + ' - ' + l_senha_usuario);
          l_x:=l_x+3;
       end;


       if l_senha_usuario = l_senha2 then
       begin
          glob_user:=l_user2;
          ShowMessage(glob_user + ': as senhas são iguais!!!');
          FPDCA.ShowModal;
          FPDCA.genable:=True;
          FPDCA.enable_bt;
          FLogar.Close;
       end
       else
       begin
          ShowMessage('As senhas não conferi!!!');
          Abort;
       end;


  end;
end;

procedure TFLogar.btsairClick(Sender: TObject);
begin
  close;
end;

procedure TFLogar.LENsenhaExit(Sender: TObject);
begin
  if ((LENsenha.Text = '') or (Length(LENsenha.Text) < 2)) then
     begin
          ShowMessage('Campo não pode ser nulo. Deve conter no máximo 8 caracteres'
                        + ' contendo letras e números.');
     end;
end;

procedure TFLogar.euserExit(Sender: TObject);
begin
  if (euser.Text <> '') then
     begin
          glob_user:=euser.Text;
          verificaLogin;
     end;
end;

procedure TFLogar.eusuarioExit(Sender: TObject);
begin
end;

procedure TFLogar.FormShow(Sender: TObject);
begin
  euser.SetFocus;
end;

procedure TFLogar.LERNsenhaExit(Sender: TObject);
begin
  if ((LERNsenha.Text = '') or (Length(LERNsenha.Text) < 2)) then
     begin
          ShowMessage('Campo não pode ser nulo. Deve conter no máximo 8 caracteres'
                        + ' contendo letras e números.');
     end
  else if (LERNsenha.Text <> LENsenha.Text) then
     ShowMessage('Campos senha diferentes');
     Abort;
end;

procedure TFLogar.Panel1Click(Sender: TObject);
begin

end;

end.

