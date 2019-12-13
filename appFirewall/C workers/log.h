//
//  appFirewall
//
//  Copyright © 2019 Doug Leith. All rights reserved.
//

#ifndef log_h
#define log_h

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <sys/errno.h>
#include <netinet/in.h>
#include <string.h>
#include "util.h"
#include "is_blocked.h"
#include "circular_list.h"


#define LOGSTRSIZE 256

//log_line_t used by swift
typedef struct log_line_t {
	char time_str[LOGSTRSIZE], log_line[LOGSTRSIZE];
	struct bl_item_t bl_item;
	double confidence; // confidence that we have the process name right
	int_sw blocked;
	conn_raw_t raw;
} log_line_t;

size_t get_log_size(void);
log_line_t* get_log_row(size_t row);
log_line_t* find_log_by_conn(char* name, conn_raw_t* c, int debug);
double update_log_by_conn(char* name, conn_raw_t* c, int blocked);
void append_log(char* str, char* long_str, struct bl_item_t* bl_item, conn_raw_t *raw, int blocked, double confidence);

//swift
void filter_log_list(int_sw show_blocked, const char* str);
int_sw get_filter_log_size(void);
log_line_t* get_filter_log_row(int_sw row);
char*  get_filter_log_addr_name(int_sw row);
char* filtered_log_hash(const void *it);
void save_log(const char* logName);
void load_log(const char* logName, const char* logTxtName);
void clear_log(void);
void open_logtxt(const char* logTxtName);
void close_logtxt(void);
void reopen_logtxt(void);
int_sw has_log_changed(void);
void clear_log_changed(void);

#endif /* log_h */
