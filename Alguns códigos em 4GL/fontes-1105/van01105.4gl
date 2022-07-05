database logix

#-----------------------------------------------------------------#
# SISTEMA.: ASSISTENCIA TECNICA E PEÇAS VANTEC                    #
# PROGRAMA: VAN1105                                               #
# OBJETIVO: APONTAMENTO DAS HORAS TECNICA PRESTADAS AOS CLIENTES  #
# AUTOR...: JOÃO PAULO                                            #
# DATA....: 11/05/2011                                            #
#-----------------------------------------------------------------#  
                 
globals
	DEFINE  p_cod_empresa          LIKE empresa.cod_empresa,
  	      	p_den_empresa	       LIKE empresa.den_empresa,
         	p_user                 LIKE usuario.nom_usuario,
         	p_den_cidade           LIKE cidades.den_cidade,
         	p_cod_uni_feder        LIKE cidades.cod_uni_feder,
         	p_cod_pais             LIKE uni_feder.cod_pais,
         	p_den_pais             LIKE paises.den_pais,
         	p_num_cgc_cpf          CHAR(19),
         	p_cgc_aux              CHAR(11),
         	p_status               SMALLINT,
         	p_houve_erro           SMALLINT,
         	p_ies_cons             SMALLINT,
         	p_pula_campo           SMALLINT,
         	p_ies_sit_cli          CHAR(01),
         	mesg                   CHAR(90),
         	g_tipo_sgbd            CHAR(03),
         	ies_email		       SMALLINT,
         	m_cidade		       CHAR(30),
         	ies_relatorio	       SMALLINT, 
         	
 	DEFINE  p_versao  		CHAR(18),
 			m_hora          CHAR(08)
 			
 	define 	p_comando       CHAR(80),
         	p_caminho       CHAR(80),
         	p_nom_tela      CHAR(80),
         	p_help          CHAR(80),
         	p_where			CHAR(100),
         	p_cancel        INTEGER,
         	g_ies_grafico   SMALLINT
	
	define mr_cdvr record like cdv_solic_viagem.*
		   
	define m_consulta_ativa smallint 
	
	define ma_array		array[3000] of record
                        dat_servico	date,
 						hr_ini_man 	char(5),
						hr_fin_man	char(5),
						hr_ini_tar	char(5),
						hr_fin_tar	char(5),
						hr_ini_ext	char(5),
						hr_fin_ext	char(5)
		                            end record 
                                   	
 	define mr_cdv record
		empresa         	like cdv_solic_viagem.empresa,
		num_viagem      	like cdv_solic_viagem.num_viagem,
		matricula_viajante	like cdv_solic_viagem.matricula_viajante,
		cliente_destino     like cdv_solic_viagem.cliente_destino,
		veiculo           	like apo_hr_tec_van.veiculo,
		placa				like apo_hr_tec_van.placa,
		km_saida			like apo_hr_tec_van.km_saida,
		km_chegada			like apo_hr_tec_van.km_chegada,
		auxiliar			like apo_hr_tec_van.auxiliar,
		dat_servico			like apo_hr_tec_van.dat_servico,
		hr_ini_man			like apo_hr_tec_van.hr_ini_man,
		hr_fin_man			like apo_hr_tec_van.hr_fin_man,
		hr_ini_tar			like apo_hr_tec_van.hr_ini_tar,
		hr_fin_tar			like apo_hr_tec_van.hr_fin_tar,
		hr_ini_ext			like apo_hr_tec_van.hr_ini_ext,
		hr_fin_ext			like apo_hr_tec_van.hr_fin_ext
	end record
	
			
end globals
                                                                                                                 
main

	CALL log0180_conecta_usuario()

  	LET p_versao = "VAN1105-10.01.03"
  	WHENEVER ANY ERROR CONTINUE
		 CALL log1400_isolation()
  	WHENEVER ERROR STOP
  	DEFER INTERRUPT

	 CALL log140_procura_caminho("VAN1105.iem") RETURNING p_caminho
  	LET p_help = p_caminho CLIPPED
  	OPTIONS
    	HELP FILE p_help

  CALL log001_acessa_usuario("VAN","logerp;loggco;loglq2")
       RETURNING p_status, p_cod_empresa, p_user
  IF p_status = 0  THEN
    CALL controle()
  END IF
	
end main

#------------------#

