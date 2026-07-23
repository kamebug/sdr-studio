#ifndef STUB_DEVICE_H
#define STUB_DEVICE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * stub_device — simula uma fonte de amostras de rádio (o que futuramente
 * virá de verdade do RTL-SDR via SoapySDR/librtlsdr).
 *
 * Gera uma onda senoidal sintética, útil para validar toda a cadeia
 * C -> Rust -> Dart sem precisar de hardware físico conectado.
 *
 * buffer:      ponteiro para onde as amostras serão escritas (já alocado pelo chamador)
 * len:         quantidade de amostras a gerar
 * sample_rate: taxa de amostragem em Hz (ex: 48000.0)
 * freq:        frequência do tom sintético em Hz (ex: 1000.0)
 */
void stub_device_generate(float* buffer, int32_t len, float sample_rate, float freq);

#ifdef __cplusplus
}
#endif

#endif // STUB_DEVICE_H
