CC = gcc
CCFLAGS = -g -O2

OUT_DIR = build/

SOURCES = $(wildcard *.c)
# TARGETS = $(SOURCES:%.c=%)
TARGETS = $(patsubst %.c, $(OUT_DIR)%.exec, $(SOURCES))

all: $(TARGETS)

$(OUT_DIR)%.exec: %.c | $(OUT_DIR)
	$(CC) $(CCFLAGS) $^ -o $@

$(OUT_DIR):
	mkdir -p $(OUT_DIR)

clean:
	rm -rf $(OUT_DIR)

