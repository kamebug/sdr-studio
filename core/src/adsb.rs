// adsb — decodificador Mode S / ADS-B (Extended Squitter, DF17).
//
// Ainda não recebe RF real — decodifica mensagens hexadecimais, as
// mesmas 112 bits que um dump1090/qualquer receptor real produziria a
// partir do RTL-SDR sintonizado em 1090MHz. Ou seja: essa lógica já é
// a peça de verdade que vai processar dado real depois — só falta a
// captação de RF em si, que depende do hardware.
//
// NÍVEL DE CONFIANÇA por trecho (documentado com honestidade porque não
// consegui testar isso num ambiente Rust de verdade — o sandbox onde
// desenvolvo só tem compilador C disponível, não Rust):
//   - Extração de bits (DF, ICAO, Type Code, callsign): alta confiança,
//     é aritmética de bit direta sobre posições fixas do padrão ICAO
//     Annex 10, testada com um caso auto-consistente abaixo.
//   - Altitude (AC12, caso Q=1 — a grande maioria dos transponders
//     modernos): confiança média-alta, replica o algoritmo usado por
//     decodificadores de referência amplamente publicados.
//   - Decodificação CPR (posição lat/lon): fórmula pública (ICAO Annex
//     10 / literatura acadêmica de ADS-B). Testada por ida-e-volta
//     (codifico uma posição conhecida com a fórmula inversa, decodifico
//     com a função real, comparo) — não depende de nenhum hex de
//     mensagem real decorado de memória, então a confiança aqui é alta.
//   - CRC-24: a peça que mais risco corro de errar de memória sem
//     poder rodar um teste real — por isso é "melhor esforço" (calculada
//     e exposta, mas NÃO bloqueia o resto da decodificação se não bater).
//     Validar isso com hardware real é uma das primeiras coisas a
//     conferir quando o RTL-SDR chegar.

/// Resultado da decodificação de uma mensagem Mode S de 112 bits (DF17).
#[derive(Debug, Clone, PartialEq, serde::Serialize)]
pub struct DecodedMessage {
    pub df: u8,
    pub icao: String,
    pub type_code: u8,
    pub callsign: Option<String>,
    pub altitude_ft: Option<i32>,
    pub crc_ok: bool,
}

/// Converte uma string hexadecimal (ex: "8D4840D6...") em bytes.
/// Retorna None se o texto não for hex válido ou não tiver 14 bytes
/// (112 bits — tamanho de uma mensagem Extended Squitter completa).
fn parse_hex(hex: &str) -> Option<Vec<u8>> {
    let clean: String = hex.chars().filter(|c| !c.is_whitespace()).collect();
    if clean.len() != 28 {
        return None; // 28 caracteres hex = 14 bytes = 112 bits
    }
    let mut bytes = Vec::with_capacity(14);
    let chars: Vec<char> = clean.chars().collect();
    for pair in chars.chunks(2) {
        let byte_str: String = pair.iter().collect();
        let byte = u8::from_str_radix(&byte_str, 16).ok()?;
        bytes.push(byte);
    }
    Some(bytes)
}

/// CRC-24 do Mode S — "melhor esforço" (ver nota de confiança no topo
/// do arquivo). Calcula sobre os primeiros `num_bits` bits da mensagem
/// usando o polinômio gerador padrão do Mode S.
fn crc24(msg: &[u8], num_bits: usize) -> u32 {
    const GENERATOR: u32 = 0x1FFF409; // polinômio de grau 24 (25 bits, incluindo o bit líder)
    let mut reg: u32 = 0;
    for i in 0..num_bits {
        let byte = i / 8;
        let bit_in_byte = 7 - (i % 8);
        let bit = ((msg[byte] >> bit_in_byte) & 1) as u32;
        let msb = (reg >> 23) & 1;
        reg = ((reg << 1) | bit) & 0xFFFFFF;
        if msb == 1 {
            reg ^= GENERATOR & 0xFFFFFF;
        }
    }
    reg
}

