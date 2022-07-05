CREATE TABLE login_van ( 
    USUARIO     	CHAR(08) NOT NULL,
    SENHA       	CHAR(08) NOT NULL,
    constraint pk_login_van primary key(usuario,senha) 
    )
