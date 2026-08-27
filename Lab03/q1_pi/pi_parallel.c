#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <sys/time.h>
#include <time.h>

long long total_points;
int num_threads;
long long global_points_in_circle = 0;
pthread_mutex_t mutex;

void* monte_carlo(void* rank) {
    long my_rank = (long)rank;
    long long points_per_thread = total_points / num_threads;
    long long start_point = my_rank * points_per_thread;
    long long end_point = (my_rank == num_threads - 1) ? total_points : start_point + points_per_thread;
    long long my_points = end_point - start_point;
    
    long long local_points_in_circle = 0;
    unsigned int seed = my_rank + time(NULL); 
    
    for (long long i = 0; i < my_points; i++) {
        double x = (double)rand_r(&seed) / RAND_MAX * 2.0 - 1.0;
        double y = (double)rand_r(&seed) / RAND_MAX * 2.0 - 1.0;
        if (x * x + y * y <= 1.0) {
            local_points_in_circle++;
        }
    }
    
    pthread_mutex_lock(&mutex);
    global_points_in_circle += local_points_in_circle;
    pthread_mutex_unlock(&mutex);
    
    return NULL;
}

double get_time() {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return tv.tv_sec + tv.tv_usec * 1e-6;
}

int main(int argc, char *argv[]) {
    if (argc != 3) {
        printf("Usage: %s <num_points> <num_threads>\n", argv[0]);
        return 1;
    }
    
    total_points = atoll(argv[1]);
    num_threads = atoi(argv[2]);
    
    pthread_t* thread_handles = malloc(num_threads * sizeof(pthread_t));
    pthread_mutex_init(&mutex, NULL);
    
    double start_time = get_time();
    
    for (long thread = 0; thread < num_threads; thread++) {
        pthread_create(&thread_handles[thread], NULL, monte_carlo, (void*)thread);
    }
    
    for (long thread = 0; thread < num_threads; thread++) {
        pthread_join(thread_handles[thread], NULL);
    }
    
    double end_time = get_time();
    
    double pi_estimate = 4.0 * global_points_in_circle / total_points;
    double time_taken = end_time - start_time;
    
    printf("%.10f %.6f\n", pi_estimate, time_taken);
    
    free(thread_handles);
    pthread_mutex_destroy(&mutex);
    return 0;
}