function controle()

	CALL log140_procura_caminho("VAN1105") returning p_nom_tela
  	open window w_van1105 at 2,02 with form p_nom_tela
   	attribute(border, message line last, prompt line last)
 	call log006_exibe_teclas("02 07", p_versao)
	clear form
  	current window is w_van1105
	let m_consulta_ativa = false
	
	menu "opcao"
		
		command key ("C") "Consultar" "Consultar Texto dos Itens por Pedidos."
			MESSAGE ""
      		IF log005_seguranca(p_user,"VAN","VAN1105","CO")  THEN
         		CALL consultar()
      		END IF
	
	    command key ("S") "Seguinte" "Exibe o registro seguinte."
	    	if m_consulta_ativa = true then
	    		call paginacao("seguinte")
	    	else
	    		error "Não existe nenhuma consulta ativa."
	    	end if
	    
	    command key ("A") "Anterior" "Exibe o registro anterior."
			if m_consulta_ativa = true then
	    		call paginacao("anterior")
	    	else
	    		error "Não existe nenhuma consulta ativa."
	    	end if	    	
		
		command key("L") "Listar" "Relatorio de livros cadastrados."
			call listar()
			
		command key("P") "aPontar" "Apontamento Horas Trabalhadas."
			if m_consulta_ativa = true then
				call aponta()
	    	else
	    		error "Não existe nenhuma consulta ativa."
	    		next option "Consultar"
	    	end if
		
		command key("F") "Fim" "Sai do programa."
				exit menu
	end menu
end function 

#-----------------------------------#
 function verifica_viajante()
#-----------------------------------#

	define l_nome_viajante like fornecedor.raz_social

	whenever error continue
		select a.raz_social
			into l_nome_viajante
		from fornecedor a, cdv_fornecedor_fun b
		where 	a.cod_fornecedor	= b.cod_fornecedor
		and		b.cod_funcio        = mr_cdv.matricula_viajante
	whenever error stop
	
	if sqlca.sqlcode <> 0 then  
		if sqlca.sqlcode = notfound then  #notfound igual ao codigo 100
			error "Viajante não cadastrado."
		else
			error "Erro ao selecionar Viajante."
		end if
		
		return false
	else
		display l_nome_viajante to viajante
	end if
	
	return true
	
end function

#-----------------------------------------#
 function busca_nome_viajante()
#-----------------------------------------#

	define l_nome_viajante like fornecedor.raz_social
	
	initialize l_nome_viajante to null
	
	whenever error continue
		select a.raz_social
			into l_nome_viajante
		from fornecedor a, cdv_fornecedor_fun b
		where 	a.cod_fornecedor	= b.cod_fornecedor
		and		b.cod_funcio        = mr_cdv.matricula_viajante
	whenever error stop
	
	if sqlca.sqlcode = 0 then
		display l_nome_viajante to viajante
	end if
end function

#-----------------------------------#
 function verifica_cliente()
#-----------------------------------#

	define l_nome_cliente like clientes.nom_cliente

	whenever error continue
		select nom_cliente
		into l_nome_cliente
		from clientes
		where cod_cliente = mr_cdv.cliente_destino
	whenever error stop
	
	if sqlca.sqlcode <> 0 then  
		if sqlca.sqlcode = notfound then  #notfound igual ao codigo 100
			error "Cliente não cadastrado."
		else
			error "Erro ao selecionar cliente."
		end if
		
		return false
	else
		display l_nome_cliente to cliente
	end if
	
	return true
	
end function

#-----------------------------------------#
 function busca_nome_cliente()
#-----------------------------------------#

	define l_nome_cliente like clientes.nom_cliente
	
	initialize l_nome_cliente to null
	
	whenever error continue
		select nom_cliente
		into l_nome_cliente
		from clientes
		where cod_cliente = mr_cdv.cliente_destino
	whenever error stop
	
	if sqlca.sqlcode = 0 then
		display l_nome_cliente to cliente
	end if
end function		  

#-----------------------------------------#
 function consultar()                                                     
