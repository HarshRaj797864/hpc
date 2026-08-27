CC = gcc
CFLAGS = -Wall -O3
LDFLAGS = -lpthread

all: dining_deadlock dining_safe

dining_deadlock: dining_deadlock.c
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

dining_safe: dining_safe.c
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

clean:
	rm -f dining_deadlock dining_safe
