/*******************************************************************
 *  Copyright (c) 2007-2008 Jetico, Inc., Finland
 *  All rights reserved.
 *
 *  File:          schemes.c
 *
 *  Description:   wiping schemes
 *
 *  Author:        Alexander Pichuev
 *
 *  Created:       10-Sep-2007
 *
 *  Revision:      $Id: schemes.c 296 2010-04-16 03:22:10Z nail $ 
 *
 *
 *******************************************************************/
#include "config.h"
#include <stdlib.h>
#include <stdio.h>
#include <errno.h>
#include <string.h>
#include "wipe.h"
#include "options.h"
#include "log.h"
#include "schemes.h"

static pass_s pg_passT[] = {
    { 0, 0, 0, PASS_RANDOM    },  /* 1  random */
    { 0, 0, 0, PASS_RANDOM    },  /* 2  random */
    { 0, 0, 0, PASS_RANDOM    },  /* 3  random */
    { 0, 0, 0, PASS_RANDOM    },  /* 4  random */
    { 1, 0, "\x55",           },  /* 5  RLL MFM */
    { 1, 0, "\xaa",           },  /* 6  RLL MFM */
    { 3, 0, "\x92\x49\x24",   },  /* 7  RLL MFM */
    { 3, 0, "\x49\x24\x92",   },  /* 8  RLL MFM */
    { 3, 0, "\x24\x92\x49",   },  /* 9  RLL MFM */
    { 1, 0, "\x00",           },  /* 10 RLL */
    { 1, 0, "\x11",           },  /* 11 RLL */
    { 1, 0, "\x22",           },  /* 12 RLL */
    { 1, 0, "\x33",           },  /* 13 RLL */
    { 1, 0, "\x44",           },  /* 14 RLL */
    { 1, 0, "\x55",           },  /* 15 RLL */
    { 1, 0, "\x66",           },  /* 16 RLL */
    { 1, 0, "\x77",           },  /* 17 RLL */
    { 1, 0, "\x88",           },  /* 18 RLL */
    { 1, 0, "\x99",           },  /* 19 RLL */
    { 1, 0, "\xaa",           },  /* 20 RLL */
    { 1, 0, "\xbb",           },  /* 21 RLL */
    { 1, 0, "\xcc",           },  /* 22 RLL */
    { 1, 0, "\xdd",           },  /* 23 RLL */
    { 1, 0, "\xee",           },  /* 24 RLL */
    { 1, 0, "\xff",           },  /* 25 RLL */
    { 3, 0, "\x92\x49\x24"    },  /* 26 RLL MFM */
    { 3, 0, "\x49\x24\x92"    },  /* 27 RLL MFM */
    { 3, 0, "\x24\x92\x49"    },  /* 28 RLL MFM */
    { 3, 0, "\x6d\xb6\xdb"    },  /* 29 RLL */
    { 3, 0, "\xb6\xdb\x6d"    },  /* 30 RLL */
    { 3, 0, "\xdb\x6d\xb6"    },  /* 31 RLL */
    { 0, 0, 0, PASS_RANDOM    },  /* 32 random */
    { 0, 0, 0, PASS_RANDOM    },  /* 33 random */
    { 0, 0, 0, PASS_RANDOM    },  /* 34 random */
    { 0, 1, 0, PASS_RANDOM    }   /* 35 random with verification */
};

static pass_s dod_passT[] = {
    { 1, 0, "\x35",         },  
    { 1, 0, "\xca",         },  
    { 1, 0, "\x97",         },  
    { 1, 0, "\x68",         },  
    { 1, 0, "\xac",         },  
    { 1, 0, "\x53",         },  
    { 0, 1, 0, PASS_RANDOM  }   
};

static pass_s bci_passT[] = {
    { 0, 0, 0, PASS_ZERO   },  
    { 1, 0, "\xFF", 0      },  
    { 0, 0, 0, PASS_ZERO   },  
    { 1, 0, "\xFF", 0      },  
    { 0, 0, 0, PASS_ZERO   },  
    { 1, 0, "\xFF", 0      },
    { 1, 1, "\xAA", 0      }
};

static pass_s test_passT[] = {
    { 0, 1, 0, PASS_TEST }  
};

static pass_s zero_passT[] = {
    { 0, 1, 0, PASS_ZERO }
};

