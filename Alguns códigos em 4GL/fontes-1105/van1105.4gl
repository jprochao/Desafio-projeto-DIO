DATABASE logix

#-----------------------------------------------------------------#
# SISTEMA.: ASSISTENCIA TECNICA E PEÇAS VANTEC                    #
# PROGRAMA: VAN1105                                               #
# OBJETIVO: APONTAMENTO DAS HORAS TECNICA PRESTADAS AOS CLIENTES  #
# AUTOR...: JOÃO PAULO                                            #
# DATA....: 11/05/2011                                            #
#-----------------------------------------------------------------#  
                 
 GLOBALS
	DEFINE p_cod_empresa           LIKE empresa.cod_empresa,
	       p_den_empresa           LIKE empresa.den_empresa,
	       p_user                  LIKE usuario.nom_usuario,
	       p_status                SMALLINT,
	       ies_relatorio           SMALLINT
         	
 	DEFINE p_versao                CHAR(18),
 	       m_hora                  CHAR(08)
 	       
 	DEFINE p_comando       CHAR(80),
 	       p_caminho       CHAR(80),
 	       p_nom_tela      CHAR(80),
 	       p_help          CHAR(80),
 	       p_where         CHAR(100),
 	       p_cancel        INTEGER,
 	       g_ies_grafico   SMALLINT
	
	DEFINE mr_cdvr RECORD LIKE cdv_solic_viagem.*
		   
	DEFINE m_consulta_ativa SMALLINT
	
	DEFINE ma_array		ARRAY[3000] OF RECORD
		      dat_servico  LIKE apo_hr_tec_van.dat_servico,
		      hr_ini_man   DATETIME HOUR TO MINUTE,
		      hr_fin_man   DATETIME HOUR TO MINUTE,
		      hr_ini_tar   DATETIME HOUR TO MINUTE,
		      hr_fin_tar   DATETIME HOUR TO MINUTE,
		      hr_ini_ext   DATETIME HOUR TO MINUTE,
		      hr_fin_ext   DATETIME HOUR TO MINUTE
		                               END RECORD
		                               
	DEFINE mr_cdv RECORD
		      empresa             LIKE cdv_solic_viagem.empresa,
		      num_viagem          LIKE cdv_solic_viagem.num_viagem, 
		      sequencia           DECIMAL(5,0),
		      matricula_viajante  LIKE cdv_solic_viagem.matricula_viajante,
		      cliente_destino     LIKE cdv_solic_viagem.cliente_destino,
		      veiculo             LIKE apo_hr_tec_van.veiculo,
		      placa               LIKE apo_hr_tec_van.placa,
		      km_saida            LIKE apo_hr_tec_van.km_saida,
		      km_chegada          LIKE apo_hr_tec_van.km_chegada,
		      mat_auxiliar        LIKE cdv_solic_viagem.matricula_viajante,
		      auxiliar            LIKE apo_hr_tec_van.auxiliar
		           END RECORD
	
	DEFINE 	p_ies_impressao       CHAR(001),
         	g_ies_ambiente        CHAR(001),
         	p_nom_arquivo         CHAR(100),
         	comando               CHAR(80),
         	m_caminho             CHAR(100) 
         	
 	DEFINE mr_dat		RECORD
 		      mviajante    LIKE cdv_solic_viagem.matricula_viajante,
 		      dat_ini      DATE,
 		      dat_fim      DATE
 		          END RECORD
 		          			
 END GLOBALS
                                                                                                                 
 MAIN
 
 	CALL log0180_conecta_usuario()
 	
 		LET p_versao = "VAN1105-10.02.03e"
  	WHENEVER ANY ERROR CONTINUE
		 CALL log1400_isolation()
  	WHENEVER ERROR STOP
  	DEFER INTERRUPT

	 	CALL log140_procura_caminho("VAN1105.iem") RETURNING p_caminho
  	LET p_help = p_caminho CLIPPED
  	OPTIONS
    	HELP FILE p_help

  	CALL log001_acessa_usuario("PADRAO","LOGERP;OUTROS")
    	RETURNING p_status,
    	          p_cod_empresa,
    	          p_user
    	
    	IF p_status = 0  THEN
    		CALL van1105_controle()
    	END IF
    	
 END MAIN
 
#------------------#
 FUNCTION van1105_controle()
#------------------#

	CALL log140_procura_caminho("VAN1105") RETURNING p_nom_tela
	OPEN WINDOW w_van1105 AT 2,02 WITH FORM p_nom_tela
	ATTRIBUTE(BORDER, MESSAGE LINE LAST, PROMPT LINE LAST)
	CALL log006_exibe_teclas("02 07", p_versao)
	CLEAR FORM
	CURRENT WINDOW is w_van1105
	LET m_consulta_ativa = FALSE
		
	MENU "opcao"
	
		COMMAND KEY ("C") "Consultar" "Consultar Texto dos Itens por Pedidos."
		MESSAGE ""
		IF log005_seguranca(p_user,"PADRAO","VAN1105","CO")  THEN
			CALL van1105_consultar()
		END IF
		
		COMMAND KEY ("S") "Seguinte" "Exibe o registro seguinte."
		IF m_consulta_ativa = TRUE THEN
			CALL van1105_paginacao("seguinte")
		ELSE
			ERROR "Não existe nenhuma consulta ativa."
		END IF
		
		COMMAND KEY ("A") "Anterior" "Exibe o registro anterior."
		IF m_consulta_ativa = TRUE THEN
			CALL van1105_paginacao("anterior")
		ELSE
			ERROR "Não existe nenhuma consulta ativa."
		END IF
		
		COMMAND KEY("L") "listar" "lista "
		LET INT_FLAG = FALSE
		MESSAGE ""
		CALL van1105_seta_variaveis_relatorio()
		
		COMMAND KEY("F") "Fim" "Sai do programa."
		EXIT MENU
		
		COMMAND KEY("P") "aPontar" "Apontamento Horas Trabalhadas."
		IF m_consulta_ativa = TRUE THEN
			CALL van1105_aponta()
		ELSE
			ERROR "Não existe nenhuma consulta ativa."
			NEXT OPTION "Consultar"
		END IF
		
		COMMAND KEY("O") "fOlga" "Horas folgadas."
		IF m_consulta_ativa = TRUE THEN
			CALL van1105_folga()
		ELSE
			ERROR "Não existe nenhuma consulta ativa."
			NEXT OPTION "Consultar"
		END IF
	
 	END MENU
 
 END FUNCTION

#---------------------------#
 FUNCTION van1105_verifica_auxiliar()
#---------------------------#

	DEFINE l_nome_auxiliar LIKE fornecedor.raz_social
	
	INITIALIZE l_nome_auxiliar TO NULL
	
	WHENEVER ERROR CONTINUE
	SELECT a.raz_social
	  INTO l_nome_auxiliar
	  FROM fornecedor a,
	       cdv_fornecedor_fun b
	 WHERE a.cod_fornecedor = b.cod_fornecedor
	   AND b.cod_funcio     = mr_cdv.mat_auxiliar
	WHENEVER ERROR STOP	
	IF SQLCA.SQLCODE <> 0 THEN
		RETURN FALSE
	ELSE 
		DISPLAY l_nome_auxiliar TO auxiliar
		RETURN TRUE
	END IF
		
 END FUNCTION

