using GNSSSignals, Tracking, GNSSReceiver, Unitful
using SoapySDR, SoapyLMS7_jll
using SoapySDR: dB
include("../xtrx_julia/software/scripts/libsigflow.jl")
gpsl1 = GPSL1()

sampling_freq = 5.0u"MHz"
one_ms_samples = Int(upreferred(sampling_freq * 1u"ms"))
num_samples = Int(upreferred(sampling_freq * 10u"s"))

Device(first(Devices())) do dev
    chan = dev.rx[1]

    chan.frequency = 1575.42u"MHz"
    chan.sample_rate = sampling_freq
    chan.bandwidth = sampling_freq
    chan.gain = 61dB

    stream = SoapySDR.Stream(ComplexF32, chan)
    # Getting samples in chunks of `mtu`
    c = stream_data(stream, num_samples)
    # Resizing the chunks to 1ms in length
    c = rechunk(c, one_ms_samples)
    # Inserts diagnostics
    #c = log_stream_xfer(c)

    vec_c = Channel{Vector{ComplexF32}}()
    @async consume_channel(c) do buff
        put!(vec_c, vec(buff))
    end

    # Performing GNSS acquisition and tracking
    data_channel, gui_channel = receive(vec_c, gpsl1, sampling_freq)

    # Display the GUI and block
    GNSSReceiver.gui(gui_channel)

    consume_channel(data_channel) do buff
    end

    # Keep this so we don't segfault right now
    sleep(1)
end