static pass_s doe_passT[] = {
    { 0, 0, 0, PASS_RANDOM },
    { 0, 0, 0, PASS_RANDOM },
    { 0, 1, 0, PASS_ZERO   }  
};

static pass_s schneier_passT[] = {
    { 1, 0, "\xFF", 0      },  
    { 0, 0, 0, PASS_ZERO   },  
    { 0, 0, 0, PASS_RANDOM },
    { 0, 0, 0, PASS_RANDOM },
    { 0, 0, 0, PASS_RANDOM },
    { 0, 0, 0, PASS_RANDOM },
    { 0, 1, 0, PASS_RANDOM }
};

int init_scheme(wipe_scheme_t *scheme) 
{
	int i;
	
	if (!scheme) {
		return -1;
	}
	
	switch (o_scheme) {
	case SCHEME_FILE:
		i = load_scheme(o_scheme_file, scheme);		
		if (o_scheme_file) {
			free(o_scheme_file);
		}
		scheme->name = "User defined";
		o_pas_num = scheme->num_passes;
		return i;

	case SCHEME_GUTMANN:
		scheme->name = "Peter Gutmann's";
		scheme->num_passes = 35;
		scheme->pass = pg_passT;
		scheme->builtin = TRUE;
		break;

	case SCHEME_DOE:
		scheme->name = "US DoE";
		scheme->num_passes = 3;
		scheme->pass = doe_passT;
		scheme->builtin = TRUE;
		break;

	case SCHEME_BCI:
		scheme->name = "German BCI/VSITR";
		scheme->num_passes = 7;
		scheme->pass = bci_passT;
		scheme->builtin = TRUE;
		break;

	case SCHEME_DOD:
		scheme->name = "US DoD 5220-22M";
		scheme->num_passes = o_pas_num;
		if (7 == scheme->num_passes) {
			scheme->pass = dod_passT;
			scheme->builtin = TRUE;
		} else {
			scheme->pass = (pass_s *)malloc(sizeof(pass_s)*scheme->num_passes);
			if (NULL == scheme->pass) {
				log_message(LOG_FATAL, "Out of memory when trying to build a scheme\n");
				return -1;
			}
			for (i = 0; i < scheme->num_passes - 1; i++) {
				scheme->pass[i] = dod_passT[i%6];
			}
			scheme->pass[scheme->num_passes - 1] = dod_passT[6];
			scheme->builtin = FALSE;
		}
		break;

	case SCHEME_SCHNEIER:
		scheme->name = "Bruce Schneier's";
		scheme->num_passes = 7;
		scheme->pass = schneier_passT;
		scheme->builtin = TRUE;
		break;
		
	case SCHEME_TEST:
		scheme->name = "Test";
		scheme->num_passes = 1;
		scheme->pass = test_passT;
		scheme->builtin = TRUE;
		break;

	case SCHEME_ZERO:
		scheme->name = "Zero";
		scheme->num_passes = 1;
		scheme->pass = zero_passT;
		scheme->builtin = TRUE;
		break;
	
		
	default:
		log_message(LOG_FATAL, "Unknown wiping scheme %d requested\n", o_scheme);
		return -1;
	}

	o_pas_num = scheme->num_passes;
	
	return 0;
}

void cleanup_scheme(wipe_scheme_t *scheme) 
{
	if (!scheme) {
		return;
	}
	
	if (!scheme->builtin && scheme->pass) {
		free(scheme->pass);
		scheme->pass = NULL;
	}
}

int print_pass_name(char *buf, int buf_len, wipe_scheme_t *scheme, int pass)
{
	int i, x, len;
	
	if (!buf || 2 > buf_len) {
		return -1;
	} else if (!scheme || pass >= scheme->num_passes) {
		buf[0] = 0;
		return 1;
	}
	
	len = scheme->pass[pass].len;
	if (len) {
		for (i = 0, x = 0; i < len; i++) { 
			x += snprintf(buf+x, buf_len-x, "%02X%s", scheme->pass[pass].pat[i], i==len-1 ? "":", ");
		}
		return x;
	}
	
	switch (scheme->pass[pass].type) {
	case PASS_RANDOM:
		return snprintf(buf, buf_len, "%srandom%s", o_use_rand ? "system ":"", o_use_buff ? " pattern" : "" );
	case PASS_COMPLEMENT:
		return snprintf(buf, buf_len, "complementary");
	case PASS_ZERO:
		return snprintf(buf, buf_len, "zeroes");
	case PASS_TEST:
		return snprintf(buf, buf_len, "test");
	default: ;
	}
	buf[0] = 0;
	return 1;
}

