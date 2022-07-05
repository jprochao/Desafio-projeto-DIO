DATABASE logix

#-----------------------------------------------------------------#
# SISTEMA.: ASSISTENCIA INTERNA                                   #
# PROGRAMA: VAN9999                                               #
# OBJETIVO: ABERTURA CHAMADO INTERNO                              #
# AUTOR...: JOÃO PAULO                                            #
# DATA....: 27/06/2012                                            #
#-----------------------------------------------------------------#  
                 
GLOBALS
	DEFINE  p_cod_empresa          LIKE empresa.cod_empresa,
        	p_den_empresa          LIKE empresa.den_empresa,
         	p_user                 LIKE usuario.nom_usuario,
         	p_status               SMALLINT,
         	p_houve_erro           SMALLINT,
         	p_ies_cons             SMALLINT,
         	p_pula_campo           SMALLINT,
         	p_ies_sit_cli          CHAR(01),
         	mesg                   CHAR(90),
         	g_tipo_sgbd            CHAR(03),
         	ies_email              SMALLINT,
         	m_cidade               CHAR(30),
         	ies_relatorio          SMALLINT

 	DEFINE  p_versao               CHAR(18),
 	        m_hora                 CHAR(08)

 	DEFINE  p_comando              CHAR(80),
         	p_caminho              CHAR(80),
         	p_nom_tela             CHAR(80),
         	p_help                 CHAR(80),
         	p_where                CHAR(100),
         	p_cancel               INTEGER,
         	g_ies_grafico          SMALLINT
         	
 END GLOBALS

	DEFINE  m_consulta_ativa 		SMALLINT

	DEFINE  ma_array ARRAY [100] OF RECORD
		       descr_def            CHAR(76)
		                          END RECORD

 	DEFINE mr_chamado, mr_chamador RECORD
					cod_empresa   LIKE empresa.cod_empresa,
					num_chamado   SERIAL,
					usuario       LIKE usuarios.cod_usuario,
					dat_abert     DATETIME YEAR TO MINUTE,
					dat_encerr    DATETIME YEAR TO MINUTE,
					area          CHAR(20),
					problema      CHAR(20),
					defeito       CHAR(20),
					atendente     CHAR(20),
					STATUS        CHAR(01),
					setor         CHAR(30)
												END RECORD

	DEFINE 	p_ies_impressao       CHAR(001),
         	g_ies_ambiente        CHAR(001),
         	p_nom_arquivo         CHAR(100),
         	comando               CHAR(80),
         	m_caminho             CHAR(100)
         	
  DEFINE  m_dat_inc           DATETIME YEAR TO MINUTE,
          m_lista_arquivos    CHAR(1000),
          m_lista_tmp_arq     CHAR(1000),
          m_anexo             SMALLINT
         


MAIN

	CALL log0180_conecta_usuario()
	#LET p_versao = "VAN9999-10.02.16e"
	#LET p_versao = "VAN9999-12.1.7.01e"
	#LET p_versao = "VAN9999-12.1.11.04e" #19/08/2016 
	LET p_versao = "VAN9999-12.1.12.05e" #05/09/2016
	
	WHENEVER ANY ERROR CONTINUE
	CALL log1400_isolation()
	WHENEVER ERROR STOP
	DEFER INTERRUPT
	CALL log140_procura_caminho("VAN9999.iem") RETURNING p_caminho
	LET p_help = p_caminho CLIPPED
	OPTIONS
	HELP FILE p_help
	CALL log001_acessa_usuario("PADRAO","LICLIB")
	RETURNING p_status, p_cod_empresa, p_user
	IF p_status = 0  THEN
		CALL van99_controle()
	END IF
	
END MAIN

#------------------#
 FUNCTION van99_controle()
#------------------#
	CALL log140_procura_caminho("VAN9999") RETURNING p_nom_tela
	OPEN WINDOW w_van9999 AT 2,02 WITH FORM p_nom_tela
	ATTRIBUTE(BORDER, MESSAGE LINE LAST, PROMPT LINE LAST)
	CALL log006_exibe_teclas("02 07", p_versao)
	CLEAR FORM
	CURRENT WINDOW IS w_van9999
	LET m_consulta_ativa = FALSE
	LET m_anexo = FALSE

	MENU "opcao"
		COMMAND KEY ("C") "Consultar" "Consultar chamados."
			MESSAGE ""
			IF log005_seguranca(p_user,"PADRAO","VAN9999","CO")  THEN
				CALL van99_consultar()
			END IF
			
		COMMAND KEY ("S") "Seguinte" "Exibe o registro seguinte."
			IF m_consulta_ativa = TRUE THEN
				CALL van99_paginacao("seguinte")
			ELSE
				ERROR "Não existe nenhuma consulta ativa."
			END IF
			
		COMMAND KEY ("A") "Anterior" "Exibe o registro anterior."
			IF m_consulta_ativa = TRUE THEN
				CALL van99_paginacao("anterior")
			ELSE
				ERROR "Não existe nenhuma consulta ativa."
			END IF
			
		COMMAND KEY("F") "Fim" "Sai do programa."
			EXIT MENU
			
		COMMAND KEY("B") "aBertura" "Abertura Chamado."
			IF log005_seguranca(p_user, "PADRAO","VAN9999","IN")  THEN
				CALL van9999_abertura()
			END IF
			
		COMMAND KEY("I") "Interação" "Interagir no chamado."
			IF m_consulta_ativa = TRUE THEN
				IF log005_seguranca(p_user, "PADRAO","VAN9999","MO")  THEN
						IF mr_chamado.status NOT IN ('E','C') THEN
							IF NOT van9999_interacao() THEN
								ERROR "Interação Cancelada pelo usuario."
							END IF
						ELSE
							CALL log0030_mensagem('Chamado já encerrado/cancelado.','info')
						END IF
				END IF
			ELSE
				ERROR "Não existe nenhuma consulta ativa."
				NEXT OPTION "Consultar"
			END IF
			
		COMMAND KEY("N") "eNcerramento" "Encerrar Chamado."
			IF m_consulta_ativa = TRUE THEN
				IF log005_seguranca(p_user, "PADRAO","VAN9999","IN")  THEN
					IF mr_chamado.atendente = UPSHIFT(p_user) OR mr_chamado.atendente = p_user OR p_user = 'jpaulo' THEN
						IF mr_chamado.status = 'P' THEN
							CALL van9999_encerramento()
						ELSE
							CALL log0030_mensagem('Chamado não pode ser encerrado, pois não está pendente.','info')
						END IF
					ELSE
						CALL log0030_mensagem('Usuario encerramento deve ser o mesmo do atendimento.','info')
					END IF
				END IF
			ELSE
				ERROR "Não existe nenhuma consulta ativa."
				NEXT OPTION "Consultar"
			END IF
			
		COMMAND KEY("R") "cancelaR" "Cancelar Chamado."
			IF m_consulta_ativa = TRUE THEN
				IF log005_seguranca(p_user, "PADRAO","VAN9999","IN")  THEN
					IF mr_chamado.atendente = UPSHIFT(p_user) 
					OR mr_chamado.atendente = p_user 
					OR p_user = 'jpaulo'
					OR mr_chamado.usuario = p_user THEN
						IF mr_chamado.status NOT IN ('E','C') THEN
							CALL van9999_cancelar()
						ELSE
							CALL log0030_mensagem('Chamado não pode ser cancelado, pois está encerrado/cancelado.','info')
						END IF
					ELSE
						CALL log0030_mensagem('Para cancelar o usuário deverá ser ou atendente ou solicitante.','info')
					END IF
				END IF
			ELSE
				ERROR "Não existe nenhuma consulta ativa."
				NEXT OPTION "Consultar"
			END IF
			
		COMMAND KEY("T") "Transferir" "Transferir chamado aberto para outro setor."
			IF m_consulta_ativa = TRUE THEN
				IF log005_seguranca(p_user, "PADRAO","VAN9999","MO")  THEN
					IF mr_chamado.usuario = p_user THEN
						IF mr_chamado.status = 'A' THEN
							CALL van9999_transferir()
						ELSE
							CALL log0030_mensagem('Chamado não pode ser transferido, pois não está aberto.','info')
						END IF
					ELSE
						CALL log0030_mensagem('Para transferir o usuário deverá ser solicitante.','info')
					END IF
				END IF
			ELSE
				ERROR "Não existe nenhuma consulta ativa."
				NEXT OPTION "Consultar"
			END IF
			
		COMMAND KEY("V") "enViar_anexo" "Enviar anexo no chamado."
			IF m_consulta_ativa = TRUE THEN
				IF log005_seguranca(p_user, "PADRAO","VAN9999","IN")  THEN
					IF mr_chamado.status NOT IN ('C','E') THEN
						IF van9999_addanexo() THEN
							LET m_anexo = TRUE
							CALL van9999_interacao()
						END IF
					ELSE
						CALL log0030_mensagem('Chamado encerrado.','info')
					END IF
				END IF
			ELSE
				ERROR "Não existe nenhuma consulta ativa."
				NEXT OPTION "Consultar"
			END IF
			
		COMMAND KEY("E") "reEnviar" "Re-enviar E-mail."
			IF m_consulta_ativa = TRUE THEN
				IF log005_seguranca(p_user, "PADRAO","VAN9999","CO")  THEN
					IF mr_chamado.status NOT IN ('C','E') THEN
						CALL van99_envia_email_usuarios()
					ELSE
						CALL log0030_mensagem('Chamado encerrado.','info')
					END IF
				END IF
			ELSE
				ERROR "Não existe nenhuma consulta ativa."
				NEXT OPTION "Consultar"
			END IF
	    	
	END MENU
	
 END FUNCTION 
 
{#-----------------------------#
 FUNCTION van9999_job(l_rotina)
#-----------------------------#   

	DEFINE l_msg         CHAR(100)
	
	DEFINE l_param_emp   CHAR(02),
	       l_param_user  LIKE usuario.nom_usuario,
	       l_param_dat   INTEGER,
	       l_rotina      CHAR(50)
	       
	INITIALIZE l_dat_ini, l_dat_fim TO NULL
	
	CALL JOB_get_parametro_gatilho_tarefa(1,0)
		RETURNING l_status, l_param_dat
		
	IF l_param_dat IS NULL OR l_param_dat = " " THEN
		LET l_msg = "Parâmetro 1 de sequencia 0 (Qtd. Dias) ",
		            "não repassado para a tarefa agendada."
		            CALL LOG_consoleError(l_msg)
		            RETURN 1 # Falha na execução do JOB.
	END IF
	
	LET l_dat_ini = (TODAY - l_param_dat)
	
	LET l_dat_fim = TODAY
	
	IF NOT van2202_carrega_dados() THEN
		RETURN 1
	END IF
	
	RETURN 0 # JOB executado com sucesso.
	
 END FUNCTION}
 
#--------------------------#
 FUNCTION van9999_addanexo()
