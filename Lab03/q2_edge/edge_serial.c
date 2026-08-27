#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>

#define N 8192

int image[N][N];
int output[N][N];

int sobel_x[3][3] = {{-1, 0, 1}, {-2, 0, 2}, {-1, 0, 1}};
int sobel_y[3][3] = {{-1, -2, -1}, {0, 0, 0}, {1, 2, 1}};

double get_time() {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return tv.tv_sec + tv.tv_usec * 1e-6;
}

int main() {
    // Initialize image with random values
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            image[i][j] = rand() % 256;
        }
    }

    double start_time = get_time();
    
    // Apply edge detection (ignoring 1px border for simplicity)
    for (int i = 1; i < N - 1; i++) {
        for (int j = 1; j < N - 1; j++) {
            int gx = 0;
            int gy = 0;
            for (int u = -1; u <= 1; u++) {
                for (int v = -1; v <= 1; v++) {
                    gx += image[i+u][j+v] * sobel_x[u+1][v+1];
                    gy += image[i+u][j+v] * sobel_y[u+1][v+1];
                }
            }
            output[i][j] = abs(gx) + abs(gy); // Approximation of sqrt(gx^2 + gy^2)
        }
    }
    
    double end_time = get_time();
    
    printf("%.6f\n", end_time - start_time);
    return 0;
}
