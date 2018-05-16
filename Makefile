MAKEFILE_DIR=$(dir $(lastword $(MAKEFILE_LIST)))
INCLUDE_DIR=$(MAKEFILE_DIR)include
SRC_DIR=$(MAKEFILE_DIR)src
OUTPUT_DIR=$(MAKEFILE_DIR)lib

CC=gcc
CFLAGS=-shared -fPIC -DKXVER=3 -Wall -I$(INCLUDE_DIR)

IRC_SOURCE=$(SRC_DIR)/irc.c
IRC_LIB=

all: irc32 irc64

irc32: mkdir
	$(CC) $(CFLAGS) -m32 -o $(OUTPUT_DIR)/irc.l32.so $(IRC_SOURCE) $(IRC_LIB)

irc64: mkdir
	$(CC) $(CFLAGS) -m64 -o $(OUTPUT_DIR)/irc.l64.so $(IRC_SOURCE) $(IRC_LIB)

mkdir:
	mkdir -p $(OUTPUT_DIR)
	rm -rf $(OUTPUT_DIR)/*
