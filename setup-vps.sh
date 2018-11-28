#!/bin/bash

# Outputs install log line
function setup_log() {
    echo -e "\033[1;32m$*\033[m"
}

function setup_alert() {
    echo -e "\e[31m$*\e[m"
}

sleep 1

# necessário ser root
if [ "$(id -u)" != "0" ]; then
   echo "Desculpe! Este script deve ser executado como root." 1>&2
   exit 1
fi

# prompt
setup_log "Este script executará as configurações iniciais neste servidor."
read -r -p "Digite 'S' para continuar ou qualquer tecla para cancelar: " GO
if [ "$GO" != "S" ]; then
    echo "Aborting." 1>&2
    exit 1
fi

# define timezone
setup_log "Atualizando pacotes e definindo o fuso horário..."
apt-get update
apt-get dist-upgrade
apt-get autoremove
dpkg-reconfigure tzdata

# define senha root
setup_log "Definindo a senha do root..."
passwd

# cria chave SSH do root caso não exista
if [ ! -e /root/.ssh/id_rsa ]; then
   setup_log "Criando chaves SSH..."
   ssh-keygen -t rsa
fi

# criar arquivo known_hosts caso não exista
if [ ! -e /root/.ssh/known_hosts ]; then
   setup_log "Criando arquivo known_hosts..."
   touch /root/.ssh/known_hosts
fi

# criar arquivo authorized_keys caso não exista
if [ ! -e /root/.ssh/authorized_keys ]; then
	setup_log "Criando arquivo authorized_keys..."
	touch /root/.ssh/authorized_keys
fi


# adiciona bitbucket.org, gitlab.com, github.com
setup_log "Adicionando bitbucket.org, gitlab.com e github.com aos hosts confiáveis..."
ssh-keyscan bitbucket.org >> /root/.ssh/known_hosts
ssh-keyscan gitlab.com >> /root/.ssh/known_hosts
ssh-keyscan github.com >> /root/.ssh/known_hosts


# pedir nome de usuário do novo usuário padrão
read -r -p "Insira um username para o usuário que fará deploy de aplicações (Ex.: deployer):" DEPLOYER_USERNAME
if [ -z "$DEPLOYER_USERNAME" ]; then
    echo "Nenhum nome de usuário inserido, abortando." 1>&2
    exit 1
fi

# pedir nome de "vendor" que será utilizado como prefixo nas pastas de apps, storage e backups. Ex.: nome de um organização como google ou codions
read -r -p "Insira um nome de pasta padrão onde ficarão os apps, storage e backups (Ex.: suaempresa): " VENDOR_NAME
if [ -z "$VENDOR_NAME" ]; then
    echo "Nenhum nome de pasta padrão inserido, abortando." 1>&2
    exit 1
fi

# adiciona usuário padrão
setup_log "Criando usuário padrão..."
useradd -s /bin/bash -d /home/$DEPLOYER_USERNAME -m -U $DEPLOYER_USERNAME
passwd $DEPLOYER_USERNAME

# copia SSH authorized_keys
setup_log "Copiando a chave pública SSH para diretório home do novo usuário padrão..."
if [ ! -d /home/$DEPLOYER_USERNAME/.ssh ]; then
	mkdir /home/$DEPLOYER_USERNAME/.ssh
fi
cp -r /root/.ssh/* /home/$DEPLOYER_USERNAME/.ssh/
chown -R $DEPLOYER_USERNAME.$DEPLOYER_USERNAME /home/$DEPLOYER_USERNAME/.ssh

# adiciona usuário padrão aos sudoers
setup_log "Adicionando $DEPLOYER_USERNAME aos sudoers com todos os privilégios..."
echo "$DEPLOYER_USERNAME ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/$DEPLOYER_USERNAME
chmod 0440 /etc/sudoers.d/$DEPLOYER_USERNAME

# instala git, zip, unzip
setup_log "Instalando programas essenciais (git, zip, unzip, curl)..."
apt-get install -y git zip unzip curl wget

setup_log "Instalando docker..."
curl -fsSL get.docker.com -o get-docker.sh && sh get-docker.sh

setup_log "Instalando docker-compose..."
curl -L "https://github.com/docker/compose/releases/download/1.23.1/docker-compose-Linux-x86_64" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

setup_log "Adicionando usuário padrão no grupo www-data..."
usermod -aG www-data $DEPLOYER_USERNAME

setup_log "Adicionando usuário padrão no grupo docker..."
usermod -aG docker $DEPLOYER_USERNAME

setup_log "Criando diretório de trabalho para os containers (aplicações)..."
mkdir -p /var/$VENDOR_NAME/apps

setup_log "Criando diretório de trabalho para os volumes (storage) dos containers..."
mkdir -p /var/$VENDOR_NAME/storage

setup_log "Criando diretório de trabalho para os backups..."
mkdir -p /var/$VENDOR_NAME/backups

setup_log "Mudando proprietário do diretório de trabalho de root para $DEPLOYER_USERNAME..."
chown -R $DEPLOYER_USERNAME.$DEPLOYER_USERNAME /var/$VENDOR_NAME

# cleanup
setup_log "Limpando..."
apt-get autoremove
apt-get clean

# concluído
setup_log "Concluído! Por favor, reinicie o servidor para aplicar algumas mudanças."
setup_alert "Importante: Adicione a chave id_rsa.pub do usuário $DEPLOYER_USERNAME no seu servidor VCS (bitbucket, gitlab, github, etc) para conseguir fazer deploy de aplicações com git."
