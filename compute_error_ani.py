import numpy as np
from generate_problem import *

def exact_solution(N, h):
    sol_vec = []
    for i in range(0, N+1):
        sol_vec.append((2 * (-14 * np.exp(i*h) + 14 * np.exp(3 * i * h) + 8 * np.exp(3 + i * h) - 8 * np.exp(1 + 3 * i * h) - np.exp(1) * (1 + 3 * i * h) + np.exp(3) * (1 + 3 * i * h))) / (9 * np.exp(1) * (-1 + np.exp(2))))
    return sol_vec

sol_vec = exact_solution(N, 1/N)

vector = []
with open('solution.txt', 'r') as file:
    for line in file:
        vector.append(float(line.strip()))
if len(vector) != len(sol_vec):
    raise ValueError("Векторы должны быть одинаковой длины для сравнения.")

max_error = max(abs(v - o) for v, o in zip(vector, sol_vec))

print(f"Максимальная погрешность: {max_error}")