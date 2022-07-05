
drop function eis_f_get_taxa_adm;
CREATE FUNCTION eis_f_get_taxa_adm ( data1 date)
                                         RETURNING decimal(8,2)
    define valor decimal(8,2);
    define valorcc decimal(8,2);
    define valoraux decimal(8,2);
    define tothoras decimal(8,2);

   //total de apontamento no dia
    select sum(tmp_ativo_producao)
    into tothoras
    from man_apo_mestre mam
    join man_tempo_producao tp on (mam.empresa = tp.empresa
                               and mam.seq_reg_mestre = tp.seq_reg_mestre
                               and tp.periodo_produtivo = 'A')
    where mam.empresa = '01'
    and extend(mam.data_producao, year to month) = extend(data1, year to month)
    and mam.sit_apontamento = 'A';

    //grupo administrativo
    select sum(val_debito_seg-val_credito_seg)
    into valoraux
    from saldos 
    where per_contabil = year(data1)
    and cod_seg_periodo = month(data1)
    and num_conta like '3.03.03%';

    let valorcc = nvl(valoraux,0);
    
    select sum(val_debito_seg-val_credito_seg)
    into valoraux
    from saldos 
    where per_contabil = year(data1)
    and cod_seg_periodo = month(data1)
    and num_conta like '3.03.04%';
   
    let valorcc = valorcc+nvl(valoraux,0);

    let valorcc = (valorcc*(0.4)) / (nvl(tothoras,1));
    
    return (nvl(valorcc,0));

end function;

/*
select 
year(today),
month(today),
eis_f_get_taxa_adm('2009-06-15') from empresa


/**
select 
sum(val_debito_seg-val_credito_seg)
from saldos 
where 
per_contabil = '2009'
and cod_seg_periodo = '7'
and num_conta like '3.03.03%'

*/  