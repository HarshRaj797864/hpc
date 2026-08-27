CC = gcc
CFLAGS = -Wall -O3
LDFLAGS = -lpthread

all: edge_serial edge_parallel

edge_serial: edge_serial.c
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

edge_parallel: edge_parallel.c
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

clean:
	rm -f edge_serial edge_parallel
