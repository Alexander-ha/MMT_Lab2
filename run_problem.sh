#!/bin/bash

if [ ! -f "generate_problem.py" ]; then
    echo "Ошибка: Файл generate_problem.py не найден."
    exit 1
fi

echo "Запуск generate_problem.py..."
python3 generate_problem.py

if [ ! -f "output.txt" ]; then
    echo "Ошибка: Файл output.txt не создан."
    exit 1
fi

echo "Создание файла CSRsystem..."
cat output.txt > CSRsystem

if [ ! -f "CSRsystem" ]; then
    echo "Ошибка: Файл CSRsystem не создан."
    exit 1
fi

if [ ! -f "prog" ]; then
    echo "Ошибка: Программа prog не найдена. Убедитесь, что она скомпилирована."
    exit 1
fi

echo "Запуск программы prog..."
./prog

echo "Решение завершено."

python3 compute_error.py