#-----------------------------------------#
 FUNCTION van1105_busca_nome_viajante()
#-----------------------------------------#

	DEFINE l_nome_viajante LIKE fornecedor.raz_social
	
	INITIALIZE l_nome_viajante TO NULL
	
	WHENEVER ERROR CONTINUE
	SELECT a.raz_social
		INTO l_nome_viajante
		FROM fornecedor a,
		     cdv_fornecedor_fun b
	 WHERE a.cod_fornecedor	= b.cod_fornecedor
	   AND b.cod_funcio     = mr_cdv.matricula_viajante
	WHENEVER ERROR STOP
	
	IF SQLCA.SQLCODE = 0 THEN
		DISPLAY l_nome_viajante TO viajante
	END IF
	
 END FUNCTION

#-----------------------------------#
 FUNCTION van1105_verifica_cliente()
#-----------------------------------#

	DEFINE l_nome_cliente LIKE clientes.nom_cliente
	
	WHENEVER ERROR CONTINUE
	SELECT nom_cliente
	  INTO l_nome_cliente
	  FROM clientes
	 WHERE cod_cliente = mr_cdv.cliente_destino
	WHENEVER ERROR STOP
	
	IF SQLCA.SQLCODE <> 0 THEN
		IF SQLCA.SQLCODE = NOTFOUND THEN  #notfound igual ao codigo 100
			ERROR "Cliente não cadastrado."
		ELSE
			ERROR "Erro ao selecionar cliente."
		END IF
		
		RETURN FALSE
	ELSE
		DISPLAY l_nome_cliente TO cliente
	END IF
	
	RETURN TRUE
	
END FUNCTION

#------------------------------------#
 FUNCTION van1105_busca_nome_cliente()
#------------------------------------#

	DEFINE l_nome_cliente LIKE clientes.nom_cliente
	
	INITIALIZE l_nome_cliente TO NULL
	
	WHENEVER ERROR CONTINUE
	SELECT nom_cliente
	  INTO l_nome_cliente
	  FROM clientes
	 WHERE cod_cliente = mr_cdv.cliente_destino
	WHENEVER ERROR STOP
	
	IF SQLCA.SQLCODE = 0 THEN
		DISPLAY l_nome_cliente TO cliente
	END IF
	
 END FUNCTION
 
#---------------------------#
 FUNCTION van1105_consultar()                                                     
#---------------------------#

	DEFINE where_clause CHAR(1000),
	       l_sql_stmt   CHAR(5000),
	       l_msg        CHAR(200)
	       
	INITIALIZE mr_cdv.* TO NULL
	
	CLEAR FORM
	
	DISPLAY p_cod_empresa TO empresa
	
	LET INT_FLAG = 0
	
	CONSTRUCT where_clause ON a.num_viagem,
	                          a.matricula_viajante,
	                          a.cliente_destino FROM num_viagem,
	                                                 matricula_viajante,
	                                                 cliente_destino	
		AFTER FIELD cliente_destino
			ON KEY (control-z)
				CALL van1105_popup_cli()
	END CONSTRUCT
	
	IF INT_FLAG <> 0 THEN
		LET INT_FLAG = 0
		CLEAR FORM
		RETURN FALSE
	END IF
	
	LET l_sql_stmt = " select a.empresa,a.num_viagem, '', a.matricula_viajante,a.cliente_destino, ",
	                 " substr(a.observacao, 0, 50), substr(a.observacao, 51, 100), substr(a.observacao, 101, 150), '', '', substr(a.observacao, 151, 200) ",
	                 " from cdv_solic_viagem a ",
	                 " where ", where_clause CLIPPED,
	                 " order by a.empresa, a.num_viagem  "
	                 
	PREPARE var_query FROM l_sql_stmt
	DECLARE cq_consulta SCROLL CURSOR WITH HOLD FOR var_query
		WHENEVER ERROR CONTINUE
		OPEN cq_consulta
		FETCH cq_consulta INTO mr_cdv.*
		WHENEVER ERROR STOP
		IF SQLCA.SQLCODE <> 0 THEN
			IF SQLCA.SQLCODE = 100 THEN
				CALL fgl_winmessage("Consulta Solicitação de Viagem", "Argumentos de pesquisa não encontrados.", "info")
			ELSE
				LET l_msg = "Erro ao selecionar dados da tabela cdv_solic_viagem - ", SQLCA.SQLCODE
				CALL fgl_winmessage("Consulta Solicitação de Viagem", l_msg, "stop")
			END IF
			RETURN FALSE
		END IF
		
		CALL van1105_exibe_dados()
		CALL van1105_consulta_aponta()
	LET m_consulta_ativa = TRUE
	RETURN TRUE

 END FUNCTION

#---------------------------------#
 FUNCTION van1105_consulta_aponta()
#---------------------------------#

	DEFINE l_msg   CHAR(200),
	       l_ind   INTEGER 
	       
	FOR l_ind = 1 TO 10
		INITIALIZE ma_array[l_ind].* TO NULL
	END FOR
	
	DECLARE cq_consulta_ap CURSOR FOR
		SELECT empresa,
		       num_viagem,
		       sequencia,
		       matricula_viajante,
		       cliente_destino,
		       veiculo, placa,
		       km_saida,
		       km_chegada,
		       matricula_auxiliar,
		       auxiliar
		  FROM apo_hr_tec_van
		 WHERE empresa		= mr_cdv.empresa
		   AND num_viagem	= mr_cdv.num_viagem
		   
	WHENEVER ERROR CONTINUE
	OPEN cq_consulta_ap
	FETCH cq_consulta_ap INTO mr_cdv.*
	WHENEVER ERROR STOP
	
	#if sqlca.sqlcode = 0 then
	CALL van1105_exibe_dados()
	CALL van1105_chama_aponta()
	LET m_consulta_ativa = TRUE
	RETURN TRUE
	#end if
	
 END FUNCTION
 
#---------------------------------#
 FUNCTION van1105_exibe_dados()
#---------------------------------#

	DISPLAY mr_cdv.empresa            TO empresa
	DISPLAY mr_cdv.num_viagem         TO num_viagem
	DISPLAY mr_cdv.matricula_viajante	TO matricula_viajante
	DISPLAY mr_cdv.cliente_destino		TO cliente_destino
	DISPLAY mr_cdv.veiculo            TO veiculo
	DISPLAY mr_cdv.placa              TO placa
	DISPLAY mr_cdv.km_saida           TO km_saida
	DISPLAY mr_cdv.km_chegada         TO km_chegada
	DISPLAY mr_cdv.mat_auxiliar       TO mat_aux
	DISPLAY mr_cdv.auxiliar           TO auxiliar
	
	CALL van1105_busca_nome_viajante()
	CALL van1105_busca_nome_cliente()
	
 END FUNCTION
 
