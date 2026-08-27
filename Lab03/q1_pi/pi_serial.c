#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <sys/time.h>

double get_time() {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return tv.tv_sec + tv.tv_usec * 1e-6;
}

int main(int argc, char *argv[]) {
    if (argc != 2) {
        printf("Usage: %s <num_points>\n", argv[0]);
        return 1;
    }
    long long total_points = atoll(argv[1]);
    long long points_in_circle = 0;
    
    unsigned int seed = time(NULL);
    double start_time = get_time();
    for (long long i = 0; i < total_points; i++) {
        double x = (double)rand_r(&seed) / RAND_MAX * 2.0 - 1.0;
        double y = (double)rand_r(&seed) / RAND_MAX * 2.0 - 1.0;
        if (x * x + y * y <= 1.0) {
            points_in_circle++;
        }
    }
    double end_time = get_time();
    
    double pi_estimate = 4.0 * points_in_circle / total_points;
    printf("%.10f %.6f\n", pi_estimate, end_time - start_time);
    return 0;
}
