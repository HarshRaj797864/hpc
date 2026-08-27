#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <unistd.h>

#define NUM_PHILOSOPHERS 5

pthread_mutex_t chopsticks[NUM_PHILOSOPHERS];

void* philosopher(void* arg) {
    long id = (long)arg;
    int left = id;
    int right = (id + 1) % NUM_PHILOSOPHERS;

    for (int i = 0; i < 3; i++) {
        printf("Philosopher %ld is thinking...\n", id);
        usleep(100000); 

        // Asymmetric solution: Even philosophers pick left then right. 
        // Odd philosophers pick right then left.
        if (id % 2 == 0) {
            pthread_mutex_lock(&chopsticks[left]);
            usleep(50000); 
            pthread_mutex_lock(&chopsticks[right]);
        } else {
            pthread_mutex_lock(&chopsticks[right]);
            usleep(50000);
            pthread_mutex_lock(&chopsticks[left]);
        }

        printf("Philosopher %ld is EATING!\n", id);
        usleep(100000); 

        pthread_mutex_unlock(&chopsticks[left]);
        pthread_mutex_unlock(&chopsticks[right]);
        
        printf("Philosopher %ld finished eating and put down chopsticks.\n", id);
    }
    return NULL;
}

int main() {
    pthread_t phils[NUM_PHILOSOPHERS];

    for (int i = 0; i < NUM_PHILOSOPHERS; i++) {
        pthread_mutex_init(&chopsticks[i], NULL);
    }

    printf("Starting Dining Philosophers (Safe Asymmetric version)\n");
    for (long i = 0; i < NUM_PHILOSOPHERS; i++) {
        pthread_create(&phils[i], NULL, philosopher, (void*)i);
    }

    for (int i = 0; i < NUM_PHILOSOPHERS; i++) {
        pthread_join(phils[i], NULL);
    }

    for (int i = 0; i < NUM_PHILOSOPHERS; i++) {
        pthread_mutex_destroy(&chopsticks[i]);
    }

    printf("All philosophers finished eating safely!\n");
    return 0;
}