#--------------------------#

	DEFINE anexo       CHAR(1000),
	       l_comando   CHAR(1000),
	       l_arquivo   SMALLINT,
	       l_name      CHAR(100),
	       l_ext       CHAR(10),
	       l_tam       SMALLINT,
	       l_i         SMALLINT,
	       l_ii        SMALLINT,
	       l_iii       SMALLINT,
	       l_final     CHAR(100),
	       l_tamanho   CHAR(100)
	
	OPEN WINDOW w_van99994 AT 6,3 WITH FORM 'van99994'
	ATTRIBUTES (BORDER, MESSAGE LINE LAST, PROMPT LINE LAST)
	CURRENT WINDOW IS w_van99994
	
	LET INT_FLAG = 0
	
	INITIALIZE m_lista_arquivos, 
	           m_lista_tmp_arq, 
	           anexo,
	           l_comando,
	           l_arquivo,
	           l_name TO NULL
	
	INPUT BY NAME anexo WITHOUT DEFAULTS
		
		AFTER FIELD anexo
			IF anexo IS NULL AND anexo = " " THEN
				CALL log0030_mensagem('Caminho não pode ser nulo','info')
				NEXT FIELD anexo
			END IF
			
		AFTER INPUT
			IF INT_FLAG = 0 THEN
				IF anexo IS NULL AND anexo = " " THEN
					CALL log0030_mensagem('Caminho não pode ser nulo','info')
					NEXT FIELD anexo
				END IF
			END IF
				
	END INPUT
	
	LET m_lista_arquivos = anexo
	
	LET l_tam = LENGTH(m_lista_arquivos)
	
	CALL conout ('l_tam: ', l_tam)
	CALL conout ('m_lista_arquivos: ', m_lista_arquivos)
	
  LET l_ii = l_tam
  
 	FOR l_i = l_ii  TO 1 STEP -1
 		#CALL conout ('l_tam1: ', l_tam)
 		#CALL conout ('l_i1: ', l_i)
 		IF m_lista_arquivos[l_i,l_i] = '\\' THEN
 			#CALL conout ('l_tam2: ', l_tam)
 			#CALL conout ('l_i2: ', l_i)
 			LET l_name = m_lista_arquivos[l_i+1,l_tam]
 			
 			EXIT FOR
 		END IF
 	END FOR
 	
 	CALL conout ('l_name: ', l_name)
	
	LET m_lista_tmp_arq  = '/totvs/temp/', l_name CLIPPED
	CALL conout ('m_lista_tmp_arq: ', m_lista_tmp_arq)
	
	IF m_lista_arquivos IS NOT NULL THEN
		IF NOT LOG_file_CopyClientToServer(m_lista_arquivos,m_lista_tmp_arq,1) THEN
			CALL log0030_mensagem('Falha na copia para servidor.','info')
			RETURN FALSE
		END IF
		
		CALL conout ('m_lista_tmp_arq :', m_lista_tmp_arq)
		
		LET l_tamanho  = '/totvs/temp/VAN9999.unl'
	
		LET l_comando = 'ls -lhas ', m_lista_tmp_arq CLIPPED, ' > ', l_tamanho CLIPPED
	
		CALL conout ('l_comando: ', l_comando)
	
		RUN l_comando RETURNING l_arquivo
	
		CALL conout ('l_arquivo: ', l_arquivo)
	
	
		IF l_arquivo = 0 THEN
			WHENEVER ERROR CONTINUE
			DROP TABLE t_arq_tam
			DELETE FROM t_arq_tam
			 WHERE 1 = 1
			 
			CREATE TEMP TABLE t_arq_tam (arquivo  CHAR(100)) WITH NO LOG
			WHENEVER ERROR STOP
			
			WHENEVER ERROR CONTINUE
			LOAD FROM l_tamanho DELIMITER 'ƒ' INSERT INTO t_arq_tam
			WHENEVER ERROR STOP
			IF SQLCA.SQLCODE = 0 THEN
				LET l_comando = 'rm ',l_tamanho
	      RUN l_comando
	      LET l_tamanho = NULL
			END IF
			
			WHENEVER ERROR CONTINUE
			SELECT arquivo[1,10]
			  INTO l_tamanho
			  FROM t_arq_tam
			WHENEVER ERROR STOP
			IF SQLCA.SQLCODE = 0 THEN
				LET l_tam = LENGTH(l_tamanho)
				FOR l_iii = 1 TO l_tam
					IF l_tamanho[l_iii,l_iii] = 'G' THEN
						CALL log0030_mensagem('Sistema não suporta arquivo GIGA','info')
						LET l_comando = 'rm -rf ',m_lista_tmp_arq CLIPPED
						RUN l_comando
						RETURN FALSE
						EXIT FOR
					ELSE
						IF l_tamanho[l_iii,l_iii] = 'M' THEN
							IF l_tamanho[1,l_iii-1] > 5 THEN
								CALL conout('l_tamanho: ',l_tamanho[1,l_iii-1])
								CALL log0030_mensagem('Anexo maior que 5MB.','info')
								LET l_comando = 'rm -rf ',m_lista_tmp_arq CLIPPED
								RUN l_comando
								RETURN FALSE
								EXIT FOR
							END IF
						END IF
					END IF
				END FOR
			END IF
		END IF
		
	END IF
					
	CLOSE WINDOW w_van99994
	CURRENT WINDOW IS w_van9999
	
	IF INT_FLAG THEN
		CALL log0030_mensagem("Inclusão anexo cancelado.","info")
		LET INT_FLAG = FALSE
		RETURN FALSE
	END IF
	
	RETURN TRUE

 END FUNCTION
#--------------------------#
 FUNCTION van9999_abertura()
#--------------------------#

	DEFINE l_dat_abert		DATETIME YEAR TO MINUTE,
	       l_data         CHAR(10),
	       l_hor_abert  	DATETIME YEAR TO MINUTE,
	       l_hora       	CHAR(05),
	       p_ind          INTEGER,
	       l_sequencia    INTEGER,
	       l_seq_txt      INTEGER

	INITIALIZE mr_chamado.*, l_sequencia, l_seq_txt TO NULL

	IF van99_entrada_dados("IN") = TRUE THEN
		IF van99_entrada_array("IN") = TRUE THEN
 			
			BEGIN WORK
			
			WHENEVER ERROR CONTINUE
			SELECT MAX(num_chamado)
			  INTO mr_chamado.num_chamado
			  FROM chamado_van
			WHENEVER ERROR STOP
			
			IF SQLCA.SQLCODE = 0 THEN
				IF mr_chamado.num_chamado < 1 OR mr_chamado.num_chamado IS NULL THEN
					LET mr_chamado.num_chamado = 1
				ELSE
					LET mr_chamado.num_chamado = mr_chamado.num_chamado + 1
				END IF
			ELSE
				CALL log0030_mensagem("Erro ao tentar selecionar dados", "info")
				RETURN FALSE
			END IF
			
			LET l_dat_abert = CURRENT YEAR TO SECOND
			LET l_data      = EXTEND(l_dat_abert, YEAR TO DAY)
			LET l_hor_abert = CURRENT HOUR TO MINUTE
			LET l_hora      = EXTEND(l_hor_abert, HOUR TO MINUTE)
			
			WHENEVER ERROR CONTINUE
			INSERT INTO chamado_van (cod_empresa,
			                         num_chamado,
			                         usuario,
			                         dat_abert,
			                         area,
			                         problema,
			                         defeito,
			                         ies_status,
			                         setor_solic)
			                         VALUES (p_cod_empresa,
			                                 mr_chamado.num_chamado,
			                                 mr_chamado.usuario,
			                                 l_dat_abert,
			                                 mr_chamado.area,
			                                 mr_chamado.problema,
			                                 mr_chamado.defeito,
			                                 'A',
			                                 mr_chamado.setor)
			WHENEVER ERROR STOP
		  
		  IF SQLCA.SQLCODE = 0 THEN 
				WHENEVER ERROR CONTINUE
			  	SELECT MAX(sequencia) INTO l_sequencia
			  	FROM texto_chamado_van
			  	WHERE cod_empresa  = p_cod_empresa
			  	  AND num_chamado  = mr_chamado.num_chamado
			  WHENEVER ERROR STOP
			  
			  IF SQLCA.SQLCODE = 0 THEN
			  	IF l_sequencia IS NULL OR l_sequencia < 1 THEN
			  		LET l_sequencia = 1
			  	ELSE
			  		LET l_sequencia = l_sequencia + 1
			  	END IF
			  END IF
			  
			  WHENEVER ERROR CONTINUE
			  	SELECT MAX(seq_txt) INTO l_seq_txt
			  	FROM texto_chamado_van
			  	WHERE cod_empresa = p_cod_empresa
			  	  AND num_chamado = mr_chamado.num_chamado
			  	  AND sequencia   = l_sequencia
		    WHENEVER ERROR STOP
		    IF SQLCA.SQLCODE = 0 THEN
		    	IF l_seq_txt IS NULL OR l_seq_txt < 1 THEN
		    		LET l_seq_txt = 1
		    	ELSE
		    		LET l_seq_txt = l_seq_txt + 1
		    	END IF
		    END IF
		    	
		    FOR p_ind = 1 TO ARR_COUNT()
					IF ma_array[p_ind].descr_def IS NOT NULL THEN	
				    WHENEVER ERROR CONTINUE
				    LET m_dat_inc = CURRENT
							INSERT INTO texto_chamado_van (cod_empresa,
							                               num_chamado,
							                               dat_inc,
							                               sequencia,
							                               seq_txt,
							                               descr_def)
							                               VALUES (p_cod_empresa,
							                                       mr_chamado.num_chamado,
							                                       m_dat_inc,
							                                       l_sequencia,
							                                       l_seq_txt,
							                                       ma_array[p_ind].descr_def)
				  	WHENEVER ERROR STOP
				  	IF SQLCA.SQLCODE <> 0 THEN
				  		ERROR "Erro na abertura do chamado."
							EXIT FOR
						END IF
						let l_seq_txt = l_seq_txt + 1
					END IF
				END FOR
	
				IF SQLCA.SQLCODE = 0 THEN
					DISPLAY mr_chamado.num_chamado TO chamado
					ERROR "Abertura do chamado efetuada com sucesso."
					COMMIT WORK
					CALL van99_envia_email_usuarios()
				ELSE
					ERROR "Erro durante a abertura do chamado -", SQLCA.SQLCODE 
					ROLLBACK WORK
				END IF
			END IF
		ELSE #fecha array...
			CLEAR FORM
			ERROR "Abertura cancelada."
 			RETURN FALSE
 		END IF
	ELSE #fecha cabeçalho...
		INITIALIZE mr_chamado.* TO NULL
		CLEAR FORM
		ERROR  "Abertura cancelada."
	END IF 
 
 END FUNCTION

#---------------------------------#
 FUNCTION van99_entrada_dados(l_funcao)
