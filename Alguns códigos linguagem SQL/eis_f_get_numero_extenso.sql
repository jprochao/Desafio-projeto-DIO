drop  FUNCTION eis_f_get_numero_extenso ;

CREATE FUNCTION eis_f_get_numero_extenso ( pnValor DECIMAL(18,2) )
					RETURNING CHAR(8000)

define valorCentavos decimal(20,0); --Valor dos Centavos
define valorInt decimal(20,0); --Remove os centavos
define valorStr char(20); --Valor como string
define pedacoStr1 char(20); --Pedaco da str
define pedacoStr2 char(20); --Pedaco da str
define pedacoStr3 char(20); --Pedaco da str
define pedacoInt1 decimal(20,0); --Pedaco da INT
define pedacoInt2 decimal(20,0); --Pedaco da INT
define pedacoInt3 decimal(20,0); --Pedaco da INT
define menorN decimal(20,0);
define aux1 char(50);
define aux2 char(50);
define aux3 char(50);
define retorno CHAR(8000);
define vnPos smallint;

let retorno = '';
let valorInt = cast( trunc(pnValor) as decimal(20,0) );
let valorStr = cast( valorInt as char(20) );
let valorCentavos =  cast( ( pnValor * 100 ) - ( valorInt * 100 )  as decimal(20,0) ); 

--return valorCentavos;


--Retorna Zero
if (pnValor = 0)
then return 'Zero';
end if;

--Busca o número de casas (sempre em 3)
select min( menor ) - 1 
 into menorN
 from eis_t_milhar where menor > length(valorStr);

--Adiciona casas a esquerda (tratando sempre de 3 em 3 casas)
let valorStr = lpad(trim(valorStr), menorN , '0' );

--Varre Convertendo os valores para valores por extenso
  for vnPos = 1 to length(valorStr) / 3

    LET pedacoStr1 = substr(valorStr, 1, 3);
    LET pedacoStr2 = substr(valorStr, 2, 2);
    LET pedacoStr3 = substr(valorStr, 3, 1);
    LET pedacoInt1 = cast(pedacoStr1 as decimal(20,0));
    LET pedacoInt2 = cast(pedacoStr2 as decimal(20,0));
    LET pedacoInt3 = cast(pedacoStr3 as decimal(20,0));

    --Busca a centena
    SELECT descricao
    INTO aux1
    FROM eis_t_numeros 
    WHERE ( ( length( cast(pedacoInt1 as char(99) ) ) = 3) AND pedacoStr1 BETWEEN menor AND maior) ;

    --Busca a dezena
    SELECT descricao
    INTO aux2
    FROM eis_t_numeros 
    WHERE ( (pedacoInt2 <> 0 AND length( cast(pedacoInt2 as char(99) ) ) = 2) AND pedacoInt2 BETWEEN menor AND maior) ;

    --Busca a centena
    SELECT descricao
    INTO aux3
    FROM eis_t_numeros 
    WHERE ( (pedacoInt3 <> 0 AND(pedacoInt2 < 10 OR pedacoInt2 > 20)) AND pedacoInt3 BETWEEN menor AND maior); --Remove de 11 a 19

    let retorno = trim(nvl(retorno,''))||' '||trim(nvl(aux1,''))||' '||trim(nvl(aux2,''))||' '||trim(nvl(aux3,''))||' ';

    --Define o milhar (se foi escrito algum valor para ele)
    IF ( pedacoInt1 > 0 ) then
        SELECT CASE WHEN pedacoInt1 > 1 
                    THEN descricaoPL 
                    ELSE descricaoUm END 
           INTO AUX1
           FROM eis_t_milhar 
          WHERE (length(valorStr) BETWEEN menor and maior);
    end if;
    let retorno = trim(nvl(retorno,''))||' '||trim(nvl(aux1,''));

    --Remove os pedaços efetuados
    LET valorStr = substr(valorStr, 4, 99);

    IF ( cast( substr( valorStr, 1, 3) as int ) > 0) then
        LET retorno = trim(nvl(retorno,'')) || ' e ';
    ELSE
        IF ( cast( valorStr as decimal(20,0) ) = 0 AND length(valorStr) = 6) then
           LET retorno = trim(nvl(retorno,'')) || ' de ';
        END IF;
    END IF;
  
  end for;

    
    --Somente coloca se tiver algum valor.
    IF ( length(retorno) > 0 ) then
       lET retorno = trim(nvl(retorno,'')) || CASE WHEN valorInt > 1 THEN ' Reais ' ELSE ' Real ' END ;
    END IF;


    --Busca os centavos
    LET valorStr = trim(cast(valorCentavos as char(80) ))||'00';

    --Define os centavos
    --Busca os 2 caracteres
    LET pedacoStr1 = substr(valorStr, 1, 2);
    LET pedacoStr2 = substr(valorStr, 2, 1);
    LET pedacoInt1 = cast(pedacoStr1 as decimal(20,0));
    LET pedacoInt2 = cast(pedacoStr2 as decimal(20,0));


    --Define a descrição (Não coloca se não tiver reais)
    IF (pedacoInt1 > 0 AND (length(retorno) > 0) ) then
        LET retorno = trim(nvl(retorno,'')) || ' e ';
    end if;

    --Busca a dezena
    SELECT descricao
    INTO aux1
    FROM eis_t_numeros 
    WHERE ( (pedacoInt1 <> 0 AND length( cast(pedacoInt1 as char(99) ) ) = 2) AND pedacoInt1 BETWEEN menor AND maior);

    --Busca a centena
    SELECT descricao
    INTO aux2
    FROM eis_t_numeros 
    WHERE ( (pedacoInt2 <> 0 AND(pedacoInt1 < 10 OR pedacoInt1 > 20)) AND pedacoInt2 BETWEEN menor AND maior); --Remove de 11 a 19


    let retorno = trim(nvl(retorno,''))||' '||trim(nvl(aux1,''))||' '||trim(nvl(aux2,''))||' ';

    --Define a descrição
    IF (pedacoInt1 > 0) then
        LET retorno = trim(nvl(retorno,'')) || ' Centavo' || CASE WHEN pedacoInt1 > 1 THEN 's' ELSE '' END;
    END IF;


  RETURN retorno;

END function;
GO
