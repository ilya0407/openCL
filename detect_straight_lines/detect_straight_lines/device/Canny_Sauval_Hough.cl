#define COLS 720
#define ROWS 540
#define SR_LENGTH_5x5 (4 * COLS + 5)

#define SR_INIT_CYCLES_5x5 (2 * COLS + 3)

#define INITIALIZATION_CYCLES (SR_INIT_CYCLES_5x5 - 1)

struct pixel {
   unsigned char b;
   unsigned char g;
   unsigned char r;
};

__kernel
void edgedetect(global const struct pixel* restrict image_in, global unsigned char* restrict image_out,
	const int iterations, const short low_threshold, const short high_threshold)
{
	// Filter coefficients
	unsigned char gaussian[5][5] = { {2,4,5,4,2},{4,9,12,9,4},{5,12,15,12,5},{4,9,12,9,4},{2,4,5,4,2} };
	unsigned char Cx[3][3] = { {-1, 0, 1},{-2, 0, 2},{-1, 0, 1} };
	unsigned char Cy[3][3] = { {-1,-2,-1},{ 0, 0, 0},{ 1, 2, 1} };
	
	// Pixel buffer of 4 rows and 5 extra pixels for doing 5x5 box operations
	unsigned char rows_gaus[SR_LENGTH_5x5];
	unsigned char rows_sobel[SR_INIT_CYCLES_5x5];
	unsigned char rows_non_max[SR_INIT_CYCLES_5x5];
	unsigned char theta[SR_INIT_CYCLES_5x5];
	unsigned char rows_thres[SR_INIT_CYCLES_5x5];

	int count = -INITIALIZATION_CYCLES;
	int nth_pixel = 0;

	int x, y;
	unsigned int height = iterations / COLS;
	int numerator, denominator;
	float cx, cy;
	int temp = 0;
    float sum = 0, avg, k = 0.2, sygma = 0, R = 128;
    unsigned short threshold;

	float angle;
	const float PI = 3.14159265;

	while (count != iterations + 3 * COLS + 3) {

		// Shift registers
		#pragma unroll
		for (int i = SR_LENGTH_5x5 - 1; i > 0; --i) {
			rows_gaus[i] = rows_gaus[i - 1];
		}

		/// Load pixel + Grayscale Conversion
		unsigned char pixel_grayscale_8bit = 0;

		if (count < (iterations - INITIALIZATION_CYCLES)) {
			struct pixel pixel_color_24bit = image_in[nth_pixel++];
			pixel_grayscale_8bit = ((unsigned short)pixel_color_24bit.r + (unsigned short)pixel_color_24bit.g + (unsigned short)pixel_color_24bit.b) / 3;
		}

		rows_gaus[0] = pixel_grayscale_8bit;

		// As a placeholder, do a null operation (simply pass on the grayscale pixel 
		// at the center of the frame to image_out). You should replace the code
		// to carry out the necessary box operations before outputting to image_out.
		if (count >= 0 && count < iterations) {
			#pragma unroll
			for (int i = SR_INIT_CYCLES_5x5 - 1; i > 0; --i) {
				rows_sobel[i] = rows_sobel[i - 1];
			}

			numerator = 0;
			denominator = 0;
			x = count % COLS;
			y = count / COLS;

			#pragma unroll
			for (int i = -2; i <= 2; ++i) {
				#pragma unroll
				for (int j = -2; j <= 2; ++j) {
					if ((x + j) >= 0 && (x + j) < COLS && (y + i) >= 0 && (y + i) < height) {
						numerator += rows_gaus[SR_LENGTH_5x5 - 1 - ((2 + i) * COLS + (2 + j))] * gaussian[i + 2][j + 2];
						denominator += gaussian[i + 2][j + 2];
					}
				}
			}
		
			rows_sobel[0] = numerator / denominator;
		}

		if (count >= COLS + 1 && count < iterations + COLS + 1) {
			cx = 0;
			cy = 0;
			x = (count - (COLS + 1)) % COLS;
			y = (count - (COLS + 1)) / COLS;

			#pragma unroll
			for (int i = -1; i <= 1; ++i) {
				#pragma unroll
				for (int j = -1; j <= 1; ++j) {
					if ((x + j) >= 0 && (x + j) < COLS && (y + i) >= 0 && (y + i) < height) {
						cx += rows_sobel[SR_INIT_CYCLES_5x5 - 1 - ((1 + i) * COLS + (1 + j))] * Cx[i + 1][j + 1];
						cy += rows_sobel[SR_INIT_CYCLES_5x5 - 1 - ((1 + i) * COLS + (1 + j))] * Cy[i + 1][j + 1];
					}
				}
			}

			#pragma unroll
			for (int i = SR_INIT_CYCLES_5x5 - 1; i > 0; --i) {
				rows_non_max[i] = rows_non_max[i - 1];
				theta[i] = theta[i - 1];
			}
				 
			temp = fabs(cx) + fabs(cy);
			rows_non_max[0] = (unsigned char)temp; 
			angle = atan2(cy, cx);

			if (angle < 0) {
				angle = fmod((angle + 2 * PI), (2 * PI));
			}

			if (angle <= PI / 8)
			{
				theta[0] = 0;
			}
			else if (angle <= 3 * PI / 8)
			{
				theta[0] = 45;
			}
			else if (angle <= 5 * PI / 8)
			{
				theta[0] = 90;
			}
			else if (angle <= 7 * PI / 8)
			{
				theta[0] = 135;
			}
			else if (angle <= 9 * PI / 8)
			{
				theta[0] = 0;
			}
			else if (angle <= 11 * PI / 8)
			{
				theta[0] = 45;
			}
			else if (angle <= 13 * PI / 8)
			{
				theta[0] = 90;
			}
			else if (angle <= 15 * PI / 8)
			{
				theta[0] = 135;
			}
			else 
			{
				theta[0] = 0;
			}
		}

		if (count >= 2 * COLS + 2 && count < iterations + 2 * COLS + 2) {
			#pragma unroll
			for (int i = SR_INIT_CYCLES_5x5 - 1; i > 0; --i) {
				rows_thres[i] = rows_thres[i - 1];
			}

			switch (theta[COLS + 1]) {
			case 0:
				if (rows_non_max[COLS + 1] <= rows_non_max[COLS] ||
					rows_non_max[COLS + 1] <= rows_non_max[COLS + 2]) {
					rows_thres[0] = 0;
				}
				else {
					rows_thres[0] = rows_non_max[COLS + 1];
				}
				break;
			case 45:
				if (rows_non_max[COLS + 1] <= rows_non_max[1] ||
					rows_non_max[COLS + 1] <= rows_non_max[2 * COLS + 1]) {
					rows_thres[0] = 0;
				}
				else {
					rows_thres[0] = rows_non_max[COLS + 1];
				}
				break;
			case 90:
				if (rows_non_max[COLS + 1] <= rows_non_max[2] ||
					rows_non_max[COLS + 1] <= rows_non_max[2 * COLS]) {
					rows_thres[0] = 0;
				}
				else {
					rows_thres[0] = rows_non_max[COLS + 1];
				}
				break;
			case 135:
				if (rows_non_max[COLS + 1] <= rows_non_max[0] ||
					rows_non_max[COLS + 1] <= rows_non_max[2 * COLS + 2]) {
					rows_thres[0] = 0;
				}
				else {
					rows_thres[0] = rows_non_max[COLS + 1];
				}
				break;
			default:
				rows_thres[0] = rows_non_max[COLS + 1];
				break;
			}
		}

		if (count >= 3 * COLS + 3 && count < iterations + 3 * COLS + 3) {
            sum = 0;
            sygma = 0;
            for (int i = 0; i < 3; ++i) {
                for(int j = 0; j < 3; ++j){
                    sum += (float)rows_thres[i * COLS + j];
                }
            }
            avg = sum / 9;
            for (int i = 0; i < 3; ++i) {
                for(int j = 0; j < 3; ++j){
                    sygma += ((float)rows_thres[i * COLS + j] - avg) * ((float)rows_thres[i * COLS + j] - avg);
                }
            }
            sygma /= 9;
            sygma = sqrt(sygma);
            threshold = (short)(avg * (1 + k * (sygma / R - 1)));

			if (rows_thres[COLS + 1] > threshold) {
				image_out[count - (3 * COLS + 3)] = 255;
			}
			else {
				image_out[count - (3 * COLS + 3)] = 0;
			}
		}
		count++;
	}
}