#-----------------------------------------# 
	define where_clause char(1000),
			l_sql_stmt	char(5000),
			l_msg       char(200)
			
	initialize mr_cdv.* to null
	
	clear form
	
	let int_flag = 0
	
	construct where_clause on
							a.empresa, 
							a.num_viagem,
							a.matricula_viajante,
							a.cliente_destino
							from 
								empresa, 
								num_viagem,
								matricula_viajante,
								cliente_destino	
   	    
   		after field cliente_destino
   		
   		on key (control-z)
 		call popup_cli()	
	end construct
 	
	if int_flag <> 0 then
		let int_flag = 0
		clear form
		return false
	end if

		let l_sql_stmt = " select a.empresa,a.num_viagem,a.matricula_viajante,a.cliente_destino, ",
					 	 " substr(a.observacao, 0, 50), substr(a.observacao, 51, 100), substr(a.observacao, 101, 150), '', substr(a.observacao, 151, 200) ",
					 	 " from cdv_solic_viagem a ",
					 	 " where ", where_clause CLIPPED,
					 	 " order by a.empresa, a.num_viagem  "
	

			prepare var_query from l_sql_stmt
			declare cq_consulta scroll cursor with hold for var_query
	
			whenever error continue
			open cq_consulta
			fetch cq_consulta into mr_cdv.*
			whenever error stop

			if sqlca.sqlcode <> 0 then
				if sqlca.sqlcode = 100 then
					call fgl_winmessage("Consulta Solicitação de Viagem", "Argumentos de pesquisa não encontrados.", "info") #"excl", "stop"
				else
            		let l_msg = "Erro ao selecionar dados da tabela cdv_solic_viagem - ", sqlca.sqlcode 
					call fgl_winmessage("Consulta Solicitação de Viagem", l_msg, "stop")
				end if
		
				return false
			end if
	    
	
	call exibe_dados()
	call consulta_aponta()
	
	let m_consulta_ativa = true
	return true
	
end function

#---------------------------------#
 function consulta_aponta()
#---------------------------------# 
    define 	l_msg	char(200),
    		l_ind 	integer 
    		
    for l_ind = 1 to 10
    	initialize ma_array[l_ind].* to null
    end for

    
	declare cq_consulta_ap cursor for
	select empresa, num_viagem, matricula_viajante, cliente_destino,
		   veiculo, placa, km_saida, km_chegada, auxiliar
	from apo_hr_tec_van
	where 	empresa		= mr_cdv.empresa
	and		num_viagem	= mr_cdv.num_viagem
	
	whenever error continue
	open cq_consulta_ap
	fetch cq_consulta_ap into mr_cdv.*
	whenever error stop
	
	#if sqlca.sqlcode = 0 then
		call exibe_dados()
		call chama_aponta()
		let m_consulta_ativa = true
	return true
    #end if
end function
#---------------------------------#
 function exibe_dados()
#---------------------------------#

	display mr_cdv.empresa				to empresa	
	display mr_cdv.num_viagem			to num_viagem
	display mr_cdv.matricula_viajante	to matricula_viajante
	display mr_cdv.cliente_destino		to cliente_destino
	display mr_cdv.veiculo				to veiculo
	display mr_cdv.placa				to placa
	display mr_cdv.km_saida				to km_saida
	display mr_cdv.km_chegada			to km_chegada
	display mr_cdv.auxiliar				to auxiliar

	call busca_nome_viajante()
	call busca_nome_cliente()
					
end function

#---------------------------------#
 function chama_aponta()
#---------------------------------#
	define	l_msg	char(200),
			p_ind 	smallint,
			m_count smallint,
			l_ind 	integer
	
	for p_ind = 1 to 100
    	initialize ma_array[p_ind].* to null
    	if p_ind <= 5 then
       		display ma_array[p_ind].* to sr_array[p_ind].* 
    	end if
	end for

	whenever error continue
  		declare cq_array2 cursor for
   		select 	dat_servico, 
				hr_ini_man, 
				hr_fin_man, 
				hr_ini_tar, 
				hr_fin_tar, 
				hr_ini_ext, 
				hr_fin_ext  
     	from apo_hr_tec_van
    	where 	empresa 	= mr_cdv.empresa
    	and 	num_viagem	= mr_cdv.num_viagem
    	order by empresa, num_viagem, sequencia
	whenever error stop

	
	let m_count = 1
    
	foreach cq_array2 into 	ma_array [m_count].dat_servico, 
   						  	ma_array [m_count].hr_ini_man, 
							ma_array [m_count].hr_fin_man, 
							ma_array [m_count].hr_ini_tar, 
							ma_array [m_count].hr_fin_tar, 
							ma_array [m_count].hr_ini_ext, 
							ma_array [m_count].hr_fin_ext 
	
       	let m_count = m_count + 1
   	end foreach
   
   	let m_count = m_count - 1

   	call set_count(m_count)

   	if m_count <= 5 then
   		for l_ind = 1 to m_count
     		display ma_array [l_ind].* to sr_array[l_ind].*
     	end for
   	else
     	display array ma_array to sr_array.*
   	end if 
   	