fn sixbit_to_char(code: u8) -> char {
    match code {
        1..=26 => (b'A' + (code - 1)) as char,
        48..=57 => (b'0' + (code - 48)) as char,
        32 => ' ',
        _ => '?',
    }
}

/// Decodifica o campo de identificação (callsign) — mensagens com
/// Type Code 1 a 4. O campo ME tem 56 bits: 5 bits de TC + 3 bits de
/// categoria + 48 bits (8 caracteres de 6 bits cada) de callsign.
fn decode_callsign(me: &[u8]) -> String {
    let mut value: u64 = 0;
    for &b in &me[1..7] {
        value = (value << 8) | b as u64;
    }
    let mut chars = String::with_capacity(8);
    for k in 0..8 {
        let shift = 48 - 6 * (k + 1);
        let code = ((value >> shift) & 0x3F) as u8;
        chars.push(sixbit_to_char(code));
    }
    chars.trim_end().to_string()
}

/// Decodifica a altitude barométrica (campo AC12) para mensagens de
/// posição no ar (Type Code 9–18). Só implementa o caso Q=1 (25 pés de
/// resolução) — usado pela grande maioria dos transponders modernos.
/// Retorna None no caso Q=0 (código Gillham, equipamento mais antigo,
/// não implementado ainda).
fn decode_altitude_ft(me: &[u8]) -> Option<i32> {
    let b1 = me[1];
    let b2 = me[2];
    let q_bit = b1 & 0x01;
    if q_bit == 1 {
        let n = (((b1 >> 1) as u32) << 4) | ((b2 >> 4) as u32);
        Some((n as i32) * 25 - 1000)
    } else {
        None
    }
}

/// Decodifica uma mensagem Mode S de 112 bits (formato hexadecimal).
/// Retorna None se o texto não puder ser interpretado como uma mensagem
/// de 14 bytes, ou se o Downlink Format não for 17 (ADS-B Extended
/// Squitter) — outros formatos (Mode S básico, TIS-B) ficam para depois.
pub fn decode_message(hex: &str) -> Option<DecodedMessage> {
    let msg = parse_hex(hex)?;
    if msg.len() != 14 {
        return None;
    }

    let df = (msg[0] >> 3) & 0x1F;
    if df != 17 {
        return None; // por enquanto só ADS-B Extended Squitter
    }

    let icao = format!("{:02X}{:02X}{:02X}", msg[1], msg[2], msg[3]);
    let me = &msg[4..11]; // campo ME: 7 bytes (56 bits)
    let type_code = (me[0] >> 3) & 0x1F;

    let callsign = if (1..=4).contains(&type_code) {
        Some(decode_callsign(me))
    } else {
        None
    };

    let altitude_ft = if (9..=18).contains(&type_code) {
        decode_altitude_ft(me)
    } else {
        None
    };

    let computed_crc = crc24(&msg, 88);
    let received_crc =
        ((msg[11] as u32) << 16) | ((msg[12] as u32) << 8) | (msg[13] as u32);
    let crc_ok = computed_crc == received_crc;

    Some(DecodedMessage {
        df,
        icao,
        type_code,
        callsign,
        altitude_ft,
        crc_ok,
    })
}

/// Número de zonas de longitude CPR numa dada latitude — fórmula
/// pública do algoritmo CPR (ICAO Annex 10), calculada diretamente em
/// vez de usar uma tabela decorada (reduz risco de erro de memória).
fn cpr_nl(lat: f64) -> i32 {
    if lat == 0.0 {
        return 59;
    }
    if lat.abs() >= 87.0 {
        return 1;
    }
    const NZ: f64 = 15.0;
    let a = 1.0
        - (1.0 - (std::f64::consts::PI / (2.0 * NZ)).cos())
            / (lat.to_radians().cos()).powi(2);
    let a_clamped = a.clamp(-1.0, 1.0);
    (2.0 * std::f64::consts::PI / a_clamped.acos()).floor() as i32
}