#-----------------------------#
 FUNCTION van1105_chama_aponta()
#-----------------------------#

	DEFINE l_msg    CHAR(200),
	       p_ind    SMALLINT,
	       m_count  SMALLINT,
	       l_ind    INTEGER
	       
	FOR p_ind = 1 TO 100
		INITIALIZE ma_array[p_ind].* TO NULL
		IF p_ind <= 5 THEN
			DISPLAY ma_array[p_ind].* TO sr_array[p_ind].* 
		END IF
	END FOR
	
	WHENEVER ERROR CONTINUE
	DECLARE cq_array2 CURSOR FOR
		SELECT dat_servico,
		       hr_ini_man,
		       hr_fin_man,
		       hr_ini_tar,
		       hr_fin_tar,
		       hr_ini_ext,
		       hr_fin_ext
		  FROM apo_hr_tec_van
		 WHERE empresa 	= mr_cdv.empresa
		   AND num_viagem	= mr_cdv.num_viagem
		 ORDER BY empresa,
		          num_viagem,
		          sequencia
	WHENEVER ERROR STOP
	
	LET m_count = 1
    
	FOREACH cq_array2 INTO 	ma_array[m_count].dat_servico,
		                      ma_array[m_count].hr_ini_man,
		                      ma_array[m_count].hr_fin_man,
		                      ma_array[m_count].hr_ini_tar, 
		                      ma_array[m_count].hr_fin_tar,
		                      ma_array[m_count].hr_ini_ext,
		                      ma_array[m_count].hr_fin_ext
		LET m_count = m_count + 1
	END FOREACH
	
	LET m_count = m_count - 1
	CALL SET_COUNT(m_count)
	
	IF m_count <= 5 THEN
		FOR l_ind = 1 TO m_count
			DISPLAY ma_array[l_ind].* TO sr_array[l_ind].*
		END FOR
		ELSE
			DISPLAY ARRAY ma_array TO sr_array.*
		END IF

 END FUNCTION
 
#----------------------------#
 FUNCTION van1105_paginacao(lr_funcao)
#----------------------------#

	DEFINE lr_funcao CHAR(20)
	
	WHILE TRUE
		CASE
			WHEN lr_funcao = "seguinte"
				FETCH NEXT cq_consulta INTO mr_cdv.empresa,
				                            mr_cdv.num_viagem,
				                            mr_cdv.sequencia,
				                            mr_cdv.matricula_viajante,
				                            mr_cdv.cliente_destino,
				                            mr_cdv.veiculo,
				                            mr_cdv.placa,
				                            mr_cdv.km_saida,
				                            mr_cdv.km_chegada,
				                            mr_cdv.mat_auxiliar,
				                            mr_cdv.auxiliar
	  										
	  										
	  										
	  		WHEN lr_funcao = "anterior"
	  		FETCH PREVIOUS cq_consulta INTO mr_cdv.empresa,
	  		                                mr_cdv.num_viagem,
	  		                                mr_cdv.sequencia,
	  		                                mr_cdv.matricula_viajante,
	  		                                mr_cdv.cliente_destino,
	  		                                mr_cdv.veiculo,
	  		                                mr_cdv.placa,
	  		                                mr_cdv.km_saida,
	  		                                mr_cdv.km_chegada,
	  		                                mr_cdv.mat_auxiliar,
	  		                                mr_cdv.auxiliar
	  									
	  										
	  END CASE
	  IF SQLCA.SQLCODE = NOTFOUND THEN
	  	ERROR "Não existem mais viagens nesta direção."
	  	EXIT WHILE
	  END IF
		
		WHENEVER ERROR CONTINUE
		SELECT a.empresa,
		       a.num_viagem,
		       b.sequencia,
		       a.matricula_viajante,
		       a.cliente_destino, 
		       substr(a.observacao,0,50),
		       substr(a.observacao,51,100), 
		       substr(a.observacao,101,150), 
		       b.km_chegada, 
		       b.matricula_auxiliar, 
		       substr(a.observacao,151,200)
		  FROM cdv_solic_viagem a,
		       OUTER(apo_hr_tec_van b)
		 WHERE a.empresa    = p_cod_empresa
		   AND a.num_viagem	= mr_cdv.num_viagem
		   AND a.empresa    = b.empresa
		   AND a.num_viagem	= b.num_viagem
		WHENEVER ERROR STOP
		IF SQLCA.SQLCODE <> 0 THEN
			CLEAR FORM
			CALL fgl_winmessage("Consulta Viagem", "Argumentos de pesquisa não encontrados.", "info")
			EXIT WHILE
		ELSE
			CALL van1105_exibe_dados()
			CALL van1105_consulta_aponta()
			EXIT WHILE
		END IF
	END WHILE
END FUNCTION 

#--------------------------#
 FUNCTION van1105_popup_cli()
#--------------------------#

	CASE
		WHEN INFIELD(mat_aux)
			
			CALL van1105_zoom_auxiliar() RETURNING mr_cdv.mat_auxiliar
			IF mr_cdv.mat_auxiliar IS NOT NULL AND mr_cdv.mat_auxiliar <> " " THEN
				CURRENT WINDOW IS w_van1105
				DISPLAY mr_cdv.mat_auxiliar TO mat_aux
				CALL van1105_verifica_auxiliar()
			END IF
		END CASE
		
END FUNCTION

#-------------------------------#
 FUNCTION van1105_zoom_auxiliar()
#-------------------------------#
    
	DEFINE where_clause     CHAR(1000),
	       l_sql_stmt       CHAR(500),
	       l_msg            CHAR(200)
	       
	DEFINE l_ind            SMALLINT,
	       l_linha_corrente INTEGER
	       
	DEFINE la_auxiliar ARRAY [500] OF RECORD
		      mat_aux      CHAR(8),
		      nom_auxiliar CHAR(50)
		      END RECORD
		      
	OPEN WINDOW w_popup_cli AT 6,3 WITH FORM 'popup_cli'
	ATTRIBUTES (BORDER, MESSAGE LINE LAST, PROMPT LINE LAST)
	
	CURRENT WINDOW IS w_popup_cli
	
	LET INT_FLAG = 0
	
	CONSTRUCT where_clause ON cdv_fornecedor_fun.cod_funcio,
	                          fornecedor.raz_social FROM auxiliar,
	                                                     nome_auxiliar
		IF INT_FLAG <> 0 THEN
			LET INT_FLAG = 0
			CLEAR FORM
			RETURN FALSE
		END IF
		
		LET l_sql_stmt = "select cdv_fornecedor_fun.cod_funcio, fornecedor.raz_social ", 
		                 " from fornecedor, cdv_fornecedor_fun ",
		                 " where ", where_clause CLIPPED,
		                 " and  fornecedor.cod_fornecedor=cdv_fornecedor_fun.cod_fornecedor ",
		                 " order by fornecedor.raz_social"
		                 
		PREPARE var_query FROM l_sql_stmt
		DECLARE cq_popup SCROLL CURSOR WITH HOLD FOR var_query
			
			FOR l_ind = 1 TO 500  # mesmo que o de cima
				INITIALIZE la_auxiliar[l_ind].* TO NULL
			END FOR
			
			LET l_ind = 1
			
			FOREACH cq_popup INTO la_auxiliar[l_ind].mat_aux,
				                    la_auxiliar[l_ind].nom_auxiliar
				LET l_ind = l_ind + 1
			END FOREACH
			
			IF l_ind > 1 THEN
				LET l_ind = l_ind -1
			ELSE
				CLOSE WINDOW w_popup_cli
				RETURN NULL
			END IF
			
			LET int_flag = 0
			
			CALL SET_COUNT(l_ind)
			DISPLAY ARRAY la_auxiliar TO sr_cliente.*
			
			LET l_linha_corrente = ARR_CURR()
			
			IF INT_FLAG THEN
				CLOSE WINDOW w_popup_cli
				RETURN NULL
			ELSE
				CLOSE WINDOW w_popup_cli
				RETURN la_auxiliar[l_linha_corrente].mat_aux
			END IF
			
 END FUNCTION
 
