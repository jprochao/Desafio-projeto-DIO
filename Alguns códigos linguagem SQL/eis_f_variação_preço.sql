-- atualizado em 19/05/2015
-- atualizado em 28/11/2018

-- DROP FUNCTION eis_f_variacao_preco;

CREATE FUNCTION EIS_F_VARIACAO_PRECO ( EMP CHAR(02) )
                                        RETURNING CHAR(20)
  DEFINE L_COD_ITEM CHAR(15);
  DEFINE L_COD_FORNEC CHAR(15);
  DEFINE L_DAT_COMP DATE;
  DEFINE L_PRECO    DECIMAL(17,6);
  DEFINE L_ORDEM    SMALLINT;
  DEFINE LR_COD     CHAR(15);
  DEFINE L_COD_ITEM1 CHAR(15);
  DEFINE L_COD_FORNEC1 CHAR(15);
  DEFINE L_DAT_COMP1 DATE;
  DEFINE L_PRECO1    DECIMAL(17,6);
  DEFINE L_MSG       CHAR(20);
  
  DELETE FROM T_VARIACAO;

  DELETE FROM TT_VARIACAO; 
  
  FOREACH
  	SELECT DISTINCT COD_ITEM
  	  INTO L_COD_ITEM
  	  FROM ITEM_FORNEC_COMP
  	 WHERE COD_EMPRESA  = EMP
  	 
  	LET L_ORDEM = 1;
  	
  	FOREACH
  		SELECT COD_ITEM,
               COD_FORNECEDOR,
  		       DAT_COMPRA_2,
  		       PRE_UNIT_COMPRA_2 
  		  INTO LR_COD,
               L_COD_FORNEC,
  		       L_DAT_COMP,
  		       L_PRECO
  		  FROM ITEM_FORNEC_COMP 
  		 WHERE DAT_COMPRA_2 IS NOT NULL
  		   AND COD_ITEM = L_COD_ITEM
  		   
  		INSERT INTO T_VARIACAO VALUES (L_COD_ITEM,
                                       L_COD_FORNEC,
    	                               L_DAT_COMP,
    	                               L_PRECO,
                                       CURRENT);
  	END FOREACH;
    FOREACH	 
  		SELECT COD_ITEM,
               COD_FORNECEDOR,
               DAT_COMPRA_3,
               PRE_UNIT_COMPRA_3 
          INTO LR_COD,
               L_COD_FORNEC,
               L_DAT_COMP,
               L_PRECO
          FROM ITEM_FORNEC_COMP 
         WHERE DAT_COMPRA_3 IS NOT NULL 
           AND COD_ITEM = L_COD_ITEM
    
    	INSERT INTO T_VARIACAO VALUES (L_COD_ITEM,
                                       L_COD_FORNEC,
    	                               L_DAT_COMP,
    	                               L_PRECO,
                                       CURRENT);
    END FOREACH;
    FOREACH
    	SELECT COD_ITEM , 
               COD_FORNECEDOR,
    	       DAT_COMPRA , 
    	       PRE_UNIT_COMPRA 
    	  INTO L_COD_ITEM1,
               L_COD_FORNEC1,
    	       L_DAT_COMP1,
    	       L_PRECO1
    	  FROM T_VARIACAO
    	 WHERE COD_ITEM = L_COD_ITEM
    	 ORDER BY 1, 3 DESC
    	 INSERT INTO TT_VARIACAO VALUES (L_COD_ITEM1,
                                         L_COD_FORNEC1,
    	                                 L_DAT_COMP1,
    	                                 L_PRECO1,
    	                                 L_ORDEM,
                                         CURRENT);
    	                                 LET L_ORDEM = L_ORDEM + 1;
        IF L_ORDEM > 3 THEN
            EXIT FOREACH;
        END IF;
	END FOREACH;
			
  END FOREACH;	
  IF SQLCODE = 0 THEN
    LET L_MSG = "EXECUTADO COM SUCESSO";
  ELSE
    LET L_MSG = "ERRO - ", SQLCODE;
  END IF;

  RETURN L_MSG;
    
 END FUNCTION;
GO
