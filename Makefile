CC ?= gcc
CFLAGS_common ?= -Wall -std=gnu99
CFLAGS_orig = -O0
CFLAGS_opt  = -O0 -pthread -g -pg
CFLAGS_tpool = -O0 -pthread -g -pg
CFLAGS_lftpool = -O0 -pthread -g -pg

ifdef THREAD
CFLAGS_opt  += -D THREAD_NUM=${THREAD}
endif

ifeq ($(strip $(DEBUG)),1)
CFLAGS_opt += -DDEBUG -g
endif

EXEC = phonebook_orig phonebook_opt phonebook_tpool phonebook_lftpool
all: $(EXEC)

SRCS_common = main.c

file_align: file_align.c
	$(CC) $(CFLAGS_common) $^ -o $@

phonebook_orig: $(SRCS_common) phonebook_orig.c phonebook_orig.h
	$(CC) $(CFLAGS_common) $(CFLAGS_orig) \
		-DIMPL="\"$@.h\"" -o $@ \
		$(SRCS_common) $@.c

phonebook_opt: $(SRCS_common) phonebook_opt.c phonebook_opt.h
	$(CC) $(CFLAGS_common) $(CFLAGS_opt) \
		-DIMPL="\"$@.h\"" -o $@ \
		$(SRCS_common) $@.c

phonebook_tpool: $(SRCS_common) phonebook_tpool.c phonebook_tpool.h
	$(CC) $(CFLAGS_common) $(CFLAGS_tpool) \
		-DIMPL="\"$@.h\"" -o $@ \
		$(SRCS_common) $@.c $ threadpool.c

phonebook_lftpool: $(SRCS_common) phonebook_lftpool.c phonebook_lftpool.h
	$(CC) $(CFLAGS_common) $(CFLAGS_lftpool) \
		-DIMPL="\"$@.h\"" -o $@ \
		$(SRCS_common) $@.c $ lockfree_threadpool.c


run: $(EXEC)
	echo 3 | sudo tee /proc/sys/vm/drop_caches
	watch -d -t "./phonebook_orig && echo 3 | sudo tee /proc/sys/vm/drop_caches"

cache-test: $(EXEC)
	perf stat --repeat 100 \
		-e cache-misses,cache-references,instructions,cycles \
		./phonebook_orig
	perf stat --repeat 100 \
		-e cache-misses,cache-references,instructions,cycles \
		./phonebook_opt	
	perf stat --repeat 100 \
		-e cache-misses,cache-references,instructions,cycles \
		./phonebook_tpool
	perf stat --repeat 100 \
		-e cache-misses,cache-references,instructions,cycles \
		./phonebook_lftpool

output.txt: cache-test calculate
	./calculate

plot: output.txt
	gnuplot scripts/runtime.gp

calculate: calculate.c
	$(CC) $(CFLAGS_common) $^ -o $@

.PHONY: clean
clean:
	$(RM) $(EXEC) *.o perf.* \
	      	calculate orig.txt opt.txt output.txt tpool.txt lftpool.txt runtime.png file_align align.txt
