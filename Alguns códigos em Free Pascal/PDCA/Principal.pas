unit Principal;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, DbCtrls,
  DBGrids, StdCtrls, MaskEdit, ExtCtrls, ColorBox, Grids, ComObj, LCLType,
  CheckLst, ActnList, sqldb;

type

  { TFPDCA }

  TFPDCA = class(TForm)
    btincluir: TButton;
    btsair: TButton;
    btmodificar: TButton;
    btexcluir: TButton;
    btsalvar: TButton;
    btpesquisar: TButton;
    btcancelar: TButton;
    btLogar: TButton;
    btanexo: TButton;
    Button9: TButton;
    CBArea: TComboBox;
    CBLocal: TComboBox;
    CBAva25: TColorBox;
    CBAva50: TColorBox;
    CBAva75: TColorBox;
    CBAva100: TColorBox;
    DBGrid: TDBGrid;
    Edit2: TEdit;
    Edit3: TEdit;
    Edit4: TEdit;
    ERespon: TEdit;
    ESeq_item: TEdit;
    EVal: TEdit;
    GroupBox1: TGroupBox;
    GroupBox2: TGroupBox;
    GroupBox3: TGroupBox;
    GroupBox4: TGroupBox;
    Image1: TImage;
    Label1: TLabel;
    Label10: TLabel;
    Label11: TLabel;
    Label12: TLabel;
    Label13: TLabel;
    Label14: TLabel;
    Label15: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    Label8: TLabel;
    Label9: TLabel;
    LEganhos: TLabeledEdit;
    Legenda: TStaticText;
    Legenda1: TStaticText;
    Legenda2: TStaticText;
    Legenda3: TStaticText;
    LEusu_resp: TLabeledEdit;
    LEnom_proj: TLabeledEdit;
    LEnum_proj: TLabeledEdit;
    lbanexo: TLabel;
    Label2: TLabel;
    Label7: TLabel;
    LEPesquisar: TLabeledEdit;
    MMotivo: TMemo;
    MEDat_inc: TMaskEdit;
    MEPrazo: TMaskEdit;
    MFoco: TMemo;
    MMetodo: TMemo;
    odir: TOpenDialog;
    procedure btcancelarClick(Sender: TObject);
    procedure btexcluirClick(Sender: TObject);
    procedure btincluirClick(Sender: TObject);
    procedure btLogarClick(Sender: TObject);
    procedure btmodificarClick(Sender: TObject);
    procedure btsairClick(Sender: TObject);
    procedure btsalvarClick(Sender: TObject);
    procedure btanexoClick(Sender: TObject);
    procedure Button9Click(Sender: TObject);
    procedure cbdepartExit(Sender: TObject);
    procedure CBLocalExit(Sender: TObject);
    //procedure cbrumoEnter(Sender: TObject);
    procedure cbstatusEnter(Sender: TObject);
    procedure CBAva25Exit(Sender: TObject);
    procedure DBGridDblClick(Sender: TObject);
    procedure DBGridDrawColumnCell(Sender: TObject; const Rect: TRect;
      DataCol: Integer; Column: TColumn; State: TGridDrawState);
    procedure enter(Sender: TObject);
    procedure consulta_cc;
    procedure carrega_dados;
    procedure codifica_auto;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure Image1Click(Sender: TObject);
    procedure incluir;
    procedure grava_incluir;
    procedure grava_modificar;
    procedure enable_bt;
    procedure consulta_feliciano;
    procedure limpa_campos;
    procedure excluir;
    procedure MMotivoChange(Sender: TObject);
    procedure modificar;
    Procedure GerarExcel(Consulta:TSQLQuery);
    procedure carrega_cc;
    procedure bloquear_campos;
    function consulta_proj(user: String):Boolean;
    //procedure carrega_check_list;

  private
    { private declarations }
  public
    { public declarations }
    gusuario : String;
    genable  : Boolean;
    gcor     : String;
    gconfirma: String;
    arquivo_anexo : String;
    novo_proj : String;

  end;

var
  FPDCA: TFPDCA;

implementation

uses DataM, login, carrega;

{$R *.lfm}

{ TFPDCA }

