// build.rs — executado pelo Cargo antes de compilar o crate.
//
// Aqui é onde a arquitetura polyglot realmente se conecta: pedimos pro
// crate `cc` compilar o código C dos drivers e linkar estaticamente
// dentro da biblioteca Rust final. É assim que o core Rust vai integrar
// com bibliotecas C/C++ reais (SoapySDR, librtlsdr) mais adiante —
// aqui ainda é só o stub_device sintético, pra validar o mecanismo.

fn main() {
    cc::Build::new()
        .file("../drivers/stub/stub_device.c")
        .include("../drivers/stub")
        .compile("stub_device");

    // Recompila se o C mudar, não só quando o Rust mudar.
    println!("cargo:rerun-if-changed=../drivers/stub/stub_device.c");
    println!("cargo:rerun-if-changed=../drivers/stub/stub_device.h");
}
