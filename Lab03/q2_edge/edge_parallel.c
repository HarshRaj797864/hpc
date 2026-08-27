#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <sys/time.h>

#define N 8192

int image[N][N];
int output[N][N];
int num_threads;

int sobel_x[3][3] = {{-1, 0, 1}, {-2, 0, 2}, {-1, 0, 1}};
int sobel_y[3][3] = {{-1, -2, -1}, {0, 0, 0}, {1, 2, 1}};

void* edge_detect(void* rank) {
    long my_rank = (long)rank;
    
    // Divide rows among threads
    int rows_per_thread = (N - 2) / num_threads;
    int start_row = 1 + my_rank * rows_per_thread;
    int end_row = (my_rank == num_threads - 1) ? N - 1 : start_row + rows_per_thread;
    
    for (int i = start_row; i < end_row; i++) {
        for (int j = 1; j < N - 1; j++) {
            int gx = 0;
            int gy = 0;
            for (int u = -1; u <= 1; u++) {
                for (int v = -1; v <= 1; v++) {
                    gx += image[i+u][j+v] * sobel_x[u+1][v+1];
                    gy += image[i+u][j+v] * sobel_y[u+1][v+1];
                }
            }
            output[i][j] = abs(gx) + abs(gy); 
        }
    }
    
    return NULL;
}

double get_time() {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return tv.tv_sec + tv.tv_usec * 1e-6;
}

int main(int argc, char *argv[]) {
    if (argc != 2) {
        printf("Usage: %s <num_threads>\n", argv[0]);
        return 1;
    }
    num_threads = atoi(argv[1]);
    
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            image[i][j] = rand() % 256;
        }
    }

    pthread_t* thread_handles = malloc(num_threads * sizeof(pthread_t));
    
    double start_time = get_time();
    
    for (long thread = 0; thread < num_threads; thread++) {
        pthread_create(&thread_handles[thread], NULL, edge_detect, (void*)thread);
    }
    
    for (long thread = 0; thread < num_threads; thread++) {
        pthread_join(thread_handles[thread], NULL);
    }
    
    double end_time = get_time();
    
    printf("%.6f\n", end_time - start_time);
    
    free(thread_handles);
    return 0;
}
