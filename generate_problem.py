import math
import numpy as np

eps = 1.0e-15

def write_CSR_file(aelem, jptr, iptr, f, filename ):
    out = open(filename, 'w')
    n = np.size(iptr) - 1
    out.write(str(n) + "\n")
    for i in range(0, np.size(iptr)):
        out.write(str(iptr[i]+1) + " ")
    out.write("\n")
    for i in range(0, np.size(jptr)):
        out.write(str(jptr[i]+1) + " ")
    out.write("\n")
    for i in range(0, np.size(aelem)):
        out.write(str(aelem[i]) + " ")
    out.write("\n")
    for i in range(0, np.size(f)):
        out.write(str(f[i]) + " ")
    out.close()

def seq_matrix_calculation(A):
    N = len(A)
    NN = 0
    for i in range(0, N):
        for j in range(0, N):
            if (math.fabs(A[i][j]) > eps):
                NN = NN + 1

    aelem = np.zeros((NN), 'double')
    jptr = np.zeros((NN), 'int')
    iptr = np.zeros((N + 1), 'int')
    iptr[0] = 0
    k = 0
    for i in range(0, N):
        for j in range(0, N):
            if (math.fabs(A[i][j]) > eps):
                aelem[k] = A[i][j]
                jptr[k] = j
                k = k + 1
        iptr[i + 1] = k
    return aelem, jptr, iptr
      

def apply_differential_task(n, val_start, val_end):
    A = np.zeros((n, n), dtype='double')
    f = np.zeros(n, dtype='double')
    h = 1.0 / (n - 1.0)

    for i in range(n):
        if i == 0:
            A[i][i] = 1.0
            f[i] = val_start
        elif i == n - 1:
            A[i][i] = 1.0
            f[i] = val_end
        else:
            A[i][i + 1] = (1.0 / (h * h)) - (7.0 / h)
            A[i][i] = (-2.0 / (h * h)) + (10.0 / h) + 3.0
            A[i][i - 1] = (1.0 / (h * h)) - (3.0 / h)
            f[i] = 2 * i * h - 2
    return A, f

N = 400
val_start = 2.0 
val_end = 4.0 

A, f_r = apply_differential_task(N + 1, val_start, val_end)
aelem, jptr, iptr = seq_matrix_calculation(A)

# N = 3  # Размер матрицы
# iptr = [0, 1, 4, 5]  # Индексы строк (должно быть n+1 элементов)
# jptr = [0, 0, 1, 2, 2]  # Индексы столбцов (nz элементов)
# aelem = [1.0,  -2.0,  15.0, -10.0, 1.0]  # Ненулевые элементы (nz элементов)
# f_r = [2, -1, 4]  # Правая часть (n элементов)

# with open("output.txt", "w") as f:
#         f.write(f"{N}\n")
#         f.write(" ".join(map(str, iptr)) + "\n")
#         f.write(" ".join(map(str, jptr)) + "\n")
#         f.write(" ".join(map(str, aelem)) + "\n")
#         f.write(" ".join(map(str, f_r)) + "\n")

write_CSR_file(aelem, jptr, iptr, f_r, "output.txt" )