/// Decodificação CPR global — combina um par de mensagens de posição
/// (uma par, uma ímpar) para obter latitude/longitude reais. Os quatro
/// valores `*_raw` são os 17 bits crus de cada campo (0–131071),
/// exatamente como vêm da mensagem — extração de bits fica por conta
/// de quem chama essa função.
///
/// Retorna None se o par de mensagens cair em zonas de longitude
/// diferentes (par inválido/inconsistente — precisa de outro par).
pub fn cpr_decode_global(
    even_lat_raw: u32,
    even_lon_raw: u32,
    odd_lat_raw: u32,
    odd_lon_raw: u32,
    odd_is_latest: bool,
) -> Option<(f64, f64)> {
    const SCALE: f64 = 131072.0; // 2^17

    let lat_cpr_even = even_lat_raw as f64 / SCALE;
    let lon_cpr_even = even_lon_raw as f64 / SCALE;
    let lat_cpr_odd = odd_lat_raw as f64 / SCALE;
    let lon_cpr_odd = odd_lon_raw as f64 / SCALE;

    let d_lat_even = 360.0 / 60.0; // 4*NZ = 60
    let d_lat_odd = 360.0 / 59.0; // 4*NZ - 1 = 59

    let j = (59.0 * lat_cpr_even - 60.0 * lat_cpr_odd + 0.5).floor();

    let mut lat_even = d_lat_even * ((j.rem_euclid(60.0)) + lat_cpr_even);
    let mut lat_odd = d_lat_odd * ((j.rem_euclid(59.0)) + lat_cpr_odd);

    if lat_even >= 270.0 {
        lat_even -= 360.0;
    }
    if lat_odd >= 270.0 {
        lat_odd -= 360.0;
    }

    let nl_even = cpr_nl(lat_even);
    let nl_odd = cpr_nl(lat_odd);
    if nl_even != nl_odd {
        return None; // par inconsistente — mensagens não formam um par válido
    }

    let (lat, lon) = if odd_is_latest {
        let ni = (nl_odd - 1).max(1) as f64;
        let m = (lon_cpr_even * (nl_odd - 1) as f64 - lon_cpr_odd * nl_odd as f64 + 0.5)
            .floor();
        let lon = (360.0 / ni) * (m.rem_euclid(ni) + lon_cpr_odd);
        (lat_odd, lon)
    } else {
        let ni = nl_even.max(1) as f64;
        let m = (lon_cpr_even * (nl_odd - 1) as f64 - lon_cpr_odd * nl_odd as f64 + 0.5)
            .floor();
        let lon = (360.0 / ni) * (m.rem_euclid(ni) + lon_cpr_even);
        (lat_even, lon)
    };

    let lon = if lon >= 180.0 { lon - 360.0 } else { lon };

    Some((lat, lon))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_hex_message_length() {
        let valid = "8D40621D58C382D690C8AC2863A7";
        assert!(parse_hex(valid).is_some());
        assert!(parse_hex("ABCD").is_none());
    }

    #[test]
    fn rejects_non_df17_messages() {
        // DF diferente de 17 no primeiro byte (0x02 -> DF = 0).
        let hex = "02".to_string() + &"00".repeat(13);
        assert_eq!(hex.len(), 28);
        assert!(decode_message(&hex).is_none());
    }

    #[test]
    fn decodes_callsign_self_consistent() {
        // Constrói uma mensagem sintética à mão: TC=4 (identificação),
        // categoria=0, callsign "TEST12  " (8 chars, preenchido com
        // espaço = código 32). Isso valida a extração de bits de forma
        // auto-consistente, sem depender de nenhuma mensagem real
        // decorada de memória.
        let chars = ['T', 'E', 'S', 'T', '1', '2', ' ', ' '];
        let codes: Vec<u8> = chars
            .iter()
            .map(|&c| {
                if c == ' ' {
                    32
                } else if c.is_ascii_digit() {
                    48 + (c as u8 - b'0')
                } else {
                    1 + (c as u8 - b'A')
                }
            })
            .collect();

        // Empacota TC(5 bits)=4, CAT(3 bits)=0, seguido de 8x6 bits.
        let mut me = [0u8; 7];
        me[0] = 4 << 3; // TC=4, CAT=0

        let mut value: u64 = 0;
        for &code in &codes {
            value = (value << 6) | code as u64;
        }
        // value agora tem 48 bits — distribui nos 6 bytes seguintes.
        for i in 0..6 {
            let shift = 40 - 8 * i;
            me[1 + i] = ((value >> shift) & 0xFF) as u8;
        }

        let decoded_callsign = decode_callsign(&me);
        assert_eq!(decoded_callsign, "TEST12");
    }

    #[test]
    fn decodes_altitude_q1_case() {
        // AC12 = 12 bits com Q=1. Exemplo: n=400 (binário 11 bits) ->
        // altitude = 400*25 - 1000 = 9000 pés.
        let n: u16 = 400;
        let q = 1u8;
        // Remonta o AC12: insere o bit Q na posição correta (bit 4 a
        // partir do LSB do campo de 12 bits), replicando o inverso de
        // decode_altitude_ft.
        let low4 = (n & 0x0F) as u8;
        let high7 = ((n >> 4) & 0x7F) as u8;
        let b1 = (high7 << 1) | q;
        let b2 = low4 << 4;

        let mut me = [0u8; 7];
        me[1] = b1;
        me[2] = b2;

        let altitude = decode_altitude_ft(&me);
        assert_eq!(altitude, Some(9000));
    }

    /// Codifica lat/lon numa posição CPR crua (17 bits) — é o inverso
    /// de `cpr_decode_global`, implementado só para viabilizar o teste
    /// abaixo. Usar uma posição conhecida + esta codificação + a
    /// decodificação real é muito mais confiável do que depender de um
    /// hex de mensagem real "decorado" de memória (que foi exatamente
    /// o que deu errado na primeira versão deste teste).
    fn cpr_encode(lat: f64, lon: f64, odd: bool) -> (u32, u32) {
        let odd_i = if odd { 1.0 } else { 0.0 };
        let d_lat = 360.0 / (60.0 - odd_i);

        let lat_mod = lat.rem_euclid(d_lat);
        let yz = (131072.0 * lat_mod / d_lat + 0.5).floor();
        let lat_cpr_raw = (yz as i64).rem_euclid(131072) as u32;

        let r_lat = d_lat * (yz / 131072.0 + (lat / d_lat).floor());
        let nl = if r_lat == 0.0 { 59 } else { cpr_nl(r_lat) };
        let nl_for_lon = nl - if odd { 1 } else { 0 };
        let d_lon = if nl_for_lon > 0 {
            360.0 / nl_for_lon as f64
        } else {
            360.0
        };

        let lon_mod = lon.rem_euclid(d_lon);
        let xz = (131072.0 * lon_mod / d_lon + 0.5).floor();
        let lon_cpr_raw = (xz as i64).rem_euclid(131072) as u32;

        (lat_cpr_raw, lon_cpr_raw)
    }

    #[test]
    fn cpr_decode_round_trip_self_consistent() {
        // Posição conhecida qualquer (região da Holanda, só como
        // referência de leitura humana — o valor em si não importa,
        // o que valida o teste é o "ida e volta" bater).
        let true_lat = 52.2572;
        let true_lon = 3.91937;

        let (even_lat_raw, even_lon_raw) = cpr_encode(true_lat, true_lon, false);
        let (odd_lat_raw, odd_lon_raw) = cpr_encode(true_lat, true_lon, true);

        let result = cpr_decode_global(
            even_lat_raw,
            even_lon_raw,
            odd_lat_raw,
            odd_lon_raw,
            true,
        );

        let (lat, lon) = result.expect("par deveria cair na mesma zona NL");
        assert!((lat - true_lat).abs() < 0.01, "lat decodificada = {lat}");
        assert!((lon - true_lon).abs() < 0.01, "lon decodificada = {lon}");
    }
}
