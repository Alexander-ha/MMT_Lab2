#!/bin/bash
set -e

OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
  Darwin*)  OS="macOS" ;;
  Linux*)   OS="Linux" ;;
  *)        echo "Unsupported OS: $OS"; exit 1 ;;
esac

# Configuration
BLAS_LIBS=""
ANI2D_DIR="${PWD}/ani2D-3.1"

# macOS specific settings
if [ "$OS" = "macOS" ]; then
    if [ "$ARCH" = "arm64" ]; then
        HOMEBREW_PREFIX="/opt/homebrew"
    else
        HOMEBREW_PREFIX="/usr/local"
    fi
    export PATH="${HOMEBREW_PREFIX}/bin:$PATH"
    BLAS_LIBS="-L${HOMEBREW_PREFIX}/opt/openblas/lib -lopenblas"
else
    BLAS_LIBS="-lblas -llapack"
fi

check_sudo() {
    if command -v sudo &> /dev/null && sudo -n true 2>/dev/null; then
        echo "sudo доступен"
        return 0
    else
        echo "sudo недоступен"
        return 1
    fi
}

install_lapack() {
    local LAPACK_VER="3.11.0"
    local LAPACK_DIR="${PWD}/lapack-${LAPACK_VER}"
    local LAPACK_TAR="lapack-${LAPACK_VER}.tar.gz"
    local LAPACK_URL=https://github.com/Reference-LAPACK/lapack/archive/refs/tags/v3.11.0.tar.gz

    if [ -d "${LAPACK_DIR}" ]; then
        echo "LAPACK ${LAPACK_VER} уже установлен"
        return 0
    fi

    echo "Скачивание LAPACK ${LAPACK_VER}..."
    [ -f "${LAPACK_TAR}" ] || curl -L -o "lapack-3.11.0.tar.gz" "https://github.com/Reference-LAPACK/lapack/archive/refs/tags/v3.11.0.tar.gz"

    echo "Распаковка LAPACK..."
    tar -xzf lapack-3.11.0.tar.gz || { echo "Ошибка распаковки LAPACK"; exit 1; }

    cd "${LAPACK_DIR}"

    echo "Настройка make.inc..."
    cp make.inc.example make.inc
    
    # Модификация make.inc для совместимости
    # Для macOS
    if [ "$OS" = "macOS" ]; then
        sed -i.bak 's/^FC.*=.*/FC = gfortran/' make.inc
        sed -i.bak 's/^FFLAGS.*=.*/FFLAGS = -O2 -fPIC/' make.inc
    else
    # Для Linux
        sed -i 's/^FC.*=.*/FC = gfortran/' make.inc
        sed -i 's/^FFLAGS.*=.*/FFLAGS = -O2 -fPIC/' make.inc
    fi

    echo "Сборка BLAS..."
    make blaslib || { echo "Ошибка сборки BLAS"; exit 1; }

    echo "Сборка LAPACK..."
    make lapacklib || { echo "Ошибка сборки LAPACK"; exit 1; }

    echo "Сборка LAPACKE..."
    make lapackelib || { echo "Ошибка сборки LAPACKE"; exit 1; }

    echo "Полная сборка..."
    make all || { echo "Ошибка полной сборки"; exit 1; }

    cd ..
}

install_package() {
    local package=$1
    
    if [ "$OS" = "Linux" ]; then
        if dpkg -l | grep -q "^ii  $package "; then
            echo "$package уже установлен."
            return 0
        fi

        if command -v sudo &> /dev/null; then
            echo "Установка $package с использованием sudo..."
            sudo apt-get install -y "$package"
        elif [ "$(id -u)" -eq 0 ]; then
            echo "Установка $package как root..."
            apt-get install -y "$package"
        else
            echo "Ошибка: Требуются права root для установки $package!"
            echo "Выполните скрипт с правами root или установите sudo:"
            echo "  apt-get update && apt-get install -y sudo"
            exit 1
        fi

    else
        if brew list | grep -q "^${package}\$"; then
            echo "$package уже установлен."
            return 0
        fi
        echo "Установка $package..."
        brew install "$package"
    fi
}

