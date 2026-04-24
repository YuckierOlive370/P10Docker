#!/bin/bash

source ./FunGENERALES.sh

# ─── Variables globales ───────────────────────────────────────────────────────
_raiz="/home"
_dirFtp="$_raiz/ftp"
_dirLocal="$_dirFtp/LocalUser"
opcion=0
install="0"
confirm="0"

# ─── Funciones ────────────────────────────────────────────────────────────────

registrarGrupo() {
    local _nombreBase="$1"
    CampoRequerido "$_nombreBase" "Nombre del grupo"

    local _etiqueta="${_nombreBase}Alumno"
    local _carpeta="/home/ftp/$_etiqueta"

    if ! getent group "$_etiqueta" >/dev/null; then
        groupadd "$_etiqueta"
        echo "Grupo '$_etiqueta' registrado correctamente."
    else
        echo "Aviso: el grupo '$_etiqueta' ya se encuentra registrado."
    fi

    mkdir -p "$_carpeta"
    chown root:"$_etiqueta" "$_carpeta"
    chmod 2775 "$_carpeta"
}

eliminarGrupo() {
    local _nombreBase="$1"
    local _sufijo="Alumno"
    local _etiqueta="${_nombreBase}${_sufijo}"
    local _carpeta="/home/ftp/$_etiqueta"

    echo "Procesando eliminación del grupo: $_etiqueta"

    if [[ ! "$_etiqueta" == *"$_sufijo" ]]; then
        echo -e "\e[31mError: únicamente se permite eliminar grupos con sufijo '$_sufijo'.\e[0m"
        return 1
    fi

    if ! getent group "$_etiqueta" >/dev/null; then
        echo -e "\e[33mEl grupo '$_etiqueta' no fue encontrado en el sistema.\e[0m"
        return 1
    fi

    echo "Liberando puntos de montaje asociados..."
    for _jaula in /home/ftp/LocalUser/*; do
        local _punto="$_jaula/${_etiqueta%$_sufijo}"
        if mountpoint -q "$_punto"; then
            umount -f "$_punto"
            echo " -> Desmontado: $(basename "$_jaula")"
        fi
        [ -d "$_punto" ] && rmdir "$_punto"
    done

    if [ -d "$_carpeta" ]; then
        echo "Eliminando contenido del grupo en $_carpeta..."
        rm -rf "$_carpeta"
    fi

    groupdel "$_etiqueta"

    if [ $? -eq 0 ]; then
        echo -e "\e[32mGrupo '$_etiqueta' eliminado sin problemas.\e[0m"
    else
        echo -e "\e[31mOcurrió un error al intentar eliminar el grupo.\e[0m"
    fi
}

consultarGrupos() {
    local _sufijo="Alumno"

    echo -e "\e[34m--------------------------------------------------------\e[0m"
    echo -e "\e[1mGRUPOS ACADÉMICOS ACTIVOS (Sufijo: $_sufijo)\e[0m"
    echo -e "\e[34m--------------------------------------------------------\e[0m"
    echo -e "\e[1mGRUPO\t\tGID\tMIEMBROS\e[0m"
    echo -e "\e[34m--------------------------------------------------------\e[0m"
    getent group | grep "$_sufijo" | cut -d: -f1,3,4 | column -t -s ":"
    echo -e "\e[34m--------------------------------------------------------\e[0m"
}

registrarUsuarios() {
    local _idx=0
    local _dirLocal="/home/ftp/LocalUser"
    local _dirPublico="/home/ftp/public"

    IFS=',' read -ra names <<< "$names"
    IFS=',' read -ra passwords <<< "$passwords"

    ValidarArregloLleno "${names[@]}"
    ValidarArregloLleno "${passwords[@]}"

    if [ ! -d "$_dirPublico" ]; then
        mkdir -p "$_dirPublico"
        chown root:users "$_dirPublico"
        chmod 2775 "$_dirPublico"
    fi

    while [ $_idx -lt "$no_users" ]; do
        local _nombre="${names[$_idx]}"
        local _clave="${passwords[$_idx]}"

        local _jaula="$_dirLocal/$_nombre"
        local _personal="$_jaula/$_nombre"
        local _publico="$_jaula/public"

        echo "Preparando entorno para: $_nombre..."

        useradd "$_nombre" -m -d "$_jaula" -G "users" -c "Alumno" 2>/dev/null

        if [ $? -ne 0 ]; then
            echo "Error: no fue posible crear al usuario '$_nombre'."
            exit 1
        fi

        echo "$_nombre:$_clave" | chpasswd

        mkdir -p "$_personal"
        mkdir -p "$_publico"

        chown root:root "$_jaula"
        chmod 755 "$_jaula"

        chown "$_nombre:$_nombre" "$_personal"
        chmod 700 "$_personal"

        # Montar public solo si no está ya montado
        if mountpoint -q "$_publico"; then
            echo " -> Aviso: $_publico ya estaba montado, se omite."
        else
            mount --bind "$_dirPublico" "$_publico"
        fi

        # Asegurar que el usuario pueda escribir en public (vía grupo users)
        chown root:users "$_publico"
        chmod 2775 "$_publico"

        echo " -> Listo: '$_nombre' configurado (jaula y público montados)."
        ((_idx++))
    done

    echo "------------------------------------------"
    echo "Proceso completado: $no_users usuario(s) configurado(s)."
}

eliminarUsuario() {
    local _nombre="$1"
    local _etiqueta="$2"

    CampoRequerido "$_nombre" "Nombre de usuario"
    CampoRequerido "$_etiqueta" "Etiqueta"

    local _registro
    _registro=$(getent passwd | grep "^$_nombre:" | grep ":$_etiqueta")

    if [ -z "$_registro" ]; then
        echo -e "\e[33mNo se halló al usuario '$_nombre' con la etiqueta '$_etiqueta'.\e[0m"
        return 1
    fi

    echo "Confirmado: se procederá a eliminar a $_nombre (Etiqueta: $_etiqueta)"

    local _ruta="$_dirLocal/$_nombre"

    for _punto in $(mount | grep "/home/ftp/LocalUser/$_nombre/" | cut -d " " -f3); do
        echo " -> Desmontando: $_punto"
        umount -l "$_punto" 2>/dev/null
    done

    if [ -d "$_ruta" ]; then
        echo "Limpiando directorio del usuario: $_ruta"
        rm -rf "$_ruta"
    fi

    userdel -f "$_nombre"

    if [ $? -eq 0 ]; then
        echo -e "\e[32mUsuario '$_nombre' dado de baja exitosamente.\e[0m"
    else
        echo -e "\e[31mFallo al intentar eliminar al usuario del sistema.\e[0m"
    fi
}

consultarAlumnos() {
    local _desc="$1"
    echo -e "\e[34m--------------------------------------------------------\e[0m"
    echo -e "\e[1mUsuarios registrados con descripción: $_desc\e[0m"
    echo -e "\e[34m--------------------------------------------------------\e[0m"
    getent passwd | grep ":$_desc:" | cut -d: -f1,3,5,6 | column -t -s ":"
    echo -e "\e[34m--------------------------------------------------------\e[0m"
}

moverGrupoUsuario() {
    CampoRequerido "$names"
    CampoRequerido "$groups"

    local _sufijo="$1"
    local _etiquetaDestino="${groups}Alumno"

    local _existeGrupo
    _existeGrupo=$(getent group | grep "^$groups""Alumno:")

    if [ -z "$_existeGrupo" ]; then
        echo "Error: el grupo '$groups' no se encuentra registrado."
        exit 1
    fi

    if groups "$names" | grep -q "\b$groups\b"; then
        echo "El usuario $names ya pertenece al grupo $groups."
        exit 1
    fi

    echo "Reasignando a $names hacia el grupo $groups..."

    local _gruposAnteriores
    _gruposAnteriores=$(getent group | grep "$_sufijo" | grep "$names" | cut -d: -f1)

    for _ga in $_gruposAnteriores; do
        echo "Quitando del grupo anterior: $_ga"
        gpasswd -d "$names" "$_ga" 2>/dev/null

        local _puntoAnterior="$_dirLocal/$names/${_ga%$_sufijo}"
        if mountpoint -q "$_puntoAnterior"; then
            umount -lf "$_puntoAnterior"
        fi
        [ -d "$_puntoAnterior" ] && rmdir "$_puntoAnterior"
    done

    usermod -aG "$_etiquetaDestino" "$names"

    local _nuevoPunto="$_dirLocal/$names/$groups"
    local _carpetaGrupo="/home/ftp/${groups}Alumno"

    mkdir -p "$_nuevoPunto"
    mount --bind "$_carpetaGrupo" "$_nuevoPunto"
    chown root:"${groups}Alumno" "$_nuevoPunto"
    chmod 2775 "$_nuevoPunto"

    echo -e "\e[32mReasignación completada: $names ahora pertenece a $groups\e[0m"
}

aplicarConfiguracion() {
    # ── En contenedor Docker, /home/ftp/public ya es el volumen web_content.
    # ── Esta función solo configura vsftpd.conf y crea el usuario anonymous.
    # ── NUNCA desmonta ni remonta /home/ftp/public para no romper el volumen.

    if [ "$(dpkg -l "vsftpd" 2>&1 | grep 'ii')" = "" ]; then
        echo -e "\nEl servicio vsftpd no fue detectado en el sistema"
        exit 1
    fi

    if [ -f /etc/vsftpd.conf ]; then
        sed -ir 's/anonymous_enable=NO/anonymous_enable=YES/' /etc/vsftpd.conf
        sed -ir 's/#chroot_local_user=YES/chroot_local_user=YES/' /etc/vsftpd.conf
        sed -ir 's/#write_enable=YES/write_enable=YES/' /etc/vsftpd.conf

        grep -q "user_sub_token=\$USER" /etc/vsftpd.conf || \
            echo "user_sub_token=\$USER" >> /etc/vsftpd.conf

        grep -q "local_root=$_dirLocal" /etc/vsftpd.conf || \
            echo "local_root=$_dirLocal/\$USER" >> /etc/vsftpd.conf

        grep -q "anon_root=" /etc/vsftpd.conf || \
            echo "anon_root=$_dirFtp/public" >> /etc/vsftpd.conf

        grep -q "local_umask=002" /etc/vsftpd.conf || \
            echo "local_umask=002" >> /etc/vsftpd.conf

        # Anonymous: solo lectura
        grep -q "anon_upload_enable=NO" /etc/vsftpd.conf || \
            echo "anon_upload_enable=NO" >> /etc/vsftpd.conf
        grep -q "anon_mkdir_write_enable=NO" /etc/vsftpd.conf || \
            echo "anon_mkdir_write_enable=NO" >> /etc/vsftpd.conf
    else
        echo "No se encontró /etc/vsftpd.conf, operación cancelada."
        exit 1
    fi

    # ── Crear estructura base si no existe (sin tocar /home/ftp/public) ──
    if [ -d "$_raiz" ]; then
        chmod 755 "$_raiz"
        chown root:root "$_raiz"

        [ -d "$_dirFtp" ]   || { mkdir "$_dirFtp";   echo "Directorio creado: $_dirFtp"; }
        chmod 755 "$_dirFtp"; chown root:root "$_dirFtp"

        [ -d "$_dirLocal" ] || { mkdir "$_dirLocal"; echo "Directorio creado: $_dirLocal"; }
        chmod 755 "$_dirLocal"; chown root:root "$_dirLocal"

        # Asegurar permisos correctos en public (ya montado por Docker)
        if mountpoint -q "$_dirFtp/public"; then
            chown root:users "$_dirFtp/public"
            chmod 2775 "$_dirFtp/public"
            echo "Permisos aplicados en $_dirFtp/public (volumen Docker activo)."
        else
            echo "Aviso: $_dirFtp/public no está montado. Verifica el volumen Docker."
        fi
    else
        echo "El directorio base $_raiz no existe, operación cancelada."
        exit 1
    fi

    ReiniciarPaquete "vsftpd"
    echo -e "\e[32mConfiguración aplicada. Anonymous: solo lectura. Usuarios: lectura/escritura en public.\e[0m"
}