#--------------------------#
 FUNCTION van1105_cabecalho()### modifica o cabeçalho
#--------------------------#

	LET INT_FLAG = 0

	INPUT mr_cdv.veiculo,
		    mr_cdv.placa,
		    mr_cdv.km_saida,
		    mr_cdv.km_chegada,
		    mr_cdv.mat_auxiliar WITHOUT DEFAULTS FROM veiculo,
		                                              placa,
		                                              km_saida,
					                                        km_chegada,
					                                        mat_aux
					                                        
	AFTER FIELD mat_aux
		IF mr_cdv.mat_auxiliar IS NOT NULL AND mr_cdv.mat_auxiliar <> " " THEN
			IF mr_cdv.mat_auxiliar <> mr_cdv.matricula_viajante THEN
				IF NOT van1105_verifica_auxiliar() THEN
					ERROR "Matricula Auxiliar não encontrada."
					NEXT FIELD mat_aux
				END IF
			ELSE
				ERROR "Matricula auxiliar não pode ser igual viajante."
				NEXT FIELD mat_aux
			END IF
		END IF

  ON KEY (CONTROL-z)
  	CALL van1105_popup_cli()
  END INPUT
  
  IF INT_FLAG <> 0 THEN
  	LET INT_FLAG = 0
  	CLEAR FORM
  	RETURN FALSE
  END IF    		
    
 END FUNCTION
#----------------#
 FUNCTION van1105_aponta()
#----------------#

	DEFINE pa_curr      SMALLINT,
	       sc_curr      SMALLINT
	       
  DEFINE l_idx_arr 	  integer,
         l_idx_scr    integer,
         l_erro       integer,
         la_aponta	  ARRAY[100] OF RECORD 
         	dat_servico LIKE apo_hr_tec_van.dat_servico,
         	hr_ini_man  DATETIME HOUR TO MINUTE,
         	hr_fin_man  DATETIME HOUR TO MINUTE,
         	hr_ini_tar  DATETIME HOUR TO MINUTE,
         	hr_fin_tar  DATETIME HOUR TO MINUTE,
         	hr_ini_ext  DATETIME HOUR TO MINUTE,
         	hr_fin_ext  DATETIME HOUR TO MINUTE
         	                      END RECORD

	INITIALIZE la_aponta TO NULL

	DECLARE cq_aponta CURSOR FOR
		SELECT dat_servico,
		       hr_ini_man,
		       hr_fin_man,
		       hr_ini_tar,
		       hr_fin_tar,
		       hr_ini_ext,
		       hr_fin_ext
		  FROM apo_hr_tec_van
		 WHERE empresa    = mr_cdv.empresa
		   AND num_viagem = mr_cdv.num_viagem
		 ORDER BY empresa, num_viagem, sequencia
	
	LET l_idx_arr = 1
	
	FOREACH cq_aponta INTO la_aponta[l_idx_arr].dat_servico,
		                     la_aponta[l_idx_arr].hr_ini_man,
		                     la_aponta[l_idx_arr].hr_fin_man,
		                     la_aponta[l_idx_arr].hr_ini_tar,
		                     la_aponta[l_idx_arr].hr_fin_tar,
		                     la_aponta[l_idx_arr].hr_ini_ext,
		                     la_aponta[l_idx_arr].hr_fin_ext

		LET l_idx_arr = l_idx_arr + 1

	END FOREACH
	
	FREE cq_aponta
	
	LET l_idx_arr = l_idx_arr - 1
	
	CALL SET_COUNT(l_idx_arr)
		
	IF NOT van1105_cabecalho() THEN
		ERROR "Apontamento cancelado pelo usuario."
		RETURN FALSE
	END IF
	
	INPUT ARRAY la_aponta WITHOUT DEFAULTS FROM sr_array.*
		BEFORE ROW
			LET pa_curr = ARR_CURR()
			LET sc_curr = SCR_LINE()
			
		AFTER FIELD dat_servico
    	IF la_aponta[pa_curr].dat_servico IS NULL AND pa_curr > 0 THEN
    		ERROR "Campo data não pode ser nulo."
    		NEXT FIELD dat_servico
    	END IF
    	
    	IF la_aponta[pa_curr].dat_servico > TODAY THEN
    		ERROR "Data não pode ser maior que data corrente."
    		NEXT FIELD dat_servico
    	END IF
     
     	IF pa_curr > 1 THEN
     		IF la_aponta[pa_curr].dat_servico = la_aponta[pa_curr - 1].dat_servico THEN
     			IF log0040_confirm(17,30,"Data de servico já lançada acima, deseja continuar?") THEN
     			ELSE
     				NEXT FIELD dat_servico
     			END IF
     		END IF
     	END IF

    AFTER FIELD hr_ini_man
    	IF la_aponta[pa_curr].hr_ini_man IS NULL AND pa_curr > 0 THEN
    		ERROR "Campo hora não pode ser nulo."
    		NEXT FIELD hr_ini_man
    	END IF  
    	
    AFTER FIELD hr_fin_man
    	IF la_aponta[pa_curr].hr_fin_man IS NULL AND pa_curr > 0 THEN
    		ERROR "Campo hora não pode ser nulo."
    		NEXT FIELD hr_fin_man
    	END IF  
     
   	 
		AFTER INPUT
			IF INT_FLAG = 0 THEN
				WHENEVER ERROR CONTINUE
				BEGIN WORK
				DELETE FROM apo_hr_tec_van
				 WHERE empresa    = mr_cdv.empresa
				   AND num_viagem	= mr_cdv.num_viagem
				DELETE FROM apo_hr_tec_aux_van
				 WHERE empresa    = mr_cdv.empresa
				   AND num_viagem	= mr_cdv.num_viagem
				WHENEVER ERROR STOP
				
				IF SQLCA.SQLCODE = 0 THEN
					LET l_erro = FALSE
					FOR l_idx_arr = 1 TO ARR_COUNT()
						IF la_aponta[l_idx_arr].dat_servico IS NOT NULL THEN
							WHENEVER ERROR CONTINUE
							INSERT INTO apo_hr_tec_van VALUES (mr_cdv.empresa,
							                                   mr_cdv.num_viagem,
							                                   l_idx_arr,
							                                   mr_cdv.matricula_viajante,
							                                   mr_cdv.cliente_destino,
							                                   mr_cdv.veiculo,
							                                   mr_cdv.placa,
							                                   mr_cdv.km_saida,
							                                   mr_cdv.km_chegada,
							                                   mr_cdv.mat_auxiliar,
							                                   mr_cdv.auxiliar,
							                                   la_aponta[l_idx_arr].dat_servico,
							                                   la_aponta[l_idx_arr].hr_ini_man,
							                                   la_aponta[l_idx_arr].hr_fin_man,
							                                   la_aponta[l_idx_arr].hr_ini_tar,
							                                   la_aponta[l_idx_arr].hr_fin_tar,
							                                   la_aponta[l_idx_arr].hr_ini_ext,
							                                   la_aponta[l_idx_arr].hr_fin_ext)
							                                   
							                                   IF mr_cdv.mat_auxiliar IS NOT NULL THEN
							                                   	WHENEVER ERROR CONTINUE
							                                   	INSERT INTO apo_hr_tec_aux_van VALUES (mr_cdv.empresa,
							                                   	                                       mr_cdv.num_viagem,
							                                   	                                       l_idx_arr,
							                                   	                                       mr_cdv.mat_auxiliar,
							                                   	                                       la_aponta[l_idx_arr].dat_servico,
							                                   	                                       la_aponta[l_idx_arr].hr_ini_man,
							                                   	                                       la_aponta[l_idx_arr].hr_fin_man,
							                                   	                                       la_aponta[l_idx_arr].hr_ini_tar,
							                                   	                                       la_aponta[l_idx_arr].hr_fin_tar,
							                                   	                                       la_aponta[l_idx_arr].hr_ini_ext,
							                                   	                                       la_aponta[l_idx_arr].hr_fin_ext)
							                                   	WHENEVER ERROR STOP
							                                   END IF
							WHENEVER ERROR STOP
          	END IF
          	
          	IF SQLCA.SQLCODE <> 0 THEN
          		ERROR "Erro na inclusão."
          		LET l_erro = TRUE
          		EXIT FOR
          	END IF
          END FOR
          
          IF l_erro = TRUE THEN
          	WHENEVER ERROR CONTINUE
          	ROLLBACK WORK
          	WHENEVER ERROR STOP
          ELSE
          	WHENEVER ERROR CONTINUE
          	COMMIT WORK
          	WHENEVER ERROR STOP
          	IF SQLCA.SQLCODE <> 0 THEN
          		ERROR "Erro na efetivação."
          	ELSE
          		ERROR "Inclusão efetuada com sucesso."
          	END IF
          END IF
        ELSE
         	ERROR "Erro na exclusão."
         	WHENEVER ERROR CONTINUE
         	ROLLBACK WORK
         	WHENEVER ERROR STOP
    		END IF
  		END IF
	END INPUT
	
	IF INT_FLAG <> 0 THEN
		LET INT_FLAG = 0
		ERROR "Apontamento cancelado."
		CLEAR FORM
		RETURN FALSE
	END IF 