#define X_START -COLS/2
#define Y_START -ROWS/2
#define X_END COLS/2
#define Y_END 0

#define RHO_RESOLUTION 1
#define RHOS (900/RHO_RESOLUTION)
#define THETAS 180

constant float sinvals[180] = {0.0, 0.01745240643728351, 0.03489949670250097, 0.05233595624294383, 0.0697564737441253, 0.08715574274765817, 0.10452846326765346, 0.12186934340514748, 0.13917310096006544, 0.15643446504023087, 0.17364817766693033, 0.1908089953765448, 0.20791169081775931, 0.224951054343865, 0.24192189559966773, 0.25881904510252074, 0.27563735581699916, 0.29237170472273677, 0.3090169943749474, 0.32556815445715664, 0.3420201433256687, 0.35836794954530027, 0.374606593415912, 0.3907311284892737, 0.40673664307580015, 0.42261826174069944, 0.4383711467890774, 0.45399049973954675, 0.4694715627858908, 0.48480962024633706, 0.49999999999999994, 0.5150380749100542, 0.5299192642332049, 0.5446390350150271, 0.5591929034707469, 0.573576436351046, 0.5877852522924731, 0.6018150231520483, 0.6156614753256582, 0.6293203910498374, 0.6427876096865393, 0.6560590289905072, 0.6691306063588582, 0.6819983600624985, 0.6946583704589973, 0.7071067811865475, 0.7193398003386511, 0.7313537016191705, 0.7431448254773941, 0.754709580222772, 0.766044443118978, 0.7771459614569708, 0.788010753606722, 0.7986355100472928, 0.8090169943749475, 0.8191520442889918, 0.8290375725550417, 0.8386705679454239, 0.848048096156426, 0.8571673007021122, 0.8660254037844386, 0.8746197071393957, 0.8829475928589269, 0.8910065241883678, 0.898794046299167, 0.9063077870366499, 0.9135454576426009, 0.9205048534524403, 0.9271838545667874, 0.9335804264972017, 0.9396926207859083, 0.9455185755993167, 0.9510565162951535, 0.9563047559630354, 0.9612616959383189, 0.9659258262890683, 0.9702957262759965, 0.9743700647852352, 0.9781476007338056, 0.981627183447664, 0.984807753012208, 0.9876883405951378, 0.9902680687415703, 0.992546151641322, 0.9945218953682733, 0.9961946980917455, 0.9975640502598242, 0.9986295347545738, 0.9993908270190958, 0.9998476951563913, 1.0, 0.9998476951563913, 0.9993908270190958, 0.9986295347545738, 0.9975640502598242, 0.9961946980917455, 0.9945218953682734, 0.9925461516413221, 0.9902680687415704, 0.9876883405951377, 0.984807753012208, 0.981627183447664, 0.9781476007338057, 0.9743700647852352, 0.9702957262759965, 0.9659258262890683, 0.9612616959383189, 0.9563047559630355, 0.9510565162951536, 0.9455185755993168, 0.9396926207859084, 0.9335804264972017, 0.9271838545667874, 0.9205048534524404, 0.913545457642601, 0.90630778703665, 0.8987940462991669, 0.8910065241883679, 0.8829475928589271, 0.8746197071393959, 0.8660254037844387, 0.8571673007021123, 0.8480480961564261, 0.8386705679454239, 0.8290375725550417, 0.819152044288992, 0.8090169943749475, 0.7986355100472927, 0.788010753606722, 0.777145961456971, 0.766044443118978, 0.7547095802227718, 0.7431448254773942, 0.7313537016191706, 0.7193398003386514, 0.7071067811865476, 0.6946583704589971, 0.6819983600624986, 0.6691306063588583, 0.6560590289905073, 0.6427876096865395, 0.6293203910498377, 0.6156614753256584, 0.6018150231520482, 0.5877852522924732, 0.5735764363510464, 0.5591929034707469, 0.544639035015027, 0.5299192642332049, 0.5150380749100544, 0.49999999999999994, 0.48480962024633717, 0.4694715627858911, 0.45399049973954686, 0.4383711467890773, 0.4226182617406995, 0.40673664307580043, 0.39073112848927416, 0.37460659341591224, 0.3583679495453002, 0.3420201433256689, 0.32556815445715703, 0.3090169943749475, 0.29237170472273705, 0.27563735581699966, 0.258819045102521, 0.24192189559966773, 0.22495105434386478, 0.20791169081775931, 0.19080899537654497, 0.17364817766693028, 0.15643446504023098, 0.13917310096006574, 0.12186934340514755, 0.10452846326765373, 0.08715574274765864, 0.06975647374412552, 0.05233595624294381, 0.0348994967025007, 0.01745240643728344};
constant float cosvals[180] = {1.0, 0.9998476951563913, 0.9993908270190958, 0.9986295347545738, 0.9975640502598242, 0.9961946980917455, 0.9945218953682733, 0.992546151641322, 0.9902680687415704, 0.9876883405951378, 0.984807753012208, 0.981627183447664, 0.9781476007338057, 0.9743700647852352, 0.9702957262759965, 0.9659258262890683, 0.9612616959383189, 0.9563047559630354, 0.9510565162951535, 0.9455185755993168, 0.9396926207859084, 0.9335804264972017, 0.9271838545667874, 0.9205048534524404, 0.9135454576426009, 0.9063077870366499, 0.898794046299167, 0.8910065241883679, 0.882947592858927, 0.8746197071393957, 0.8660254037844387, 0.8571673007021123, 0.848048096156426, 0.838670567945424, 0.8290375725550416, 0.8191520442889918, 0.8090169943749475, 0.7986355100472928, 0.788010753606722, 0.7771459614569709, 0.766044443118978, 0.7547095802227721, 0.7431448254773942, 0.7313537016191706, 0.7193398003386512, 0.7071067811865476, 0.6946583704589974, 0.6819983600624985, 0.6691306063588582, 0.6560590289905073, 0.6427876096865394, 0.6293203910498375, 0.6156614753256583, 0.6018150231520484, 0.5877852522924731, 0.5735764363510462, 0.5591929034707468, 0.5446390350150272, 0.5299192642332049, 0.5150380749100544, 0.5000000000000001, 0.4848096202463371, 0.46947156278589086, 0.4539904997395468, 0.43837114678907746, 0.42261826174069944, 0.4067366430758002, 0.39073112848927394, 0.37460659341591196, 0.3583679495453004, 0.3420201433256688, 0.32556815445715676, 0.30901699437494745, 0.29237170472273677, 0.27563735581699916, 0.25881904510252074, 0.2419218955996679, 0.22495105434386492, 0.20791169081775945, 0.19080899537654492, 0.17364817766693041, 0.15643446504023092, 0.1391731009600657, 0.12186934340514749, 0.10452846326765346, 0.08715574274765814, 0.06975647374412546, 0.052335956242943966, 0.03489949670250108, 0.017452406437283376, 6.123233995736766e-17, -0.017452406437283477, -0.03489949670250073, -0.05233595624294362, -0.06975647374412533, -0.08715574274765824, -0.10452846326765333, -0.12186934340514737, -0.13917310096006535, -0.15643446504023104, -0.1736481776669303, -0.1908089953765448, -0.20791169081775912, -0.2249510543438648, -0.24192189559966779, -0.25881904510252085, -0.27563735581699905, -0.29237170472273666, -0.30901699437494734, -0.3255681544571564, -0.3420201433256687, -0.35836794954530027, -0.37460659341591207, -0.3907311284892736, -0.40673664307580004, -0.42261826174069933, -0.4383711467890775, -0.4539904997395467, -0.46947156278589053, -0.484809620246337, -0.4999999999999998, -0.5150380749100543, -0.5299192642332048, -0.5446390350150271, -0.5591929034707467, -0.5735764363510458, -0.587785252292473, -0.6018150231520484, -0.6156614753256583, -0.6293203910498373, -0.6427876096865394, -0.6560590289905075, -0.6691306063588582, -0.6819983600624984, -0.694658370458997, -0.7071067811865475, -0.7193398003386512, -0.7313537016191705, -0.743144825477394, -0.754709580222772, -0.7660444431189779, -0.7771459614569707, -0.7880107536067219, -0.7986355100472929, -0.8090169943749473, -0.8191520442889916, -0.8290375725550416, -0.8386705679454242, -0.848048096156426, -0.8571673007021122, -0.8660254037844387, -0.8746197071393957, -0.8829475928589268, -0.8910065241883678, -0.898794046299167, -0.9063077870366499, -0.9135454576426008, -0.9205048534524402, -0.9271838545667873, -0.9335804264972017, -0.9396926207859083, -0.9455185755993167, -0.9510565162951535, -0.9563047559630354, -0.9612616959383187, -0.9659258262890682, -0.9702957262759965, -0.9743700647852352, -0.9781476007338057, -0.981627183447664, -0.984807753012208, -0.9876883405951377, -0.9902680687415703, -0.992546151641322, -0.9945218953682733, -0.9961946980917455, -0.9975640502598242, -0.9986295347545738, -0.9993908270190958, -0.9998476951563913};

__kernel void houghline(global const unsigned char * restrict image_in, global unsigned short * restrict accum)
{
	int rho = 0;
	int cur_rho, k;
	
	#pragma unroll
	for (int r = -RHOS / 2; r < RHOS / 2; ++r) {
		#pragma	unroll
		for (int theta = 0; theta < THETAS; ++theta) {
			accum[theta * RHOS + (r + RHOS / 2)] = 0;
		}
	}
	
	#pragma unroll
	for (int y = Y_START; y < Y_END; ++y) {
		#pragma	unroll
		for (int x = X_START; x < X_END; ++x) {
	
			if (image_in[(y + ROWS / 2) * COLS + (x + COLS / 2)] > 0) {
				#pragma unroll
				for (int theta = 0; theta < THETAS; ++theta) {
					rho = x * cosvals[theta] + y * sinvals[theta];
					accum[theta * RHOS + (rho + RHOS / 2)]++;
				}
			}
		}
	}
}