end function

#--------------------------------------#
 function paginacao(lr_funcao)
#--------------------------------------#

	define lr_funcao char(20)
	
	while true
		case
			when lr_funcao = "seguinte"
				fetch next cq_consulta into	mr_cdv.empresa,
	  										mr_cdv.num_viagem,
	  										mr_cdv.matricula_viajante,
											mr_cdv.cliente_destino,
											mr_cdv.veiculo,
											mr_cdv.placa,
											mr_cdv.km_saida,
											mr_cdv.km_chegada,
											mr_cdv.auxiliar
	  										
	  										
	  										
	  		when lr_funcao = "anterior"
	  		fetch previous cq_consulta into	mr_cdv.empresa,
	  										mr_cdv.num_viagem,
	  										mr_cdv.matricula_viajante,
											mr_cdv.cliente_destino,
											mr_cdv.veiculo,
											mr_cdv.placa,
											mr_cdv.km_saida,
											mr_cdv.km_chegada,
											mr_cdv.auxiliar
	  									
	  										
	  	end case
	  	
	  	if sqlca.sqlcode = notfound then
	  		error "Não existem mais viagens nesta direção."
			exit while
		end if
		
		whenever error continue
			select a.empresa, a.num_viagem, a.matricula_viajante, a.cliente_destino, 
				   substr(a.observacao, 0, 50), substr(a.observacao, 51, 100), substr(a.observacao, 101, 150), '', substr(a.observacao, 151, 200) 
			from cdv_solic_viagem a
		    where	a.empresa 		= mr_cdv.empresa
		    and 	a.num_viagem	= mr_cdv.num_viagem
		whenever error stop
		
		if sqlca.sqlcode <> 0 then
			clear form
			call fgl_winmessage("Consulta Viagem", "Argumentos de pesquisa não encontrados.", "info")
			exit while
		else
			call exibe_dados()
			call consulta_aponta()
			exit while
		end if
	end while
end function 

#---------------------------------#
 function popup_cli()
#---------------------------------#

	case
		when infield(cliente_destino)
			#let mr_livros.editora = zoom_editora()
			call zoom_clientes() returning mr_cdv.cliente_destino
			
			if mr_cdv.cliente_destino is not null and mr_cdv.cliente_destino <> " " then
				current window is w_van1105
				display by name  mr_cdv.cliente_destino
				call busca_nome_cliente()
			end if
	end case
end function

#--------------------------------#
 function zoom_clientes()
#--------------------------------#
    
	define where_clause	char(1000),
			l_sql_stmt	char(500),
			l_msg       char(200)
			
	define	l_ind smallint,
			l_linha_corrente integer
			
	define	la_cliente	array[10000]	of record
						cod_cliente		char(15),
						nom_cliente		char(50)
										end record
	
	open window w_popup_cli at 6,3 with form 'popup_cli'
		attributes (border, message line last, prompt line last)
		
	current window is w_popup_cli
	
	let int_flag = 0
	
	construct where_clause on clientes.cod_cliente, clientes.nom_cliente from cliente, nome_cliente
	
	if int_flag <> 0 then
		let int_flag = 0
		clear form
		return false
	end if
	
	let l_sql_stmt = "select cod_cliente, nom_cliente ", 
					 " from clientes",
					 " where ", where_clause clipped,
					 " order by cod_cliente"
					 
	prepare var_query from l_sql_stmt
	declare cq_popup scroll cursor with hold for var_query
	
	for l_ind = 1 to 10000   # mesmo que o de cima
		initialize la_cliente[l_ind].* to null
	end for
	
	let l_ind = 1
	
		#declare cq_popup cursor for
		#select cod_cliente, nom_cliente
		#from clientes
		#order by cod_cliente
		
	foreach cq_popup into la_cliente[l_ind].cod_cliente,
						  la_cliente[l_ind].nom_cliente
						  
		let l_ind = l_ind + 1
	end foreach
	
	if l_ind > 1 then
		let l_ind = l_ind -1
	else
		close window w_popup_cli
		return null
	end if
	
	let int_flag = 0
	
	call set_count(l_ind)
	display array la_cliente to sr_cliente.*
	
	let l_linha_corrente = arr_curr()
	
	if int_flag then
		close window w_popup_cli
		return null
	else
		close window w_popup_cli
		return la_cliente[l_linha_corrente].cod_cliente
	end if
	