int load_scheme(char *filename, wipe_scheme_t *scheme) 
{
	FILE *f;
	char buf[1024];
	int i, x, n, pat[4];

	if (!filename) {
		log_message(LOG_ERR, "Missing scheme filename\n");
		return ERROR;
	}
	f = fopen(filename, "r");
	if (!f) {
		log_message(LOG_ERR, "Could not open scheme file '%s': %s\n", filename, strerror(errno));
		return ERROR;
	}
	scheme->builtin = FALSE;
	scheme->num_passes = 0;
	while (fgets(buf, 1024, f)) {
		/* Make buffer lowercase */
		for (i = 0; i < 1024; i++) {
			if (!buf[i])
				break;
			buf[i] = tolower(buf[i]);
		}		
		/* Look for keywords */
		if (strstr(buf, "random")) {
			scheme->num_passes++;
		} else if (strstr(buf, "complementary")) {
			scheme->num_passes++;
		} else if (strstr(buf, "test")) {
			scheme->num_passes++;
		} else if (strstr(buf, "zero")) {
			scheme->num_passes++;
		} else {
			x = sscanf(buf, "%d.%x,%x,%x,%x", &i, pat, pat+1, pat+2, pat+3);
			if (x > 1) {
				scheme->num_passes++;
			}
		}
	}
	if (!scheme->num_passes) {
		log_message(LOG_ERR, "No passes defined in '%s' scheme file\n", filename);
		return ERROR;
	}

	scheme->pass = (pass_s *)malloc(sizeof(pass_s) * scheme->num_passes);
	if (!scheme->pass) {
		log_message(LOG_ERR, "Error allocating memory for a scheme\n");
		return ERROR;
	}
	memset(scheme->pass, 0, sizeof(pass_s)*scheme->num_passes);

	fseek(f, 0, SEEK_SET);
	n = 0;
	while (fgets(buf, 1024, f)) {
		/* Make buffer lowercase */
		for (i = 0; i < 1024; i++) {
			if (!buf[i])
				break;
			buf[i] = tolower(buf[i]);
		}		

		/* Look for keywords */
		if (strstr(buf, "random")) {
			scheme->pass[n].len  = 0;
			scheme->pass[n].pat  = NULL;
			scheme->pass[n].type = PASS_RANDOM;
			scheme->pass[n].verify = strstr(buf, "verify") ? 1 : 0;
			n++;
		} else if (strstr(buf, "complement")) {
			scheme->pass[n].len  = 0;
			scheme->pass[n].pat  = NULL;
			scheme->pass[n].type = PASS_COMPLEMENT;
			scheme->pass[n].verify = strstr(buf, "verify") ? 1 : 0;
			n++;
		} else if (strstr(buf, "test")) {
			scheme->pass[n].len  = 0;
			scheme->pass[n].pat  = NULL;
			scheme->pass[n].type = PASS_TEST;
			scheme->pass[n].verify = strstr(buf, "verify") ? 1 : 0;
			n++;
		} else if (strstr(buf, "zero")) {
			scheme->pass[n].len  = 0;
			scheme->pass[n].pat  = NULL;
			scheme->pass[n].type = PASS_ZERO;
			scheme->pass[n].verify = strstr(buf, "verify") ? 1 : 0;
			n++;
		} else {
			x = sscanf(buf, "%d.%x,%x,%x,%x", &i, pat, pat+1, pat+2, pat+3);
			if (x > 1) {
				scheme->pass[n].len  = x - 1;
				scheme->pass[n].pat  = (char *)(&scheme->pass[n].type);
				scheme->pass[n].pat[0] = pat[0] & 0xFF;
				scheme->pass[n].pat[1] = pat[1] & 0xFF;
				scheme->pass[n].pat[2] = pat[2] & 0xFF;
				scheme->pass[n].pat[3] = pat[3] & 0xFF;
				scheme->pass[n].verify = strstr(buf, "verify") ? 1 : 0;
				n++;
			}
		}
	}

	fclose(f);

	return OK;
}
