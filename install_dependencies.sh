#!/bin/bash

check_sudo() {
    if command -v sudo &> /dev/null; then
        echo "sudo доступен."
        return 0
    else
        echo "sudo недоступен."
        return 1
    fi
}

install_package() {
    local package=$1
    if check_sudo; then
        sudo apt-get install -y "$package"
    else
        apt-get install -y "$package"
    fi
}

update_packages() {
    if check_sudo; then
        sudo apt-get update
    else
        apt-get update
    fi
}

install_gfortran() {
    echo "Установка gfortран..."
    update_packages
    install_package gfortran
}

if ! command -v gfortran &> /dev/null; then
    echo "gfortran не найден."
    install_gfortran
else
    echo "gfortran уже установлен."
fi

if ! command -v python3 &> /dev/null; then
    echo "Python не найден. Установка Python..."
    update_packages
    install_package python3
fi

if ! command -v pip3 &> /dev/null; then
    echo "pip не найден. Установка pip..."
    update_packages
    install_package python3-pip
fi

if ! python3 -c "import numpy" &> /dev/null; then
    echo "numpy не найден. Установка numpy..."
    pip3 install numpy
fi

SPARSKIT_DIR="SPARSKIT2"
if [ ! -d "$SPARSKIT_DIR" ]; then
    echo "SPARSKIT не найден. Загрузка SPARSKIT..."
    wget https://www-users.cse.umn.edu/~saad/software/SPARSKIT/SPARSKIT2.tar.gz
    tar -xvzf SPARSKIT2.tar.gz
    rm SPARSKIT2.tar.gz
else
    echo "SPARSKIT уже установлен."
fi

LAPACK_DIR="lapack-3.11.0"
if [ ! -d "$LAPACK_DIR" ]; then
    echo "LAPACK не найден. Загрузка LAPACK..."
    wget https://github.com/Reference-LAPACK/lapack/archive/refs/tags/v3.11.0.tar.gz -O lapack-3.11.0.tar.gz
    tar -xvzf lapack-3.11.0.tar.gz
    rm lapack-3.11.0.tar.gz
else
    echo "LAPACK уже установлен."
fi

if [ -d "$LAPACK_DIR" ]; then
    echo "Проверка сборки LAPACK..."
    cd "$LAPACK_DIR"

    if [ ! -f "librefblas.a" ] || [ ! -f "liblapack.a" ] || [ ! -f "liblapacke.a" ]; then
        echo "Сборка LAPACK..."
        cp make.inc.example make.inc

        if [ ! -f "librefblas.a" ]; then
            echo "Сборка BLAS..."
            make blaslib
            if [ $? -ne 0 ]; then
                echo "Ошибка при сборке BLAS. Убедитесь, что gfortran установлен."
                exit 1
            fi
        else
            echo "BLAS уже собран."
        fi

        if [ ! -f "liblapack.a" ]; then
            echo "Сборка LAPACK..."
            make lapacklib
            if [ $? -ne 0 ]; then
                echo "Ошибка при сборке LAPACK. Убедитесь, что gfortran установлен."
                exit 1
            fi
        else
            echo "LAPACK уже собран."
        fi

        if [ ! -f "liblapacke.a" ]; then
            echo "Сборка LAPACKE..."
            make lapackelib
            if [ $? -ne 0 ]; then
                echo "Ошибка при сборке LAPACKE. Убедитесь, что gfortran установлен."
                exit 1
            fi
        else
            echo "LAPACKE уже собран."
        fi
    else
        echo "LAPACK, BLAS и LAPACKE уже собраны."
    fi

    cd ..
else
    echo "Ошибка: Директория LAPACK не найдена."
    exit 1
fi

if [ -f "$SPARSKIT_DIR/makefile" ]; then
    echo "Проверка Makefile SPARSKIT..."
    if ! grep -q "F77 = gfortran -fallow-argument-mismatch" "$SPARSKIT_DIR/makefile"; then
        echo "Изменение Makefile SPARSKIT..."
        sed -i '23s/.*/F77 = gfortran -fallow-argument-mismatch/' "$SPARSKIT_DIR/makefile"
    else
        echo "Makefile SPARSKIT уже изменен."
    fi
else
    echo "Ошибка: Makefile SPARSKIT не найден."
    exit 1
fi

echo "Проверка сборки SPARSKIT..."
cd "$SPARSKIT_DIR"
if [ ! -f "libskit.a" ]; then
    echo "Сборка SPARSKIT..."
    make clean
    make all
    if [ $? -ne 0 ]; then
        echo "Ошибка при сборке SPARSKIT. Убедитесь, что gfortran установлен."
        exit 1
    fi
else
    echo "SPARSKIT уже собран."
fi
cd ..

ITSOL_DIR="$SPARSKIT_DIR/ITSOL"

if [ -f "$ITSOL_DIR/rilut.f" ] && [ -f "$ITSOL_DIR/ilut.o" ] && [ -f "$ITSOL_DIR/itaux.o" ]; then
    echo "Файлы rilut.f, ilut.o и itaux.o найдены в $ITSOL_DIR."

    if [ ! -f "$ITSOL_DIR/rilut.o" ]; then
        echo "Компиляция rilut.f..."
        gfortran -c "$ITSOL_DIR/rilut.f" -o "$ITSOL_DIR/rilut.o"
        if [ $? -ne 0 ]; then
            echo "Ошибка при компиляции rilut.f. Убедитесь, что gfortran установлен."
            exit 1
        fi
    else
        echo "rilut.o уже скомпилирован."
    fi

    echo "Линковка main..."
    gfortran -o main "$ITSOL_DIR/ilut.o" "$ITSOL_DIR/itaux.o" "$ITSOL_DIR/rilut.o" -L"$SPARSKIT_DIR" -L"$LAPACK_DIR" -lrefblas -lskit
    if [ $? -ne 0 ]; then
        echo "Ошибка при линковке main. Убедитесь, что SPARSKIT и LAPACK собраны."
        exit 1
    fi
    echo "Программа main успешно скомпилирована."
else
    echo "Ошибка: Файлы rilut.f, ilut.o или itaux.o не найдены в $ITSOL_DIR."
    exit 1
fi

if [ -f "prog.f" ]; then
    echo "Компиляция prog.f..."
    gfortran -c prog.f
    if [ $? -ne 0 ]; then
        echo "Ошибка при компиляции prog.f. Убедитесь, что gfortran установлен."
        exit 1
    fi
    gfortran -o prog "$ITSOL_DIR/ilut.o" "$ITSOL_DIR/itaux.o" prog.f -L"$SPARSKIT_DIR" -L"$LAPACK_DIR" -lrefblas -lskit
    if [ $? -ne 0 ]; then
        echo "Ошибка при линковке prog.f. Убедитесь, что SPARSKIT и LAPACK собраны."
        exit 1
    fi
    echo "Программа prog успешно скомпилирована."
else
    echo "Файл prog.f не найден. Пропуск компиляции prog.f."
fi

echo "Установка завершена."