end function

#----------------------------------#
 function cabecalho()
#----------------------------------#
	input 	mr_cdv.veiculo,
	  		mr_cdv.placa,
	  		mr_cdv.km_saida,
	  		mr_cdv.km_chegada,
	  		mr_cdv.auxiliar		 without defaults from 	veiculo,
														placa,	
                                                      	km_saida,
                                                      	km_chegada,
                                                      	auxiliar 
    
 end function
#----------------------------------#
 function aponta()
#----------------------------------#

	define l_idx_arr integer,
		   l_idx_scr integer,
		   l_erro	 integer,
		   la_aponta	array[100] 	of record 
		   			dat_servico	date,
 					hr_ini_man 	char(5),
					hr_fin_man	char(5),
					hr_ini_tar	char(5),
					hr_fin_tar	char(5),
					hr_ini_ext	char(5),
					hr_fin_ext	char(5)
      						   		end record
      						   
    initialize la_aponta to null		   
		   
		declare cq_aponta cursor for
		select	dat_servico, 
				hr_ini_man, 
				hr_fin_man, 
				hr_ini_tar, 
				hr_fin_tar, 
				hr_ini_ext, 
				hr_fin_ext  
     	from apo_hr_tec_van
    	where 	empresa 	= mr_cdv.empresa
    	and 	num_viagem	= mr_cdv.num_viagem
    	order by empresa, num_viagem, sequencia
	
	let l_idx_arr = 1
	
	foreach cq_aponta into	la_aponta[l_idx_arr].dat_servico, 
						  	la_aponta[l_idx_arr].hr_ini_man,
							la_aponta[l_idx_arr].hr_fin_man, 
							la_aponta[l_idx_arr].hr_ini_tar, 
							la_aponta[l_idx_arr].hr_fin_tar, 
							la_aponta[l_idx_arr].hr_ini_ext, 
							la_aponta[l_idx_arr].hr_fin_ext 
							
	let l_idx_arr = l_idx_arr + 1
				
	end foreach
	
	free cq_aponta
	
	let l_idx_arr = l_idx_arr - 1
	
	call set_count(l_idx_arr)
	let int_flag = 0
	
	call cabecalho()
	
	input array la_aponta without defaults from sr_array.*
	
		after input
			if int_flag = 0 then
				whenever error continue
				begin work
				delete from apo_hr_tec_van
					where 	empresa 	= mr_cdv.empresa
    				and 	num_viagem	= mr_cdv.num_viagem 
				whenever error stop
				
				if sqlca.sqlcode = 0 then
					let l_erro = false
					
					for l_idx_arr = 1 to arr_count()
						whenever error continue
						insert into apo_hr_tec_van
						values (mr_cdv.empresa, 
								mr_cdv.num_viagem, 
								l_idx_arr,
								mr_cdv.matricula_viajante,
								mr_cdv.cliente_destino,
								mr_cdv.veiculo,
								mr_cdv.placa,
								mr_cdv.km_saida,
								mr_cdv.km_chegada,
								mr_cdv.auxiliar, 
								la_aponta[l_idx_arr].dat_servico, 
						  		la_aponta[l_idx_arr].hr_ini_man,
								la_aponta[l_idx_arr].hr_fin_man, 
								la_aponta[l_idx_arr].hr_ini_tar, 
								la_aponta[l_idx_arr].hr_fin_tar, 
								la_aponta[l_idx_arr].hr_ini_ext, 
								la_aponta[l_idx_arr].hr_fin_ext)
						whenever error stop
						
						if sqlca.sqlcode <> 0 then
							error "Erro na inclusão."
							let l_erro = true
							exit for
						end if
					end for
					
					if l_erro = true then
						whenever error continue
						rollback work
						whenever error stop
					else
						whenever error continue
						commit work
						whenever error stop
						
						if sqlca.sqlcode <> 0 then
							error "Erro na efetivação."
						else
							error "Inclusão efetuada com sucesso."
						end if
					end if
				else
					error "Erro na exclusão."
					
					whenever error continue
					rollback work
					whenever error stop
				end if
			end if
		end input
end function