procedure TFPDCA.bloquear_campos;
var i : integer;
begin
  for i := 0 to ComponentCount -1 do
  begin
    if Components [i] is TLabeledEdit then
    TLabeledEdit (Components [i]).Enabled:=genable;
    if Components [i] is TEdit then
    TEdit (Components [i]).Enabled:=genable;
    if Components [i] is TComboBox then
    TComboBox (Components [i]).Enabled:=genable;
    if Components [i] is TMemo then
    TMemo (Components [i]).Enabled:=genable;
    if Components [i] is TMaskEdit then
    TMaskEdit (Components [i]).Enabled:=genable;
  end;
end;

procedure TFPDCA.carrega_cc();
begin
  consulta_cc;
  while not dm.SQLQCC.eof do
    begin
      CBArea.items.add(dm.SQLQCC.FieldByName('nom_cent_cust').asString);
      CBLocal.items.add(dm.SQLQCC.FieldByName('nom_cent_cust').asString);
      dm.SQLQCC.next;
    end;
end;

Procedure TFPDCA.GerarExcel(Consulta:TSQLQuery);
var
     coluna, linha: integer;
     excel: variant;
     valor: string;
begin
     try
          excel:=CreateOleObject('Excel.Application');
          excel.Workbooks.add(1);
     except
          Application.MessageBox ('Vers??o do Ms-Excel'+
          'Incompat??vel','Erro',MB_OK+MB_ICONEXCLAMATION);
     end;

     Consulta.First;
     try
        for linha:=0 to Consulta.RecordCount-1 do
        begin
            for coluna:=1 to Consulta.FieldCount do // eliminei a coluna 0 da rela????o do Excel
            begin
                 valor:= Consulta.Fields[coluna-1].AsString;
                 excel.cells [linha+2,coluna]:=valor;
            end;
            Consulta.Next;
        end;

        for coluna:=1 to Consulta.FieldCount do // eliminei a coluna 0 da rela????o do Excel
        begin
             valor:= Consulta.Fields[coluna-1].DisplayLabel;
             excel.cells[1,coluna]:=valor;
        end;
        excel.columns.AutoFit; // esta linha ?? para fazer com que o Excel dimencione as c??lulas adequadamente.
        excel.visible:=true;
     except
          Application.MessageBox ('Aconteceu um erro desconhecido durante a convers??o'+
          'da tabela para o Ms-Excel','Erro',MB_OK+MB_ICONEXCLAMATION);
     end;
end;


procedure TFPDCA.modificar;
begin
  with dm.SQLQPDCA do
  dm.SQLQPDCA.Close;
  dm.SQLQPDCA.SQL.Clear;
  dm.SQLQPDCA.Sql.Add(' update pdca_van set num_projeto=:prmNum,    '+
                                          ' nom_projeto=:prmNom,    '+
                                          ' usuario_resp=:prmUsre,  '+
                                          ' area=:prmArea,          '+
                                          ' dat_inclusao=:prmDati,  '+
                                          ' dat_revisao=:prmDatr,   '+
                                          ' seq_item=:prmSeq,       '+
                                          ' foco_oque=:prmFoc,      '+
                                          ' motivo_por_que=:prmMot, '+
                                          ' resp_quem=:prmRes,      '+
                                          ' prazo_quando=:prmPrz,   '+
                                          ' local_onde=:prmLoc,     '+
                                          ' acoes_como=:prmAco,     '+
                                          ' valores_quanto=:prmVal, '+
                                          ' ganhos_estimado=:prmGan,'+
                                          ' avaliacao25=:prmAv25,   '+
                                          ' avaliacao50=:prmAv50,   '+
                                          ' avaliacao75=:prmAv75,   '+
                                          ' avaliacao100=:prmAv100, '+
                                          ' anexo=:prmAnex');
  dm.SQLQPDCA.Sql.Add('where num_projeto=:prmNum and seq_item=:prmSeq');
  dm.SQLQPDCA.ParamByName('prmNum').AsString:=LEnum_proj.Text;
  dm.SQLQPDCA.ParamByName('prmNom').AsString:=LEnom_proj.Text;
  dm.SQLQPDCA.ParamByName('prmUsre').AsString:=LEusu_resp.Text;
  dm.SQLQPDCA.ParamByName('prmArea').AsString:=CBArea.Text;
  dm.SQLQPDCA.ParamByName('prmDati').AsString:=MEDat_inc.Text;
  dm.SQLQPDCA.ParamByName('prmDatr').AsString:=MEDat_inc.Text;
  dm.SQLQPDCA.ParamByName('prmSeq').AsString:=ESeq_item.Text;
  dm.SQLQPDCA.ParamByName('prmFoc').AsString:=MFoco.Text;
  dm.SQLQPDCA.ParamByName('prmMot').AsString:=MMotivo.Text;
  dm.SQLQPDCA.ParamByName('prmRes').AsString:=ERespon.Text;
  dm.SQLQPDCA.ParamByName('prmPrz').AsString:=MEPrazo.Text;
  dm.SQLQPDCA.ParamByName('prmLoc').AsString:=CBLocal.Text;
  dm.SQLQPDCA.ParamByName('prmAco').AsString:=MMetodo.Text;
  dm.SQLQPDCA.ParamByName('prmVal').AsString:=EVal.Text;
  dm.SQLQPDCA.ParamByName('prmGan').AsString:=LEganhos.Text;
  dm.SQLQPDCA.ParamByName('prmAv25').AsString:=CBAva25.Text;
  dm.SQLQPDCA.ParamByName('prmAv50').AsString:=CBAva50.Text;
  dm.SQLQPDCA.ParamByName('prmAv75').AsString:=CBAva75.Text;
  dm.SQLQPDCA.ParamByName('prmAv100').AsString:=CBAva100.Text;
  dm.SQLQPDCA.ParamByName('prmAnex').AsString:='';
  dm.SQLQPDCA.ExecSQL;

