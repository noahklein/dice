package audio

import "core:fmt"
import ma "vendor:miniaudio"

DELAY :: 1
DECAY :: 1

engine: ma.engine
mp3_decoder: ma.decoder
sound: ma.sound
delay_node: ma.delay_node

AUDIO_MOONWALK :: #load("../../assets/moonwalk.mp3")

Clip :: struct { sound: ma.sound }

// See ma.resource_manager_data_source_flags.
// Flag :: enum i32 {
//     Stream = 1 << 0,
//     Async  = 1 << 1,
//     Decode = 1 << 2,
// }
// Flags :: bit_set[Flag]

init :: proc()  {
    if true do return // TODO: sound effects

    if result := ma.engine_init(nil, &engine); result != .SUCCESS {
        fmt.eprintln("Failed to init audio engine:", result)
    }
    if result := ma.engine_start(&engine); result != .SUCCESS {
        fmt.eprintln("Failed to start audio engine:", result)
    }

    decoder_config := ma.decoder_config_init(.f32, 0, 0)
    decoder_config.encodingFormat = .mp3

    result := ma.decoder_init_memory(
        pData = raw_data(AUDIO_MOONWALK),
        dataSize = len(AUDIO_MOONWALK),
        pConfig = &decoder_config,
        pDecoder = &mp3_decoder,
    )
    if result != .SUCCESS {
        fmt.eprintln("Failed to init audio decoder:", result)
    }

    if result := ma.sound_init_from_data_source(&engine, mp3_decoder.ds.pCurrent, 0, nil, &sound); result != .SUCCESS {
        fmt.eprintln("Failed to init sound:", result)
    }

    if result := ma.sound_start(&sound); result != .SUCCESS {
        fmt.eprintln("Failed to play sound:", result)
    }
}

deinit :: proc() {
    ma.sound_uninit(&sound)
    ma.engine_uninit(&engine)
}
