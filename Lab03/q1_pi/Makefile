CC = gcc
CFLAGS = -Wall -O3
LDFLAGS = -lpthread -lm

all: pi_serial pi_parallel

pi_serial: pi_serial.c
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

pi_parallel: pi_parallel.c
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

clean:
	rm -f pi_serial pi_parallel