end;

procedure TFPDCA.excluir;
begin
with DM.SQLQPDCA do
  DM.SQLQPDCA.Close;
  DM.SQLQPDCA.SQL.Clear;
  DM.SQLQPDCA.Sql.Add('delete from pdca_van');
  DM.SQLQPDCA.Sql.Add('where num_projeto=:prmNum and seq_item=:prmSeq');
  DM.SQLQPDCA.ParamByName('prmNum').Value:=LEnum_proj.Text;
  DM.SQLQPDCA.ParamByName('prmSeq').Value:=ESeq_item.Text;
  DM.SQLQPDCA.ExecSQL;
end;

procedure TFPDCA.MMotivoChange(Sender: TObject);
begin

end;

procedure TFPDCA.limpa_campos;
var i : integer;
begin
  for i := 0 to ComponentCount -1 do
  begin
    if Components [i] is TLabeledEdit then
    TLabeledEdit (Components [i]).Clear;
    if Components [i] is TEdit then
    TEdit (Components [i]).Clear;
    if Components [i] is TComboBox then
    TComboBox (Components [i]).Clear;
    if Components [i] is TMemo then
    TMemo (Components [i]).Clear;
    if Components [i] is TMaskEdit then
    TMaskEdit (Components [i]).Clear;
  end;
end;

procedure TFPDCA.enable_bt;
var i : integer;
begin
  for i := 0 to FPDCA.ComponentCount -1 do
  begin
    if FPDCA.Components [i] is TButton then
    TButton (Components [i]).Enabled:=genable;
  end;
end;

