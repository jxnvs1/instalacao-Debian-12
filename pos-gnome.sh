#!/usr/bin/env bash

# Verifica se está rodando como root
if [[ $EUID -ne 0 ]]; then
   echo "Este script precisa ser executado como root (use sudo)." 
   exit 1
fi

# Função para fazer backup e criar nova sources.list
configurar_sources_list() {
    echo "Fazendo backup da sources.list original..."
    if [[ -f /etc/apt/sources.list ]]; then
        mv /etc/apt/sources.list /etc/apt/sources.list.bkp
        echo "Backup feito com sucesso: /etc/apt/sources.list.bkp"
    else
        echo "Arquivo /etc/apt/sources.list não encontrado, prosseguindo sem backup."
    fi

    echo "Criando nova sources.list com os repositórios oficiais do Debian 12 'Bookworm'..."
    cat <<EOF > /etc/apt/sources.list
#############################################################################################################
#                                Repositórios Oficiais - Debian 12 "Bookworm"                               #
#############################################################################################################
## Para habilitar os repos de código fonte (deb-src) e Backports basta retirar a # da linha correspondente ##
#############################################################################################################

deb http://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware
# deb-src http://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware

deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
# deb-src http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware

deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
# deb-src http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware

## Debian Bookworm Backports
# deb http://deb.debian.org/debian bookworm-backports main contrib non-free non-free-firmware
# deb-src http://deb.debian.org/debian bookworm-backports main contrib non-free non-free-firmware

##############################################################################################################
EOF

    echo "Nova sources.list criada com sucesso."
    
     # Atualiza a lista de pacotes após criar a nova sources.list
    echo "Atualizando a lista de pacotes com os novos repositórios..."
    apt update
}

# Função para instalar pacotes via APT
instalar_pacotes() {
    echo "Instalando pacotes: $*"
    apt install -y "$@"
    if [[ $? -ne 0 ]]; then
        echo "Erro ao instalar pacotes: $*"
        exit 1
    fi
}

# Função para configurar Wine
instalar_wine() {
    dpkg --add-architecture i386
    mkdir -pm755 /etc/apt/keyrings
    wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key
    wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/debian/dists/bookworm/winehq-bookworm.sources
    apt update
    instalar_pacotes --install-recommends winehq-stable
}

# Função para configurar Lutris
instalar_lutris() {
    echo "Instalando Lutris..."
    echo "deb [signed-by=/etc/apt/keyrings/lutris.gpg] https://download.opensuse.org/repositories/home:/strycore/Debian_12/ ./" | tee /etc/apt/sources.list.d/lutris.list > /dev/null
    wget -q -O- https://download.opensuse.org/repositories/home:/strycore/Debian_12/Release.key | gpg --dearmor | tee /etc/apt/keyrings/lutris.gpg > /dev/null
    apt update
    instalar_pacotes lutris
}

# Função para baixar e instalar pacotes .deb
instalar_pacotes_deb() {
    cd /home/jonas/Downloads
    local pacotes_deb=(
        "https://files2.freedownloadmanager.org/6/latest/freedownloadmanager.deb"
        "https://cdn.akamai.steamstatic.com/client/installer/steam.deb"
        "https://github.com/fastfetch-cli/fastfetch/releases/download/2.23.0/fastfetch-linux-amd64.deb"
        "https://launchpad.net/veracrypt/trunk/1.26.14/+download/veracrypt-1.26.14-Debian-12-amd64.deb"
    )
    for pacote in "${pacotes_deb[@]}"; do
        wget "$pacote"
    done
    dpkg -i *.deb
    apt install -f -y

    # Limpar os pacotes .deb baixados
    rm -f *.deb
}

# Função para instalar o navegador Brave
instalar_brave() {
    echo "Instalando o navegador Brave..."
    
    # Instalar o curl se não estiver instalado
    instalar_pacotes curl

    # Baixar a chave GPG do Brave e adicionar ao keyring
    curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
    
    # Adicionar o repositório do Brave ao sources.list.d
    echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | tee /etc/apt/sources.list.d/brave-browser-release.list
    
    # Atualizar a lista de pacotes e instalar o Brave
    apt update
    instalar_pacotes brave-browser
}

# Função para limpar configurações de rede no /etc/network/interfaces
configurar_networkmanager() {
    echo "Limpando as configurações de rede do /etc/network/interfaces..."
    
    # Faz um backup do arquivo atual antes de modificar
    cp /etc/network/interfaces /etc/network/interfaces.bkp
    
    # Limpa todo o conteúdo relacionado a interfaces de rede (exceto o loopback)
    cat <<EOF > /etc/network/interfaces
# Este arquivo foi modificado pelo script de instalação.
# Mantemos apenas a interface loopback para permitir que o NetworkManager gerencie outras conexões.

auto lo
iface lo inet loopback

# Outras interfaces serão gerenciadas pelo NetworkManager.
EOF

    echo "Configurações de rede removidas. Backup criado em /etc/network/interfaces.bkp"
}

# Função principal de instalação
main_instalacao() {
    # Instalar gnome e programas
    instalar_pacotes gnome-shell gnome-core gnome-terminal gnome-tweaks

    instalar_pacotes mpv simplescreenrecorder keepassxc thunderbird thunderbird-l10n-pt-br adb fastboot  \
    fonts-noto-color-emoji ttf-mscorefonts-installer exa bat gufw tlp aspell-pt-br zsh lollypop \
    git curl telegram-desktop fonts-noto fonts-dejavu

    # Ativar suporte ao Flatpak e instalar pacotes Flatpak
    instalar_pacotes flatpak
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak install -y flathub com.rtosta.zapzap com.stremio.Stremio org.onlyoffice.desktopeditors

    # Configurar Wine
    instalar_wine

    # Configurar Lutris
    instalar_lutris

    # Baixar e instalar pacotes .deb
    instalar_pacotes_deb

    fc-cache -f -v    # Atualiza o cache de fontes
    gtk-update-icon-cache /usr/share/icons/hicolor   # Atualiza o cache de ícones
}

# Execução das funções
configurar_sources_list
main_instalacao
instalar_brave
configurar_networkmanager


# Reiniciar o sistema após todas as instalações
echo "Instalação concluída com sucesso! O sistema será reiniciado em 10 segundos."
sleep 10
reboot