install_dependencies() {
    echo "Установка зависимостей для $OS..."
    
    if [ "$OS" = "Linux" ]; then
        check_sudo && sudo apt-get update
        install_package software-properties-common
        check_sudo && sudo add-apt-repository universe -y
        check_sudo && sudo apt-get update
        
        install_package gfortran
        install_package cmake
        install_package wget
        install_package libblas-dev
        install_package liblapack-dev

    elif [ "$OS" = "macOS" ]; then
        if ! command -v brew &>/dev/null; then
            echo "Установка Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        
        brew update
        brew install gfortran cmake openblas lapack
    fi

    # Python dependencies
    if ! command -v python3 &>/dev/null; then install_package python3; fi
    if ! command -v pip3 &>/dev/null; then
        if [ "$OS" = "Linux" ]; then
            install_package python3-pip
        else
            curl -sS https://bootstrap.pypa.io/get-pip.py | python3
        fi
    fi
    python3 -c "import numpy" &>/dev/null || pip3 install numpy
}

install_ani2d() {
    local TAR_FILE="ani2D-3.1.tar.gz"
    local INSTALL_MARKER="${ANI2D_DIR}/.installed"
    
    if [ -f "$INSTALL_MARKER" ]; then
        echo "Ani2D уже установлен"
        return 0
    fi

    # Download and extract
    if [ ! -d "$ANI2D_DIR" ]; then
        echo "Скачивание Ani-2D..."
        [ -f "$TAR_FILE" ] || curl -L -o "$TAR_FILE" https://sourceforge.net/projects/ani2d/files/latest/download
        
        echo "Распаковка архива..."
        tar -xzf "$TAR_FILE"
        rm -f "$TAR_FILE"
    fi

    # Build
    echo "Сборка Ani-2D..."
    mkdir -p "${ANI2D_DIR}/build"
    cd "${ANI2D_DIR}/build"
    
    # Configure
    if [ ! -f "CMakeCache.txt" ]; then
        [ "$OS" = "macOS" ] && export PKG_CONFIG_PATH="${HOMEBREW_PREFIX}/opt/openblas/lib/pkgconfig:${PKG_CONFIG_PATH}"
        cmake -DCMAKE_Fortran_FLAGS="-fallow-argument-mismatch" ..
    fi

    # Compile
    make -j$(nproc)

    # Install
    if check_sudo; then
        sudo make install
    else
        make install
    fi
    
    touch "../.installed"
    cd ../..
}

compile_prog() {
    local PROG_NAME="prog_ani"
    local SRC_FILE="${PROG_NAME}.f"
    
    local ANI2D_LIB="${PWD}/ani2D-3.1/lib"
    local LAPACK_LIB="${PWD}/lapack-3.11.0"

    check_lib() {
        if [ ! -f "$1" ]; then
            echo "Ошибка: Библиотека $1 не найдена!"
            exit 1
        fi
    }

    check_lib "${ANI2D_LIB}/libilu-3.1.a"
    check_lib "${LAPACK_LIB}/liblapacke.a"
    check_lib "${LAPACK_LIB}/librefblas.a"

    gfortran -o "${PROG_NAME}" "${SRC_FILE}" \
        -L"${ANI2D_LIB}" -lilu-3.1 \
        -L"${LAPACK_LIB}" \
        -Wl,--start-group \
        -lrefblas \
        -llapacke \
        -Wl,--end-group

    if [ $? -eq 0 ]; then
        echo "Программа успешно скомпилирована: ./${PROG_NAME}"
    else
        echo "Ошибка линковки!"
        exit 1
    fi
}

main() {
    install_dependencies
    install_lapack
    install_ani2d
    compile_prog
    echo "Установка завершена успешно!"
}

main "$@"