END FUNCTION

#-----------------------#
 FUNCTION van1105_folga()
#-----------------------#

	DEFINE l_id            INTEGER,
	       l_erro          INTEGER,
	       l_sequencia     INTEGER,
	       pa_curr         SMALLINT,
	       sc_curr         SMALLINT,
	       la_folga ARRAY[100] OF RECORD
	       	empresa        LIKE empresa.cod_empresa,
	       	num_viagem     LIKE apo_hr_tec_van.num_viagem,
	       	mviajante      LIKE apo_hr_tec_van.matricula_viajante,
	       	dat_folga      LIKE apo_hr_tec_van.dat_servico,
	       	hrs_folga      INTERVAL HOUR TO MINUTE
	       	                  END RECORD,
	      la_apo_folga ARRAY[100] OF RECORD
	      	dat_folga      LIKE apo_hr_tec_van.dat_servico,
	      	hrs_folga      INTERVAL HOUR TO MINUTE
	      	                     END RECORD
	      	                     
	INITIALIZE la_folga, la_apo_folga TO NULL
	
	OPEN WINDOW w_van1105_fg AT 6,3 WITH FORM 'van1105_fg'
	ATTRIBUTES (BORDER, MESSAGE LINE LAST, PROMPT LINE LAST)
	CURRENT WINDOW IS w_van1105_fg
	
	WHENEVER ERROR CONTINUE
	DECLARE cq_folga CURSOR FOR
		SELECT dat_folga,
		       hrs_folga
		  FROM apo_hr_folga_van
		 WHERE empresa            = mr_cdv.empresa
		   AND num_viagem	        = mr_cdv.num_viagem
		   AND matricula_viajante = mr_cdv.matricula_viajante
		 ORDER BY empresa, num_viagem, dat_folga
	WHENEVER ERROR STOP
	
	LET l_id = 1
	
	FOREACH cq_folga INTO la_apo_folga[l_id].dat_folga,
		                    la_apo_folga[l_id].hrs_folga
		let l_id = l_id + 1
	END FOREACH
	
	FREE cq_folga
	
	IF l_id > 0 THEN
		LET l_id = l_id -1
	ELSE
		CALL log0030_mensagem("Viajante sem horas apontadas.", "excl")
		CLOSE WINDOW w_van1105_fg
	END IF
	
	CALL SET_COUNT(l_id)
	
	LET INT_FLAG = 0
	
	LET l_sequencia = 1
	
	INPUT ARRAY la_apo_folga WITHOUT DEFAULTS FROM sr_folga.*
		
		BEFORE ROW
			LET pa_curr = ARR_CURR()
			LET sc_curr = SCR_LINE()
			
		AFTER FIELD dat_folga
    	IF la_apo_folga[pa_curr].dat_folga IS NULL AND pa_curr > 0 THEN
    		ERROR "Campo data não pode ser nulo."
    		NEXT FIELD dat_folga
    	END IF
    	
    	IF la_apo_folga[pa_curr].dat_folga > TODAY THEN
    		ERROR "Data não pode ser maior que data corrente."
    		NEXT FIELD dat_folga
    	END IF
     
     	IF pa_curr > 1 THEN
     		IF la_apo_folga[pa_curr].dat_folga = la_apo_folga[pa_curr - 1].dat_folga THEN
     			IF log0040_confirm(17,30,"Data já lançada acima, deseja continuar?") THEN
     			ELSE
     				NEXT FIELD dat_folga
     			END IF
     		END IF
     	END IF

    AFTER FIELD hrs_folga
    	IF la_apo_folga[pa_curr].hrs_folga IS NULL AND pa_curr > 0 THEN
    		ERROR "Campo hora não pode ser nulo."
    		NEXT FIELD hrs_folga
    	END IF
		
		AFTER INPUT
			IF INT_FLAG = 0 THEN
				WHENEVER ERROR CONTINUE
				BEGIN WORK
				DELETE FROM apo_hr_folga_van
				 WHERE empresa = mr_cdv.empresa
				   AND num_viagem	= mr_cdv.num_viagem 
				WHENEVER ERROR STOP
				IF SQLCA.SQLCODE = 0 THEN
					LET l_erro = FALSE
					FOR l_id = 1 TO ARR_COUNT()
						IF la_apo_folga[l_id].dat_folga IS NOT NULL THEN
							WHENEVER ERROR CONTINUE
							INSERT INTO apo_hr_folga_van VALUES (mr_cdv.empresa,
						                                       mr_cdv.num_viagem,
						                                       mr_cdv.matricula_viajante,
						                                       l_sequencia,
						                                       la_apo_folga[l_id].dat_folga,
						                                       la_apo_folga[l_id].hrs_folga)
			        WHENEVER ERROR STOP
			      
				      IF SQLCA.SQLCODE <> 0 THEN
				      	ERROR "Erro na inclusão."
				      	LET l_erro = TRUE
				      	EXIT FOR
				      END IF
				      LET l_sequencia = l_sequencia +1
			    	END IF
			    END FOR
			    IF l_erro = TRUE THEN
			    	WHENEVER ERROR CONTINUE
			    	ROLLBACK WORK
			    	WHENEVER ERROR STOP
			    ELSE
			    	WHENEVER ERROR CONTINUE
			    	COMMIT WORK
			    	WHENEVER ERROR STOP
			    	IF SQLCA.SQLCODE <> 0 THEN
			    		ERROR "Erro na efetivação."
			    	ELSE
			    		CALL log0030_mensagem("Horas folga apontada com sucesso.", "exclamation")
			    	END IF
			    END IF
			   ELSE
			   	ERROR "Erro na exclusão."
			   	WHENEVER ERROR CONTINUE
			   	ROLLBACK WORK
			   	WHENEVER ERROR STOP
			   END IF
			  END IF
			 END INPUT
			 CLOSE WINDOW w_van1105_fg
 
 END FUNCTION
 
