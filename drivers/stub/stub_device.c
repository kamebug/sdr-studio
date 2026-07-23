#include "stub_device.h"
#include <math.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

void stub_device_generate(float* buffer, int32_t len, float sample_rate, float freq) {
    for (int32_t i = 0; i < len; i++) {
        float t = (float)i / sample_rate;
        buffer[i] = sinf(2.0f * (float)M_PI * freq * t);
    }
}
