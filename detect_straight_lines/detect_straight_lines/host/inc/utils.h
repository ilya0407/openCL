#ifndef __UTILS_H_
#define __UTILS_H_

struct pixel {
   unsigned char b;
   unsigned char g;
   unsigned char r;
};

void write_bmp(char* filename, unsigned char* header, struct pixel* data);
void write_bmp2(const char* filename, unsigned char* header, unsigned char* data);
bool read_bmp(const char* filename, unsigned char* header, struct pixel** data);
double get_wall_time();

#endif