#########################################################
######  RELATORIO PARA CONTROLAR HORAS PARA FOLGAS  #####
#########################################################

#-----------------------------------------#
 FUNCTION van1105_seta_variaveis_relatorio()
#-----------------------------------------#

	DEFINE l_empresa       CHAR(02),
	       sql_stmt        CHAR(5000),
	       l_cliente       CHAR(100),
	       l_cidade        LIKE cidades.den_cidade,
	       l_situacao      CHAR(10)
	    
	OPEN WINDOW w_van1105_rel AT 3,2
	WITH FORM "van1105_rel" ATTRIBUTE (BORDER)
	
	CURRENT WINDOW IS w_van1105_rel
        	
 	SELECT cod_empresa
 	  INTO l_empresa
   	FROM par_vdp
   WHERE par_vdp.cod_empresa = p_cod_empresa
   
  DISPLAY l_empresa TO empresa
  
  INITIALIZE mr_cdv.* TO NULL 
  
  INPUT mr_dat.mviajante,
  		  mr_dat.dat_ini, 
  		  mr_dat.dat_fim FROM mviajante,
  		                      dat_ini,
  		                      dat_fim
  		                      
		AFTER FIELD dat_ini
			IF mr_dat.dat_ini IS NULL THEN
				ERROR "Data obrigatoria."
				NEXT FIELD dat_ini
			END IF
			
		AFTER FIELD dat_fim
			IF mr_dat.dat_fim IS NULL THEN
				ERROR "Data obrigatoria."
				NEXT FIELD dat_fim
			END IF
		
	END INPUT
	
	IF mr_dat.mviajante IS NULL THEN
		LET sql_stmt = " select empresa, num_viagem, sequencia, matricula_viajante  ",
		               " from apo_hr_tec_van ",
		               " where dat_servico BETWEEN '",mr_dat.dat_ini,"' AND '",mr_dat.dat_fim,"' " ,
		               " union ",
		               " select empresa, num_viagem, sequencia, matricula_viajante  ",
		               " from apo_hr_tec_aux_van ",
		               " where dat_servico BETWEEN '",mr_dat.dat_ini,"' AND '",mr_dat.dat_fim,"' " 
	ELSE
		LET sql_stmt = " select empresa, num_viagem, sequencia, matricula_viajante  ",
		               " from apo_hr_tec_van ",
		               " where matricula_viajante = '",mr_dat.mviajante,"' ", 
		               " and dat_servico BETWEEN '",mr_dat.dat_ini,"' AND '",mr_dat.dat_fim,"' ",
		               " union ",
		               " select empresa, num_viagem, sequencia, matricula_viajante  ",
		               " from apo_hr_tec_aux_van ",
		               " where matricula_viajante = '",mr_dat.mviajante,"' ", 
		               " and dat_servico BETWEEN '",mr_dat.dat_ini,"' AND '",mr_dat.dat_fim,"' "  
	END IF
	
	CALL log0810_prepare_sql(sql_stmt) RETURNING sql_stmt
	PREPARE relat_query FROM sql_stmt
	DECLARE cq_relatorio SCROLL CURSOR WITH HOLD FOR relat_query
		OPEN cq_relatorio
		FETCH cq_relatorio INTO mr_cdv.*
		IF SQLCA.SQLCODE = NOTFOUND THEN
			CALL log0030_mensagem("argumentos de pesquisa nao encontrados. ","exclamation")
			LET ies_relatorio = FALSE
		ELSE
			LET ies_relatorio = TRUE
		END IF
		IF ies_relatorio = TRUE THEN
			IF log028_saida_relat(19,20) IS NOT NULL THEN
				CALL van1105_lista_horas()
			END IF
		END IF
		
 CLOSE WINDOW w_van1105_rel

 END FUNCTION

#-------------------------------#
 FUNCTION van1105_lista_horas()