procedure TFPDCA.grava_incluir;
begin
  try
    incluir;
    dm.SQLTrans.CommitRetaining;
    consulta_feliciano;
    Showmessage('Inclus??o efetuada com sucesso!');
    limpa_campos;
    //travando;
  except
    On E:Exception do
      begin
        dm.SQLTrans.RollbackRetaining;
        consulta_feliciano;
        Showmessage('Falha na inclus??o dos dados!'#13#10'Mensagem: '+E.Message);
      end;
  end;

end;

procedure TFPDCA.grava_modificar;
begin
  try
    modificar;
    dm.SQLTrans.CommitRetaining;
    consulta_feliciano;
    Showmessage('Modifica????o efetuada com sucesso!');
    limpa_campos;
    //travando;
  except
    On E:Exception do
      begin
        dm.SQLTrans.RollbackRetaining;
        consulta_feliciano;
        Showmessage('Falha na modifica????o dos dados!'#13#10'Mensagem: '+E.Message);
      end;
  end;
end;

procedure TFPDCA.incluir;
begin
  with dm.SQLQPDCA do
  dm.SQLQPDCA.Close;
  dm.SQLQPDCA.SQL.Clear;
  dm.SQLQPDCA.Sql.Add(' insert into pdca_van (num_projeto, nom_projeto, usuario_resp, '+
                      ' area, dat_inclusao, dat_revisao, seq_item, foco_oque, '+
                      ' motivo_por_que, resp_quem, prazo_quando, local_onde, acoes_como, '+
                      ' valores_quanto, ganhos_estimado, avaliacao25, avaliacao50, '+
                      ' avaliacao75, avaliacao100, anexo) '+
                      ' Values '+
                      ' (:prmNum, :prmNom, :prmUsre, :prmArea, :prmDati, '+
                      '  :prmDatr, :prmSeq, :prmFoc, :prmMot, :prmRes, '+
                      '  :prmPrz, :prmLoc, :prmAco, :prmVal, :prmGan, '+
                      '  :prmAv25, :prmAv50, :prmAv75, :prmAv100, :prmAnex)');
  dm.SQLQPDCA.ParamByName('prmNum').AsString:=LEnum_proj.Text;
  dm.SQLQPDCA.ParamByName('prmNom').AsString:=LEnom_proj.Text;
  dm.SQLQPDCA.ParamByName('prmUsre').AsString:=LEusu_resp.Text;
  dm.SQLQPDCA.ParamByName('prmArea').AsString:=CBArea.Text;
  dm.SQLQPDCA.ParamByName('prmDati').AsString:=MEDat_inc.Text;
  dm.SQLQPDCA.ParamByName('prmDatr').AsString:=MEDat_inc.Text;
  dm.SQLQPDCA.ParamByName('prmSeq').AsString:=ESeq_item.Text;
  dm.SQLQPDCA.ParamByName('prmFoc').AsString:=MFoco.Text;
  dm.SQLQPDCA.ParamByName('prmMot').AsString:=MMotivo.Text;
  dm.SQLQPDCA.ParamByName('prmRes').AsString:=ERespon.Text;
  dm.SQLQPDCA.ParamByName('prmPrz').AsString:=MEPrazo.Text;
  dm.SQLQPDCA.ParamByName('prmLoc').AsString:=CBLocal.Text;
  dm.SQLQPDCA.ParamByName('prmAco').AsString:=MMetodo.Text;
  dm.SQLQPDCA.ParamByName('prmVal').AsString:=EVal.Text;
  dm.SQLQPDCA.ParamByName('prmGan').AsString:=LEganhos.Text;
  dm.SQLQPDCA.ParamByName('prmAv25').AsString:=CBAva25.Text;
  dm.SQLQPDCA.ParamByName('prmAv50').AsString:=CBAva50.Text;
  dm.SQLQPDCA.ParamByName('prmAv75').AsString:=CBAva75.Text;
  dm.SQLQPDCA.ParamByName('prmAv100').AsString:=CBAva100.Text;
  dm.SQLQPDCA.ParamByName('prmAnex').AsString:='';
  dm.SQLQPDCA.ExecSQL;
end;

procedure TFPDCA.codifica_auto;
var
  cod,cod2 : String;
  i,x : Real;
begin
i:=0;
x:=0;
  begin
    if (novo_proj = 'S') then
    begin
    with dm.SQLQseq do
    begin
      Close;
      SQL.Clear;
      SQL.Add('select max(num_projeto) as num from pdca_van');
      Open;
      if (fieldByname('num').AsString) = '' then
      begin
        i:=0;
        cod:=floattostr(i);
        cod:=FormatFloat('00000',i+1);
        LEnum_proj.Text:=cod;
      end
      else
      begin
        i:=(fieldByname('num').AsFloat);
        cod:=floattostr(i);
        cod:=FormatFloat('00000',i+1);
        LEnum_proj.Text:=cod;
      end;
    end;
    end;
    end;
    if (novo_proj <> 'S') then
    begin
      ShowMessage('aqui');
      cod:=Trim(LEnum_proj.Text);
    end;
    with DM.SQLQSEQ do   //aqui faz seq_item
    begin
      Close;
      SQL.Clear;
      SQL.Add('select max(seq_item) as seq from pdca_van');
      SQL.Add('where num_projeto ='+ cod);
      Open;
      if (FieldByName('seq').AsString) = '' then
      begin
        x:=0;
        cod2:=FloatToStr(x);
        cod2:=FormatFloat('00000', x+1);
        ESeq_item.Text:=cod2;
      end
      else
      begin
        x:=(FieldByName('seq').AsFloat);
        cod2:=FloatToStr(x);
        cod2:=FormatFloat('00000', x+1);
        ESeq_item.Text:=cod2;
      end;
    end;
  end;
//end;

procedure TFPDCA.FormCreate(Sender: TObject);
begin

end;

procedure TFPDCA.FormShow(Sender: TObject);
begin
  gusuario:=FLogar.glob_user;
  ShowMessage(gusuario);
  LEusu_resp.Text:=gusuario;
  consulta_feliciano;
  //genable:= false;
  bloquear_campos;
  //enable_bt;
  //btLogar.Enabled:=true;
  //btsair.Enabled:=true;

end;

procedure TFPDCA.Image1Click(Sender: TObject);
begin

end;

procedure TFPDCA.consulta_cc;
begin
  with dm.SQLQCC do
    dm.SQLQCC.Close;
    dm.SQLQCC.SQL.Clear;
    dm.SQLQCC.SQL.Add('select * from CAD_CC');
    dm.SQLQCC.SQL.Add('where ies_situa=:prmsitua');
    dm.SQLQCC.ParamByName('prmsitua').AsString:='A';
    dm.SQLQCC.Open;
end;

procedure TFPDCA.consulta_feliciano;
begin
  with dm.SQLQPDCA do
    dm.SQLQPDCA.Close;
    dm.SQLQPDCA.SQL.Clear;
    dm.SQLQPDCA.SQL.Add('select * from pdca_van');
    dm.SQLQPDCA.SQL.Add('order by seq_item');
    dm.SQLQPDCA.Open;
end;

procedure TFPDCA.enter(Sender: TObject);
begin

end;

{procedure TFPDCA.cbrumoEnter(Sender: TObject);
begin
  cbrumo.items.Add('D');
  cbrumo.items.Add('R');
  cbrumo.items.Add('A');
  cbrumo.items.Add('I');
end;}

procedure TFPDCA.cbstatusEnter(Sender: TObject);
begin

end;

procedure TFPDCA.CBAva25Exit(Sender: TObject);
begin
  CBAva25.Text:= ColorToString(CBAva25.Selected);
end;

procedure TFPDCA.DBGridDblClick(Sender: TObject);
begin
  carrega_dados;
end;

procedure TFPDCA.DBGridDrawColumnCell(Sender: TObject; const Rect: TRect;
          DataCol: Integer; Column: TColumn; State: TGridDrawState);
var
  cores : string;
begin
  with DBGrid do
    begin
      if AnsiLowerCase(Column.FieldName) = 'avaliacao25' then
      begin
        Canvas.Brush.Color := clSilver;
        cores:=trim(DM.SQLQPDCA.FieldByName('avaliacao25').AsString);
        if (cores = 'clRed') then
        begin
          Canvas.Brush.Color := clRed;
          Canvas.Font.Color  := clRed;
        end;
        if (cores = 'clBlue') then
        begin
          Canvas.Brush.Color := clBlue;
          Canvas.Font.Color  := clBlue;
        end;
        if (cores = 'clYellow') then
        begin
          Canvas.Brush.Color := clYellow;
          Canvas.Font.Color  := clYellow;
        end;
        if (cores = 'clLime') then
        begin
          Canvas.Brush.Color := clLime;
          Canvas.Font.Color  := clLime;
        end;
      end;
      Canvas.FillRect(Rect);
      DefaultDrawColumnCell(Rect,DataCol,Column,State);
    end;
end;

procedure TFPDCA.btsairClick(Sender: TObject);
begin
  close;
end;

procedure TFPDCA.btsalvarClick(Sender: TObject);
begin
  if ((trim(ESeq_item.Text) <> '') and (trim(CBArea.Text) <> '')) then
  begin
     if (gconfirma = 'I') then
        grava_incluir;
     if (gconfirma = 'M') then
        grava_modificar;
  end
  else
  begin
     ShowMessage('Existe(m) campo(s) sem preenchimento.');
  end;
  genable:=true;
  enable_bt;
  //limpa_campos;
  consulta_feliciano;

end;

procedure TFPDCA.btanexoClick(Sender: TObject);
begin
  if ((trim(ESeq_item.Text) <> '') and (trim(CBArea.Text) <> '')) then
  begin
     if odir.Execute then
        begin
          if CopyFile(PChar(odir.FileName), PChar('C:\publico\'+ExtractFileName(odir.FileName)), True) then
             arquivo_anexo:=PChar('C:\publico\'+ExtractFileName(odir.FileName));
             ShowMessage('Arquivo copiado com sucesso!');
        end;
  end
  else
     ShowMessage('Nenhum registro selecionado!');
end;

procedure TFPDCA.Button9Click(Sender: TObject);
begin
  GerarExcel(dm.SQLQPDCA);
end;

procedure TFPDCA.cbdepartExit(Sender: TObject);
begin
  if (trim(CBArea.Text) <> '') then
  begin
     CBArea.Text:=trim(CBArea.Text);
  end
  else
     ShowMessage('Campo n??o pode ser nulo.');
end;

procedure TFPDCA.CBLocalExit(Sender: TObject);
begin
  if (trim(CBLocal.Text) <> '') then
  begin
     CBLocal.Text:=trim(CBLocal.Text);
  end
  else
     ShowMessage('Campo n??o pode ser nulo.');
end;

procedure TFPDCA.btincluirClick(Sender: TObject);
begin
  gconfirma:='I';
  genable:=true;
  bloquear_campos;
  genable:=false;
  enable_bt;
  //gusuario:=FLogar.glob_user;
  LEusu_resp.Text:=gusuario;
  MEDat_inc.Text:=DateToStr(now);
  carrega_cc;
  btsalvar.Enabled:=true;
  btcancelar.Enabled:=true;
  btanexo.Enabled:=true;
  consulta_feliciano;

  if consulta_proj(gusuario) then
  begin
     if Application.MessageBox ('Deseja cadastrar um novo projeto?','Inclus??o',
                                MB_YESNO+MB_ICONEXCLAMATION)=idyes then
     begin
        novo_proj:='S';
        codifica_auto;
        LEnom_proj.SetFocus;
     end
     else
     begin
       novo_proj:='N';
       FCarrega.ShowModal;
       codifica_auto;
       CBArea.SetFocus;
     end;
  end
  else
  begin
    novo_proj:='S';
    codifica_auto;
    LEnom_proj.SetFocus;
  end;
end;

function TFPDCA.consulta_proj(user: String):Boolean;
begin
  with DM.SQLQSEQ do
    begin
      Close;
      SQL.Clear;
      SQL.Text:='select * from pdca_van where usuario_resp like '+QuotedStr(user+'%');
      begin
        Prepare;
        Open;
        if RowsAffected > 0 then
        Result:=True
        else
        Result:=False;
      end;
    end;
end;

procedure TFPDCA.btLogarClick(Sender: TObject);
begin
    FLogar.ShowModal;
end;

procedure TFPDCA.btmodificarClick(Sender: TObject);
begin
  if (Trim(ESeq_item.Text) <> '') and
     (Trim(CBArea.Text) <> '') and
     (Trim(CBLocal.Text) <> '') then
    begin
       gconfirma:='M';
       genable:=true;
       bloquear_campos;
       genable:=false;
       enable_bt;
       LEnom_proj.SetFocus;
       btsalvar.Enabled:=true;
       btcancelar.Enabled:=true;
       carrega_cc;
    end
  else
    showmessage('Nenhuma sele????o ativa!');
end;

procedure TFPDCA.btcancelarClick(Sender: TObject);
begin
  limpa_campos;
  genable:=true;
  enable_bt;
  consulta_feliciano;
  genable:=false;
  bloquear_campos;
end;

procedure TFPDCA.btexcluirClick(Sender: TObject);
begin
  if (trim(ESeq_item.Text) <> '') and
     (trim(CBArea.Text) <> '') and
     (trim(CBLocal.Text) <> '') then
  begin
     try
       if Application.MessageBox ('Deseja excluir registro?','Exclus??o',MB_YESNO+MB_ICONEXCLAMATION)=idyes then
       //if MessageDlg('Exclus??o', 'Deseja excluir registro?', mtConfirmation,
       //              [mbYes, mbNo],0) = mrYes then
       begin
          excluir;
          dm.SQLTrans.CommitRetaining;
          consulta_feliciano;
          Showmessage('Exclus??o efetuada com sucesso!');
          limpa_campos;
       end
       else
          showmessage('Exclus??o cancelada.');
       except
         On E:Exception do
         begin
           dm.SQLTrans.RollbackRetaining;
           consulta_feliciano;
           Showmessage('Falha na exclus??o dos dados!'#13#10'Mensagem: '+E.Message);
         end;
       end;
  end
  else
      ShowMessage('Nenhum sele????o ativa.');
end;


procedure TFPDCA.carrega_dados;
var
  cor,cor2,cor3,cor4 : String;
begin
  LEnum_proj.Text	:=	dm.SQLQPDCA.FieldByName('num_projeto').AsString	;
  LEnom_proj.Text	:=	dm.SQLQPDCA.FieldByName('nom_projeto').AsString	;
  LEusu_resp.Text	:=	dm.SQLQPDCA.FieldByName('usuario_resp').AsString;
  CBArea.Text	        :=	dm.SQLQPDCA.FieldByName('area').AsString;
  MEDat_inc.Text	:=	dm.SQLQPDCA.FieldByName('dat_inclusao').AsString;
  MEDat_inc.Text	:=	dm.SQLQPDCA.FieldByName('dat_revisao').AsString	;
  ESeq_item.Text	:=	dm.SQLQPDCA.FieldByName('seq_item').AsString;
  MFoco.Text	        :=	dm.SQLQPDCA.FieldByName('foco_oque').AsString;
  MMotivo.Text	        :=	dm.SQLQPDCA.FieldByName('motivo_por_que').AsString;
  ERespon.Text	        :=	dm.SQLQPDCA.FieldByName('resp_quem').AsString;
  MEPrazo.Text	        :=	dm.SQLQPDCA.FieldByName('prazo_quando').AsString;
  CBLocal.Text	        :=	dm.SQLQPDCA.FieldByName('local_onde').AsString;
  MMetodo.Text	        :=	dm.SQLQPDCA.FieldByName('acoes_como').AsString;
  EVal.Text	        :=	Formatfloat('#,##0.00',dm.SQLQPDCA.FieldByName('valores_quanto').AsFloat);
  LEganhos.Text	        :=	dm.SQLQPDCA.FieldByName('ganhos_estimado').AsString;
  //CBAva25.Text	        :=	dm.SQLQPDCA.FieldByName('avaliacao25').AsString;
  //CBAva50.Text	        :=	dm.SQLQPDCA.FieldByName('avaliacao50').AsString;
  //CBAva75.Text	        :=	dm.SQLQPDCA.FieldByName('avaliacao75').AsString;
  //CBAva100.Text	        :=	dm.SQLQPDCA.FieldByName('avaliacao100').AsString;
  //:=	  dm.SQLQPDCA.FieldByName('prmAnex').AsString	;


  cor  :=trim(dm.SQLQPDCA.FieldByName('avaliacao25').AsString);
  cor2 :=trim(dm.SQLQPDCA.FieldByName('avaliacao50').AsString);
  cor3 :=trim(dm.SQLQPDCA.FieldByName('avaliacao75').AsString);
  cor4 :=trim(dm.SQLQPDCA.FieldByName('avaliacao100').AsString);

  if (cor = 'clRed') then
  begin
    CBAva25.Selected:=clRed
  end;
  if (cor = 'clLime') then
  begin
    CBAva25.Selected:=clLime
  end;
  if (cor = 'clYellow') then
  begin
    CBAva25.Selected:=clYellow
  end;
  if (cor2 = 'clSilver') then
  begin
    CBAva50.Selected:=clSilver
  end;
  if (cor3 = 'clSilver') then
  begin
    CBAva75.Selected:=clSilver
  end;
  if (cor4 = 'clSilver') then
  begin
    CBAva100.Selected:=clSilver
  end;
  //EVal.Text:=Formatfloat('#,##0.00',(dm.SQLQPDCA.FieldByName('valor').AsFloat));
  //lbanexo.Caption:=dm.SQLQPDCA.FieldByName('anexo').AsString;
end;

end.