#---------------------------------#
	
	DEFINE l_user				LIKE usuarios.cod_usuario,
	       l_dat_abert  DATETIME YEAR TO MINUTE,
	       l_hor_abert  DATETIME YEAR TO MINUTE,
	       l_hora       CHAR(05),
	       l_mail       LIKE usuarios.e_mail
	      
	DEFINE l_funcao     CHAR(2)
	
	IF l_funcao = "IN" THEN
		CLEAR FORM
	  
	  DISPLAY p_cod_empresa TO empresa
				
		LET INT_FLAG = 0
		
		LET l_user      = p_user
		LET l_dat_abert = CURRENT YEAR TO SECOND
		LET l_hor_abert = CURRENT HOUR TO MINUTE
		LET l_hora      = EXTEND(l_hor_abert, HOUR TO MINUTE)
		
		DISPLAY l_dat_abert TO dat_abert
		DISPLAY l_hora TO hor_abert
	END IF

	INPUT mr_chamado.usuario,
		    mr_chamado.setor,
		    mr_chamado.area,
		    mr_chamado.problema,
		    mr_chamado.defeito,	
		    mr_chamado.atendente WITHOUT DEFAULTS FROM	usuario,
		                                                setor,
		                                                area,
		                                                problema,
		                                                defeito,
		                                                atendente
		
		BEFORE FIELD usuario
			IF l_funcao = "IN" THEN
				WHENEVER ERROR CONTINUE
				SELECT 1 
				  FROM adm_chamado_van
				 WHERE cod_empresa = p_cod_empresa
				   AND (area       = 'TI' OR area = 'MARKETING')
				   AND responsavel = p_user
				WHENEVER ERROR STOP
				IF SQLCA.SQLCODE = 100 THEN
					LET mr_chamado.usuario = p_user
					DISPLAY l_user TO usuario
					NEXT FIELD setor
				END IF
			END IF
			
			IF l_funcao = "TR" THEN
				NEXT FIELD area
			END IF
			
		AFTER FIELD usuario
			IF mr_chamado.usuario IS NOT NULL AND mr_chamado.usuario <> " " THEN
				WHENEVER ERROR CONTINUE
				  SELECT DISTINCT 1
				    FROM log_bloqueios
				   WHERE usuario = mr_chamado.usuario
				WHENEVER ERROR STOP
				IF SQLCA.SQLCODE = 0 THEN
					CALL log0030_mensagem("Usuario bloqueado.","info")
					NEXT FIELD usuario
				END IF
				WHENEVER ERROR CONTINUE
					SELECT e_mail INTO l_mail
					  FROM usuarios
					 WHERE cod_usuario = mr_chamado.usuario
				WHENEVER ERROR STOP
				IF SQLCA.SQLCODE <> 0 THEN
					CALL log0030_mensagem("Usuario não encontrado.","info")
					NEXT FIELD usuario
				ELSE
					IF l_mail IS NULL THEN
						CALL log0030_mensagem("Usuario sem e-mail cadastrado.","info")
						NEXT FIELD usuario
					END IF
				END IF
			ELSE
				CALL log0030_mensagem('Usuario deve ser preenchido.','info')
				NEXT FIELD usuario
			END IF
			
		AFTER FIELD setor
			IF mr_chamado.setor IS NOT NULL AND mr_chamado.setor <> " " THEN
				WHENEVER ERROR CONTINUE
				  SELECT DISTINCT 1
				    FROM uni_funcional 
				   WHERE cod_empresa = p_cod_empresa
				     AND den_uni_funcio = mr_chamado.setor
				     AND dat_validade_fim > TODAY
				WHENEVER ERROR STOP
				IF SQLCA.SQLCODE <> 0 THEN
					CALL log0030_mensagem("Setor não cadastrado.","info")
					NEXT FIELD setor
				END IF
				{WHENEVER ERROR CONTINUE
					SELECT e_mail INTO l_mail
					  FROM usuarios
					 WHERE cod_usuario = mr_chamado.usuario
				WHENEVER ERROR STOP
				IF SQLCA.SQLCODE <> 0 THEN
					CALL log0030_mensagem("Usuario não encontrado.","info")
					NEXT FIELD usuario
				ELSE
					IF l_mail IS NULL THEN
						CALL log0030_mensagem("Usuario sem e-mail cadastrado.","info")
						NEXT FIELD usuario
					END IF
				END IF}
			ELSE
				CALL log0030_mensagem('Setor solicitante deve ser preenchido.','info')
				NEXT FIELD setor
			END IF
		
		AFTER FIELD area
			IF mr_chamado.area IS NOT NULL AND mr_chamado.area <> " " THEN
				IF NOT van99_verifica_area() THEN
					NEXT FIELD area
				END IF
			ELSE
					ERROR "Campo não pode ser nulo."
 					NEXT FIELD area
 			END IF
 			
 		AFTER FIELD problema
			IF mr_chamado.problema IS NOT NULL AND mr_chamado.problema <> " " THEN
				IF NOT van99_verifica_problema() THEN
					NEXT FIELD problema
				END IF
			ELSE
					ERROR "Campo não pode ser nulo."
 					NEXT FIELD problema
 			END IF
 			
 		AFTER FIELD defeito
			IF mr_chamado.defeito IS NOT NULL AND mr_chamado.defeito <> " " THEN
			ELSE
					ERROR "Campo não pode ser nulo."
 					NEXT FIELD defeito
 			END IF 
 			
 		ON KEY (CONTROL-z)
 		CALL van9999_popup()
 		
 		END INPUT
 		
 		IF INT_FLAG <> 0 THEN
 			LET INT_FLAG = 0
 			RETURN FALSE
 		END IF
 	
 	RETURN TRUE
 	
  END FUNCTION
  
#-----------------------------#
 FUNCTION van99_entrada_array(l_funcao2)
#-----------------------------#

	DEFINE l_funcao2    CHAR(02),
	       l_user       LIKE usuarios.cod_usuario

	DEFINE pa_curr      SMALLINT,
	       sc_curr      SMALLINT,
	       corrente     CHAR(76),
	       p_cont       SMALLINT
	       
	INITIALIZE pa_curr, sc_curr, corrente TO NULL
	
	FOR p_cont = 1 TO 100
		INITIALIZE ma_array[p_cont].descr_def TO NULL
	END FOR
	       
	LET INT_FLAG = 0
	
	INPUT ARRAY ma_array WITHOUT DEFAULTS FROM sr_descr_def.*
		
		BEFORE ROW
			LET pa_curr = ARR_CURR()
			LET sc_curr = SCR_LINE()
			LET l_user = UPSHIFT(p_user)
    
    BEFORE FIELD descr_def
    	IF ma_array[pa_curr].descr_def IS NULL AND pa_curr = 1 THEN
    		LET ma_array[pa_curr].descr_def = TODAY, ' ', TIME, ' - ', l_user CLIPPED, ' - '
    		LET ma_array[pa_curr].descr_def = ma_array[pa_curr].descr_def CLIPPED
    		DISPLAY ma_array[pa_curr].descr_def TO sr_descr_def[sc_curr].descr_def
     	END IF
     
   	AFTER FIELD descr_def
   		IF LENGTH(ma_array[pa_curr].descr_def) < 35 AND pa_curr = 1 THEN
   			CALL log0030_mensagem('Linha 1 deve conter data, nome e relato. 35 caracteres minimo.','info')
   			NEXT FIELD descr_def
   		END IF
    	{IF ma_array[pa_curr].descr_def IS NULL AND pa_curr > 1 THEN
    		NEXT FIELD descr_def
    	END IF}
     
	END INPUT
 	 	
 	IF INT_FLAG <> 0 THEN
 		LET INT_FLAG = 0
 		RETURN FALSE
 	END IF
 	
 	RETURN TRUE 
 
 END FUNCTION
  
#-----------------------------#
 FUNCTION van99_verifica_area()
#-----------------------------#

	WHENEVER ERROR CONTINUE
	 SELECT DISTINCT 1
		 FROM mot_chamado_van
		WHERE cod_empresa = p_cod_empresa
		  AND area        = mr_chamado.area
	WHENEVER ERROR STOP
	
	IF SQLCA.SQLCODE <> 0 THEN
		CALL log0030_mensagem("Area não encontrada, entre contato adm do programa.", "info")
		RETURN FALSE
	END IF
	
	RETURN TRUE
	
 END FUNCTION
 
#---------------------------------#
 FUNCTION van99_verifica_problema()
#---------------------------------#

	WHENEVER ERROR CONTINUE
	 SELECT DISTINCT 1
		 FROM mot_chamado_van
		WHERE cod_empresa = p_cod_empresa
		  AND area        = mr_chamado.area
		  AND problema    = mr_chamado.problema
	WHENEVER ERROR STOP
	
	IF SQLCA.SQLCODE <> 0 THEN
		CALL log0030_mensagem("Problema não encontrada, entre contato adm do programa.", "info")
		RETURN FALSE
	END IF
	
	RETURN TRUE
	
 END FUNCTION
 
 #-----------------------#
 FUNCTION van9999_popup()
 #-----------------------#
 
	CASE
		WHEN INFIELD(usuario)
			CALL van99_zoom_usuario() RETURNING mr_chamado.usuario 
			IF mr_chamado.usuario IS NOT NULL AND mr_chamado.usuario <> " " THEN
				CURRENT WINDOW IS w_van9999
				DISPLAY mr_chamado.usuario TO usuario
			ELSE
				CALL log0030_mensagem("Argumentos de pesquisa não encontrados.", "info") 
			END IF
			
		WHEN INFIELD(setor)
			CALL van99_zoom_setor() RETURNING mr_chamado.setor
			IF mr_chamado.setor IS NOT NULL AND mr_chamado.setor <> " " THEN
				CURRENT WINDOW IS w_van9999
				DISPLAY mr_chamado.setor TO setor
			ELSE
				CALL log0030_mensagem("Argumentos de pesquisa não encontrados.", "info") 
			END IF
			
		WHEN INFIELD(area)
			CALL van99_zoom_area() RETURNING mr_chamado.area 
			IF mr_chamado.area IS NOT NULL AND mr_chamado.area <> " " THEN
				CURRENT WINDOW IS w_van9999
				DISPLAY mr_chamado.area TO area
			ELSE
				CALL log0030_mensagem("Argumentos de pesquisa não encontrados.", "info") 
			END IF
			
	  WHEN INFIELD(problema)
			CALL van99_zoom_problema() RETURNING mr_chamado.problema 
			IF mr_chamado.problema IS NOT NULL AND mr_chamado.problema <> " " THEN
				CURRENT WINDOW IS w_van9999
				DISPLAY mr_chamado.problema TO problema
			ELSE
				CALL log0030_mensagem("Argumentos de pesquisa não encontrados.", "info") 
			END IF

	END CASE
 END FUNCTION
 
#---------------------------#
 FUNCTION van99_zoom_usuario()
#---------------------------#
	DEFINE l_ind		    SMALLINT,
			   l_lin_arr    INTEGER
			
	DEFINE la_user ARRAY[1000] OF RECORD
		      usuario LIKE usuarios.cod_usuario,
		      nome    LIKE usuarios.nom_funcionario		             	
										        END RECORD
										        	
	OPEN WINDOW w_van99990 AT 6,3 WITH FORM 'van99990'
	ATTRIBUTES (BORDER, MESSAGE LINE LAST, PROMPT LINE LAST)
	CURRENT WINDOW IS w_van99990
	
	LET l_ind = 1
	                 
	DECLARE cq_user CURSOR FOR
	 SELECT DISTINCT
	        cod_usuario, 
		      nom_funcionario
		 FROM usuarios, log_bloqueios
		WHERE usuarios.cod_usuario <> log_bloqueios.usuario
		ORDER BY cod_usuario

		FOREACH cq_user INTO la_user[l_ind].usuario,
			                   la_user[l_ind].nome
			LET l_ind = l_ind + 1
		END FOREACH
		
		IF l_ind > 1 THEN
		   LET l_ind = l_ind -1
		ELSE
			CLOSE WINDOW w_van99990
			RETURN NULL
	  END IF
	  
	  LET INT_FLAG = 0
	  
	  CALL SET_COUNT(l_ind)
	  
	  DISPLAY ARRAY la_user TO sr_user.*
	  
	  LET l_lin_arr = ARR_CURR()
	  
	  IF INT_FLAG THEN 
	  	CLOSE WINDOW w_van99990
			RETURN NULL
		ELSE
			CLOSE WINDOW w_van99990
			RETURN la_user[l_lin_arr].usuario
		END IF
	
 END FUNCTION
 