#-------------------------------#
	DEFINE 	l_mensagem      CHAR(100),
	        i               SMALLINT,
        	m_count         SMALLINT,
        	hora            RECORD
        		dat_servico		DATE,
        		hr_man_ini		DATETIME HOUR TO MINUTE,
        		hr_man_fim		DATETIME HOUR TO MINUTE,
        		hr_tar_ini		DATETIME HOUR TO MINUTE,
        		hr_tar_fim		DATETIME HOUR TO MINUTE,
        		hr_ext_ini		DATETIME HOUR TO MINUTE,
        		hr_ext_fim		DATETIME HOUR TO MINUTE
        		          END RECORD
        		
	DEFINE hr_tot      INTERVAL HOUR TO MINUTE,
	       hr_ext_tot  INTERVAL HOUR TO MINUTE,
	       dia         INTERVAL HOUR TO MINUTE,
	       hr_man      INTERVAL HOUR TO MINUTE,
	       hr_tar      INTERVAL HOUR TO MINUTE,
	       hr_ext      INTERVAL HOUR TO MINUTE,
	       l_hora_char CHAR(16),
	       viajante    CHAR(36),
	       hora_extra  INTERVAL HOUR TO MINUTE,
	       hora_folga  INTERVAL HOUR TO MINUTE
	       
	DEFINE sql_stmt       	CHAR(5000) 
	
	INITIALIZE hora TO NULL
 	
	WHENEVER ERROR CONTINUE
	DROP TABLE w_van_hora
	
	CREATE TEMP TABLE w_van_hora (matricula 			 INTEGER,
	                              hora_extra_total INTERVAL HOUR TO MINUTE)
  WITH NO LOG;
  WHENEVER ERROR STOP
 	
 	WHENEVER ERROR CONTINUE 
 	DELETE FROM w_van_hora
 	WHENEVER ERROR STOP
 	
 	IF g_ies_ambiente = "w" THEN
 		IF p_ies_impressao = "s" THEN
 			CALL log150_procura_caminho("lst") RETURNING m_caminho
 			LET m_caminho = m_caminho CLIPPED, "van1105.tmp"
 			START REPORT van1105_relatorio TO m_caminho
 		ELSE
 			START REPORT van1105_relatorio TO p_nom_arquivo
 		END IF
 	ELSE
 		IF p_ies_impressao = "s" THEN 
 			START REPORT van1105_relatorio TO PIPE p_nom_arquivo
 		ELSE
 			START REPORT van1105_relatorio TO p_nom_arquivo
 		END IF
 	END IF

	IF mr_dat.mviajante IS NULL THEN
		LET sql_stmt = " select empresa, num_viagem, sequencia, matricula_viajante  ",
		               " from apo_hr_tec_van ",
		               " where dat_servico BETWEEN '",mr_dat.dat_ini,"' AND '",mr_dat.dat_fim,"' " ,
		               " union ",
		               " select empresa, num_viagem, sequencia, matricula_viajante  ",
		               " from apo_hr_tec_aux_van ",
		               " where dat_servico BETWEEN '",mr_dat.dat_ini,"' AND '",mr_dat.dat_fim,"' ",
		               " order by empresa, matricula_viajante , num_viagem, sequencia" 
	ELSE
		LET sql_stmt = " select empresa, num_viagem, sequencia, matricula_viajante  ",
		               " from apo_hr_tec_van ",
		               " where matricula_viajante = '",mr_dat.mviajante,"' ", 
		               " and dat_servico BETWEEN '",mr_dat.dat_ini,"' AND '",mr_dat.dat_fim,"' ", 
		               " union ",
		               " select empresa, num_viagem, sequencia, matricula_viajante  ",
		               " from apo_hr_tec_aux_van ",
		               " where matricula_viajante = '",mr_dat.mviajante,"' ", 
		               " and dat_servico BETWEEN '",mr_dat.dat_ini,"' AND '",mr_dat.dat_fim,"' ",
		               " order by empresa, matricula_viajante, num_viagem, sequencia " 
	END IF
	
	CALL log0810_prepare_sql(sql_stmt) RETURNING sql_stmt
	PREPARE relat_query2 FROM sql_stmt

 	DECLARE cq_relatorio CURSOR FOR relat_query2

 	FOREACH cq_relatorio INTO mr_cdv.* 
 		
 		WHENEVER ERROR CONTINUE
 		SELECT DISTINCT b.raz_social 
 		  INTO viajante
 		  FROM cdv_fornecedor_fun a,
 		       fornecedor b
 		 WHERE a.cod_fornecedor = b.cod_fornecedor
 		   AND a.cod_funcio     = mr_cdv.matricula_viajante
 		WHENEVER ERROR STOP
	 	
	 	WHENEVER ERROR CONTINUE
	 	SELECT empresa.den_empresa 
	 	  INTO p_den_empresa
	 	  FROM empresa 
	 	 WHERE empresa.cod_empresa = p_cod_empresa
	  WHENEVER ERROR STOP
	    
	    LET hora.dat_servico = NULL
	    LET hr_ext_tot       = NULL
	    LET hr_tot           = NULL 
	    LET dia              = NULL
	    LET hr_man           = NULL
	    LET hr_tar           = NULL
	    LET hr_ext           = NULL
	    LET hora_extra       = NULL
	    LET hora_folga       = NULL               
	        
		OUTPUT TO REPORT van1105_relatorio(mr_cdv.*,
		                                   p_den_empresa,
		                                   hora.dat_servico,
		                                   dia,
		                                   hr_man,
		                                   hr_tar,
		                                   hr_ext,
		                                   viajante,
		                                   hr_tot,
		                                   hr_ext_tot,
		                                   hora_extra,
		                                   hora_folga )
		
		WHENEVER ERROR CONTINUE
		DECLARE cm_hora CURSOR FOR
			SELECT dat_servico, 
			       hr_ini_man, 
			       hr_fin_man, 
			       hr_ini_tar, 
			       hr_fin_tar, 
			       hr_ini_ext, 
			       hr_fin_ext
			  FROM apo_hr_tec_van
			 WHERE empresa	  = mr_cdv.empresa
			   AND num_viagem	= mr_cdv.num_viagem
			   AND sequencia  = mr_cdv.sequencia
	  WHENEVER ERROR STOP
	  	    
	    FOREACH cm_hora INTO hora.*
	     
	    	IF hora.hr_man_ini IS NULL OR hora.hr_man_ini = " " THEN 
	    		LET hora.hr_man_ini = '0:10'
	  		END IF
	  		
	  		IF hora.hr_man_fim IS NULL OR hora.hr_man_fim = " " THEN
	    		LET hora.hr_man_fim = '0:10'
	  		END IF
	  		
	  		IF hora.hr_tar_ini IS NULL OR hora.hr_tar_ini = " " THEN
	  			LET hora.hr_tar_ini = '0:10'
	  		END IF
	  		
	  		IF hora.hr_tar_fim IS NULL OR hora.hr_tar_fim = " " THEN
	  			LET hora.hr_tar_fim = '0:10'
	  		END IF
	  		
	  		IF hora.hr_ext_ini IS NULL OR hora.hr_ext_ini = " " THEN
	  			LET hora.hr_ext_ini = '0:10'
	  		END IF            
	  		
	  		IF hora.hr_ext_fim IS NULL OR hora.hr_ext_fim = " " THEN
	  			LET hora.hr_ext_fim = '0:10'
	  		END IF
	  		
	  		LET hr_man = hora.hr_man_fim - hora.hr_man_ini
	  		LET hr_tar = hora.hr_tar_fim - hora.hr_tar_ini
	  		LET hr_ext = hora.hr_ext_fim - hora.hr_ext_ini
	  		
	  		LET hr_tot = (hr_man + hr_tar + hr_ext)
	  		
	  		CALL CONOUT ('CAMPO DE hr_tot: ',hr_tot)
	  		
	  		LET dia = '8:50'
	  		
	  		LET hr_ext_tot = (hr_tot - dia)
	  		
	  		CALL CONOUT ('CAMPO DE hr_ext_tot: ',hr_ext_tot)
	  		
	  		{IF hr_ext_tot = "-08:50" then 
	  			LET hr_ext_tot = "00:00"
	  		END IF}
	  		
	  		WHENEVER ERROR STOP
	  		INSERT INTO w_van_hora VALUES (mr_cdv.matricula_viajante,
	  		                               hr_ext_tot)
	  		WHENEVER ERROR STOP
	  		
	  		WHENEVER ERROR CONTINUE
	  		SELECT SUM(hora_extra_total)
	  		  INTO hora_extra
	  		  FROM w_van_hora
	  		 WHERE matricula = mr_cdv.matricula_viajante
	  		WHENEVER ERROR STOP
	  		
	  		WHENEVER ERROR CONTINUE
	  		SELECT SUM(hrs_folga)
	  		  INTO hora_folga
	  		  FROM apo_hr_folga_van
	  		 WHERE matricula_viajante = mr_cdv.matricula_viajante
	  		   AND dat_folga BETWEEN mr_dat.dat_ini AND mr_dat.dat_fim
	  		WHENEVER ERROR STOP
	  		
	  		OUTPUT TO REPORT van1105_relatorio(mr_cdv.*,
	  		                                   p_den_empresa,
	  		                                   hora.dat_servico,
	  		                                   dia,
	  		                                   hr_man,
	  		                                   hr_tar,
	  		                                   hr_ext,
	  		                                   viajante,
	  		                                   hr_tot,
	  		                                   hr_ext_tot,
	  		                                   hora_extra,
	  		                                   hora_folga )
	  		 		
		END FOREACH

 END FOREACH

 IF p_ies_impressao = "s" THEN
 	LET l_mensagem = " relatorio impresso com sucesso. "
    CALL log0030_mensagem(l_mensagem,"info")
 ELSE
 	LET l_mensagem = " relatorio gravado no arquivo ", p_nom_arquivo CLIPPED, "."
	CALL log0030_mensagem(l_mensagem,"info")
 END IF

	FINISH REPORT van1105_relatorio

