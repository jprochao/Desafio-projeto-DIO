/* atualizado em 01/08/2019 */

-- drop function eis_f_gera_estrutura;

create function eis_f_gera_estrutura (p_cod_empresa char(01), l_item_pai char(15)) returning int;

	DEFINE lr_estrut ROW (empresa      CHAR(02),
		                  item_pai     CHAR(15),
		                  item_comp    CHAR(15),
		                  qtd_nece     DEC(14,7),
		                  sequencia    INTEGER,
		                  repete       SMALLINT,
		                  nivel        SMALLINT);
    DEFINE l_texto                     CHAR(50);

SET DEBUG FILE TO '/tmp/gera_estrutura.log';
    trace on;

    LET lr_estrut = NULL;

    FOREACH
        SELECT DISTINCT cod_empresa,
               cod_item_pai,
               cod_item_compon,
               qtd_necessaria,
               num_sequencia/*,
               CONNECT_BY_ISLEAF leaf, 
               LEVEL*/
          INTO lr_estrut.empresa,
               lr_estrut.item_pai,
               lr_estrut.item_comp,
               lr_estrut.qtd_nece,
               lr_estrut.sequencia/*,
               lr_estrut.repete,
               lr_estrut.nivel*/
          FROM estrut_grade
         WHERE cod_empresa       = p_cod_empresa
         START WITH cod_item_pai = l_item_pai
         CONNECT BY cod_item_pai = PRIOR cod_item_compon
		
		
		SELECT texto
		  INTO l_texto
		  FROM man_estrut_texto
		 WHERE empresa         = p_cod_empresa
		   AND item_pai        = lr_estrut.item_pai
		   AND item_componente = lr_estrut.item_comp
		   AND sequencia       = lr_estrut.sequencia;
		
		
		INSERT INTO w_van0302 (item_pai,
		                       item_comp,
		                       qtd_nece,
		                       desenho,
		                       den_compon,
		                       peso_compon,
		                       cod_material,
		                       den_material,
		                       medidas) VALUES (lr_estrut.item_pai,
		                                        lr_estrut.item_comp,
		                                        lr_estrut.qtd_nece,
		                                        "",
		                                        "",
		                                        "",
		                                        "",
		                                        "",
		                                        l_texto);
		
		
		
		LET lr_estrut = NULL;
	
	END FOREACH;
	
	RETURN 1;
	
 END FUNCTION;