#--------------------------#
 FUNCTION van99_zoom_setor()
#--------------------------#
	DEFINE l_ind		    SMALLINT,
			   l_lin_arr    INTEGER
			
	DEFINE la_setor ARRAY[100] OF RECORD
		      setor   LIKE uni_funcional.den_uni_funcio		             	
										        END RECORD
										        	
	OPEN WINDOW w_van99993 AT 9,35 WITH FORM 'van99993'
	ATTRIBUTES (BORDER, MESSAGE LINE LAST, PROMPT LINE LAST)
	CURRENT WINDOW IS w_van99993
	
	LET l_ind = 1
	                 
	WHENEVER ERROR CONTINUE
	DECLARE cq_setor CURSOR FOR
	 SELECT DISTINCT
	        den_uni_funcio
		 FROM uni_funcional
		WHERE dat_validade_fim > TODAY
		  AND cod_empresa      = p_cod_empresa
	WHENEVER ERROR STOP

		FOREACH cq_setor INTO la_setor[l_ind].setor
			LET l_ind = l_ind + 1
		END FOREACH
		
		IF l_ind > 1 THEN
		   LET l_ind = l_ind -1
		ELSE
			CLOSE WINDOW w_van99993
			RETURN NULL
	  END IF
	  
	  LET INT_FLAG = 0
	  
	  CALL SET_COUNT(l_ind)
	  
	  DISPLAY ARRAY la_setor TO sr_setor.*
	  
	  LET l_lin_arr = ARR_CURR()
	  
	  IF INT_FLAG THEN 
	  	CLOSE WINDOW w_van99993
			RETURN NULL
		ELSE
			CLOSE WINDOW w_van99993
			RETURN la_setor[l_lin_arr].setor
		END IF
	
 END FUNCTION
 
#------------------------#
 FUNCTION van99_zoom_area()
#------------------------#
	DEFINE l_ind		    SMALLINT,
			   l_lin_arr    INTEGER
			
	DEFINE la_area ARRAY[1000] OF RECORD
		             area         CHAR(20)	
										        END RECORD
										        	
	OPEN WINDOW w_van99991 AT 6,3 WITH FORM 'van99991'
	ATTRIBUTES (BORDER, MESSAGE LINE LAST, PROMPT LINE LAST)
	CURRENT WINDOW IS w_van99991
	
	LET l_ind = 1
	                 
	DECLARE cq_area CURSOR FOR
		SELECT DISTINCT area
		  FROM mot_chamado_van
		 WHERE cod_empresa = p_cod_empresa
		 ORDER BY area

		FOREACH cq_area INTO la_area[l_ind].area
			LET l_ind = l_ind + 1
		END FOREACH
		
		IF l_ind > 1 THEN
		   LET l_ind = l_ind -1
		ELSE
			CLOSE WINDOW w_van99991
			RETURN NULL
	  END IF
	  
	  LET INT_FLAG = 0
	  
	  CALL SET_COUNT(l_ind)
	  
	  DISPLAY ARRAY la_area TO sr_area.*
	  
	  LET l_lin_arr = ARR_CURR()
	  
	  IF INT_FLAG THEN 
	  	CLOSE WINDOW w_van99991
			RETURN NULL
		ELSE
			CLOSE WINDOW w_van99991
			RETURN la_area[l_lin_arr].area
		END IF
	
 END FUNCTION
 
#----------------------#
 FUNCTION van99_zoom_problema()
#----------------------#
	DEFINE l_ind		    SMALLINT,
			   l_lin_arr    INTEGER
			
	DEFINE la_problema ARRAY[1000] OF RECORD
		                 area         CHAR(20),
		                 problema     CHAR(20)
										        END RECORD
										        	
	OPEN WINDOW w_van99992 AT 6,3 WITH FORM 'van99992'
	ATTRIBUTES (BORDER, MESSAGE LINE LAST, PROMPT LINE LAST)
	CURRENT WINDOW IS w_van99992
	
	LET l_ind = 1
	                 
	DECLARE cq_problema CURSOR FOR
		SELECT DISTINCT area,
		                problema
		           FROM mot_chamado_van
		          WHERE area        = mr_chamado.area
		            AND cod_empresa = p_cod_empresa
		       ORDER BY area,
		                problema

		FOREACH cq_problema INTO la_problema[l_ind].area,
			                       la_problema[l_ind].problema
			                      
			LET l_ind = l_ind + 1
		END FOREACH
		
		IF l_ind > 1 THEN
		   LET l_ind = l_ind -1
		ELSE
			CLOSE WINDOW w_van99992
			RETURN NULL
	  END IF
	  
	  LET INT_FLAG = 0
	  
	  CALL SET_COUNT(l_ind)
	  
	  DISPLAY ARRAY la_problema TO sr_problema.*
	  
	  LET l_lin_arr = ARR_CURR()
	  
	  IF INT_FLAG THEN 
	  	CLOSE WINDOW w_van99992
			RETURN NULL
		ELSE
			CLOSE WINDOW w_van99992
			RETURN la_problema[l_lin_arr].problema
		END IF
	
 END FUNCTION
 
#-------------------------#
 FUNCTION van99_consultar()