END FUNCTION

#-------------------------------------#
 REPORT van1105_relatorio(l_cdv,
                          l_empresa,
                          dat_servico,
                          dia,
                          hr_man,
                          hr_tar,
                          hr_ext,
                          nom_viajante,
                          hr_tot,
                          hr_ext_tot,
                          hora_extra,
                          hora_folga )
#------------------------------------#

	DEFINE l_cdv RECORD
	       	empresa             LIKE cdv_solic_viagem.empresa,
	       	num_viagem          LIKE cdv_solic_viagem.num_viagem,
	       	sequencia           DECIMAL(5,0),
	       	matricula_viajante  LIKE cdv_solic_viagem.matricula_viajante,
	       	cliente_destino     LIKE cdv_solic_viagem.cliente_destino,
	       	veiculo             LIKE apo_hr_tec_van.veiculo,
	       	placa               LIKE apo_hr_tec_van.placa,
	       	km_saida            LIKE apo_hr_tec_van.km_saida,
	       	km_chegada          LIKE apo_hr_tec_van.km_chegada,
	       	mat_auxiliar        LIKE cdv_solic_viagem.matricula_viajante,
	       	auxiliar            LIKE apo_hr_tec_van.auxiliar
	       	END RECORD
	       	
	DEFINE  hr_tot        INTERVAL HOUR TO MINUTE,
	        hr_ext_tot    INTERVAL HOUR TO MINUTE,
	        dia           INTERVAL HOUR TO MINUTE,
	        hr_man        INTERVAL HOUR TO MINUTE,
	        hr_tar        INTERVAL HOUR TO MINUTE,
	        hr_ext        INTERVAL HOUR TO MINUTE,
	        dat_servico   DATE,
	        hora_extra    INTERVAL HOUR TO MINUTE,
	        hora_folga    INTERVAL HOUR TO MINUTE
	       
	DEFINE  nom_viajante     CHAR(36)
        	

 DEFINE 	l_last_row		SMALLINT,
        	l_empresa     CHAR(50)



  OUTPUT LEFT MARGIN 0
         TOP MARGIN 0
         RIGHT MARGIN 132
         BOTTOM MARGIN 1
         PAGE LENGTH 66


	ORDER EXTERNAL BY l_cdv.empresa, l_cdv.matricula_viajante, l_cdv.num_viagem
		FORMAT
		PAGE HEADER
			PRINT log500_determina_cpp(132) CLIPPED;
			BEFORE GROUP OF l_cdv.empresa
			PRINT COLUMN 001, l_empresa
			PRINT COLUMN 001, "VAN1105"
			PRINT COLUMN 025, "RELATORIO HORAS TECNICAS",
			      COLUMN 076, "FL. ", PAGENO USING "##&"
			PRINT COLUMN 044, "EXTRAIDO EM ", TODAY,
			                  " AS ", TIME, " HRS."
			      SKIP 2 LINE
			PRINT COLUMN 001, "Num.Mat.",
			      COLUMN 011, "Nome Funcionario / Viajante"
			PRINT COLUMN 001, "Data Servico",
			      COLUMN 017, "Hrs.Normais",
			      COLUMN 031, "Hrs.Trab.",
			      COLUMN 046, "Hrs.Extras"
			PRINT COLUMN 001, "---------",
			      COLUMN 011, "-----------------------------------",
			      COLUMN 047, "-----------------------------"
			PRINT COLUMN 001, "------------",
			      COLUMN 017, "-----------",
			      COLUMN 031, "-----------",
			      COLUMN 046, "-----------"
			      SKIP 1 LINE
			BEFORE GROUP OF l_cdv.matricula_viajante
				PRINT COLUMN 001, l_cdv.matricula_viajante USING "<<<<<" CLIPPED,
				      COLUMN 010, nom_viajante CLIPPED
				      BEFORE GROUP OF l_cdv.num_viagem
				      	PRINT COLUMN 046, "Num. Viagem...: ", l_cdv.num_viagem USING "<<<<<" CLIPPED
				      	ON EVERY ROW
				      	NEED 3 LINE
				      	PRINT COLUMN 001, dat_servico CLIPPED,
				      	      COLUMN 016, dia CLIPPED,
				      	      COLUMN 030, hr_tot CLIPPED,
				      	      COLUMN 045, ((hr_man + hr_tar + hr_ext) - dia) CLIPPED
				      	      SKIP 1 LINE
				      AFTER GROUP OF l_cdv.matricula_viajante
					      PRINT COLUMN 046, ".............................................. "
					      PRINT COLUMN 046, "Total Extra Viajante...: ", hora_extra CLIPPED
					      PRINT COLUMN 046, "Total Folga Viajante...: ", hora_folga CLIPPED
				            SKIP 1 LINE
			AFTER GROUP OF l_cdv.empresa
				SKIP 1 LINE
				      	       
     	ON LAST ROW
      	LET l_last_row = TRUE

     	PAGE TRAILER
     		IF  l_last_row THEN
     			PRINT "* * * ULTIMA FOLHA * * *"
     		ELSE
     			PRINT " "
     		END IF

 END REPORT 
