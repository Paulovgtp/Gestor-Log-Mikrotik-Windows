# Gestor-Log-Mikrotik-Windows
Ferramenta para capturar logs de conexões em uma rede provida por um mikrotik (versão Windows).

Esta versao do gestor log utiliza o xampp como servidor web, dentro da pasta do xampp possui um execultavel com nome de xampp-control.exe, este programa tem a finalidade de facilitar o start dos serviços, ao clicar neste execultavel sera possivel fazer o start do apache e do mysql, apos estes serviços estar rodando sera possivel abrir em seu navegador o Gestor Log Mikrotik, em seu navegador digite localhost ou ip da maquina que esta o xampp rodando.

Na primeira tela sera solicitado login e senha que neste caso é admin e senha admin, apos efeturar login a primeira coisa a ser feita é clicar em processar log, ao clicar em processar log o programa MT_Syslog.exe sera execultado, este programa tem a finalidade de recolher os log, nesta tela devera ser apresentada os logs que são recebidos em tempo real.

Apos estas etapas basta configurar o mikrotik para enviar os logs para o servidor de log.