#-------------------------#
 
 	DEFINE l_empresa CHAR(02)

 	DEFINE sql_stmt       CHAR(500),
        where_clause   CHAR(500),
        l_situacao	   CHAR(10),
        l_area         CHAR(20)

 	SELECT cod_empresa 
   INTO l_empresa
   FROM par_vdp
  WHERE par_vdp.cod_empresa = p_cod_empresa

 	DISPLAY l_empresa TO  empresa

 	INITIALIZE mr_chamado.* TO NULL

	CLEAR FORM
	
 	LET sql_stmt =  " select * ",
                 " from chamado_van ",
                 " where num_chamado =  """,""" "

	CONSTRUCT where_clause ON num_chamado,
	                          ies_status,
	                          usuario,
	                          setor,
	                          {dat_abert,
	                          dat_encerr,
	                          area,}
	                          problema,
	                          defeito,
	                          atendente 
	                          FROM chamado,
	                               STATUS,
	                               usuario,
	                               setor,
	                               {dat_abert,
	                               dat_encerr,
	                               area,}
	                               problema,
	                               defeito,
	                               atendente
	                               
	BEFORE FIELD usuario
		WHENEVER ERROR CONTINUE
		SELECT 1
		  FROM adm_chamado_van
		 WHERE cod_empresa = p_cod_empresa
		   AND responsavel = p_user
		WHENEVER ERROR STOP
		IF SQLCA.SQLCODE = 100 THEN
			NEXT FIELD
		END IF
		
	BEFORE FIELD area
		WHENEVER ERROR CONTINUE
		SELECT area
		  INTO l_area
		  FROM adm_chamado_van
		 WHERE cod_empresa = p_cod_empresa
		   #AND area       != 'TI'
		   AND responsavel = p_user
		WHENEVER ERROR STOP
		IF SQLCA.SQLCODE = 0 THEN
			#NEXT FIELD 
		END IF
		
	END CONSTRUCT
                                                
 	CALL log006_exibe_teclas("01", p_versao)
 
 	IF INT_FLAG THEN
 		LET INT_FLAG = 0
 		LET mr_chamado.* = mr_chamador.*
 		ERROR "Consulta cancelada."
 		RETURN
 	END IF
 	
 	LET sql_stmt =  " select * ",
 	                " from chamado_van "
 	                
 	LET sql_stmt = sql_stmt CLIPPED,
 	                "  where  ", where_clause CLIPPED
 	                
 	WHENEVER ERROR CONTINUE
		SELECT area
		  INTO l_area
		  FROM adm_chamado_van
		 WHERE cod_empresa = p_cod_empresa
		   AND responsavel = p_user
	WHENEVER ERROR STOP
	IF SQLCA.SQLCODE = 0 THEN
		
	END IF
 	                
 	#verifica se é tecnico em geral
 	WHENEVER ERROR CONTINUE
 	SELECT 1
 	  FROM adm_chamado_van
 	 WHERE cod_empresa = p_cod_empresa
 	   AND responsavel = p_user
 	WHENEVER ERROR STOP
 	IF SQLCA.SQLCODE = 100 THEN
 		LET sql_stmt = sql_stmt CLIPPED, 
  	               " and usuario = '",p_user,"' "
 	ELSE
 		LET sql_stmt = sql_stmt CLIPPED,
 		               " and (area = '",l_area,"' OR usuario = '",p_user,"') "
  END IF
  
  {#verifica se é tecnico eletrica
  WHENEVER ERROR CONTINUE
 	SELECT 1
 	  FROM adm_chamado_van
 	 WHERE cod_empresa = p_cod_empresa
 	   AND area        = 'MANUTENCAO INTERNA'
 	   AND responsavel = p_user
 	WHENEVER ERROR STOP
 	IF SQLCA.SQLCODE = 0 THEN
  	LET sql_stmt = sql_stmt CLIPPED,
  	               " and (area = 'MANUTENCAO INTERNA' OR usuario = '",p_user,"') "
  END IF
  
  #verifica se é layout
  WHENEVER ERROR CONTINUE
 	SELECT 1
 	  FROM adm_chamado_van
 	 WHERE cod_empresa = p_cod_empresa
 	   AND area        = 'LAYOUT'
 	   AND responsavel = p_user
 	WHENEVER ERROR STOP
 	IF SQLCA.SQLCODE = 0 THEN
  	LET sql_stmt = sql_stmt CLIPPED,
  	               " and (area = 'LAYOUT' OR usuario = '",p_user,"') "
  END IF
  
  #verifica se é TI
  WHENEVER ERROR CONTINUE
 	SELECT 1
 	  FROM adm_chamado_van
 	 WHERE cod_empresa = p_cod_empresa
 	   AND area        = 'TI'
 	   AND responsavel = p_user
 	WHENEVER ERROR STOP
 	IF SQLCA.SQLCODE = 0 THEN
  	LET sql_stmt = sql_stmt CLIPPED,
  	               " and (area = 'TI' OR usuario = '",p_user,"') "
  END IF}
  
  LET sql_stmt = sql_stmt CLIPPED,
  	               " order by cod_empresa, num_chamado desc"
	
	WHENEVER ERROR CONTINUE
	CALL log0810_prepare_sql(sql_stmt) RETURNING sql_stmt
	WHENEVER ERROR STOP
	
	WHENEVER ERROR CONTINUE
	PREPARE relat_query FROM sql_stmt
	WHENEVER ERROR STOP
	
	WHENEVER ERROR CONTINUE
	DECLARE cq_consulta SCROLL CURSOR WITH HOLD FOR relat_query
	WHENEVER ERROR STOP
		
		WHENEVER ERROR CONTINUE
		OPEN cq_consulta
		WHENEVER ERROR STOP
		
		WHENEVER ERROR CONTINUE
		FETCH cq_consulta into mr_chamado.*
		WHENEVER ERROR STOP
		IF SQLCA.SQLCODE = NOTFOUND THEN
			CALL log0030_mensagem("Chamado não encontrado na base.", "info")
			LET ies_relatorio = FALSE
			LET m_consulta_ativa = FALSE
		ELSE
			LET ies_relatorio = TRUE
			LET m_consulta_ativa = TRUE
			CALL van99_exibe_dados()
			CALL van99_consulta_descr()
		END IF
 END FUNCTION
 
#---------------------------#
 FUNCTION van99_exibe_dados()
#---------------------------#

 	DEFINE l_hora     CHAR(05),
 	       l_hora_enc CHAR(05),
 	       l_nome_ate LIKE usuarios.nom_funcionario,
 	       l_den_status CHAR(10)
 	
 	LET l_hora     = EXTEND(mr_chamado.dat_abert, HOUR TO MINUTE)
 	LET l_hora_enc = EXTEND(mr_chamado.dat_encerr, HOUR TO MINUTE)

	DISPLAY mr_chamado.num_chamado      TO chamado
	DISPLAY mr_chamado.usuario          TO usuario
	DISPLAY mr_chamado.setor            TO setor
	DISPLAY mr_chamado.dat_abert        TO dat_abert
	DISPLAY l_hora                      TO hor_abert
	DISPLAY mr_chamado.dat_encerr       TO dat_encerr
	DISPLAY l_hora_enc                  TO hor_encerr
	DISPLAY mr_chamado.area             TO area
	DISPLAY mr_chamado.problema         TO problema
	DISPLAY mr_chamado.defeito          TO defeito
	DISPLAY mr_chamado.status           TO STATUS
	
	CASE 
		WHEN mr_chamado.status = 'A' 
			LET l_den_status = "ABERTO"
		WHEN mr_chamado.status = 'P'
			LET l_den_status = "PENDENTE"
		WHEN mr_chamado.status = 'E'
			LET l_den_status = "ENCERRADO"
		WHEN mr_chamado.status = 'C'
			LET l_den_status = "CANCELADO"
	END CASE
	
	DISPLAY l_den_status  TO den_sit
	
	IF mr_chamado.atendente IS NULL THEN
		DISPLAY mr_chamado.atendente TO atendente
	ELSE	
		WHENEVER ERROR CONTINUE
		SELECT nom_funcionario INTO l_nome_ate
		  FROM usuarios
		 WHERE cod_usuario = mr_chamado.atendente
		WHENEVER ERROR STOP
		IF SQLCA.SQLCODE = 0 THEN
			DISPLAY l_nome_ate TO atendente
		END IF
	END IF
				
 END FUNCTION
 
#----------------------------------#
 FUNCTION van99_paginacao(lr_funcao)
#----------------------------------#

	DEFINE lr_funcao CHAR(20)
	
	WHILE TRUE
		CASE 
			WHEN lr_funcao = "seguinte"
				FETCH NEXT cq_consulta INTO mr_chamado.*
	  										
	  	WHEN lr_funcao = "anterior"
	  		FETCH PREVIOUS cq_consulta INTO mr_chamado.*
		END CASE
		
		IF SQLCA.SQLCODE = NOTFOUND THEN
			ERROR "Não existem mais itens nesta direção."
			EXIT WHILE
		END IF

		WHENEVER ERROR CONTINUE
		SELECT *
			FROM chamado_van
		 WHERE cod_empresa 	= mr_chamado.cod_empresa
		   AND num_chamado		= mr_chamado.num_chamado
		WHENEVER ERROR STOP
		IF SQLCA.SQLCODE <> 0 THEN
			CLEAR FORM
			CALL log0030_mensagem("Argumentos de pesquisa não encontrados.", "info")
			EXIT WHILE
		ELSE
			CALL van99_exibe_dados()
			CALL van99_consulta_descr()
			EXIT WHILE
		END IF
	END WHILE
END FUNCTION

#-----------------------------#
 FUNCTION van99_consulta_descr()
#-----------------------------#
	DEFINE p_ind        SMALLINT,
	       m_count      SMALLINT,
	       l_ind        INTEGER
			
	
	FOR p_ind = 1 to 100
		INITIALIZE ma_array[p_ind].* TO NULL
		IF p_ind <= 10 THEN
			DISPLAY ma_array[p_ind].* TO sr_descr_def[p_ind].*
		END IF
	END FOR
	    
	WHENEVER ERROR CONTINUE
	DECLARE cq_descr CURSOR FOR
		SELECT descr_def
		  FROM texto_chamado_van
		 WHERE cod_empresa  = p_cod_empresa
		   AND num_chamado  = mr_chamado.num_chamado
		 ORDER BY cod_empresa asc,
		          num_chamado asc,
		          sequencia DESC,
		          seq_txt ASC
	WHENEVER ERROR STOP
	
	LET m_count = 1
	
	FOREACH cq_descr INTO ma_array[m_count].descr_def
		LET m_count = m_count + 1
	END FOREACH
	  
  LET m_count = m_count - 1
  
  CALL SET_COUNT(m_count)
  
	IF m_count <= 10 THEN
		FOR l_ind = 1 TO m_count
			DISPLAY ma_array [l_ind].* TO sr_descr_def[l_ind].*
		END FOR
 	ELSE
 		DISPLAY ARRAY ma_array TO sr_descr_def.*
 	END IF
 END FUNCTION
 
#---------------------------#
 FUNCTION van9999_interacao()
#---------------------------#

	DEFINE l_idx_arr 	   INTEGER,
	       l_idx_scr 	   INTEGER,
	       l_erro	 	     INTEGER,
	       l_sequencia	 SMALLINT,
	       l_seq_txt     SMALLINT,
	       la_texto	 	   ARRAY[100] OF RECORD
	       	descr_def  	             CHAR(76)
	       	                       END RECORD
      						   		
	DEFINE lr_texto	     ARRAY[100] OF RECORD
		      descr_def     	         CHAR(76)
		                             END RECORD
		                             
	DEFINE pa_curr      SMALLINT,
	       sc_curr      SMALLINT,
	       corrente     CHAR(76),
	       l_user       LIKE usuarios.cod_usuario

	INITIALIZE la_texto, corrente, pa_curr, sc_curr TO NULL
	
	FOR l_idx_scr = 1 TO 100
		INITIALIZE lr_texto[l_idx_scr].descr_def TO NULL
	END FOR

	
	LET INT_FLAG = 0
	
	INPUT ARRAY lr_texto WITHOUT DEFAULTS FROM sr_descr_def.*
		BEFORE ROW
     LET pa_curr = ARR_CURR()
     LET sc_curr = SCR_LINE()
     LET l_user = UPSHIFT(p_user)
    
    BEFORE FIELD descr_def
    	IF lr_texto[pa_curr].descr_def IS NULL AND pa_curr = 1 THEN
    		LET lr_texto[pa_curr].descr_def = TODAY,
    		                                  ' ',
    		                                  TIME,
    		                                  ' - ',
    		                                  l_user CLIPPED,
    		                                  ' - '
    		DISPLAY lr_texto[pa_curr].descr_def TO sr_descr_def[sc_curr].descr_def
     	END IF
     
   	AFTER FIELD descr_def
   		IF LENGTH(lr_texto[pa_curr].descr_def) < 35 AND pa_curr = 1 THEN
   			CALL log0030_mensagem('Linha 1 deve conter data, nome e relato. 35 caracteres minimo.','info')
   			NEXT FIELD descr_def
   		END IF
    	{IF lr_texto[pa_curr].descr_def IS NULL AND pa_curr > 0 THEN
    		NEXT FIELD descr_def
    	END IF}
		
		AFTER INPUT
			IF INT_FLAG = 0 THEN
				WHENEVER ERROR CONTINUE
				BEGIN WORK
				DELETE FROM texto_chamado_van
				 WHERE cod_empresa 	= mr_chamado.cod_empresa
					 AND num_chamado  = mr_chamado.num_chamado
					 AND descr_def IS NULL
				WHENEVER ERROR STOP
								
				IF SQLCA.SQLCODE = 0 THEN
					WHENEVER ERROR CONTINUE
					SELECT max(sequencia)	INTO l_sequencia
					  FROM texto_chamado_van
					 WHERE cod_empresa	= mr_chamado.cod_empresa
					   AND num_chamado  = mr_chamado.num_chamado
					WHENEVER ERROR STOP
					
					IF SQLCA.SQLCODE = 0 THEN
						IF l_sequencia IS NULL THEN
							LET l_sequencia = 1
						ELSE
							LET l_sequencia = l_sequencia + 1
						END IF
					ELSE
						CALL log003_err_sql("select", "texto_chamao_van")
						RETURN FALSE
 					END IF
 					
 					WHENEVER ERROR CONTINUE
 					SELECT MAX(seq_txt) INTO l_seq_txt
 					  FROM texto_chamado_van
 					 WHERE cod_empresa	= mr_chamado.cod_empresa
 					   AND num_chamado  = mr_chamado.num_chamado
 					   AND sequencia    = l_sequencia
 					WHENEVER ERROR STOP
 					
 					IF SQLCA.SQLCODE = 0 THEN
 						IF l_seq_txt IS NULL THEN
 							LET l_seq_txt = 1
 						ELSE
 							LET l_seq_txt = l_seq_txt + 1
 						END IF
 					ELSE
 						CALL log003_err_sql("select", "texto_chamado_van")
 						RETURN FALSE
 				  END IF
				
				  IF SQLCA.SQLCODE = 0 THEN
				  	FOR l_idx_scr = 1 TO ARR_COUNT()
				  		IF lr_texto[l_idx_scr].descr_def IS NOT NULL THEN
				  			WHENEVER ERROR CONTINUE
				  			LET m_dat_inc = CURRENT
				  			INSERT INTO texto_chamado_van (cod_empresa,
				  			                               num_chamado,
				  			                               dat_inc,
				  			                               sequencia,
				  			                               seq_txt,
				  			                               descr_def)
				  			                               VALUES (p_cod_empresa,
				  			                                       mr_chamado.num_chamado,
				  			                                       m_dat_inc,
				  			                                       l_sequencia,
				  			                                       l_seq_txt,
				  			                                       lr_texto[l_idx_scr].descr_def)
				  			WHENEVER ERROR STOP
				  			IF SQLCA.SQLCODE <> 0 THEN
				  				ERROR "Erro na inclusão."
				  				LET l_erro = TRUE
				  				EXIT FOR
								END IF
								LET l_seq_txt = l_seq_txt + 1
							END IF
						END FOR
						
						WHENEVER ERROR CONTINUE
						SELECT 1
						  FROM adm_chamado_van
						 WHERE cod_empresa = p_cod_empresa
						   AND responsavel = p_user
						   AND area        = mr_chamado.area
						WHENEVER ERROR STOP
						IF SQLCA.SQLCODE = 0 THEN
							IF NOT van99_update_atendente("INTER") THEN
								LET l_erro = TRUE
							END IF
						END IF
						
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
								CALL van99_envia_email_usuarios()
							END IF
						END IF
					ELSE
						ERROR "Erro na exclusão."
						WHENEVER ERROR CONTINUE
						ROLLBACK WORK
						WHENEVER ERROR STOP
					END IF
				END IF
			END IF
	END INPUT
	
	IF INT_FLAG <> 0 THEN
 		LET INT_FLAG = 0
 		RETURN FALSE
 	END IF
 	
 	CALL van99_atualiza_dados()
 	CALL van99_consulta_descr()
 	RETURN TRUE
END FUNCTION

#----------------------------------------#
 FUNCTION van99_update_atendente(l_funcao)
#----------------------------------------#
	DEFINE l_funcao   CHAR(05)
	
	DEFINE l_user     LIKE usuarios.cod_usuario,
	       l_status   CHAR(01)
	       
  INITIALIZE l_status, l_user TO NULL
  
  LET l_user = p_user
	
	WHENEVER ERROR CONTINUE
	SELECT ies_status INTO l_status
	  FROM chamado_van
	 WHERE cod_empresa = p_cod_empresa
	   AND num_chamado = mr_chamado.num_chamado
	WHENEVER ERROR STOP
	
	IF SQLCA.SQLCODE = 0 THEN
		
		#WHENEVER ERROR CONTINUE
		#BEGIN WORK
		#WHENEVER ERROR STOP
				
		IF l_status  = 'A' AND l_funcao = 'INTER' THEN
			WHENEVER ERROR CONTINUE
			UPDATE chamado_van SET ies_status = 'P',
			                       atendente  = l_user
			 WHERE cod_empresa = p_cod_empresa
			   AND num_chamado = mr_chamado.num_chamado
			WHENEVER ERROR STOP
			
			IF SQLCA.SQLCODE <> 0 THEN
				CALL log0030_mensagem("Erro ao tentar atualizar STATUS","info")
				#ROLLBACK WORK
				RETURN FALSE
		  END IF
		  
		END IF
		
		IF l_status = 'P' AND l_funcao = 'ENCER' THEN
			WHENEVER ERROR CONTINUE
			UPDATE chamado_van SET ies_status = 'E',
			                       dat_encerr = CURRENT YEAR TO MINUTE	
			WHERE cod_empresa = p_cod_empresa
			  AND num_chamado = mr_chamado.num_chamado
			WHENEVER ERROR STOP
			
			IF SQLCA.SQLCODE <> 0 THEN
				CALL log0030_mensagem("Erro ao tentar atualizar STATUS","info")
				#ROLLBACK WORK
				RETURN FALSE
		  END IF
		  
		END IF
		
		IF l_status <> 'E' AND l_funcao = 'CANC' THEN
			WHENEVER ERROR CONTINUE
			UPDATE chamado_van SET ies_status = 'C',
			                       dat_encerr = CURRENT YEAR TO MINUTE	
			WHERE cod_empresa = p_cod_empresa
			  AND num_chamado = mr_chamado.num_chamado
			WHENEVER ERROR STOP
			
			IF SQLCA.SQLCODE <> 0 THEN
				CALL log0030_mensagem("Erro ao tentar atualizar STATUS","info")
				RETURN FALSE
		  END IF
		  
		END IF
		
		IF l_status = 'A' AND l_funcao = 'TRANS' THEN
			WHENEVER ERROR CONTINUE
			UPDATE chamado_van SET area = mr_chamado.area,
			                       problema = mr_chamado.problema
			WHERE cod_empresa = p_cod_empresa
			  AND num_chamado = mr_chamador.num_chamado
			WHENEVER ERROR STOP
			
			IF SQLCA.SQLCODE <> 0 THEN
				CALL log0030_mensagem("Erro ao tentar atualizar STATUS","info")
				RETURN FALSE
		  END IF
		END IF
		
	END IF
	
	#COMMIT WORK
	RETURN TRUE
	
 END FUNCTION 
	   
#-------------------------------------#
 FUNCTION van99_envia_email_usuarios()
#-------------------------------------#

  DEFINE l_nom_arq_corpo        CHAR(150),
         l_assunto              CHAR(040),
         l_sql_stmt             CHAR(500),
         l_funcao               CHAR(002),
         l_dest      ARRAY[10] OF RECORD
         	mail            CHAR(100)
         	              END RECORD,
         m_email_dest           CHAR(500),
         l_ind                  SMALLINT,
         l_ind2                 SMALLINT, 
         l_ind3                 SMALLINT,
         q_user                 CHAR(50)

  DEFINE lr_chamado             RECORD
           msg_inicial          CHAR(100),
           nom_usuario          LIKE usuarios.nom_funcionario,
           tel_usuario          LIKE usuarios.num_telefone,
           ramal_usuario        LIKE usuarios.num_ramal,
           fax_usuario          LIKE usuarios.num_fax,
           email_usuario        LIKE usuarios.e_mail,
           num_chamado          INTEGER,
           usuario              LIKE usuarios.cod_usuario,
           dat_abert            DATETIME YEAR TO MINUTE,
           dat_encerr           DATETIME YEAR TO MINUTE,
           area                 CHAR(20),
           problema             CHAR(20),
           defeito              CHAR(20),
           atendente            LIKE usuarios.cod_usuario,
           nom_atendente        LIKE usuarios.nom_funcionario,
           tel_atendente        LIKE usuarios.num_telefone,
           email_atendente      LIKE usuarios.e_mail,
           STATUS               CHAR(01),
           setor                CHAR(30)
                            END RECORD
                            
                            
	LET lr_chamado.msg_inicial = 'CHAMADO INTERNO'

  
  #busca informações da empresa
  WHENEVER ERROR CONTINUE
  SELECT den_empresa
    INTO p_den_empresa
    FROM empresa
   WHERE cod_empresa = p_cod_empresa
  WHENEVER ERROR STOP
  IF SQLCA.SQLCODE <> 0 THEN
    CALL log0030_processa_err_sql("SELECT","empresa",0)
    RETURN
  END IF

  #busca informações chamado
  WHENEVER ERROR CONTINUE
  SELECT num_chamado,
         usuario,
         dat_abert,
         dat_encerr,
         area,
         problema,
         defeito,
         atendente,
         ies_status,
         setor_solic
    INTO lr_chamado.num_chamado,
         lr_chamado.usuario,
         lr_chamado.dat_abert,
         lr_chamado.dat_encerr,
         lr_chamado.area,
         lr_chamado.problema,
         lr_chamado.defeito,
         lr_chamado.atendente,
         lr_chamado.status,
         lr_chamado.setor
    FROM chamado_van
   WHERE cod_empresa = p_cod_empresa
     AND num_chamado = mr_chamado.num_chamado
  WHENEVER ERROR STOP
  IF SQLCA.SQLCODE <> 0 THEN
    CALL log0030_processa_err_sql("SELECT","chamado_van",0)
    RETURN
  END IF

  #busca informações do usuarios que está enviando o email
  WHENEVER ERROR CONTINUE
  SELECT usuarios.nom_funcionario,
         usuarios.num_telefone,
         usuarios.num_ramal,
         usuarios.num_fax,
         usuarios.e_mail
    INTO lr_chamado.nom_usuario,
         lr_chamado.tel_usuario,
         lr_chamado.ramal_usuario,
         lr_chamado.fax_usuario,
         lr_chamado.email_usuario
    FROM usuarios
   WHERE usuarios.cod_usuario = lr_chamado.usuario
  WHENEVER ERROR STOP
  IF SQLCA.SQLCODE <> 0 THEN
    CALL log0030_processa_err_sql("SELECT","usuarios",0)
    RETURN
  END IF
  
  WHENEVER ERROR CONTINUE
  SELECT usuarios.nom_funcionario,
         usuarios.num_telefone,
         usuarios.e_mail
    INTO lr_chamado.nom_atendente,
         lr_chamado.tel_atendente,
         lr_chamado.email_atendente
    FROM usuarios
   WHERE usuarios.cod_usuario = lr_chamado.atendente
  WHENEVER ERROR STOP

  #inicia relatorio
  LET l_nom_arq_corpo = log150_procura_caminho("LST")
  LET l_nom_arq_corpo = l_nom_arq_corpo CLIPPED,
                        "van9999_",
                        p_user CLIPPED,
                        ".html"

  START REPORT van99_email TO l_nom_arq_corpo

	#monta email
  OUTPUT TO REPORT van99_email(lr_chamado.*)
  
  FINISH REPORT van99_email

  LET l_assunto = 'Chamado ', mr_chamado.num_chamado USING "<<<<<"
  
  #IF mr_chamado.area = 'TI' THEN
  	WHENEVER ERROR CONTINUE 
  	SELECT DISTINCT responsavel 
  	  INTO q_user
  	  FROM mot_chamado_van
  	 WHERE cod_empresa = p_cod_empresa
  	   AND area        = mr_chamado.area
  	WHENEVER ERROR STOP
  	IF SQLCA.SQLCODE <> 0 THEN
  		CALL log0030_processa_err_sql("SELECT","mot_chamado_van",0)
    	RETURN
    ELSE
  		
  		#busca os usuários que serão enviado o email
  		LET l_sql_stmt = " SELECT usuarios.e_mail ",
    		               " FROM usuarios ",
      		             " WHERE cod_usuario  in ( '",q_user,"', '",lr_chamado.usuario,"') "
    END IF
  {ELSE
  	WHENEVER ERROR CONTINUE 
  	SELECT DISTINCT responsavel 
  	  INTO q_user
  	  FROM mot_chamado_van
  	 WHERE cod_empresa = p_cod_empresa
  	   AND area        = mr_chamado.area
  	WHENEVER ERROR STOP
  	IF SQLCA.SQLCODE <> 0 THEN
  		CALL log0030_processa_err_sql("SELECT","mot_chamado_van",0)
    	RETURN
    ELSE
  	
  		#busca os usuários que serão enviado o email
  		LET l_sql_stmt = " SELECT usuarios.e_mail ",
    	              	 " FROM usuarios ",
      	            	 " WHERE cod_usuario  in ( '",q_user,"', '",lr_chamado.usuario,"') "
  END IF}
  
  WHENEVER ERROR CONTINUE
  PREPARE var_email FROM l_sql_stmt
  WHENEVER ERROR STOP
  IF SQLCA.SQLCODE <> 0 THEN
    CALL log0030_processa_err_sql("PREPARE SQL","var_email",0)
    RETURN
  END IF

  WHENEVER ERROR CONTINUE
  DECLARE cq_email CURSOR FOR var_email
  WHENEVER ERROR STOP
  IF SQLCA.SQLCODE <> 0 THEN
    CALL log0030_processa_err_sql("DECLARE CURSOR","cq_email",0)
    RETURN
  END IF

	LET l_ind = 1
	
  WHENEVER ERROR CONTINUE
  FOREACH cq_email INTO l_dest[l_ind].mail
  WHENEVER ERROR STOP
    IF SQLCA.SQLCODE <> 0 THEN
      CALL log0030_processa_err_sql("FOREACH CURSOR","cq_email",0)
      RETURN
    END IF
		
		LET l_ind = l_ind + 1
    
  END FOREACH
  
  LET m_email_dest = l_dest[1].mail CLIPPED, ",", 
                     l_dest[2].mail CLIPPED, ",", 
                     l_dest[3].mail CLIPPED, ",",
                     l_dest[4].mail CLIPPED, ",",
                     l_dest[5].mail CLIPPED, ",",
                     l_dest[6].mail CLIPPED, ",",
                     l_dest[7].mail CLIPPED, ",",
                     l_dest[8].mail CLIPPED
  
  #envia email
  
  
  
  IF m_anexo = FALSE THEN
  	CALL LOG_sendMail('no_replay@vantec.ind.br',
  	                  m_email_dest CLIPPED,
  	                  l_assunto CLIPPED,
  	                  l_nom_arq_corpo CLIPPED,
  	                  1)
 	ELSE                       
 		CALL LOG_sendMailAttach('no_replay@vantec.ind.br',
 		                        m_email_dest CLIPPED,
 		                        l_assunto CLIPPED,
 		                        l_nom_arq_corpo CLIPPED,
 		                        1,
 		                        m_lista_tmp_arq CLIPPED)
 		LET m_anexo = FALSE		      
  END IF

 END FUNCTION

#------------------------------#
 REPORT van99_email(lr_chamado)
#------------------------------#
   DEFINE l_ind               SMALLINT,
          l_seq_txt           SMALLINT,
          l_sequencia         SMALLINT,
          l_descr_def         CHAR(76),
          l_status            CHAR(20)
   
   DEFINE lr_chamado            RECORD
           msg_inicial          CHAR(100),
           nom_usuario          LIKE usuarios.nom_funcionario,
           tel_usuario          LIKE usuarios.num_telefone,
           ramal_usuario        LIKE usuarios.num_ramal,
           fax_usuario          LIKE usuarios.num_fax,
           email_usuario        LIKE usuarios.e_mail,
           num_chamado          INTEGER,
           usuario              LIKE usuarios.cod_usuario,
           dat_abert            DATETIME YEAR TO MINUTE,
           dat_encerr           DATETIME YEAR TO MINUTE,
           area                 CHAR(20),
           problema             CHAR(20),
           defeito              CHAR(20),
           atendente            LIKE usuarios.cod_usuario,
           nom_atendente        LIKE usuarios.nom_funcionario,
           tel_atendente        LIKE usuarios.num_telefone,
           email_atendente      LIKE usuarios.e_mail,
           STATUS               CHAR(01),
           setor                CHAR(30)
                               END RECORD

{

XXXXXXXXXXXXXXXX
TELEFONE: 99 9999 9999
   RAMAL: 9999
     FAX: 99 9999 9999
   EMAIL: xxxxxxxxx@xxxxxx.xxx.xx
}
   OUTPUT
     LEFT MARGIN 0
     TOP MARGIN 0
     BOTTOM MARGIN 1
     RIGHT MARGIN 0

   	FORMAT
     	FIRST PAGE HEADER
        PRINT log500_determina_cpp(90) CLIPPED;
        PRINT "<font size='3' face='courier'>"
	        PRINT "<table width='600' align='center' cellspacing='0' cellpadding='0' border='0' class='devicewidthinner'>"
          	PRINT "<tbody>"
            	PRINT "<tr>"
              	PRINT "<td align='center'>"
                	PRINT "<a href='http://www.vantec.ind.br'  target='_blank'><img src='http://192.168.0.8/Interface/img/logo_vantec.png' alt='Vantec M&aacute;quinas' width='100%'"
                  	PRINT "style='display:block; border:none; outline:none; text-decoration:none;' class='bigimage'/>"
                  PRINT "</a>"
                PRINT "</td>"
              PRINT "</tr>"
            	PRINT "<tr>"
          			PRINT "<td>"
          				PRINT "<table width='600' align='center' style='font-family: Tahoma, arial, sans-serif; font-size: 18px;color: #FFFFFF; line-height:22px; background-color:#FF4500; text-align: left; padding: 0px'>"
	          				PRINT "<tr>"
	          					PRINT "<td align='right'><strong>Número Chamado:</strong></td>"
	          					PRINT "<td align='left'>", lr_chamado.num_chamado CLIPPED,"</td>"
	          				PRINT "</tr>"
	          				PRINT "<tr>"
	          					PRINT "<td align='right'><strong>Atendente:</strong></td>"
	          					PRINT "<td align='left'>", lr_chamado.nom_atendente,"</td>"
	          				PRINT "</tr>"
	          				PRINT "<tr>"
	          					PRINT "<td align='right'><strong>Telefone:</strong></td>"
	          					PRINT "<td align='left'>", lr_chamado.tel_atendente,"</td>"
	          				PRINT "</tr>"
	          				PRINT "<tr>"
	          					PRINT "<td align='right'><strong>E-mail:</strong></td>"
	          					PRINT "<td align='left'>", lr_chamado.email_atendente,"</td>"
	          				PRINT "</tr>"
	          				PRINT "<tr>"
	          					PRINT "<td align='right'><strong>Data Abertura:</strong></td>"
	          					PRINT "<td align='left'>", lr_chamado.dat_abert,"</td>"
	          				PRINT "</tr>"
	          				PRINT "<tr>"
	          					PRINT "<td align='right'><strong>Data Encerram:</strong></td>"
	          					PRINT "<td align='left'>", lr_chamado.dat_encerr,"</td>"
	          				PRINT "</tr>"
          				PRINT "</table>"
				    		PRINT "</td>"
              PRINT "</tr>"
				    
		        	PRINT "<tr>"
		        		PRINT "<td height=10 valign=top>"
		        			PRINT "<table width='600' border=1 bordercolor='#afafaf'>"
		        				PRINT "<tr align='left' bgcolor='#FF4500'>"
			        				PRINT "<td style='font-size: 20px; color: #FFFFFF'>Setor Responsável</td>"
			        				PRINT "<td style='font-size: 20px; color: #FFFFFF'>Processo</td>"
			        				PRINT "<td style='font-size: 20px; color: #FFFFFF'>Resumo</td>"
			        				PRINT "<td style='font-size: 20px; color: #FFFFFF'>Atendente</td>"
			        				PRINT "<td style='font-size: 20px; color: #FFFFFF'>Status</td>"
		        			  PRINT "</tr>"
		        			  PRINT "<tr align='left'>"
			        				PRINT "<td align='left'> ",lr_chamado.area," </td>"
			        				PRINT "<td align='left'> ",lr_chamado.problema," </td>"
			        				PRINT "<td> ",lr_chamado.defeito," </td>"
			        				PRINT "<td> ",lr_chamado.nom_atendente," </td>"  
							        CASE 
							        	WHEN lr_chamado.status = 'A'
							        		LET l_status = "ABERTO"
							        	WHEN lr_chamado.status = 'P'
							        		LET l_status = "PENDENTE"
							        	WHEN lr_chamado.status = 'E'
							        		LET l_status = "ENCERRADO"
							        END CASE
							        PRINT "<td> ",l_status CLIPPED," </td>"
						      	PRINT "</tr>"
						    	PRINT "</table>"
						  	PRINT "</td>"
							PRINT "</tr>"
						
							PRINT "<tr>"
								PRINT "<td height=10 valign=top>"
									PRINT "<table width='600' border=1 bordercolor='#afafaf'>"
										PRINT "<tr align='center' bgcolor='#FF4500'>"
											PRINT "<td style='font-size: 20px; color: #FFFFFF'>Descrição</td>"
										PRINT "</tr>"
										WHENEVER ERROR CONTINUE
										DECLARE cq_sequencia CURSOR FOR 
										 SELECT DISTINCT sequencia
										   FROM texto_chamado_van
										  WHERE cod_empresa	= p_cod_empresa
										    AND num_chamado = lr_chamado.num_chamado
										  ORDER BY sequencia DESC
										WHENEVER ERROR STOP
										IF SQLCA.SQLCODE <> 0 THEN
										END IF
										      
										WHENEVER ERROR CONTINUE
										FOREACH cq_sequencia INTO l_sequencia
										WHENEVER ERROR STOP
											PRINT "<tr align='left'>"
												PRINT "<td>"
													WHENEVER ERROR CONTINUE
													DECLARE cq_descricao CURSOR FOR
													SELECT descr_def
													  FROM texto_chamado_van
													 WHERE cod_empresa = p_cod_empresa
										         AND num_chamado = lr_chamado.num_chamado
										         AND sequencia   = l_sequencia
										       ORDER BY seq_txt
										      WHENEVER ERROR STOP
										      
										      WHENEVER ERROR CONTINUE
										      FOREACH cq_descricao INTO l_descr_def
										      WHENEVER ERROR STOP
											      IF l_descr_def IS NOT NULL AND l_descr_def <> " " THEN
											      	PRINT l_descr_def, "<BR>"
											      END IF
										      END FOREACH
										      PRINT "</td>"
							  				PRINT "</tr>"
							  		FREE cq_descricao
							  	END FOREACH
							  	PRINT "</table>"
							  PRINT "</td>"
							PRINT "</tr>"
					
							ON LAST ROW
								PRINT "<tr>"
									PRINT "<td height=10 valign=top>"
										PRINT "<table width='600' border=1 bordercolor='#afafaf'>"
											PRINT "<tr align='left' bgcolor='#FF4500'>"
												PRINT "<td style='font-size: 16px; color: #FFFFFF'><BR>"
													PRINT "Dados do usuário solicitante.<BR><BR>"
												PRINT "</td>"
												PRINT "<td style='font-size: 14px; color: #FFFFFF'>"
													PRINT "Setor Solic: "    ,lr_chamado.setor,"<BR>"
													PRINT "Usuário: "   ,lr_chamado.nom_usuario,"<BR>"
													PRINT "Telefone: "    ,lr_chamado.tel_usuario,"<BR>"
													PRINT "Ramal: "   ,lr_chamado.ramal_usuario,"<BR>"
													PRINT "Fax: " , lr_chamado.fax_usuario,"<BR>"
													PRINT "E-mail: "  ,lr_chamado.email_usuario,"<BR>"
												PRINT "</td>"
											PRINT "</tr>"
										PRINT "</table>"
									PRINT "</td>"
								PRINT "</tr>"
							#fim do on last row
					  PRINT "</tbody>"
          PRINT "</table>"	        
				PRINT "</font>"

 END REPORT
 
#------------------------------#
 FUNCTION van9999_encerramento()
#------------------------------#
	
	DEFINE l_sequencia, l_seq_txt INTEGER,
	       descricao              CHAR(76),
	       l_erro	 	              INTEGER,
	       l_user                 LIKE usuarios.cod_usuario
	       
	INITIALIZE l_sequencia, l_seq_txt, l_user TO NULL
	
	IF log0040_confirm(15,44, "Deseja encerrar chamado?") THEN
		
		WHENEVER ERROR CONTINUE
		BEGIN WORK
		DELETE FROM texto_chamado_van
		 WHERE cod_empresa 	= mr_chamado.cod_empresa
		   AND num_chamado  = mr_chamado.num_chamado
		   AND descr_def IS NULL
		WHENEVER ERROR STOP
								
			IF SQLCA.SQLCODE = 0 THEN
				WHENEVER ERROR CONTINUE
					SELECT max(sequencia)	INTO l_sequencia
					  FROM texto_chamado_van
					 WHERE cod_empresa	= mr_chamado.cod_empresa
					   AND num_chamado  = mr_chamado.num_chamado
				WHENEVER ERROR STOP
					
					IF SQLCA.SQLCODE = 0 THEN
						IF l_sequencia IS NULL THEN
							LET l_sequencia = 1
						ELSE
							LET l_sequencia = l_sequencia + 1
						END IF
					ELSE
						CALL log003_err_sql("select", "texto_chamao_van")
						RETURN FALSE
 					END IF
 					
 					WHENEVER ERROR CONTINUE
 					SELECT MAX(seq_txt) INTO l_seq_txt
 					  FROM texto_chamado_van
 					 WHERE cod_empresa	= mr_chamado.cod_empresa
 					   AND num_chamado  = mr_chamado.num_chamado
 					   AND sequencia    = l_sequencia
 					WHENEVER ERROR STOP
 					
 					IF SQLCA.SQLCODE = 0 THEN
 						IF l_seq_txt IS NULL THEN
 							LET l_seq_txt = 1
 						ELSE
 							LET l_seq_txt = l_seq_txt + 1
 						END IF
 					ELSE
 						CALL log003_err_sql("select", "texto_chamado_van")
 						RETURN FALSE
 				  END IF
 				  
 				  LET l_user = UPSHIFT(p_user)
 				  
 				  LET descricao = TODAY,
 				                  ' ',
 				                  TIME,
 				                  ' - ',
 				                  l_user CLIPPED,
 				                  ' - Encerrado pelo setor de ',
 				                  mr_chamado.area CLIPPED
				
				  IF SQLCA.SQLCODE = 0 THEN
				  	WHENEVER ERROR CONTINUE
				  	LET m_dat_inc = CURRENT
				  	INSERT INTO texto_chamado_van (cod_empresa,
				  	                               num_chamado,
				  	                               dat_inc,
				  	                               sequencia,
				  	                               seq_txt,
				  	                               descr_def)
				  	                               VALUES (p_cod_empresa,
				  	                                       mr_chamado.num_chamado,
				  	                                       m_dat_inc,
				  	                                       l_sequencia,
				  	                                       l_seq_txt,
				  	                                       descricao)
				  	WHENEVER ERROR STOP
				  	IF SQLCA.SQLCODE <> 0 THEN
				  		ERROR "Erro na inclusão."
				  		LET l_erro = TRUE
						END IF
						
						IF NOT van99_update_atendente("ENCER") THEN
							LET l_erro = TRUE
						END IF
						
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
								ERROR "Chamado encerrado com sucesso."
								CALL van99_envia_email_usuarios()
							END IF
						END IF
					ELSE
						ERROR "Erro na exclusão."
						WHENEVER ERROR CONTINUE
						ROLLBACK WORK
						WHENEVER ERROR STOP
					END IF
				END IF
	END IF
	
	CALL van99_atualiza_dados()
	CALL van99_consulta_descr()

 END FUNCTION 
 
#------------------------------#
 FUNCTION van9999_cancelar()
#------------------------------#
	
	DEFINE l_sequencia, l_seq_txt INTEGER,
	       descricao              CHAR(76),
	       l_erro	 	              INTEGER,
	       l_user                 LIKE usuarios.cod_usuario
	       
	INITIALIZE l_sequencia, l_seq_txt, l_user TO NULL
	
	IF log0040_confirm(15,44, "Ao cancelar o chamado, você estará abrindo mão de uma solução e o mesmo não poderá ser reaberto. Tem certeza que deseja cancelar?") THEN
		
		WHENEVER ERROR CONTINUE
		BEGIN WORK
		DELETE FROM texto_chamado_van
		 WHERE cod_empresa 	= mr_chamado.cod_empresa
		   AND num_chamado  = mr_chamado.num_chamado
		   AND descr_def IS NULL
		WHENEVER ERROR STOP
								
			IF SQLCA.SQLCODE = 0 THEN
				WHENEVER ERROR CONTINUE
					SELECT max(sequencia)	INTO l_sequencia
					  FROM texto_chamado_van
					 WHERE cod_empresa	= mr_chamado.cod_empresa
					   AND num_chamado  = mr_chamado.num_chamado
				WHENEVER ERROR STOP
					
					IF SQLCA.SQLCODE = 0 THEN
						IF l_sequencia IS NULL THEN
							LET l_sequencia = 1
						ELSE
							LET l_sequencia = l_sequencia + 1
						END IF
					ELSE
						CALL log003_err_sql("select", "texto_chamao_van")
						RETURN FALSE
 					END IF
 					
 					WHENEVER ERROR CONTINUE
 					SELECT MAX(seq_txt) INTO l_seq_txt
 					  FROM texto_chamado_van
 					 WHERE cod_empresa	= mr_chamado.cod_empresa
 					   AND num_chamado  = mr_chamado.num_chamado
 					   AND sequencia    = l_sequencia
 					WHENEVER ERROR STOP
 					
 					IF SQLCA.SQLCODE = 0 THEN
 						IF l_seq_txt IS NULL THEN
 							LET l_seq_txt = 1
 						ELSE
 							LET l_seq_txt = l_seq_txt + 1
 						END IF
 					ELSE
 						CALL log003_err_sql("select", "texto_chamado_van")
 						RETURN FALSE
 				  END IF
 				  
 				  LET l_user = UPSHIFT(p_user)
 				  
 				  LET descricao = TODAY,
 				                  ' ',
 				                  TIME,
 				                  ' - ',
 				                  l_user CLIPPED,
 				                  ' - Chamado cancelado no ',
 				                  mr_chamado.area CLIPPED
				
				  IF SQLCA.SQLCODE = 0 THEN
				  	WHENEVER ERROR CONTINUE
				  	LET m_dat_inc = CURRENT
				  	INSERT INTO texto_chamado_van (cod_empresa,
				  	                               num_chamado,
				  	                               dat_inc,
				  	                               sequencia,
				  	                               seq_txt,
				  	                               descr_def)
				  	                               VALUES (p_cod_empresa,
				  	                                       mr_chamado.num_chamado,
				  	                                       m_dat_inc,
				  	                                       l_sequencia,
				  	                                       l_seq_txt,
				  	                                       descricao)
				  	WHENEVER ERROR STOP
				  	IF SQLCA.SQLCODE <> 0 THEN
				  		ERROR "Erro na inclusão."
				  		LET l_erro = TRUE
						END IF
						
						IF NOT van99_update_atendente("CANC") THEN
							LET l_erro = TRUE
						END IF
						
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
								ERROR "Chamado cancelado com sucesso."
								CALL van99_envia_email_usuarios()
							END IF
						END IF
					ELSE
						ERROR "Erro na exclusão."
						WHENEVER ERROR CONTINUE
						ROLLBACK WORK
						WHENEVER ERROR STOP
					END IF
				END IF
	END IF
	
	CALL van99_atualiza_dados()
	CALL van99_consulta_descr()

 END FUNCTION 
 
 #------------------------------#
 FUNCTION van9999_transferir()
#------------------------------#
	
	DEFINE l_sequencia, l_seq_txt INTEGER,
	       descricao              CHAR(76),
	       l_erro	 	              INTEGER,
	       l_user                 LIKE usuarios.cod_usuario
	       
	INITIALIZE l_sequencia, l_seq_txt, l_user TO NULL
	
	IF log0040_confirm(15,44, "Tem certeza que deseja transferir o chamado para outro setor?") THEN
		
		LET mr_chamador = mr_chamado.*
		
		INITIALIZE mr_chamado.area, mr_chamado.problema TO NULL
		
		IF van99_entrada_dados('TR') THEN
			
		
			WHENEVER ERROR CONTINUE
			BEGIN WORK
			DELETE FROM texto_chamado_van
			 WHERE cod_empresa 	= mr_chamador.cod_empresa
			   AND num_chamado  = mr_chamador.num_chamado
			   AND descr_def IS NULL
			WHENEVER ERROR STOP
									
				IF SQLCA.SQLCODE = 0 THEN
					WHENEVER ERROR CONTINUE
						SELECT max(sequencia)	INTO l_sequencia
						  FROM texto_chamado_van
						 WHERE cod_empresa	= mr_chamador.cod_empresa
						   AND num_chamado  = mr_chamador.num_chamado
					WHENEVER ERROR STOP
						
						IF SQLCA.SQLCODE = 0 THEN
							IF l_sequencia IS NULL THEN
								LET l_sequencia = 1
							ELSE
								LET l_sequencia = l_sequencia + 1
							END IF
						ELSE
							CALL log003_err_sql("select", "texto_chamao_van")
							RETURN FALSE
	 					END IF
	 					
	 					WHENEVER ERROR CONTINUE
	 					SELECT MAX(seq_txt) INTO l_seq_txt
	 					  FROM texto_chamado_van
	 					 WHERE cod_empresa	= mr_chamador.cod_empresa
	 					   AND num_chamado  = mr_chamador.num_chamado
	 					   AND sequencia    = l_sequencia
	 					WHENEVER ERROR STOP
	 					
	 					IF SQLCA.SQLCODE = 0 THEN
	 						IF l_seq_txt IS NULL THEN
	 							LET l_seq_txt = 1
	 						ELSE
	 							LET l_seq_txt = l_seq_txt + 1
	 						END IF
	 					ELSE
	 						CALL log003_err_sql("select", "texto_chamado_van")
	 						RETURN FALSE
	 				  END IF
	 				  
	 				  LET l_user = UPSHIFT(p_user)
	 				  
	 				  LET descricao = TODAY,
	 				                  ' ',
	 				                  TIME,
	 				                  ' - ',
	 				                  l_user CLIPPED,
	 				                  ' - transferido para setor ',
	 				                  mr_chamado.area CLIPPED
					
					  IF SQLCA.SQLCODE = 0 THEN
					  	WHENEVER ERROR CONTINUE
					  	LET m_dat_inc = CURRENT
					  	INSERT INTO texto_chamado_van (cod_empresa,
					  	                               num_chamado,
					  	                               dat_inc,
					  	                               sequencia,
					  	                               seq_txt,
					  	                               descr_def)
					  	                               VALUES (p_cod_empresa,
					  	                                       mr_chamador.num_chamado,
					  	                                       m_dat_inc,
					  	                                       l_sequencia,
					  	                                       l_seq_txt,
					  	                                       descricao)
					  	WHENEVER ERROR STOP
					  	IF SQLCA.SQLCODE <> 0 THEN
					  		ERROR "Erro na inclusão."
					  		LET l_erro = TRUE
							END IF
							
							IF NOT van99_update_atendente("TRANS") THEN
								LET l_erro = TRUE
							END IF
							
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
									ERROR "Chamado transferido com sucesso."
									CALL van99_envia_email_usuarios()
								END IF
							END IF
						ELSE
							ERROR "Erro na exclusão."
							WHENEVER ERROR CONTINUE
							ROLLBACK WORK
							WHENEVER ERROR STOP
						END IF
					END IF
		END IF
	END IF
	
	CALL van99_atualiza_dados()
	CALL van99_consulta_descr()

 END FUNCTION 
 
#-----------------------------#
 FUNCTION van99_atualiza_dados()
#-----------------------------#
 
  DEFINE l_dat_encerr   DATETIME YEAR TO MINUTE,
         l_hora_encer   CHAR(05)
         
  WHENEVER ERROR CONTINUE
  SELECT * INTO mr_chamado.*
    FROM chamado_van
   WHERE cod_empresa	= mr_chamado.cod_empresa
     AND num_chamado  = mr_chamado.num_chamado
  WHENEVER ERROR STOP
  
  IF SQLCA.SQLCODE = 0 THEN  	
  	CALL van99_exibe_dados() 	
  END IF
  
 END FUNCTION 
