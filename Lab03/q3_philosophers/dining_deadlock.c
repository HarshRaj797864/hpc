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
        usleep(100000); // Think

        printf("Philosopher %ld is reaching for left chopstick %d\n", id, left);
        pthread_mutex_lock(&chopsticks[left]);
        
        // Artificial delay to almost guarantee deadlock
        usleep(50000); 

        printf("Philosopher %ld is reaching for right chopstick %d\n", id, right);
        pthread_mutex_lock(&chopsticks[right]);

        printf("Philosopher %ld is EATING!\n", id);
        usleep(100000); // Eat

        pthread_mutex_unlock(&chopsticks[right]);
        pthread_mutex_unlock(&chopsticks[left]);
        printf("Philosopher %ld finished eating and put down chopsticks.\n", id);
    }
    return NULL;
}

int main() {
    pthread_t phils[NUM_PHILOSOPHERS];

    for (int i = 0; i < NUM_PHILOSOPHERS; i++) {
        pthread_mutex_init(&chopsticks[i], NULL);
    }

    printf("Starting Dining Philosophers (Naive Deadlock-prone version)\n");
    for (long i = 0; i < NUM_PHILOSOPHERS; i++) {
        pthread_create(&phils[i], NULL, philosopher, (void*)i);
    }

    for (int i = 0; i < NUM_PHILOSOPHERS; i++) {
        pthread_join(phils[i], NULL);
    }

    for (int i = 0; i < NUM_PHILOSOPHERS; i++) {
        pthread_mutex_destroy(&chopsticks[i]);
    }
    
    printf("Done.\n");
    return 0;
}
